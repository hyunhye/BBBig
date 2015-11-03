#line 1 "Image/ExifTool/Scalado.pm"
#------------------------------------------------------------------------------
# File:         Scalado.pm
#
# Description:  Read APP4 SCALADO metadata
#
# Revisions:    2013-09-13 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::Scalado;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::PLIST;

$VERSION = '1.01';

sub ProcessScalado($$$);

# JPEG APP4 SCALADO tags
%Image::ExifTool::Scalado::Main = (
    GROUPS => { 0 => 'APP4', 1 => 'Scalado', 2 => 'Image' },
    PROCESS_PROC => \&ProcessScalado,
    TAG_PREFIX => 'Scalado',
    FORMAT => 'int32s',
    NOTES => q{
        Tags extracted from the JPEG APP4 "SCALADO" segment found in images from
        HTC, LG and Samsung phones.  (Presumably written by Scalado mobile software,
        L<http://www.scalado.com/>.)
    },
    SPMO => {
        Name => 'DataLength',
        Unknown => 1,
    },
    WDTH => {
        Name => 'PreviewImageWidth',
        ValueConv => '$val ? abs($val) : undef',
    },
    HGHT => {
        Name => 'PreviewImageHeight',
        ValueConv => '$val ? abs($val) : undef',
    },
    QUAL => {
        Name => 'PreviewQuality',
        ValueConv => '$val ? abs($val) : undef',
    },
    # tags not yet decoded with observed values:
    # CHKH: 0, various negative values
    # CHKL: various negative values
    # CLEN: -1024
    # CSPC: -2232593
    # DATA: (+ve data length)
    # HDEC: 0
    # MAIN: 0, 60
    # META: 24
    # SCI0: (+ve data length) often 36
    # SCI1: (+ve data length) 36
    # SCX0: (+ve data length)
    # SCX1: (+ve data length) often 84
    # WDEC: 0
    # VERS: -131328
);

#------------------------------------------------------------------------------
# Extract information from the JPEG APP4 SCALADO segment
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessScalado($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $pos = 0;
    my $end = length $$dataPt;
    my $unknown = $et->Options('Unknown');

    $et->VerboseDir('APP4 SCALADO', undef, $end);
    SetByteOrder('MM');

    for (;;) {
        last if $pos + 12 > $end;
        my $tag = substr($$dataPt, $pos, 4);
        my $ver = Get32u($dataPt, $pos + 4); # (looks like a version for some tags)
        if (not $$tagTablePtr{$tag} and $unknown) {
            my $name = $tag;
            $name =~ tr/-A-Za-z0-9_//dc;
            last unless length $name;   # stop if tag is garbage
            AddTagToTable($tagTablePtr, $tag, {
                Name => "Scalado_$name",
                Description => "Scalado $name",
                Unknown => 1,
            });
        }
        $et->HandleTag($tagTablePtr, $tag, undef,
            DataPt  => $dataPt,
            Start   => $pos + 8,
            Size    => 4,
            Extra   => ", ver $ver",
        );
        if ($tag eq 'SPMO') {
            my $val = Get32u($dataPt, $pos + 8) ;
            if ($ver < 5) { # (I don't have samples for version 3 or 4, so I'm not sure about these)
                $end -= $val;     # SPMO gives trailer data length
            } else {
                $end = $val + 12; # SPMO gives length of Scalado directory (excepting this entry)
            }
        }
        $pos += 12;
    }
    return 1;
}

1;  # end

__END__

#line 142
