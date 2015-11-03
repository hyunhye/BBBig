#line 1 "Win32/API.pm"
# See the bottom of this file for the POD documentation.  Search for the
# string '=head'.

#######################################################################
#
# Win32::API - Perl Win32 API Import Facility
#
# Author: Aldo Calpini <dada@perl.it>
# Maintainer: Cosimo Streppone <cosimo@cpan.org>
#
# Changes for gcc/cygwin: Daniel Risacher <magnus@alum.mit.edu>
#  ported from 0.41 based on Daniel's patch by Reini Urban <rurban@x-ray.at>
#
#######################################################################

package Win32::API;

require Exporter;      # to export the constants to the main:: space
require DynaLoader;    # to dynuhlode the module.
@ISA = qw( Exporter DynaLoader );

use vars qw( $DEBUG );
$DEBUG = 0;

sub DEBUG {
    if ($Win32::API::DEBUG) {
        printf @_ if @_ or return 1;
    }
    else {
        return 0;
    }
}

use Win32::API::Type;
use Win32::API::Struct;
use File::Basename ();

#######################################################################
# STATIC OBJECT PROPERTIES
#
$VERSION = '0.65';

#### some package-global hash to
#### keep track of the imported
#### libraries and procedures
my %Libraries  = ();
my %Procedures = ();


#######################################################################
# dynamically load in the API extension module.
#
bootstrap Win32::API;

#######################################################################
# PUBLIC METHODS
#
sub new {
    my ($class, $dll, $proc, $in, $out, $callconvention) = @_;
    my $hdll;
    my $self = {};

    if ($^O eq 'cygwin' and $dll ne File::Basename::basename($dll)) {

        # need to convert $dll to win32 path
        # isn't there an API for this?
        my $newdll = `cygpath -w "$dll"`;
        chomp $newdll;
        DEBUG "(PM)new: converted '$dll' to\n  '$newdll'\n";
        $dll = $newdll;
    }

    #### avoid loading a library more than once
    if (exists($Libraries{$dll})) {
        DEBUG "Win32::API::new: Library '$dll' already loaded, handle=$Libraries{$dll}\n";
        $hdll = $Libraries{$dll};
    }
    else {
        DEBUG "Win32::API::new: Loading library '$dll'\n";
        $hdll = Win32::API::LoadLibrary($dll);

#        $Libraries{$dll} = $hdll;
    }

    #### if the dll can't be loaded, set $! to Win32's GetLastError()
    if (!$hdll) {
        $! = Win32::GetLastError();
        DEBUG "FAILED Loading library '$dll': $!\n";
        delete $Libraries{$dll};
        return undef;
    }

    #### determine if we have a prototype or not
    if ((not defined $in) and (not defined $out)) {
        ($proc, $self->{in}, $self->{intypes}, $self->{out}, $self->{cdecl}) =
            parse_prototype($proc);
        return undef unless $proc;
        $self->{proto} = 1;
    }
    else {
        $self->{in} = [];
        if (ref($in) eq 'ARRAY') {
            foreach (@$in) {
                push(@{$self->{in}}, type_to_num($_));
            }
        }
        else {
            my @in = split '', $in;
            foreach (@in) {
                push(@{$self->{in}}, type_to_num($_));
            }
        }
        $self->{out}   = type_to_num($out);
        $self->{cdecl} = calltype_to_num($callconvention);
    }

    #### first try to import the function of given name...
    my $hproc = Win32::API::GetProcAddress($hdll, $proc);

    #### ...then try appending either A or W (for ASCII or Unicode)
    if (!$hproc) {
        my $tproc = $proc;
        $tproc .= (IsUnicode() ? "W" : "A");

        # print "Win32::API::new: procedure not found, trying '$tproc'...\n";
        $hproc = Win32::API::GetProcAddress($hdll, $tproc);
    }

    #### ...if all that fails, set $! accordingly
    if (!$hproc) {
        $! = Win32::GetLastError();
        DEBUG "FAILED GetProcAddress for Proc '$proc': $!\n";
        return undef;
    }
    DEBUG "GetProcAddress('$proc') = '$hproc'\n";

    #### ok, let's stuff the object
    $self->{procname} = $proc;
    $self->{dll}      = $hdll;
    $self->{dllname}  = $dll;
    $self->{proc}     = $hproc;

    #### keep track of the imported function
    $Libraries{$dll} = $hdll;
    $Procedures{$dll}++;

    DEBUG "Object blessed!\n";

    #### cast the spell
    bless($self, $class);
    return $self;
}

sub Import {
    my ($class, $dll, $proc, $in, $out, $callconvention) = @_;
    $Imported{"$dll:$proc"} = Win32::API->new($dll, $proc, $in, $out, $callconvention)
        or return 0;
    my $P = (caller)[0];
    eval qq(
        sub ${P}::$Imported{"$dll:$proc"}->{procname} { \$Win32::API::Imported{"$dll:$proc"}->Call(\@_); }
    );
    return $@ ? 0 : 1;
}

