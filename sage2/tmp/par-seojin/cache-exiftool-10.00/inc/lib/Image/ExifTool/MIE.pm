#line 1 "Image/ExifTool/MIE.pm"
#------------------------------------------------------------------------------
# File:         MIE.pm
#
# Description:  Read/write MIE meta information
#
# Revisions:    11/18/2005 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::MIE;

use strict;
use vars qw($VERSION %tableDefaults);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;
use Image::ExifTool::GPS;

$VERSION = '1.44';

sub ProcessMIE($$);
sub ProcessMIEGroup($$$);
sub WriteMIEGroup($$$);
sub CheckMIE($$$);
sub GetLangInfo($$);

# local variables
my $hasZlib;        # 1=Zlib available, 0=no Zlib
my %mieCode;        # reverse lookup for MIE format names
my $doneMieMap;     # flag indicating we added user-defined groups to %mieMap

# MIE format codes
my %mieFormat = (
    0x00 => 'undef',
    0x10 => 'MIE',
    0x18 => 'MIE',
    0x20 => 'string', # ASCII (ISO 8859-1)
    0x28 => 'utf8',
    0x29 => 'utf16',
    0x2a => 'utf32',
    0x30 => 'string_list',
    0x38 => 'utf8_list',
    0x39 => 'utf16_list',
    0x3a => 'utf32_list',
    0x40 => 'int8u',
    0x41 => 'int16u',
    0x42 => 'int32u',
    0x43 => 'int64u',
    0x48 => 'int8s',
    0x49 => 'int16s',
    0x4a => 'int32s',
    0x4b => 'int64s',
    0x52 => 'rational32u',
    0x53 => 'rational64u',
    0x5a => 'rational32s',
    0x5b => 'rational64s',
    0x61 => 'fixed16u',
    0x62 => 'fixed32u',
    0x69 => 'fixed16s',
    0x6a => 'fixed32s',
    0x72 => 'float',
    0x73 => 'double',
    0x80 => 'free',
);

# map of MIE directory locations
my %mieMap = (
   'MIE-Meta'       => 'MIE',
   'MIE-Audio'      => 'MIE-Meta',
   'MIE-Camera'     => 'MIE-Meta',
   'MIE-Doc'        => 'MIE-Meta',
   'MIE-Geo'        => 'MIE-Meta',
   'MIE-Image'      => 'MIE-Meta',
   'MIE-MakerNotes' => 'MIE-Meta',
   'MIE-Preview'    => 'MIE-Meta',
   'MIE-Thumbnail'  => 'MIE-Meta',
   'MIE-Video'      => 'MIE-Meta',
   'MIE-Flash'      => 'MIE-Camera',
   'MIE-Lens'       => 'MIE-Camera',
   'MIE-Orient'     => 'MIE-Camera',
   'MIE-Extender'   => 'MIE-Lens',
   'MIE-GPS'        => 'MIE-Geo',
   'MIE-UTM'        => 'MIE-Geo',
   'MIE-Canon'      => 'MIE-MakerNotes',
    EXIF            => 'MIE-Meta',
    XMP             => 'MIE-Meta',
    IPTC            => 'MIE-Meta',
    ICC_Profile     => 'MIE-Meta',
    ID3             => 'MIE-Meta',
    CanonVRD        => 'MIE-Canon',
    IFD0            => 'EXIF',
    IFD1            => 'IFD0',
    ExifIFD         => 'IFD0',
    GPS             => 'IFD0',
    SubIFD          => 'IFD0',
    GlobParamIFD    => 'IFD0',
    PrintIM         => 'IFD0',
    InteropIFD      => 'ExifIFD',
    MakerNotes      => 'ExifIFD',
);

# convenience variables for common tagInfo entries
my %binaryConv = (
    Writable => 'undef',
    Binary => 1,
);
my %dateInfo = (
    Shift => 'Time',
    PrintConv => '$self->ConvertDateTime($val)',
    PrintConvInv => '$self->InverseDateTime($val)',
);
my %noYes = ( 0 => 'No', 1 => 'Yes' );
my %offOn = ( 0 => 'Off', 1 => 'On' );

# default entries for MIE tag tables
%tableDefaults = (
    PROCESS_PROC => \&ProcessMIE,
    WRITE_PROC   => \&ProcessMIE,
    CHECK_PROC   => \&CheckMIE,
    LANG_INFO    => \&GetLangInfo,
    WRITABLE     => 'string',
    PREFERRED    => 1,
);

# MIE info
%Image::ExifTool::MIE::Main = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Main' },
    WRITE_GROUP => 'MIE-Main',
    NOTES => q{
        MIE is a flexible format which may be used as a stand-alone meta information
        format, for encapsulation of other files and information, or as a trailer
        appended to other file formats.  The tables below represent currently
        defined MIE tags, however ExifTool will also extract any other information
        present in a MIE file.

        When writing MIE information, some special features are supported:

        1) String values may be written as ASCII (ISO 8859-1) or UTF-8.  ExifTool
        automatically detects the presence of wide characters and treats the string
        appropriately. Internally, UTF-8 text may be converted to UTF-16 or UTF-32
        and stored in this format in the file if it is more compact.

        2) All MIE string-value tags support localized text.  Localized values are
        written by adding a language/country code to the tag name in the form
        C<TAG-xx_YY>, where C<TAG> is the tag name, C<xx> is a 2-character lower
        case ISO 639-1 language code, and C<YY> is a 2-character upper case ISO
        3166-1 alpha 2 country code (eg. C<Title-en_US>).  But as usual, the user
        interface is case-insensitive, and ExifTool will write the correct case to
        the file.

        3) Some numerical MIE tags allow units of measurement to be specified.  For
        these tags, units may be added in brackets immediately following the value
        (eg. C<55(mi/h)>).  If no units are specified, the default units are
        written.

        See L<http://owl.phy.queensu.ca/~phil/exiftool/MIE1.1-20070121.pdf> for the
        official MIE specification.
    },
   '0Type' => {
        Name => 'SubfileType',
        Notes => q{
            the capitalized common extension for this type of file.  If the extension
            has a dot-3 abbreviation, then the longer version is used here. For
            instance, JPEG and TIFF are used, not JPG and TIF
        },
    },
   '0Vers' => {
        Name => 'MIEVersion',
        Notes => 'version 1.1 is assumed if not specified',
    },
   '1Directory' => {
        Name => 'SubfileDirectory',
        Notes => 'original directory for the file',
    },
   '1Name'      => {
        Name => 'SubfileName',
        Notes => 'the file name, including extension if it exists',
    },
   '2MIME'      => { Name => 'SubfileMIMEType' },
    Meta => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Meta',
            DirName => 'MIE-Meta',
        },
    },
    data => {
        Name => 'SubfileData',
        Notes => 'the subfile data',
        %binaryConv,
    },
    rsrc => {
        Name => 'SubfileResource',
        Notes => 'subfile resource fork if it exists',
        %binaryConv,
    },
    zmd5 => {
        Name => 'MD5Digest',
        Notes => q{
            16-byte MD5 digest written in binary form or as a 32-character hex-encoded
            ASCII string. Value is an MD5 digest of the entire 0MIE group as it would be
            with the digest value itself set to all null bytes
        },
    },
    zmie => {
        Name => 'TrailerSignature',
        Writable => 'undef',
        Notes => q{
            used as the last element in the main "0MIE" group to identify a MIE trailer
            when appended to another type of file.  ExifTool will create this tag if set
            to any value, but always with an empty data block
        },
        ValueConvInv => '""',   # data block must be empty
    },
);

# MIE meta information group
%Image::ExifTool::MIE::Meta = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Meta', 2 => 'Image' },
    WRITE_GROUP => 'MIE-Meta',
    Audio => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Audio',
            DirName => 'MIE-Audio',
        },
    },
    Camera => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Camera',
            DirName => 'MIE-Camera',
        },
    },
    Document => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Doc',
            DirName => 'MIE-Doc',
        },
    },
    EXIF => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::Exif::Main',
            ProcessProc => \&Image::ExifTool::ProcessTIFF,
            WriteProc => \&Image::ExifTool::WriteTIFF,
        },
    },
    Geo => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Geo',
            DirName => 'MIE-Geo',
        },
    },
    ICCProfile  => {
        Name => 'ICC_Profile',
        SubDirectory => { TagTable => 'Image::ExifTool::ICC_Profile::Main' },
    },
    ID3  => { SubDirectory => { TagTable => 'Image::ExifTool::ID3::Main' } },
    IPTC => { SubDirectory => { TagTable => 'Image::ExifTool::IPTC::Main' } },
    Image => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Image',
            DirName => 'MIE-Image',
        },
    },
    MakerNotes => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::MakerNotes',
            DirName => 'MIE-MakerNotes',
        },
    },
    Preview => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Preview',
            DirName => 'MIE-Preview',
        },
    },
    Thumbnail => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Thumbnail',
            DirName => 'MIE-Thumbnail',
        },
    },
    Video => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Video',
            DirName => 'MIE-Video',
        },
    },
    XMP => { SubDirectory => { TagTable => 'Image::ExifTool::XMP::Main' } },
);

