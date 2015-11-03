#line 1 "Win32/API/Struct.pm"
#
# Win32::API::Struct - Perl Win32 API struct Facility
#
# Author: Aldo Calpini <dada@perl.it>
# Maintainer: Cosimo Streppone <cosimo@cpan.org>
#

package Win32::API::Struct;

$VERSION = '0.62';

use Carp;
use Win32::API::Type;
use Config;

require Exporter;
require DynaLoader;
@ISA = qw(Exporter DynaLoader);

my %Known = ();

sub DEBUG {
    if ($Win32::API::DEBUG) {
        printf @_ if @_ or return 1;
    }
    else {
        return 0;
    }
}

sub typedef {
    my $class  = shift;
    my $struct = shift;
    my ($type, $name);
    my $self = {
        align   => undef,
        typedef => [],
    };
    while (defined($type = shift)) {
        $name = shift;
        $name =~ s/;$//;
        push(@{$self->{typedef}}, [recognize($type, $name)]);
    }

    $Known{$struct} = $self;
    return 1;
}


sub recognize {
    my ($type, $name) = @_;
    my ($size, $packing);

    if (is_known($type)) {
        $packing = '>';
        return ($name, $packing, $type);
    }
    else {
        $packing = Win32::API::Type::packing($type);
        return undef unless defined $packing;
        if ($name =~ s/\[(.*)\]$//) {
            $size    = $1;
            $packing = $packing . '*' . $size;
        }
        DEBUG "(PM)Struct::recognize got '$name', '$type' -> '$packing'\n";
        return ($name, $packing, $type);
    }
}

sub new {
    my $class = shift;
    my ($type, $name);
    my $self = {typedef => [],};
    if ($#_ == 0) {
        if (is_known($_[0])) {
            DEBUG "(PM)Struct::new: got '$_[0]'\n";
            $self->{typedef} = $Known{$_[0]}->{typedef};
            foreach my $member (@{$self->{typedef}}) {
                ($name, $packing, $type) = @$member;
                next unless defined $name;
                if ($packing eq '>') {
                    $self->{$name} = Win32::API::Struct->new($type);
                }
            }
            $self->{__typedef__} = $_[0];
        }
        else {
            carp "Unknown Win32::API::Struct '$_[0]'";
            return undef;
        }
    }
    else {
        while (defined($type = shift)) {
            $name = shift;

            # print "new: found member $name ($type)\n";
            if (not exists $Win32::API::Type::Known{$type}) {
                warn "Unknown Win32::API::Struct type '$type'";
                return undef;
            }
            else {
                push(@{$self->{typedef}},
                    [$name, $Win32::API::Type::Known{$type}, $type]);
            }
        }
    }
    return bless $self;
}

sub members {
    my $self = shift;
    return map { $_->[0] } @{$self->{typedef}};
}

sub sizeof {
    my $self  = shift;
    my $size  = 0;
    my $align = 0;
    my $first = '';

    for my $member (@{$self->{typedef}}) {
        my ($name, $packing, $type) = @{$member};
        next unless defined $name;
        if (ref $self->{$name} eq q{Win32::API::Struct}) {

            # If member is a struct, recursively calculate its size
            # FIXME for subclasses
            $size += $self->{$name}->sizeof();
        }
        else {

            # Member is a simple type (LONG, DWORD, etc...)
            if ($packing =~ /\w\*(\d+)/) {    # Arrays (ex: 'c*260')
                $size += Win32::API::Type::sizeof($type) * $1;
                $first = Win32::API::Type::sizeof($type) * $1 unless defined $first;
                DEBUG "(PM)Struct::sizeof: sizeof with member($name) now = " . $size
                    . "\n";
            }
            else {                            # Simple types
                my $type_size = Win32::API::Type::sizeof($type);
                $align = $type_size if $type_size > $align;
                my $type_align = (($size + $type_size) % $type_size);
                $size += $type_size + $type_align;
                $first = Win32::API::Type::sizeof($type) unless defined $first;
            }
        }
    }

    my $struct_size = $size;
    if (defined $align && $align > 0) {
        $struct_size += ($size % $align);
    }
    DEBUG "(PM)Struct::sizeof first=$first totalsize=$struct_size\n";
    return $struct_size;
}

