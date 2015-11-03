#line 1 "MIME/Base64.pm"
package MIME::Base64;

# $Id: Base64.pm,v 3.5 2004/09/20 09:23:23 gisle Exp $

use strict;
use vars qw(@ISA @EXPORT $VERSION);

require Exporter;
require DynaLoader;
@ISA = qw(Exporter DynaLoader);
@EXPORT = qw(encode_base64 decode_base64);

$VERSION = '3.05';

MIME::Base64->bootstrap($VERSION);

*encode = \&encode_base64;
*decode = \&decode_base64;

1;

__END__

#line 153
