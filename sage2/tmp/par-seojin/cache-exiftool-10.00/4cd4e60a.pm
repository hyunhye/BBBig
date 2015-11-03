#line 1 "C:/Perl/site/lib/PAR/Dist.pm"
# $File: //member/autrijus/PAR-Dist/lib/PAR/Dist.pm $ $Author: autrijus $
# $Revision: #11 $ $Change: 9530 $ $DateTime: 2004/01/01 05:24:09 $

package PAR::Dist;
require Exporter;
use vars qw/$VERSION @ISA @EXPORT/;

$VERSION    = '0.08';
@ISA	    = 'Exporter';
@EXPORT	    = qw/ blib_to_par install_par uninstall_par sign_par verify_par /;

use strict;
use File::Spec;

#line 121

sub blib_to_par {
    @_ = (path => @_) if @_ == 1;

    my %args = @_;
    require Config;

    my $path	= $args{path};
    my $dist	= File::Spec->rel2abs($args{dist}) if $args{dist};
    my $name	= $args{name};
    my $version	= $args{version};
    my $suffix	= $args{suffix} || "$Config::Config{archname}-$Config::Config{version}.par";
    my $cwd;

    if (defined $path) {
	require Cwd;
	$cwd = Cwd::cwd();
	chdir $path;
    }

    _build_blib() unless -d "blib";

    my @files;
    open MANIFEST, ">blib/MANIFEST" or die $!;
    open META, ">blib/META.yml" or die $!;
    
    require File::Find;
    File::Find::find( sub {
	next unless $File::Find::name;
        (-r && !-d) and push ( @files, substr($File::Find::name, 5) );
    } , 'blib' );

    print MANIFEST join(
	"\n",
	'    <!-- accessible as jar:file:///NAME.par!/MANIFEST in compliant browsers -->',
	(sort @files),
	q(    # <html><body onload="var X=document.body.innerHTML.split(/\n/);var Y='<iframe src=&quot;META.yml&quot; style=&quot;float:right;height:40%;width:40%&quot;></iframe><ul>';for(var x in X){if(!X[x].match(/^\s*#/)&&X[x].length)Y+='<li><a href=&quot;'+X[x]+'&quot;>'+X[x]+'</a>'}document.body.innerHTML=Y">)
    );
    close MANIFEST;

    if (open(OLD_META, "META.yml")) {
        while (<OLD_META>) {
            if (/^distribution_type:/) {
                print META "distribution_type: par\n";
            }
            else {
                print META $_;
            }

	    if (/^name:\s+(.*)/) {
		$name ||= $1;
		$name =~ s/::/-/g;
	    }
	    elsif (/^version:\s+(.*)/) {
		$version ||= $1;
	    }
        }
        close OLD_META;
	close META;
    }
    elsif ((!$name or !$version) and open(MAKEFILE, "Makefile")) {
	while (<MAKEFILE>) {
	    if (/^DISTNAME\s+=\s+(.*)$/) {
		$name ||= $1;
	    }
	    elsif (/^VERSION\s+=\s+(.*)$/) {
		$version ||= $1;
	    }
	}
    }

    my $file = "$name-$version-$suffix";
    unlink $file if -f $file;

    print META << "YAML" if fileno(META);
name: $name
version: $version
build_requires: {}
conflicts: {}
dist_name: $file
distribution_type: par
dynamic_config: 0
generated_by: 'PAR::Dist version $PAR::Dist::VERSION'
license: unknown
YAML
    close META;

    mkdir('blib', 0777);
    chdir('blib');
    _zip(dist => File::Spec->catfile(File::Spec->updir, $file)) or die $!;
    chdir(File::Spec->updir);

    unlink "blib/MANIFEST";
    unlink "blib/META.yml";

    $dist ||= File::Spec->catfile($cwd, $file) if $cwd;

    if ($dist and $file ne $dist) {
        rename( $file => $dist );
        $file = $dist;
    }

    my $pathname = File::Spec->rel2abs($file);
    if ($^O eq 'MSWin32') {
        $pathname =~ s!\\!/!g;
        $pathname =~ s!:!|!g;
    };
    print << ".";
Successfully created binary distribution '$file'.
Its contents are accessible in compliant browsers as:
    jar:file://$pathname!/MANIFEST
.

    chdir $cwd if $cwd;
    return $file;
}

sub _build_blib {
    if (-e 'Build') {
	system($^X, "Build");
    }
    elsif (-e 'Makefile') {
	system($Config::Config{make});
    }
    elsif (-e 'Build.PL') {
	system($^X, "Build.PL");
	system($^X, "Build");
    }
    elsif (-e 'Makefile.PL') {
	system($^X, "Makefile.PL");
	system($Config::Config{make});
    }
}

#line 261

sub install_par {
    my %args = &_args;
    _install_or_uninstall(%args, action => 'install');
}

#line 273

sub uninstall_par {
    my %args = &_args;
    _install_or_uninstall(%args, action => 'uninstall');
}

sub _install_or_uninstall {
    my %args = &_args;
    my $name = $args{name};
    my $action = $args{action};
    my ($dist, $tmpdir) = _unzip_to_tmpdir( dist => $args{dist}, subdir => 'blib' );

    if (!$name) {
	open (META, 'blib/META.yml') or return;
	while (<META>) {
	    next unless /^name:\s+(.*)/;
	    $name = $1; last;
	}
	close META;
    }

    if (-d 'script') {
	require ExtUtils::MY;
	foreach my $file (glob("script/*")) {
	    next unless -T $file;
	    ExtUtils::MY->fixin($file);
	    chmod(0555, $file);
	}
    }

    $name =~ s{::|-}{/}g;
    require ExtUtils::Install;

    my $rv;
    if ($action eq 'install') {
	$rv = ExtUtils::Install::install_default($name);
    }
    elsif ($action eq 'uninstall') {
	require Config;
	$rv = ExtUtils::Install::uninstall(
	    "$Config::Config{installsitearch}/auto/$name/.packlist"
	);
    }

    File::Path::rmtree([$tmpdir]);
    return $rv;
}

#line 327

sub sign_par {
    my %args = &_args;
    _verify_or_sign(%args, action => 'sign');
}

#line 342

sub verify_par {
    my %args = &_args;
    $! = _verify_or_sign(%args, action => 'verify');
    return ( $! == Module::Signature::SIGNATURE_OK() );
}

sub _unzip {
    my %args = &_args;
    my $dist = $args{dist};
    my $path = $args{path} || File::Spec->curdir;
    return unless -f $dist;

    if (eval { require Archive::Zip; 1 }) {
        my $zip = Archive::Zip->new;
	$SIG{__WARN__} = sub { print STDERR $_[0] unless $_[0] =~ /\bstat\b/ };
        return unless $zip->read($dist) == Archive::Zip::AZ_OK()
                  and $zip->extractTree('', "$path/") == Archive::Zip::AZ_OK();
    }
    else {
        return if system(unzip => $dist, '-d', $path);
    }
}

sub _zip {
    my %args = &_args;
    my $dist = $args{dist};

    if (eval { require Archive::Zip; 1 }) {
        my $zip = Archive::Zip->new;
        $zip->addTree( File::Spec->curdir, '' );
        $zip->writeToFileNamed( $dist ) == Archive::Zip::AZ_OK() or die $!;
    }
    else {
        system(qw(zip -r), $dist, File::Spec->curdir) and die $!;
    }
}

sub _args {
    unshift @_, (glob('*.par'))[0] unless @_;
    @_ = (dist => @_) if @_ == 1;
    my %args = @_;

    $args{name} ||= $args{dist};
    $args{dist} .= '-' . do {
	require Config;
	$args{suffix} || "$Config::Config{archname}-$Config::Config{version}.par"
    } unless !$args{dist} or $args{dist} =~ /\.[a-zA-Z_][^.]*$/;

    $args{dist} = _fetch(dist => $args{dist})
	if ($args{dist} and $args{dist} =~ m!^\w+://!);
    return %args;
}

my %escapes;
sub _fetch {
    my %args = @_;
    require LWP::Simple;

    $ENV{PAR_TEMP} ||= File::Spec->catdir(File::Spec->tmpdir, 'par');
    mkdir $ENV{PAR_TEMP}, 0777;
    %escapes = map { chr($_) => sprintf("%%%02X", $_) } 0..255 unless %escapes;

    $args{dist} =~ s{^cpan://((([a-zA-Z])[a-zA-Z])[-_a-zA-Z]+)/}
		    {http://www.cpan.org/modules/by-authors/id/\U$3/$2/$1\E/};

    my $file = $args{dist};
    $file =~ s/([^\w\.])/$escapes{$1}/g;
    $file = File::Spec->catfile( $ENV{PAR_TEMP}, $file);
    my $rc = LWP::Simple::mirror( $args{dist}, $file );

    if (!LWP::Simple::is_success($rc)) {
	die "Error $rc: ", LWP::Simple::status_message($rc), " ($args{dist})\n";
    }

    return $file if -e $file;
    return;
}

sub _verify_or_sign {
    my %args = &_args;

    require File::Path;
    require Module::Signature;
    die "Module::Signature version 0.25 required"
	unless Module::Signature->VERSION >= 0.25;

    require Cwd;
    my $cwd = Cwd::cwd();
    my $action = $args{action};
    my ($dist, $tmpdir) = _unzip_to_tmpdir($args{dist});
    $action ||= (-e 'SIGNATURE' ? 'verify' : 'sign');

    if ($action eq 'sign') {
	open FH, '>SIGNATURE' unless -e 'SIGNATURE';
	open FH, 'MANIFEST' or die $!;

	local $/;
	my $out = <FH>;
	if ($out !~ /^SIGNATURE(?:\s|$)/m) {
	    $out =~ s/^(?!\s)/SIGNATURE\n/m;
	    open FH, '>MANIFEST' or die $!;
	    print FH $out;
	}
	close FH;

	$args{overwrite}	= 1 unless exists $args{overwrite};
	$args{skip}		= 0 unless exists $args{skip};
    }

    my $rv = Module::Signature->can($action)->(%args);
    _zip(dist => $dist) if $action eq 'sign';
    File::Path::rmtree([$tmpdir]);

    chdir($cwd);
    return $rv;
}

sub _unzip_to_tmpdir {
    my %args = &_args;

    require File::Temp;

    my $dist   = File::Spec->rel2abs($args{dist});
    my $tmpdir = File::Temp::mkdtemp(File::Spec->catdir(File::Spec->tmpdir, "parXXXXX")) or die $!;
    my $path = $tmpdir;
    $path = File::Spec->catdir($tmpdir, $args{subdir}) if defined $args{subdir};
    _unzip(dist => $dist, path => $path);

    chdir $tmpdir;
    return ($dist, $tmpdir);
}

1;

#line 501
