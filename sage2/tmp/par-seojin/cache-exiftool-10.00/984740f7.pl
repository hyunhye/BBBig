package main; shift @INC;
#line 1 "script/main.pl"
my $zip = $PAR::LibCache{$ENV{PAR_PROGNAME}} || Archive::Zip->new(__FILE__);
my $member = eval { $zip->memberNamed('script/exiftool') }
        or die qq(main.pl: Can't open perl script "script/exiftool": No such file or directory ($zip));
PAR::_run_member($member, 1);