# MIE document information
%Image::ExifTool::MIE::Doc = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Doc', 2 => 'Document' },
    WRITE_GROUP => 'MIE-Doc',
    NOTES => 'Information describing the main document, image or file.',
    Author      => { Groups => { 2 => 'Author' } },
    Comment     => { },
    Contributors=> { Groups => { 2 => 'Author' }, List => 1 },
    Copyright   => { Groups => { 2 => 'Author' } },
    CreateDate  => { Groups => { 2 => 'Time' }, %dateInfo },
    EMail       => { Name => 'Email', Groups => { 2 => 'Author' } },
    Keywords    => { List => 1 },
    ModifyDate  => { Groups => { 2 => 'Time' }, %dateInfo },
    OriginalDate=> {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        %dateInfo,
    },
    Phone       => { Name => 'PhoneNumber', Groups => { 2 => 'Author' } },
    References  => { List => 1 },
    Software    => { },
    Title       => { },
    URL         => { },
);

# MIE geographic information
%Image::ExifTool::MIE::Geo = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Geo', 2 => 'Location' },
    WRITE_GROUP => 'MIE-Geo',
    NOTES => 'Information related to geographic location.',
    Address     => { },
    City        => { },
    Country     => { },
    GPS => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::GPS',
            DirName => 'MIE-GPS',
        },
    },
    PostalCode  => { },
    State       => { Notes => 'state or province' },
    UTM => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::UTM',
            DirName => 'MIE-UTM',
        },
    },
);

# MIE GPS information
%Image::ExifTool::MIE::GPS = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-GPS', 2 => 'Location' },
    WRITE_GROUP => 'MIE-GPS',
    Altitude   => {
        Name => 'GPSAltitude',
        Writable => 'rational64s',
        Units => [ qw(m ft) ],
        Notes => q{'m' above sea level unless 'ft' specified},
    },
    Bearing => {
        Name => 'GPSDestBearing',
        Writable => 'rational64s',
        Units => [ qw(deg deg{mag}) ],
        Notes => q{'deg' CW from true north unless 'deg{mag}' specified},
    },
    Datum   => { Name => 'GPSMapDatum', Notes => 'WGS-84 assumed if not specified' },
    Differential => {
        Name => 'GPSDifferential',
        Writable => 'int8u',
        PrintConv => {
            0 => 'No Correction',
            1 => 'Differential Corrected',
        },
    },
    Distance => {
        Name => 'GPSDestDistance',
        Writable => 'rational64s',
        Units => [ qw(km mi nmi) ],
        Notes => q{'km' unless 'mi' or 'nmi' specified},
    },
    Heading  => {
        Name => 'GPSTrack',
        Writable => 'rational64s',
        Units => [ qw(deg deg{mag}) ],
        Notes => q{'deg' CW from true north unless 'deg{mag}' specified},
    },
    Latitude => {
        Name => 'GPSLatitude',
        Writable => 'rational64s',
        Count => -1,
        Notes => q{
            1 to 3 numbers: degrees, minutes then seconds.  South latitudes are stored
            as all negative numbers, but may be entered as positive numbers with a
            trailing 'S' for convenience.  For example, these are all equivalent: "-40
            -30", "-40.5", "40 30 0.00 S"
        },
        ValueConv    => 'Image::ExifTool::GPS::ToDegrees($val, 1)',
        ValueConvInv => 'Image::ExifTool::GPS::ToDMS($self, $val, 0)',
        PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
        PrintConvInv => 'Image::ExifTool::GPS::ToDegrees($val, 1)',
    },
    Longitude => {
        Name => 'GPSLongitude',
        Writable => 'rational64s',
        Count => -1,
        Notes => q{
            1 to 3 numbers: degrees, minutes then seconds.  West longitudes are
            negative, but may be entered as positive numbers with a trailing 'W'
        },
        ValueConv    => 'Image::ExifTool::GPS::ToDegrees($val, 1)',
        ValueConvInv => 'Image::ExifTool::GPS::ToDMS($self, $val, 0)',
        PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
        PrintConvInv => 'Image::ExifTool::GPS::ToDegrees($val, 1)',
    },
    MeasureMode => {
        Name => 'GPSMeasureMode',
        Writable => 'int8u',
        PrintConv => { 2 => '2-D', 3 => '3-D' },
    },
    Satellites => 'GPSSatellites',
    Speed => {
        Name => 'GPSSpeed',
        Writable => 'rational64s',
        Units => [ qw(km/h mi/h m/s kn) ],
        Notes => q{'km/h' unless 'mi/h', 'm/s' or 'kn' specified},
    },
    DateTime => { Name => 'GPSDateTime', Groups => { 2 => 'Time' }, %dateInfo },
);

# MIE UTM information
%Image::ExifTool::MIE::UTM = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-UTM', 2 => 'Location' },
    WRITE_GROUP => 'MIE-UTM',
    Datum    => { Name => 'UTMMapDatum', Notes => 'WGS-84 assumed if not specified' },
    Easting  => { Name => 'UTMEasting' },
    Northing => { Name => 'UTMNorthing' },
    Zone     => { Name => 'UTMZone', Writable => 'int8s' },
);

# MIE image information
%Image::ExifTool::MIE::Image = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Image', 2 => 'Image' },
    WRITE_GROUP => 'MIE-Image',
   '0Type'          => { Name => 'FullSizeImageType', Notes => 'JPEG if not specified' },
   '1Name'          => { Name => 'FullSizeImageName' },
    BitDepth        => { Name => 'BitDepth', Writable => 'int16u' },
    ColorSpace      => { Notes => 'standard ColorSpace values are "sRGB" and "Adobe RGB"' },
    Components      => {
        Name => 'ComponentsConfiguration',
        Notes => 'string composed of R, G, B, Y, Cb and Cr',
    },
    Compression     => { Name => 'CompressionRatio', Writable => 'rational32u' },
    ImageSize       => {
        Writable => 'int16u',
        Count => -1,
        Notes => '2 or 3 values, for number of XY or XYZ pixels',
        PrintConv => '$val=~tr/ /x/;$val',
        PrintConvInv => '$val=~tr/x/ /;$val',
    },
    Resolution      => {
        Writable => 'rational64u',
        Units => [ qw(/in /cm /deg /arcmin /arcsec), '' ],
        Count => -1,
        Notes => q{
            1 to 3 values.  A single value for equal resolution in all directions, or
            separate X, Y and Z values if necessary.  Units are '/in' unless '/cm',
            '/deg', '/arcmin', '/arcsec' or '' specified
        },
        PrintConv => '$val=~tr/ /x/;$val',
        PrintConvInv => '$val=~tr/x/ /;$val',
    },
    data => {
        Name => 'FullSizeImage',
        Groups => { 2 => 'Preview' },
        %binaryConv,
        RawConv => '$self->ValidateImage(\$val,$tag)',
    },
);

# MIE preview image
%Image::ExifTool::MIE::Preview = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Preview', 2 => 'Image' },
    WRITE_GROUP => 'MIE-Preview',
   '0Type'  => { Name => 'PreviewImageType', Notes => 'JPEG if not specified' },
   '1Name'  => { Name => 'PreviewImageName' },
    ImageSize => {
        Name => 'PreviewImageSize',
        Writable => 'int16u',
        Count => -1,
        Notes => '2 or 3 values, for number of XY or XYZ pixels',
        PrintConv => '$val=~tr/ /x/;$val',
        PrintConvInv => '$val=~tr/x/ /;$val',
    },
    data => {
        Name => 'PreviewImage',
        Groups => { 2 => 'Preview' },
        %binaryConv,
        RawConv => '$self->ValidateImage(\$val,$tag)',
    },
);

