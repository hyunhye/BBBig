#line 1 "ActivePerl/Config.pm"
package ActivePerl::Config;

use strict;
my %OVERRIDE;
my %COMPILER_ENV = map { $_ => 1 } qw(
    cc
    ccflags
    cccdlflags
    gccversion
    ar
    cpp
    cppminus
    cpprun
    cppstdin
    ld
    lddlflags
    ldflags
    libc
    libs
    optimize
    perllibs
    _a
    _o
    obj_ext
);
my $compiler_env_initialized;

use ActiveState::Path qw(find_prog);

use Config ();
my $CONFIG_OBJ = tied %Config::Config;

sub override {
    return 0 if $ENV{ACTIVEPERL_CONFIG_DISABLE};

    my $key = shift;

    if (exists $ENV{"ACTIVEPERL_CONFIG_\U$key"}) {
	$_[0] = $ENV{"ACTIVEPERL_CONFIG_\U$key"};
	return 1;
    }

    if (exists $OVERRIDE{$key}) {
	$_[0] = $OVERRIDE{$key};
	return 1;
    }

    if ($key eq "cc" && $ENV{ACTIVEPERL_CONFIG_CCACHE} && find_prog("ccache")) {
	$_[0] = "ccache " . _orig_conf("cc");
	return 1;
    }

    if ($key eq "make" && $^O eq "MSWin32") {
	for (qw(nmake dmake)) {
	    if (find_prog($_)) {
		$_[0] = $OVERRIDE{$key} = $_;
		return 1;
	    }
	}
	return 0;
    }

    if ($COMPILER_ENV{$key} && !$compiler_env_initialized++) {
	if ($^O eq "MSWin32" && !find_prog(_orig_conf("cc"))) {
	    if (find_prog("gcc")) {
		# assume MinGW or similar is available
		_override("cc", "gcc");
		my($gccversion) = qx(gcc --version);
		$gccversion =~ s/^gcc(\.exe)? \(GCC\) //;
		chomp($gccversion);
		warn "Set up gcc environment - $gccversion\n";
		_override("gccversion", $gccversion);

		foreach my $key (qw(libs perllibs)) {
		    # Old: "  foo.lib oldnames.lib bar.lib"
		    # New: "-lfoo -lbar"
		    my @libs = split / +/, _orig_conf($key);
		    # Filter out empty prefix and oldnames.lib
		    @libs = grep {$_ && $_ ne "oldnames.lib"} @libs;
		    # Remove '.lib' extension and add '-l' prefix
		    s/(.*)\.lib$/-l$1/ for @libs;
		    _override($key, join(' ', @libs));
		}

		# Copy all symbol definitions from the CCFLAGS
		my @ccflags = grep /^-D/, split / +/, _orig_conf("ccflags");
		# Add GCC specific flags
		push(@ccflags, qw(-DHASATTRIBUTE -fno-strict-aliasing));
		_override("ccflags", join(" ", @ccflags));

		# more overrides assuming MinGW
		_override("cpp",       "gcc -E");
		_override("cpprun",    "gcc -E");
		_override("cppminus",  "-");
		_override("ar",        "ar");
		_override("ld",        "gcc");
		_override("_a",        ".a");
		_override("_o",        ".o");
		_override("obj_ext",   ".o");
		_override("optimize",  "-O2");
		_override("lddlflags", "-mdll");

		if (exists $OVERRIDE{$key}) {
		    $_[0] = $OVERRIDE{$key};
		    return 1;
		}
	    }
	}
    }

    return 0;
}

sub _orig_conf {
    $CONFIG_OBJ->_fetch_string($_[0]);
}

sub _override {
    my($key, $val) = @_;
    $OVERRIDE{$key} = $val unless exists $OVERRIDE{$key};
}

1;

__END__

#line 209