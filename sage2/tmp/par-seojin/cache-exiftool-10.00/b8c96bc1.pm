#line 1 "../blib/lib/PAR/Filter.pm"
package PAR::Filter;
$PAR::Filter::VERSION = '0.02';

#line 58

sub new {
    my $class = shift;
    require "PAR/Filter/$_.pm" foreach @_;
    bless(\@_, $class);
}

sub apply {
    my ($self, $ref, $name) = @_;
    my $filename = $name || '-e';

    if (!ref $ref) {
	$name ||= $filename = $ref;
	local $/;
	open my $fh, $ref or die $!;
	binmode($fh);
	my $content = <$fh>;
	$ref = \$content;
	return $ref unless length($content);
    }

    "PAR::Filter::$_"->new->apply( $ref, $filename, $name ) foreach @$self;

    return $ref;
}

1;

#line 100