# MIE thumbnail image
%Image::ExifTool::MIE::Thumbnail = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Thumbnail', 2 => 'Image' },
    WRITE_GROUP => 'MIE-Thumbnail',
   '0Type'  => { Name => 'ThumbnailImageType', Notes => 'JPEG if not specified' },
   '1Name'  => { Name => 'ThumbnailImageName' },
    ImageSize => {
        Name => 'ThumbnailImageSize',
        Writable => 'int16u',
        Count => -1,
        Notes => '2 or 3 values, for number of XY or XYZ pixels',
        PrintConv => '$val=~tr/ /x/;$val',
        PrintConvInv => '$val=~tr/x/ /;$val',
    },
    data => {
        Name => 'ThumbnailImage',
        Groups => { 2 => 'Preview' },
        %binaryConv,
        RawConv => '$self->ValidateImage(\$val,$tag)',
    },
);

# MIE audio information
%Image::ExifTool::MIE::Audio = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Audio', 2 => 'Audio' },
    WRITE_GROUP => 'MIE-Audio',
    NOTES => q{
        For the Audio group (and any other group containing a 'data' element), tags
        refer to the contained data if present, otherwise they refer to the main
        SubfileData.  The C<0Type> and C<1Name> elements should exist only if C<data>
        is present.
    },
   '0Type'      => { Name => 'RelatedAudioFileType', Notes => 'MP3 if not specified' },
   '1Name'      => { Name => 'RelatedAudioFileName' },
    SampleBits  => { Writable => 'int16u' },
    Channels    => { Writable => 'int8u' },
    Compression => { Name => 'AudioCompression' },
    Duration    => { Writable => 'rational64u', PrintConv => 'ConvertDuration($val)' },
    SampleRate  => { Writable => 'int32u' },
    data        => { Name => 'RelatedAudioFile', %binaryConv },
);

# MIE video information
%Image::ExifTool::MIE::Video = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Video', 2 => 'Video' },
    WRITE_GROUP => 'MIE-Video',
   '0Type'      => { Name => 'RelatedVideoFileType', Notes => 'MOV if not specified' },
   '1Name'      => { Name => 'RelatedVideoFileName' },
    Codec       => { },
    Duration    => { Writable => 'rational64u', PrintConv => 'ConvertDuration($val)' },
    data        => { Name => 'RelatedVideoFile', %binaryConv },
);

# MIE camera information
%Image::ExifTool::MIE::Camera = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Camera', 2 => 'Camera' },
    WRITE_GROUP => 'MIE-Camera',
    Brightness      => { Writable => 'int8s' },
    ColorTemperature=> { Writable => 'int32u' },
    ColorBalance    => {
        Writable => 'rational64u',
        Count => 3,
        Notes => 'RGB scaling factors',
    },
    Contrast        => { Writable => 'int8s' },
    DigitalZoom     => { Writable => 'rational64u' },
    ExposureComp    => { Name => 'ExposureCompensation', Writable => 'rational64s' },
    ExposureMode    => { },
    ExposureTime    => {
        Writable => 'rational64u',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    Flash => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Flash',
            DirName => 'MIE-Flash',
        },
    },
    FirmwareVersion => { },
    FocusMode       => { },
    ISO             => { Writable => 'int16u' },
    ISOSetting      => {
        Writable => 'int16u',
        Notes => '0 = Auto, otherwise manual ISO speed setting',
    },
    ImageNumber     => { Writable => 'int32u' },
    ImageQuality    => { Notes => 'Economy, Normal, Fine, Super Fine or Raw' },
    ImageStabilization => { Writable => 'int8u', %offOn },
    Lens => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Lens',
            DirName => 'MIE-Lens',
        },
    },
    Make            => { },
    MeasuredEV      => { Writable => 'rational64s' },
    Model           => { },
    OwnerName       => { },
    Orientation     => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Orient',
            DirName => 'MIE-Orient',
        },
    },
    Saturation      => { Writable => 'int8s' },
    SensorSize      => {
        Writable => 'rational64u',
        Count => 2,
        Notes => 'width and height of active sensor area in mm',
    },
    SerialNumber    => { },
    Sharpness       => { Writable => 'int8s' },
    ShootingMode    => { },
);

# Camera orientation information
%Image::ExifTool::MIE::Orient = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Orient', 2 => 'Camera' },
    WRITE_GROUP => 'MIE-Orient',
    NOTES => 'These tags describe the camera orientation.',
    Azimuth     => {
        Writable => 'rational64s',
        Units => [ qw(deg deg{mag}) ],
        Notes => q{'deg' CW from true north unless 'deg{mag}' specified},
    },
    Declination => { Writable => 'rational64s' },
    Elevation   => { Writable => 'rational64s' },
    RightAscension => { Writable => 'rational64s' },
    Rotation => {
        Writable => 'rational64s',
        Notes => 'CW rotation angle of camera about lens axis',
    },
);

# MIE camera lens information
%Image::ExifTool::MIE::Lens = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Lens', 2 => 'Camera' },
    WRITE_GROUP => 'MIE-Lens',
    NOTES => q{
        All recorded lens parameters (focal length, aperture, etc) include the
        effects of the extender if present.
    },
    Extender => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Extender',
            DirName => 'MIE-Extender',
        },
    },
    FNumber         => { Writable => 'rational64u' },
    FocalLength     => { Writable => 'rational64u', Notes => 'all focal lengths in mm' },
    FocusDistance   => {
        Writable => 'rational64u',
        Units => [ qw(m ft) ],
        Notes => q{'m' unless 'ft' specified},
    },
    Make            => { Name => 'LensMake' },
    MaxAperture     => { Writable => 'rational64u' },
    MaxApertureAtMaxFocal => { Writable => 'rational64u' },
    MaxFocalLength  => { Writable => 'rational64u' },
    MinAperture     => { Writable => 'rational64u' },
    MinFocalLength  => { Writable => 'rational64u' },
    Model           => { Name => 'LensModel' },
    OpticalZoom     => { Writable => 'rational64u' },
    SerialNumber    => { Name => 'LensSerialNumber' },
);

# MIE lens extender information
%Image::ExifTool::MIE::Extender = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Extender', 2 => 'Camera' },
    WRITE_GROUP => 'MIE-Extender',
    Magnification   => { Name => 'ExtenderMagnification', Writable => 'rational64s' },
    Make            => { Name => 'ExtenderMake' },
    Model           => { Name => 'ExtenderModel' },
    SerialNumber    => { Name => 'ExtenderSerialNumber' },
);

# MIE camera flash information
%Image::ExifTool::MIE::Flash = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Flash', 2 => 'Camera' },
    WRITE_GROUP => 'MIE-Flash',
    ExposureComp    => { Name => 'FlashExposureComp', Writable => 'rational64s' },
    Fired           => { Name => 'FlashFired', Writable => 'int8u', PrintConv => \%noYes },
    GuideNumber     => { Name => 'FlashGuideNumber' },
    Make            => { Name => 'FlashMake' },
    Mode            => { Name => 'FlashMode' },
    Model           => { Name => 'FlashModel' },
    SerialNumber    => { Name => 'FlashSerialNumber' },
    Type            => { Name => 'FlashType', Notes => '"Internal" or "External"' },
);

# MIE maker notes information
%Image::ExifTool::MIE::MakerNotes = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-MakerNotes' },
    WRITE_GROUP => 'MIE-MakerNotes',
    NOTES => q{
        MIE maker notes are contained within separate groups for each manufacturer
        to avoid name conflicts.
    },
    Canon => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Canon',
            DirName => 'MIE-Canon',
        },
    },
    Casio       => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    FujiFilm    => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Kodak       => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    KonicaMinolta=>{ SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Nikon       => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Olympus     => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Panasonic   => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Pentax      => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Ricoh       => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Sigma       => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Sony        => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
);

# MIE Canon-specific information
%Image::ExifTool::MIE::Canon = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Canon' },
    WRITE_GROUP => 'MIE-Canon',
    VRD => {
        Name => 'CanonVRD',
        SubDirectory => { TagTable => 'Image::ExifTool::CanonVRD::Main' },
    },
);

%Image::ExifTool::MIE::Unknown = (
    PROCESS_PROC => \&ProcessMIE,
    GROUPS => { 1 => 'MIE-Unknown' },
);

