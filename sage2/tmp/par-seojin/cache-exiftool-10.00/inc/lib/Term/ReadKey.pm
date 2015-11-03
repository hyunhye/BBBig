#line 1 "Term/ReadKey.pm"
#
#  $Id: ReadKey.pm,v 2.23 2005/01/11 21:16:31 jonathan Exp $
#

#line 210

package Term::ReadKey;

$VERSION = '2.30';

require Exporter;
require AutoLoader;
require DynaLoader;
use Carp;

@ISA = qw(Exporter AutoLoader DynaLoader);

# Items to export into callers namespace by default
# (move infrequently used names to @EXPORT_OK below)

@EXPORT = qw(
  ReadKey
  ReadMode
  ReadLine
  GetTerminalSize
  SetTerminalSize
  GetSpeed
  GetControlChars
  SetControlChars
);

@EXPORT_OK = qw();

bootstrap Term::ReadKey;

# Preloaded methods go here.  Autoload methods go after __END__, and are
# processed by the autosplit program.

# Should we use LINES and COLUMNS to try and get the terminal size?
# Change this to zero if you have systems where these are commonly
# set to erroneous values. (But if either are nero zero, they won't be
# used anyhow.)

$UseEnv = 1;

%modes = (
    original    => 0,
    restore     => 0,
    normal      => 1,
    noecho      => 2,
    cbreak      => 3,
    raw         => 4,
    'ultra-raw' => 5
);

sub ReadMode
{
    my ($mode) = $modes{ $_[0] };
    my ($fh) = normalizehandle( ( @_ > 1 ? $_[1] : \*STDIN ) );
    if ( defined($mode) ) { SetReadMode( $mode, $fh ) }
    elsif ( $_[0] =~ /^\d/ ) { SetReadMode( $_[0], $fh ) }
    else { croak("Unknown terminal mode `$_[0]'"); }
}

sub normalizehandle
{
    my ($file) = @_;

    #	print "Handle = $file\n";
    if ( ref($file) ) { return $file; }    # Reference is fine

    #	if($file =~ /^\*/) { return $file; } # Type glob is good
    if ( ref( \$file ) eq 'GLOB' ) { return $file; }    # Glob is good

    #	print "Caller = ",(caller(1))[0],"\n";
    return \*{ ( ( caller(1) )[0] ) . "::$file" };
}