sub align {
    my $self  = shift;
    my $align = shift;

    if (not defined $align) {

        if (!(defined $self->{align} && $self->{align} eq 'auto')) {
            return $self->{align};
        }

        $align = 0;

        foreach my $member (@{$self->{typedef}}) {
            my ($name, $packing, $type) = @$member;

            if (ref($self->{$name}) eq "Win32::API::Struct") {
                #### ????
            }
            else {
                if ($packing =~ /\w\*(\d+)/) {
                    #### ????
                }
                else {
                    $align = Win32::API::Type::sizeof($type)
                        if Win32::API::Type::sizeof($type) > $align;
                }
            }
        }
        return $align;
    }
    else {
        $self->{align} = $align;

    }
}

sub getPack {
    my $self        = shift;
    my $packing     = "";
    my $packed_size = 0;
    my ($type, $name, $type_size, $type_align);
    my @items      = ();
    my @recipients = ();

    my $align = $self->align();

    foreach my $member (@{$self->{typedef}}) {
        ($name, $type, $orig) = @$member;
        if ($type eq '>') {
            my ($subpacking, $subitems, $subrecipients, $subpacksize) =
                $self->{$name}->getPack();
            DEBUG "(PM)Struct::getPack($self->{__typedef__}) ++ $subpacking\n";
            push(@items,      @$subitems);
            push(@recipients, @$subrecipients);
            $packing .= $subpacking;
            $packed_size += $subpacksize;
        }
        else {
            if ($type =~ /\w\*(\d+)/) {
                my $size = $1;
                $type = "a$size";
            }

            DEBUG "(PM)Struct::getPack($self->{__typedef__}) ++ $type\n";

            if ($type eq 'p') {
                $type = ($Config{ptrsize} == 8) ? 'Q' : 'L';
                push(@items, Win32::API::PointerTo($self->{$name}));
            }
            else {
                push(@items, $self->{$name});
            }
            push(@recipients, $self);
            $type_size  = Win32::API::Type::sizeof($orig);
            $type_align = (($packed_size + $type_size) % $type_size);
            $packing .= "x" x $type_align . $type;
            $packed_size += $type_size + $type_align;
        }
    }

    DEBUG
        "(PM)Struct::getPack: $self->{__typedef__}(buffer) = pack($packing, $packed_size)\n";

    return ($packing, [@items], [@recipients], $packed_size);
}

sub Pack {
    my $self = shift;
    my ($packing, $items, $recipients) = $self->getPack();

    DEBUG "(PM)Struct::Pack: $self->{__typedef__}(buffer) = pack($packing, @$items)\n";

    $self->{buffer} = pack($packing, @$items);

    if (DEBUG) {
        for my $i (0 .. $self->sizeof - 1) {
            printf "#pack#    %3d: 0x%02x\n", $i, ord(substr($self->{buffer}, $i, 1));
        }
    }

    $self->{buffer_recipients} = $recipients;
}

sub getUnpack {
    my $self        = shift;
    my $packing     = "";
    my $packed_size = 0;
    my ($type, $name, $type_size, $type_align);
    my @items = ();
    my $align = $self->align();
    foreach my $member (@{$self->{typedef}}) {
        ($name, $type, $orig) = @$member;
        if ($type eq '>') {
            my ($subpacking, @subitems, $subpacksize) = $self->{$name}->getUnpack();
            DEBUG "(PM)Struct::getUnpack($self->{__typedef__}) ++ $subpacking\n";
            $packing .= $subpacking;
            $packed_size += $subpacksize;
            push(@items, @subitems);
        }
        else {
            if ($type =~ /\w\*(\d+)/) {
                my $size = $1;
                $type = "Z$size";
            }
            DEBUG "(PM)Struct::getUnpack($self->{__typedef__}) ++ $type\n";
            $type_size  = Win32::API::Type::sizeof($orig);
            $type_align = (($packed_size + $type_size) % $type_size);
            $packing .= "x" x $type_align . $type;
            $packed_size += $type_size + $type_align;

            push(@items, $name);
        }
    }
    DEBUG "(PM)Struct::getUnpack($self->{__typedef__}): unpack($packing, @items)\n";
    return ($packing, @items, $packed_size);
}