#------------------------------------------------------------------------------
# Add user-defined MIE groups to %mieMap
# Inputs: none;  Returns: nothing, but sets $doneMieMap flag
sub UpdateMieMap()
{
    $doneMieMap = 1;    # set flag so we only do this once
    return unless %Image::ExifTool::UserDefined;
    my ($tableName, @tables, %doneTable, $tagID);
    # get list of top-level MIE tables with user-defined tags
    foreach $tableName (keys %Image::ExifTool::UserDefined) {
        next unless $tableName =~ /^Image::ExifTool::MIE::/;
        my $userTable = $Image::ExifTool::UserDefined{$tableName};
        my $tagTablePtr = GetTagTable($tableName) or next;
        # copy the WRITE_GROUP from the actual table
        $$userTable{WRITE_GROUP} = $$tagTablePtr{WRITE_GROUP};
        # add to list of tables to process
        $doneTable{$tableName} = 1;
        push @tables, [$tableName, $userTable];
    }
    # recursively add all user-defined groups to MIE map
    while (@tables) {
        my ($tableName, $tagTablePtr) = @{shift @tables};
        my $parent = $$tagTablePtr{WRITE_GROUP};
        $parent or warn("No WRITE_GROUP for $tableName\n"), next;
        $mieMap{$parent} or warn("$parent is not in MIE map\n"), next;
        foreach $tagID (TagTableKeys($tagTablePtr)) {
            my $tagInfo = $$tagTablePtr{$tagID};
            next unless ref $tagInfo eq 'HASH' and $$tagInfo{SubDirectory};
            my $subTableName = $tagInfo->{SubDirectory}->{TagTable};
            my $subTablePtr = GetTagTable($subTableName) or next;
            # only care about MIE tables
            next unless $$subTablePtr{PROCESS_PROC} and
                        $$subTablePtr{PROCESS_PROC} eq \&ProcessMIE;
            my $group = $$subTablePtr{WRITE_GROUP};
            $group or warn("No WRITE_GROUP for $subTableName\n"), next;
            if ($mieMap{$group} and $mieMap{$group} ne $parent) {
                warn("$group already has different parent ($mieMap{$group})\n"), next;
            }
            $mieMap{$group} = $parent;  # add to map
            # process tables within this one too
            $doneTable{$subTableName} and next;
            $doneTable{$subTableName} = 1;
            push @tables, [$subTableName, $subTablePtr];
        }
    }
}

#------------------------------------------------------------------------------
# Get localized version of tagInfo hash
# Inputs: 0) tagInfo hash ref, 1) locale code (eg. "en_CA")
# Returns: new tagInfo hash ref, or undef if invalid
sub GetLangInfo($$)
{
    my ($tagInfo, $langCode) = @_;
    # check for properly formatted language code
    return undef unless $langCode =~ /^[a-z]{2}([-_])[A-Z]{2}$/;
    # use '_' as a separator, but recognize '_' or '-'
    $langCode =~ tr/-/_/ if $1 eq '-';
    # can only set locale on string types
    return undef if $$tagInfo{Writable} and $$tagInfo{Writable} ne 'string';
    return Image::ExifTool::GetLangInfo($tagInfo, $langCode);
}

#------------------------------------------------------------------------------
# return true if we have Zlib::Compress
# Inputs: 0) ExifTool object ref, 1) verb for what you want to do with the info
# Returns: 1 if Zlib available, 0 otherwise
sub HasZlib($$)
{
    unless (defined $hasZlib) {
        $hasZlib = eval { require Compress::Zlib };
        unless ($hasZlib) {
            $hasZlib = 0;
            $_[0]->Warn("Install Compress::Zlib to $_[1] compressed information");
        }
    }
    return $hasZlib;
}

#------------------------------------------------------------------------------
# Get format code for MIE group element with current byte order
# Inputs: 0) [optional] true to convert result to chr()
# Returns: format code
sub MIEGroupFormat(;$)
{
    my $chr = shift;
    my $format = GetByteOrder() eq 'MM' ? 0x10 : 0x18;
    return $chr ? chr($format) : $format;
}

#------------------------------------------------------------------------------
# ReadValue() with added support for UTF formats (utf8, utf16 and utf32)
# Inputs: 0) data reference, 1) value offset, 2) format string,
#         3) number of values (or undef to use all data)
#         4) valid data length relative to offset, 5) returned rational ref
# Returns: converted value, or undefined if data isn't there
#          or list of values in list context
# Notes: all string formats are converted to UTF8
sub ReadMIEValue($$$$$;$)
{
    my ($dataPt, $offset, $format, $count, $size, $ratPt) = @_;
    my $val;
    if ($format =~ /^(utf(8|16|32)|string)/) {
        if ($1 eq 'utf8' or $1 eq 'string') {
            # read the 8-bit string
            $val = substr($$dataPt, $offset, $size);
            # (as of ExifTool 7.62, leave string values unconverted)
        } else {
            # convert to UTF8
            my $fmt;
            if (GetByteOrder() eq 'MM') {
                $fmt = ($1 eq 'utf16') ? 'n' : 'N';
            } else {
                $fmt = ($1 eq 'utf16') ? 'v' : 'V';
            }
            my @unpk = unpack("x$offset$fmt$size",$$dataPt);
            if ($] >= 5.006001) {
                $val = pack('C0U*', @unpk);
            } else {
                $val = Image::ExifTool::PackUTF8(@unpk);
            }
        }
        # truncate at null unless this is a list
        # (strings shouldn't have a null, but just in case)
        $val =~ s/\0.*//s unless $format =~ /_list$/;
    } else {
        $format = 'undef' if $format eq 'free'; # read 'free' as 'undef'
        return ReadValue($dataPt, $offset, $format, $count, $size, $ratPt);
    }
    return $val;
}

#------------------------------------------------------------------------------
# validate raw values for writing
# Inputs: 0) ExifTool object ref, 1) tagInfo hash ref, 2) raw value ref
# Returns: error string or undef (and possibly changes value) on success
sub CheckMIE($$$)
{
    my ($et, $tagInfo, $valPtr) = @_;
    my $format = $$tagInfo{Writable} || $tagInfo->{Table}->{WRITABLE};
    my $err;

    return 'No writable format' if not $format or $format eq '1';
    # handle units if supported by this tag
    my $ulist = $$tagInfo{Units};
    if ($ulist and $$valPtr =~ /(.*)\((.*)\)$/) {
        my ($val, $units) = ($1, $2);
        ($units) = grep /^$units$/i, @$ulist;
        defined $units or return 'Allowed units: (' . join('|', @$ulist) . ')';
        $err = Image::ExifTool::CheckValue(\$val, $format, $$tagInfo{Count});
        # add units back onto value
        $$valPtr = "$val($units)" unless $err;
    } elsif ($format !~ /^(utf|string|undef)/ and $$valPtr =~ /\)$/) {
        return 'Units not supported';
    } else {
        if ($format eq 'string' and $$et{OPTIONS}{Charset} ne 'UTF8' and
            $$valPtr =~ /[\x80-\xff]/)
        {
            # convert from Charset to UTF-8
            $$valPtr = $et->Encode($$valPtr,'UTF8');
        }
        $err = Image::ExifTool::CheckValue($valPtr, $format, $$tagInfo{Count});
    }
    return $err;
}