#######################################################################
# PRIVATE METHODS
#
sub DESTROY {
    my ($self) = @_;

    #### decrease this library's procedures reference count
    $Procedures{$self->{dllname}}--;

    #### once it reaches 0, free it
    if ($Procedures{$self->{dllname}} == 0) {
        DEBUG "Win32::API::DESTROY: Freeing library '$self->{dllname}'\n";
        Win32::API::FreeLibrary($Libraries{$self->{dllname}});
        delete($Libraries{$self->{dllname}});
    }
}

# Convert calling convention string (_cdecl|__stdcall)
# to an integer (1|0). Unknown counts as __stdcall
#
sub calltype_to_num {
    my $type = shift;

    if (!$type || $type eq "__stdcall") {
        return 0;
    }
    elsif ($type eq "_cdecl") {
        return 1;
    }
    else {
        warn "unknown calling convention: '$type'";
        return 0;
    }
}

sub type_to_num {
    my $type = shift;
    my $out  = shift;
    my $num;

    if (   $type eq 'N'
        or $type eq 'n'
        or $type eq 'l'
        or $type eq 'L')
    {
        $num = 1;
    }
    elsif ($type eq 'P'
        or $type eq 'p')
    {
        $num = 2;
    }
    elsif ($type eq 'I'
        or $type eq 'i')
    {
        $num = 3;
    }
    elsif ($type eq 'f'
        or $type eq 'F')
    {
        $num = 4;
    }
    elsif ($type eq 'D'
        or $type eq 'd')
    {
        $num = 5;
    }
    elsif ($type eq 'c'
        or $type eq 'C')
    {
        $num = 6;
    }
    else {
        $num = 0;
    }
    unless (defined $out) {
        if (   $type eq 's'
            or $type eq 'S')
        {
            $num = 51;
        }
        elsif ($type eq 'b'
            or $type eq 'B')
        {
            $num = 22;
        }
        elsif ($type eq 'k'
            or $type eq 'K')
        {
            $num = 101;
        }
    }
    return $num;
}

sub parse_prototype {
    my ($proto) = @_;

    my @in_params = ();
    my @in_types  = ();
    if ($proto =~ /^\s*(\S+)(?:\s+(\w+))?\s+(\S+)\s*\(([^\)]*)\)/) {
        my $ret            = $1;
        my $callconvention = $2;
        my $proc           = $3;
        my $params         = $4;

        $params =~ s/^\s+//;
        $params =~ s/\s+$//;

        DEBUG "(PM)parse_prototype: got PROC '%s'\n",   $proc;
        DEBUG "(PM)parse_prototype: got PARAMS '%s'\n", $params;

        foreach my $param (split(/\s*,\s*/, $params)) {
            my ($type, $name);
            if ($param =~ /(\S+)\s+(\S+)/) {
                ($type, $name) = ($1, $2);
            }

            if (Win32::API::Type::is_known($type)) {
                if (Win32::API::Type::is_pointer($type)) {
                    DEBUG "(PM)parse_prototype: IN='%s' PACKING='%s' API_TYPE=%d\n",
                        $type,
                        Win32::API::Type->packing($type),
                        type_to_num('P');
                    push(@in_params, type_to_num('P'));
                }
                else {
                    DEBUG "(PM)parse_prototype: IN='%s' PACKING='%s' API_TYPE=%d\n",
                        $type,
                        Win32::API::Type->packing($type),
                        type_to_num(Win32::API::Type->packing($type));
                    push(@in_params, type_to_num(Win32::API::Type->packing($type)));
                }
            }
            elsif (Win32::API::Struct::is_known($type)) {
                DEBUG "(PM)parse_prototype: IN='%s' PACKING='%s' API_TYPE=%d\n",
                    $type, 'S', type_to_num('S');
                push(@in_params, type_to_num('S'));
            }
            else {
                warn
                    "Win32::API::parse_prototype: WARNING unknown parameter type '$type'";
                push(@in_params, type_to_num('I'));
            }
            push(@in_types, $type);

        }
        DEBUG "parse_prototype: IN=[ @in_params ]\n";


        if (Win32::API::Type::is_known($ret)) {
            if (Win32::API::Type::is_pointer($ret)) {
                DEBUG "parse_prototype: OUT='%s' PACKING='%s' API_TYPE=%d\n",
                    $ret,
                    Win32::API::Type->packing($ret),
                    type_to_num('P');
                return ($proc, \@in_params, \@in_types, type_to_num('P'),
                    calltype_to_num($callconvention));
            }
            else {
                DEBUG "parse_prototype: OUT='%s' PACKING='%s' API_TYPE=%d\n",
                    $ret,
                    Win32::API::Type->packing($ret),
                    type_to_num(Win32::API::Type->packing($ret));
                return (
                    $proc, \@in_params, \@in_types,
                    type_to_num(Win32::API::Type->packing($ret)),
                    calltype_to_num($callconvention)
                );
            }
        }
        else {
            warn
                "Win32::API::parse_prototype: WARNING unknown output parameter type '$ret'";
            return ($proc, \@in_params, \@in_types, type_to_num('I'),
                calltype_to_num($callconvention));
        }

    }
    else {
        warn "Win32::API::parse_prototype: bad prototype '$proto'";
        return undef;
    }
}

1;

__END__

#######################################################################
# DOCUMENTATION
#

#line 806