sub Unpack {
    my $self = shift;
    my ($packing, @items) = $self->getUnpack();
    my @itemvalue = unpack($packing, $self->{buffer});
    DEBUG "(PM)Struct::Unpack: unpack($packing, buffer) = @itemvalue\n";
    foreach my $i (0 .. $#items) {
        my $recipient = $self->{buffer_recipients}->[$i];
        DEBUG "(PM)Struct::Unpack: %s(%s) = '%s' (0x%08x)\n",
            $recipient->{__typedef__},
            $items[$i],
            $itemvalue[$i],
            $itemvalue[$i],
            ;
        $recipient->{$items[$i]} = $itemvalue[$i];

        # DEBUG "(PM)Struct::Unpack: self.items[$i] = $self->{$items[$i]}\n";
    }
}

sub FromMemory {
    my ($self, $addr) = @_;
    DEBUG "(PM)Struct::FromMemory: doing Pack\n";
    $self->Pack();
    DEBUG "(PM)Struct::FromMemory: doing GetMemory( 0x%08x, %d )\n", $addr, $self->sizeof;
    $self->{buffer} = Win32::API::ReadMemory($addr, $self->sizeof);
    $self->Unpack();
    DEBUG "(PM)Struct::FromMemory: doing Unpack\n";
    DEBUG "(PM)Struct::FromMemory: structure is now:\n";
    $self->Dump() if DEBUG;
    DEBUG "\n";
}

sub Dump {
    my $self   = shift;
    my $prefix = shift;
    foreach my $member (@{$self->{typedef}}) {
        ($name, $packing, $type) = @$member;
        if (ref($self->{$name})) {
            $self->{$name}->Dump($name);
        }
        else {
            printf "%-20s %-20s %-20s\n", $prefix, $name, $self->{$name};
        }
    }
}


sub is_known {
    my $name = shift;
    if (exists $Known{$name}) {
        return 1;
    }
    else {
        if ($name =~ s/^LP//) {
            return exists $Known{$name};
        }
        return 0;
    }
}

sub TIEHASH {
    return Win32::API::Struct::new(@_);
}

sub EXISTS {

}

sub FETCH {
    my $self = shift;
    my $key  = shift;

    if ($key eq 'sizeof') {
        return $self->sizeof;
    }
    my @members = map { $_->[0] } @{$self->{typedef}};
    if (grep(/^\Q$key\E$/, @members)) {
        return $self->{$key};
    }
    else {
        warn "'$key' is not a member of Win32::API::Struct $self->{__typedef__}";
    }
}

sub STORE {
    my $self = shift;
    my ($key, $val) = @_;
    my @members = map { $_->[0] } @{$self->{typedef}};
    if (grep(/^\Q$key\E$/, @members)) {
        $self->{$key} = $val;
    }
    else {
        warn "'$key' is not a member of Win32::API::Struct $self->{__typedef__}";
    }
}

sub FIRSTKEY {
    my $self = shift;
    my @members = map { $_->[0] } @{$self->{typedef}};
    return $members[0];
}

sub NEXTKEY {
    my $self    = shift;
    my $key     = shift;
    my @members = map { $_->[0] } @{$self->{typedef}};
    for my $i (0 .. $#members - 1) {
        return $members[$i + 1] if $members[$i] eq $key;
    }
    return undef;
}

1;

#######################################################################
# DOCUMENTATION
#

#line 550