#------------------------------------------------------------------------------
# Rewrite a MIE directory
# Inputs: 0) ExifTool object reference, 1) DirInfo reference, 2) tag table ptr
# Returns: undef on success, otherwise error message (empty message if nothing to write)
sub WriteMIEGroup($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $outfile = $$dirInfo{OutFile};
    my $dirName = $$dirInfo{DirName};
    my $toWrite = $$dirInfo{ToWrite} || '';
    my $raf = $$dirInfo{RAF};
    my $verbose = $et->Options('Verbose');
    my $optCompress = $et->Options('Compress');
    my $out = $et->Options('TextOut');
    my ($msg, $err, $ok, $sync, $delGroup);
    my $tag = '';
    my $deletedTag = '';

    # count each MIE directory found and make name for this specific instance
    my ($grp1, %isWriting);
    my $cnt = $$et{MIE_COUNT};
    my $grp = $tagTablePtr->{GROUPS}->{1};
    my $n = $$cnt{'MIE-Main'} || 0;
    if ($grp eq 'MIE-Main') {
        $$cnt{$grp} = ++$n;
        ($grp1 = $grp) =~ s/MIE-/MIE$n-/;
    } else {
        ($grp1 = $grp) =~ s/MIE-/MIE$n-/;
        my $m = $$cnt{$grp1} = ($$cnt{$grp1} || 0) + 1;
        $isWriting{"$grp$m"} = 1;   # eg. 'MIE-Doc2'
        $isWriting{$grp1} = 1;      # eg. 'MIE1-Doc'
        $grp1 .= $m;
    }
    # build lookup for all valid group names for this MIE group
    $isWriting{$grp} = 1;           # eg. 'MIE-Doc'
    $isWriting{$grp1} = 1;          # eg. 'MIE1-Doc2'
    $isWriting{"MIE$n"} = 1;        # eg. 'MIE1'

    # determine if we are deleting this group
    if (%{$$et{DEL_GROUP}}) {
        $delGroup = 1 if $$et{DEL_GROUP}{MIE} or
                         $$et{DEL_GROUP}{$grp} or
                         $$et{DEL_GROUP}{$grp1} or
                         $$et{DEL_GROUP}{"MIE$n"};
    }

    # prepare lookups and lists for writing
    my $newTags = $et->GetNewTagInfoHash($tagTablePtr);
    my ($addDirs, $editDirs) = $et->GetAddDirHash($tagTablePtr, $dirName);
    my @editTags = sort keys %$newTags, keys %$editDirs;
    $verbose and print $out $raf ? 'Writing' : 'Creating', " $grp1:\n";

    # loop through elements in MIE group
    MieElement: for (;;) {
        my ($format, $tagLen, $valLen, $units, $oldHdr, $buff);
        my $lastTag = $tag;
        if ($raf) {
            # read first 4 bytes of element header
            my $n = $raf->Read($oldHdr, 4);
            if ($n != 4) {
                last if $n or defined $sync;
                undef $raf; # all done reading
                $ok = 1;
            }
        }
        if ($raf) {
            ($sync, $format, $tagLen, $valLen) = unpack('aC3', $oldHdr);
            $sync eq '~' or $msg = 'Invalid sync byte', last;

            # read tag name
            if ($tagLen) {
                $raf->Read($tag, $tagLen) == $tagLen or last;
                $oldHdr .= $tag;    # add tag to element header
                $et->Warn("MIE tag '$tag' out of sequence") if $tag lt $lastTag;
                # separate units from tag name if they exist
                $units = $1 if $tag =~ s/\((.*)\)$//;
            } else {
                $tag = '';
            }

            # get multi-byte value length if necessary
            if ($valLen > 252) {
                # calculate number of bytes in extended DataLength
                my $n = 1 << (256 - $valLen);
                $raf->Read($buff, $n) == $n or last;
                $oldHdr .= $buff;   # add to old header
                my $fmt = 'int' . ($n * 8) . 'u';
                $valLen = ReadValue(\$buff, 0, $fmt, 1, $n);
                if ($valLen > 0x7fffffff) {
                    $msg = "Can't write $tag (DataLength > 2GB not yet supported)";
                    last;
                }
            }
            # don't rewrite free bytes or information in deleted groups
            if ($format eq 0x80 or ($delGroup and $tagLen and ($format & 0xf0) != 0x10)) {
                $raf->Seek($valLen, 1) or $msg = 'Seek error', last;
                if ($verbose > 1) {
                    my $free = ($format eq 0x80) ? ' free' : '';
                    print $out "    - $grp1:$tag ($valLen$free bytes)\n";
                }
                ++$$et{CHANGED} if $delGroup;
                next;
            }
        } else {
            # no more elements to read
            $tagLen = $valLen = 0;
            $tag = '';
        }
#
# write necessary new tags and process directories
#
        while (@editTags) {
            last if $tagLen and $editTags[0] gt $tag;
            # we are writing the new tag now
            my ($newVal, $writable, $oldVal, $newFormat, $compress);
            my $newTag = shift @editTags;
            my $newInfo = $$editDirs{$newTag};
            if ($newInfo) {
                # create the new subdirectory or rewrite existing non-MIE directory
                my $subTablePtr = GetTagTable($newInfo->{SubDirectory}->{TagTable});
                unless ($subTablePtr) {
                    $et->Warn("No tag table for $newTag $$newInfo{Name}");
                    next;
                }
                my %subdirInfo;
                my $isMieGroup = ($$subTablePtr{WRITE_PROC} and
                                  $$subTablePtr{WRITE_PROC} eq \&ProcessMIE);

                if ($newTag eq $tag) {
                    # make sure that either both or neither old and new tags are MIE groups
                    if ($isMieGroup xor ($format & 0xf3) == 0x10) {
                        $et->Warn("Tag '$tag' not expected type");
                        next;   # don't write our new tag
                    }
                    # uncompress existing directory into $oldVal since we are editing it
                    if ($format & 0x04) {
                        last unless HasZlib($et, 'edit');
                        $raf->Read($oldVal, $valLen) == $valLen or last MieElement;
                        my $stat;
                        my $inflate = Compress::Zlib::inflateInit();
                        $inflate and ($oldVal, $stat) = $inflate->inflate($oldVal);
                        unless ($inflate and $stat == Compress::Zlib::Z_STREAM_END()) {
                            $msg = "Error inflating $tag";
                            last MieElement;
                        }
                        $compress = 1;
                        $valLen = length $oldVal;    # uncompressed value length
                    }
                } else {
                    # don't create this directory unless necessary
                    next unless $$addDirs{$newTag};
                }

                if ($isMieGroup) {
                    my $hdr;
                    if ($newTag eq $tag) {
                        # rewrite existing directory later unless it was compressed
                        last unless $compress;
                        # rewrite directory to '$newVal'
                        $newVal = '';
                        %subdirInfo = (
                            OutFile => \$newVal,
                            RAF => new File::RandomAccess(\$oldVal),
                        );
                    } elsif ($optCompress and not $$dirInfo{IsCompressed}) {
                        # write to memory so we can compress the new MIE group
                        $compress = 1;
                        %subdirInfo = (
                            OutFile => \$newVal,
                        );
                    } else {
                        $hdr = '~' . MIEGroupFormat(1) . chr(length($newTag)) .
                               "\0" . $newTag;
                        %subdirInfo = (
                            OutFile => $outfile,
                            ToWrite => $toWrite . $hdr,
                        );
                    }
                    $subdirInfo{DirName} = $newInfo->{SubDirectory}->{DirName} || $newTag;
                    $subdirInfo{Parent} = $dirName;
                    # don't compress elements of an already compressed group
                    $subdirInfo{IsCompressed} = $$dirInfo{IsCompressed} || $compress;
                    $msg = WriteMIEGroup($et, \%subdirInfo, $subTablePtr);
                    last MieElement if $msg;
                    # message is defined but empty if nothing was written
                    if (defined $msg) {
                        undef $msg; # not a problem if nothing was written
                        next;
                    } elsif (not $compress) {
                        # group was written already
                        $toWrite = '';
                        next;
                    } elsif (length($newVal) <= 4) {    # terminator only?
                        $verbose and print $out "Deleted compressed $grp1 (empty)\n";
                        next MieElement if $newTag eq $tag; # deleting the directory
                        next;       # not creating the new directory
                    }
                    $writable = 'undef';
                    $newFormat = MIEGroupFormat();
                } else {
                    if ($newTag eq $tag) {
                        unless ($compress) {
                            # read and edit existing directory
                            $raf->Read($oldVal, $valLen) == $valLen or last MieElement;
                        }
                        %subdirInfo = (
                            DataPt  => \$oldVal,
                            DataLen => $valLen,
                            DirName => $$newInfo{Name},
                            DataPos => $$dirInfo{IsCompressed} ? undef : $raf->Tell() - $valLen,
                            DirStart=> 0,
                            DirLen  => $valLen,
                        );
                        # write Compact subdirectories if we will compress the data
                        if (($compress or $optCompress or $$dirInfo{IsCompressed}) and
                            eval { require Compress::Zlib })
                        {
                            $subdirInfo{Compact} = 1;
                        }
                    }
                    $subdirInfo{Parent} = $dirName;
                    my $writeProc = $newInfo->{SubDirectory}->{WriteProc};
                    # reset processed lookup to avoid errors in case of multiple EXIF blocks
                    $$et{PROCESSED} = { };
                    $newVal = $et->WriteDirectory(\%subdirInfo, $subTablePtr, $writeProc);
                    if (defined $newVal) {
                        if ($newVal eq '') {
                            next MieElement if $newTag eq $tag; # deleting the directory
                            next;       # not creating the new directory
                        }
                    } else {
                        next unless defined $oldVal;
                        $newVal = $oldVal;  # just copy over the old directory
                    }
                    $writable = 'undef';
                    $newFormat = 0x00;  # all other directories are 'undef' format
                }
            } else {

                # get the new tag information
                $newInfo = $$newTags{$newTag};
                my $nvHash = $et->GetNewValueHash($newInfo);
                my @newVals;

                # write information only to specified group
                my $writeGroup = $$nvHash{WriteGroup};
                last unless $isWriting{$writeGroup};

                # if tag existed, must decide if we want to overwrite the value
                if ($newTag eq $tag) {
                    my $isOverwriting;
                    my $isList = $$newInfo{List};
                    if ($isList) {
                        last if $$nvHash{CreateOnly};
                        $isOverwriting = -1;    # force processing list elements individually
                    } else {
                        $isOverwriting = $et->IsOverwriting($nvHash);
                        last unless $isOverwriting;
                    }
                    my ($val, $cmpVal);
                    if ($isOverwriting < 0 or $verbose > 1) {
                        # check to be sure we can uncompress the value if necessary
                        HasZlib($et, 'edit') or last if $format & 0x04;
                        # read the old value
                        $raf->Read($oldVal, $valLen) == $valLen or last MieElement;
                        # uncompress if necessary
                        if ($format & 0x04) {
                            my $stat;
                            my $inflate = Compress::Zlib::inflateInit();
                            # must save original compressed value in case we decide
                            # not to overwrite it later
                            $cmpVal = $oldVal;
                            $inflate and ($oldVal, $stat) = $inflate->inflate($oldVal);
                            unless ($inflate and $stat == Compress::Zlib::Z_STREAM_END()) {
                                $msg = "Error inflating $tag";
                                last MieElement;
                            }
                            $valLen = length $oldVal;    # update value length
                        }
                        # convert according to specified format
                        my $formatStr = $mieFormat{$format & 0xfb} || 'undef';
                        $val = ReadMIEValue(\$oldVal, 0, $formatStr, undef, $valLen);
                        if ($isOverwriting < 0 and defined $val) {
                            # handle list values individually
                            if ($isList) {
                                my (@vals, $v);
                                if ($formatStr =~ /_list$/) {
                                    @vals = split "\0", $val;
                                } else {
                                    @vals = $val;
                                }
                                # keep any list items that we aren't overwriting
                                foreach $v (@vals) {
                                    next if $et->IsOverwriting($nvHash, $v);
                                    push @newVals, $v;
                                }
                            } else {
                                # test to see if we really want to overwrite the value
                                $isOverwriting = $et->IsOverwriting($nvHash, $val);
                            }
                        }
                    }
                    if ($isOverwriting) {
                        # skip the old value if we didn't read it already
                        unless (defined $oldVal) {
                            $raf->Seek($valLen, 1) or $msg = 'Seek error';
                        }
                        if ($verbose > 1) {
                            $val .= "($units)" if defined $units;
                            $et->VerboseValue("- $grp1:$$newInfo{Name}", $val);
                        }
                        $deletedTag = $tag;     # remember that we deleted this tag
                        ++$$et{CHANGED}; # we deleted the old value
                    } else {
                        if (defined $oldVal) {
                            # write original compressed value
                            $oldVal = $cmpVal if defined $cmpVal;
                        } else {
                            $raf->Read($oldVal, $valLen) == $valLen or last MieElement;
                        }
                        # write the old value now
                        Write($outfile, $toWrite, $oldHdr, $oldVal) or $err = 1;
                        $toWrite = '';
                        next MieElement;
                    }
                    unless (@newVals) {
                        # unshift the new tag info to write it later
                        unshift @editTags, $newTag;
                        next MieElement;    # get next element from file
                    }
                } else {
                    # write new value if creating, or if List and list existed, or
                    # if tag was previously deleted
                    next unless $$nvHash{IsCreating} or
                        (($newTag eq $lastTag and ($$newInfo{List} or $deletedTag eq $lastTag)
                        and not $$nvHash{EditOnly}));
                }
                # get the new value to write (undef to delete)
                push @newVals, $et->GetNewValues($nvHash);
                next unless @newVals;
                $writable = $$newInfo{Writable} || $$tagTablePtr{WRITABLE};
                if ($writable eq 'string') {
                    # join multiple values into a single string
                    $newVal = join "\0", @newVals;
                    # write string as UTF-8,16 or 32 if value contains valid UTF-8 codes
                    require Image::ExifTool::XMP;
                    my $isUTF8 = Image::ExifTool::XMP::IsUTF8(\$newVal);
                    if ($isUTF8 > 0) {
                        $writable = 'utf8';
                        # write UTF-16 or UTF-32 if it is more compact
                        my $to = $isUTF8 > 1 ? 'UCS4' : 'UCS2';
                        my $tmp = Image::ExifTool::Decode(undef,$newVal,'UTF8',undef,$to);
                        if (length $tmp < length $newVal) {
                            $newVal = $tmp;
                            $writable = ($isUTF8 > 1) ? 'utf32' : 'utf16';
                        }
                    }
                    # write as a list if we have multiple values
                    $writable .= '_list' if @newVals > 1;
                } else {
                    # should only be one element in the list
                    $newVal = shift @newVals;
                }
                $newFormat = $mieCode{$writable};
                unless (defined $newFormat) {
                    $msg = "Bad format '$writable' for $$newInfo{Name}";
                    next MieElement;
                }
            }

            # write the new or edited element
            while (defined $newFormat) {
                my $valPt = \$newVal;
                # remove units from value and add to tag name if supported by this tag
                if ($$newInfo{Units}) {
                    my $val2;
                    if ($$valPt =~ /(.*)\((.*)\)$/) {
                        $val2 = $1;
                        $newTag .= "($2)";
                    } else {
                        $val2 = $$valPt;
                        # add default units
                        my $ustr = '(' . $newInfo->{Units}->[0] . ')';
                        $newTag .= $ustr;
                        $$valPt .= $ustr;
                    }
                    $valPt = \$val2;
                }
                # convert value if necessary
                if ($writable !~ /^(utf|string|undef)/) {
                    my $val3 = WriteValue($$valPt, $writable, $$newInfo{Count});
                    defined $val3 or $et->Warn("Error writing $newTag"), last;
                    $valPt = \$val3;
                }
                my $len = length $$valPt;
                # compress value before writing if required
                if (($compress or $optCompress) and not $$dirInfo{IsCompressed} and
                    HasZlib($et, 'write'))
                {
                    my $deflate = Compress::Zlib::deflateInit();
                    my $val4;
                    if ($deflate) {
                        $val4 = $deflate->deflate($$valPt);
                        $val4 .= $deflate->flush() if defined $val4;
                    }
                    if (defined $val4) {
                        my $len4 = length $val4;
                        my $saved = $len - $len4;
                        # only use compressed data if it is smaller
                        if ($saved > 0) {
                            $verbose and print $out "  [$newTag compression saved $saved bytes]\n";
                            $newFormat |= 0x04; # set compressed bit
                            $len = $len4;       # set length
                            $valPt = \$val4;    # set value pointer
                        } elsif ($verbose) {
                            print $out "  [$newTag compression saved $saved bytes -- written uncompressed]\n";
                        }
                    } else {
                        $et->Warn("Error deflating $newTag (written uncompressed)");
                    }
                }
                # calculate the DataLength code
                my $extLen;
                if ($len < 253) {
                    $extLen = '';
                } elsif ($len < 65536) {
                    $extLen = Set16u($len);
                    $len = 255;
                } elsif ($len <= 0x7fffffff) {
                    $extLen = Set32u($len);
                    $len = 254;
                } else {
                    $et->Warn("Can't write $newTag (DataLength > 2GB not yet suppported)");
                    last; # don't write this tag
                }
                # write this element (with leading MIE group element if not done already)
                my $hdr = $toWrite . '~' . chr($newFormat) . chr(length $newTag);
                Write($outfile, $hdr, chr($len), $newTag, $extLen, $$valPt) or $err = 1;
                $toWrite = '';
                # we changed a tag unless just editing a subdirectory
                unless ($$editDirs{$newTag}) {
                    $et->VerboseValue("+ $grp1:$$newInfo{Name}", $newVal);
                    ++$$et{CHANGED};
                }
                last;   # didn't want to loop anyway
            }
            next MieElement if defined $oldVal;
        }
#
# rewrite existing element or descend into uncompressed MIE group
#
        # all done this MIE group if we reached the terminator element
        unless ($tagLen) {
            # skip over existing terminator data (if any)
            last if $valLen and not $raf->Seek($valLen, 1);
            $ok = 1;
            # write group terminator if necessary
            unless ($toWrite) {
                # write end-of-group terminator element
                my $term = "~\0\0\0";
                unless ($$dirInfo{Parent}) {
                    # write extended terminator for file-level group
                    my $len = ref $outfile eq 'SCALAR' ? length($$outfile) : tell $outfile;
                    $len += 10; # include length of terminator itself
                    if ($len and $len <= 0x7fffffff) {
                        $term = "~\0\0\x06" . Set32u($len) . MIEGroupFormat(1) . "\x04";
                    }
                }
                Write($outfile, $term) or $err = 1;
            }
            last;
        }

        # descend into existing uncompressed MIE group
        if ($format == 0x10 or $format == 0x18) {
            my ($subTablePtr, $dirName);
            my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
            if ($tagInfo and $$tagInfo{SubDirectory}) {
                $dirName = $tagInfo->{SubDirectory}->{DirName};
                my $subTable = $tagInfo->{SubDirectory}->{TagTable};
                $subTablePtr = $subTable ? GetTagTable($subTable) : $tagTablePtr;
            } else {
                $subTablePtr = GetTagTable('Image::ExifTool::MIE::Unknown');
            }
            my $hdr = '~' . chr($format) . chr(length $tag) . "\0" . $tag;
            my %subdirInfo = (
                DirName => $dirName || $tag,
                RAF     => $raf,
                ToWrite => $toWrite . $hdr,
                OutFile => $outfile,
                Parent  => $dirName,
                IsCompressed => $$dirInfo{IsCompressed},
            );
            my $oldOrder = GetByteOrder();
            SetByteOrder($format & 0x08 ? 'II' : 'MM');
            $msg = WriteMIEGroup($et, \%subdirInfo, $subTablePtr);
            SetByteOrder($oldOrder);
            last if $msg;
            if (defined $msg) {
                undef $msg; # no problem if nothing written
            } else {
                $toWrite = '';
            }
            next;
        }
        # just copy existing element
        my $oldVal;
        $raf->Read($oldVal, $valLen) == $valLen or last;
        if ($toWrite) {
            Write($outfile, $toWrite) or $err = 1;
            $toWrite = '';
        }
        Write($outfile, $oldHdr, $oldVal) or $err = 1;
    }
    # return error message
    if ($err) {
        $msg = 'Error writing file';
    } elsif (not $ok and not $msg) {
        $msg = 'Unexpected end of file';
    } elsif (not $msg and $toWrite) {
        $msg = '';  # flag for nothing written
        $verbose and print $out "Deleted $grp1 (empty)\n";
    }
    return $msg;
}