sub GetTerminalSize
{
    my ($file) = normalizehandle( ( @_ > 1 ? $_[1] : \*STDOUT ) );
    my (@results) = ();
    my (@fail);

    if ( &termsizeoptions() & 1 )                       # VIO
    {
        @results = GetTermSizeVIO($file);
        push( @fail, "VIOGetMode call" );
    }
    elsif ( &termsizeoptions() & 2 )                    # GWINSZ
    {
        @results = GetTermSizeGWINSZ($file);
        push( @fail, "TIOCGWINSZ ioctl" );
    }
    elsif ( &termsizeoptions() & 4 )                    # GSIZE
    {
        @results = GetTermSizeGSIZE($file);
        push( @fail, "TIOCGSIZE ioctl" );
    }
    elsif ( &termsizeoptions() & 8 )                    # WIN32
    {
        @results = GetTermSizeWin32($file);
        push( @fail, "Win32 GetConsoleScreenBufferInfo call" );
    }
    else
    {
        @results = ();
    }

    if ( @results < 4 and $UseEnv )
    {
        my ($C) = defined( $ENV{COLUMNS} ) ? $ENV{COLUMNS} : 0;
        my ($L) = defined( $ENV{LINES} )   ? $ENV{LINES}   : 0;
        if ( ( $C >= 2 ) and ( $L >= 2 ) )
        {
            @results = ( $C + 0, $L + 0, 0, 0 );
        }
        push( @fail, "COLUMNS and LINES environment variables" );
    }

    if ( @results < 4 )
    {
        my ($prog) = "resize";

        # Workaround for Solaris path sillyness
        if ( -f "/usr/openwin/bin/resize" ) {
            $prog = "/usr/openwin/bin/resize";
        }

        my ($resize) = scalar(`$prog 2>/dev/null`);
        if (
            defined $resize
            and (  $resize =~ /COLUMNS\s*=\s*(\d+)/
                or $resize =~ /setenv\s+COLUMNS\s+'?(\d+)/ )
          )
        {
            $results[0] = $1;
            if (   $resize =~ /LINES\s*=\s*(\d+)/
                or $resize =~ /setenv\s+LINES\s+'?(\d+)/ )
            {
                $results[1] = $1;
                @results[ 2, 3 ] = ( 0, 0 );
            }
            else
            {
                @results = ();
            }
        }
        else
        {
            @results = ();
        }
        push( @fail, "resize program" );
    }

    if ( @results < 4 )
    {
        die "Unable to get Terminal Size."
          . join( "", map( " The $_ didn't work.", @fail ) );
    }

    @results;
}

if ( &blockoptions() & 1 )    # Use nodelay
{
    if ( &blockoptions() & 2 )    #poll
    {
        eval <<'DONE';
		sub ReadKey {
		  my($File) = normalizehandle((@_>1?$_[1]:\*STDIN));
                  if (defined $_[0] && $_[0] > 0) {
                    if ($_[0]) {
                      return undef if &pollfile($File,$_[0]) == 0;
                    }
		  }
                  if (defined $_[0] && $_[0] < 0) {
                     &setnodelay($File,1);
                  }
                  my ($value) = getc $File;
                  if (defined $_[0] && $_[0] < 0) {
                     &setnodelay($File,0);
                  }
                  $value;
		}
		sub ReadLine {
		  my($File) = normalizehandle((@_>1?$_[1]:\*STDIN));

                  if (defined $_[0] && $_[0] > 0) {
                     if ($_[0]) {
                       return undef if &pollfile($File,$_[0]) == 0;
                     }
		  }
                  if (defined $_[0] && $_[0] < 0) {
                     &setnodelay($File,1)
                  };
                  my ($value) = scalar(<$File>);
                  if ( defined $_[0] && $_[0]<0 ) {
                    &setnodelay($File,0)
                  };
                  $value;
		}
DONE
    }
    elsif ( &blockoptions() & 4 )    #select
    {
        eval <<'DONE';
		sub ReadKey {
		  my($File) = normalizehandle((@_>1?$_[1]:\*STDIN));
                  if(defined $_[0] && $_[0]>0) {
				if($_[0]) {return undef if &selectfile($File,$_[0])==0}
		    }
			if(defined $_[0] && $_[0]<0) {&setnodelay($File,1);}
			my($value) = getc $File;
			if(defined $_[0] && $_[0]<0) {&setnodelay($File,0);}
			$value;
		}
		sub ReadLine {
		  my($File) = normalizehandle((@_>1?$_[1]:\*STDIN));
		    if(defined $_[0] && $_[0]>0) {
				if($_[0]) {return undef if &selectfile($File,$_[0])==0}
		    }
			if(defined $_[0] && $_[0]<0) {&setnodelay($File,1)};
			my($value)=scalar(<$File>);
			if(defined $_[0] && $_[0]<0) {&setnodelay($File,0)};
			$value;
		}
DONE
    }
    else
    {    #nothing
        eval <<'DONE';
		sub ReadKey {
		  my($File) = normalizehandle((@_>1?$_[1]:\*STDIN));
		    if(defined $_[0] && $_[0]>0) {
		    	# Nothing better seems to exist, so I just use time-of-day
		    	# to timeout the read. This isn't very exact, though.
		    	$starttime=time;
		    	$endtime=$starttime+$_[0];
				&setnodelay($File,1);
				my($value)=undef;
		    	while(time<$endtime) { # This won't catch wraparound!
		    		$value = getc $File;
		    		last if defined($value);
		    	}
				&setnodelay($File,0);
				return $value;
		    }
			if(defined $_[0] && $_[0]<0) {&setnodelay($File,1);}
			my($value) = getc $File;
			if(defined $_[0] && $_[0]<0) {&setnodelay($File,0);}
			$value;
		}
		sub ReadLine {
		  my($File) = normalizehandle((@_>1?$_[1]:\*STDIN));
		    if(defined $_[0] && $_[0]>0) {
		    	# Nothing better seems to exist, so I just use time-of-day
		    	# to timeout the read. This isn't very exact, though.
		    	$starttime=time;
		    	$endtime=$starttime+$_[0];
				&setnodelay($File,1);
				my($value)=undef;
		    	while(time<$endtime) { # This won't catch wraparound!
		    		$value = scalar(<$File>);
		    		last if defined($value);
		    	}
				&setnodelay($File,0);
				return $value;
		    }
			if(defined $_[0] && $_[0]<0) {&setnodelay($File,1)};
			my($value)=scalar(<$File>);
			if(defined $_[0] && $_[0]<0) {&setnodelay($File,0)};
			$value;
		}
DONE
    }
}
elsif ( &blockoptions() & 2 )    # Use poll
{
    eval <<'DONE';
	sub ReadKey {
	  my($File) = normalizehandle((@_>1?$_[1]:\*STDIN));
		if(defined $_[0] && $_[0] != 0) {
                     return undef if &pollfile($File,$_[0]) == 0
                }
		getc $File;
	}
	sub ReadLine {
	  my($File) = normalizehandle((@_>1?$_[1]:\*STDIN));
		if(defined $_[0] && $_[0]!=0) {
                     return undef if &pollfile($File,$_[0]) == 0;
                }
		scalar(<$File>);
	}
DONE
}
elsif ( &blockoptions() & 4 )    # Use select
{
    eval <<'DONE';
	sub ReadKey {
	  my($File) = normalizehandle((@_>1?$_[1]:\*STDIN));
		if(defined $_[0] && $_[0] !=0 ) {
                     return undef if &selectfile($File,$_[0])==0
                }
		getc $File;
	}
	sub ReadLine {
	  my($File) = normalizehandle((@_>1?$_[1]:\*STDIN));
		if(defined $_[0] && $_[0] != 0) {
                     return undef if &selectfile($File,$_[0]) == 0;
                }
		scalar(<$File>);
	}
DONE
}
elsif ( &blockoptions() & 8 )    # Use Win32
{
    eval <<'DONE';
	sub ReadKey {
	  my($File) = normalizehandle((@_>1?$_[1]:\*STDIN));
		if ($_[0]) {
			Win32PeekChar($File, $_[0]);
		} else {
			getc $File;
		}
		#if ($_[0]!=0) {return undef if !Win32PeekChar($File, $_[0])};
		#getc $File;
	}
	sub ReadLine {
	  my($File) = normalizehandle((@_>1?$_[1]:\*STDIN));
		#if ($_[0]!=0) {return undef if !Win32PeekChar($File, $_[0])};
		#scalar(<$File>);
		if($_[0]) 
			{croak("Non-blocking ReadLine is not supported on this architecture")}
		scalar(<$File>);
	}
DONE
}
else
{
    eval <<'DONE';
	sub ReadKey {
	  my($File) = normalizehandle((@_>1?$_[1]:\*STDIN));
		if($_[0]) 
			{croak("Non-blocking ReadKey is not supported on this architecture")}
		getc $File;
	}
	sub ReadLine {
	  my($File) = normalizehandle((@_>1?$_[1]:\*STDIN));
		if($_[0]) 
			{croak("Non-blocking ReadLine is not supported on this architecture")}
		scalar(<$File>);
	}
DONE
}

package Term::ReadKey;    # return to package ReadKey so AutoSplit is happy
1;

__END__;