#------------------------------------------------------------------------------
# Process MIE directory
# Inputs: 0) ExifTool object reference, 1) DirInfo reference, 2) tag table ref
# Returns: undef on success, or error message if there was a problem
# Notes: file pointer is positioned at the MIE end on entry
sub ProcessMIEGroup($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $raf = $$dirInfo{RAF};
    my $verbose = $et->Options('Verbose');
    my $out = $et->Options('TextOut');
    my $notUTF8 = ($$et{OPTIONS}{Charset} ne 'UTF8');
    my ($msg, $buff, $ok, $oldIndent, $mime);
    my $lastTag = '';

    # get group 1 names: $grp doesn't have numbers (eg. 'MIE-Doc'),
    # and $grp1 does (eg. 'MIE1-Doc1')
    my $cnt = $$et{MIE_COUNT};
    my $grp1 = $tagTablePtr->{GROUPS}->{1};
    my $n = $$cnt{'MIE-Main'} || 0;
    if ($grp1 eq 'MIE-Main') {
        $$cnt{$grp1} = ++$n;
        $grp1 =~ s/MIE-/MIE$n-/ if $n > 1;
    } else {
        $grp1 =~ s/MIE-/MIE$n-/ if $n > 1;
        $$cnt{$grp1} = ($$cnt{$grp1} || 0) + 1;
        $grp1 .= $$cnt{$grp1} if $$cnt{$grp1} > 1;
    }
    # set group1 name for all tags extracted from this group
    $$et{SET_GROUP1} = $grp1;

    if ($verbose) {
        $oldIndent = $$et{INDENT};
        $$et{INDENT} .= '| ';
        $et->VerboseDir($grp1);
    }
    my $wasCompressed = $$dirInfo{WasCompressed};

    # process all MIE elements
    for (;;) {
        $raf->Read($buff, 4) == 4 or last;
        my ($sync, $format, $tagLen, $valLen) = unpack('aC3', $buff);
        $sync eq '~' or $msg = 'Invalid sync byte', last;

        # read tag name
        my ($tag, $units);
        if ($tagLen) {
            $raf->Read($tag, $tagLen) == $tagLen or last;
            $et->Warn("MIE tag '$tag' out of sequence") if $tag lt $lastTag;
            $lastTag = $tag;
            # separate units from tag name if they exist
            $units = $1 if $tag =~ s/\((.*)\)$//;
        } else {
            $tag = '';
        }

        # get multi-byte value length if necessary
        if ($valLen > 252) {
            my $n = 1 << (256 - $valLen);
            $raf->Read($buff, $n) == $n or last;
            my $fmt = 'int' . ($n * 8) . 'u';
            $valLen = ReadValue(\$buff, 0, $fmt, 1, $n);
            if ($valLen > 0x7fffffff) {
                $msg = "Can't read $tag (DataLength > 2GB not yet supported)";
                last;
            }
        }

        # all done if we reached the group terminator
        unless ($tagLen) {
            # skip over terminator data block
            $ok = 1 unless $valLen and not $raf->Seek($valLen, 1);
            last;
        }

        # get tag information hash unless this is free space
        my ($tagInfo, $value);
        while ($format != 0x80) {
            $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
            last if $tagInfo;
            # extract tags with locale code
            if ($tag =~ /\W/) {
                if ($tag =~ /^(\w+)-([a-z]{2}_[A-Z]{2})$/) {
                    my ($baseTag, $langCode) = ($1, $2);
                    $tagInfo = $et->GetTagInfo($tagTablePtr, $baseTag);
                    $tagInfo = GetLangInfo($tagInfo, $langCode) if $tagInfo;
                    last if $tagInfo;
                } else {
                    $et->Warn('Invalid MIE tag name');
                    last;
                }
            }
            # extract unknown tags if specified
            $tagInfo = {
                Name => $tag,
                Writable => 0,
                PrintConv => 'length($val) > 60 ? substr($val,0,55) . "[...]" : $val',
            };
            AddTagToTable($tagTablePtr, $tag, $tagInfo);
            last;
        }

        # read value and uncompress if necessary
        my $formatStr = $mieFormat{$format & 0xfb} || 'undef';
        if ($tagInfo or ($formatStr eq 'MIE' and $format & 0x04)) {
            $raf->Read($value, $valLen) == $valLen or last;
            if ($format & 0x04) {
                if ($verbose) {
                    print $out "$$et{INDENT}\[Tag '$tag' $valLen bytes compressed]\n";
                }
                next unless HasZlib($et, 'decode');
                my $stat;
                my $inflate = Compress::Zlib::inflateInit();
                $inflate and ($value, $stat) = $inflate->inflate($value);
                unless ($inflate and $stat == Compress::Zlib::Z_STREAM_END()) {
                    $et->Warn("Error inflating $tag");
                    next;
                }
                $valLen = length $value;
                $wasCompressed = 1;
            }
        }

        # process this tag
        if ($formatStr eq 'MIE') {
            # process MIE directory
            my ($subTablePtr, $dirName);
            if ($tagInfo and $$tagInfo{SubDirectory}) {
                $dirName = $tagInfo->{SubDirectory}->{DirName};
                my $subTable = $tagInfo->{SubDirectory}->{TagTable};
                $subTablePtr = $subTable ? GetTagTable($subTable) : $tagTablePtr;
            } else {
                $subTablePtr = GetTagTable('Image::ExifTool::MIE::Unknown');
            }
            if ($verbose) {
                my $order = ', byte order ' . GetByteOrder();
                $et->VerboseInfo($tag, $tagInfo, Size => $valLen, Extra => $order);
            }
            my %subdirInfo = (
                DirName => $dirName || $tag,
                RAF     => $raf,
                Parent  => $$dirInfo{DirName},
                WasCompressed => $wasCompressed,
            );
            # read from uncompressed data instead if necessary
            $subdirInfo{RAF} = new File::RandomAccess(\$value) if $valLen;

            my $oldOrder = GetByteOrder();
            SetByteOrder($format & 0x08 ? 'II' : 'MM');
            $msg = ProcessMIEGroup($et, \%subdirInfo, $subTablePtr);
            SetByteOrder($oldOrder);
            $$et{SET_GROUP1} = $grp1;    # restore this group1 name
            last if $msg;
        } else {
            # process MIE data format types
            if ($tagInfo) {
                my $rational;
                # extract tag value
                my $val = ReadMIEValue(\$value, 0, $formatStr, undef, $valLen, \$rational);
                unless (defined $val) {
                    $et->Warn("Error reading $tag value");
                    $val = '<err>';
                }
                # save type or mime type
                $mime = $val if $tag eq '0Type' or $tag eq '2MIME';
                if ($verbose) {
                    my $count;
                    my $s = Image::ExifTool::FormatSize($formatStr);
                    if ($s and $formatStr !~ /^(utf|string|undef)/) {
                        $count = $valLen / $s;
                    }
                    $et->VerboseInfo($lastTag, $tagInfo,
                        DataPt  => \$value,
                        DataPos => $raf->Tell() - $valLen,
                        Size    => $valLen,
                        Format  => $formatStr,
                        Value   => $val,
                        Count   => $count,
                    );
                }
                if ($$tagInfo{SubDirectory}) {
                    my $subTablePtr = GetTagTable($tagInfo->{SubDirectory}->{TagTable});
                    my %subdirInfo = (
                        DirName => $$tagInfo{Name},
                        DataPt  => \$value,
                        DataLen => $valLen,
                        DirStart=> 0,
                        DirLen  => $valLen,
                        Parent  => $$dirInfo{DirName},
                        WasCompressed => $wasCompressed,
                    );
                    # set DataPos and Base for uncompressed information only
                    unless ($wasCompressed) {
                        $subdirInfo{DataPos} = 0; # (relative to Base)
                        $subdirInfo{Base}    = $raf->Tell() - $valLen;
                    }
                    # reset PROCESSED lookup for each MIE directory
                    # (there is no possibility of double-processing a MIE directory)
                    $$et{PROCESSED} = { };
                    my $processProc = $tagInfo->{SubDirectory}->{ProcessProc};
                    delete $$et{SET_GROUP1};
                    delete $$et{NO_LIST};
                    $et->ProcessDirectory(\%subdirInfo, $subTablePtr, $processProc);
                    $$et{SET_GROUP1} = $grp1;
                    $$et{NO_LIST} = 1;
                } else {
                    # convert to specified character set if necessary
                    if ($notUTF8 and $formatStr =~ /^(utf|string)/) {
                        $val = $et->Decode($val, 'UTF8');
                    }
                    if ($formatStr =~ /_list$/) {
                        # split list value into separate strings
                        my @vals = split "\0", $val;
                        $val = \@vals;
                    }
                    if (defined $units) {
                        $val = "@$val" if ref $val; # convert string list to number list
                        # add units to value if specified
                        $val .= "($units)" if defined $units;
                    }
                    my $key = $et->FoundTag($tagInfo, $val);
                    $$et{RATIONAL}{$key} = $rational if defined $rational and defined $key;
                }
            } else {
                # skip over unknown information or free bytes
                $raf->Seek($valLen, 1) or $msg = 'Seek error', last;
                $verbose and $et->VerboseInfo($tag, undef, Size => $valLen);
            }
        }
    }
    # modify MIME type if necessary
    $mime and not $$dirInfo{Parent} and $et->ModifyMimeType($mime);

    $ok or $msg or $msg = 'Unexpected end of file';
    $verbose and $$et{INDENT} = $oldIndent;
    return $msg;
}

#------------------------------------------------------------------------------
# Read/write a MIE file
# Inputs: 0) ExifTool object reference, 1) DirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid MIE file, or -1 on write error
# - process as a trailer if "Trailer" flag set in dirInfo
sub ProcessMIE($$)
{
    my ($et, $dirInfo) = @_;
    return 1 unless defined $et;
    my $raf = $$dirInfo{RAF};
    my $outfile = $$dirInfo{OutFile};
    my ($buff, $err, $msg, $pos, $end, $isCreating);
    my $numDocs = 0;
#
# process as a trailer (from end of file) if specified
#
    if ($$dirInfo{Trailer}) {
        my $offset = $$dirInfo{Offset} || 0;    # offset from end of file
        $raf->Seek(-10 - $offset, 2) or return 0;
        for (;;) {
            # read and validate last 10 bytes
            $raf->Read($buff, 10) == 10 or last;
            last unless $buff =~ /~\0\0\x06.{4}(\x10|\x18)(\x04)$/s or
                        $buff =~ /(\x10|\x18)(\x08)$/s;
            SetByteOrder($1 eq "\x10" ? 'MM' : 'II');
            my $len = ($2 eq "\x04") ? Get32u(\$buff, 4) : Get64u(\$buff, 0);
            my $curPos = $raf->Tell() or last;
            last if $len < 12 or $len > $curPos;
            # validate element header if 8-byte offset was used
            if ($2 eq "\x08") {
                last if $len < 14;
                $raf->Seek($curPos - 14, 0) and $raf->Read($buff, 4) or last;
                last unless $buff eq "~\0\0\x0a";
            }
            # looks like a good group, so remember start position
            $pos = $curPos - $len;
            $end = $curPos unless $end;
            # seek to 10 bytes from end of previous group
            $raf->Seek($pos - 10, 0) or last;
        }
        # seek to start of first MIE group
        return 0 unless defined $pos and $raf->Seek($pos, 0);
        # update DataPos and DirLen for ProcessTrailers()
        $$dirInfo{DataPos} = $pos;
        $$dirInfo{DirLen} = $end - $pos;
        if ($outfile and $$et{DEL_GROUP}{MIE}) {
            # delete the trailer
            $et->VPrint(0,"  Deleting MIE trailer\n");
            ++$$et{CHANGED};
            return 1;
        } elsif ($et->Options('Verbose') or $$et{HTML_DUMP}) {
            $et->DumpTrailer($dirInfo);
        }
    }
#
# loop through all documents in MIE file
#
    for (;;) {
        # look for "0MIE" group element
        my $num = $raf->Read($buff, 8);
        if ($num == 8) {
            # verify file identifier
            if ($buff =~ /^~(\x10|\x18)\x04(.)0MIE/s) {
                SetByteOrder($1 eq "\x10" ? 'MM' : 'II');
                my $len = ord($2);
                # skip extended DataLength if it exists
                if ($len > 252 and not $raf->Seek(1 << (256 - $len), 1)) {
                    $msg = 'Seek error';
                    last;
                }
            } else {
                return 0 unless $numDocs;   # not a MIE file
                if ($buff =~ /^~/) {
                    $msg = 'Non-standard file-level MIE element';
                } else {
                    $msg = 'Invalid MIE file-level data';
                }
            }
        } elsif ($numDocs) {
            last unless $num;   # OK, all done with file
            $msg = 'Truncated MIE element header';
        } else {
            return 0 if $num or not $outfile;
            # we have the ability to create a MIE file from scratch
            $buff = ''; # start from nothing
            # set byte order according to preferences
            $et->SetPreferredByteOrder();
            $isCreating = 1;
        }
        if ($msg) {
            last if $$dirInfo{Trailer}; # allow other trailers after MIE
            if ($outfile) {
                $et->Error($msg);
            } else {
                $et->Warn($msg);
            }
            last;
        }
        # this is a new MIE document -- increment document count
        unless ($numDocs) {
            # this is a valid MIE file (unless a trailer on another file)
            $et->SetFileType();
            $$et{NO_LIST} = 1;   # handle lists ourself
            $$et{MIE_COUNT} = { };
            undef $hasZlib;
        }
        ++$numDocs;

        # process the MIE groups recursively, beginning with the main MIE group
        my $tagTablePtr = GetTagTable('Image::ExifTool::MIE::Main');

        my %subdirInfo = (
            DirName => 'MIE',
            RAF => $raf,
            OutFile => $outfile,
            # don't define Parent so WriteMIEGroup() writes extended terminator
        );
        if ($outfile) {
            # generate lookup for MIE format codes if not done already
            unless (%mieCode) {
                foreach (keys %mieFormat) {
                    $mieCode{$mieFormat{$_}} = $_;
                }
            }
            # update %mieMap with user-defined MIE groups
            UpdateMieMap() unless $doneMieMap;
            # initialize write directories, with MIE tags taking priority
            # (note that this may re-initialize directories when writing trailer
            #  to another type of image, but this is OK because we are done writing
            #  the other format by the time we start writing the trailer)
            $et->InitWriteDirs(\%mieMap, 'MIE');
            $subdirInfo{ToWrite} = '~' . MIEGroupFormat(1) . "\x04\xfe0MIE\0\0\0\0";
            $msg = WriteMIEGroup($et, \%subdirInfo, $tagTablePtr);
            if ($msg) {
                $et->Error($msg);
                $err = 1;
                last;
            } elsif (defined $msg and $isCreating) {
                last;
            }
        } else {
            $msg = ProcessMIEGroup($et, \%subdirInfo, $tagTablePtr);
            if ($msg) {
                $et->Warn($msg);
                last;
            }
        }
    }
    delete $$et{NO_LIST};
    delete $$et{MIE_COUNT};
    delete $$et{SET_GROUP1};
    return $err ? -1 : 1;
}

1;  # end

__END__

#line 2564

