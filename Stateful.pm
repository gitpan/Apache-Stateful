package Apache::Stateful;
use strict;
use Apache;
use Apache::Cookie;
use Apache::Session::DBI;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION
	    $R $COOKIE_NAME %SESSION $DSN $DB_USER $DB_PASS $EXPIRE
	    );

use Exporter;
$VERSION = 0.01;
@ISA = qw(Exporter);

@EXPORT      = qw(start_session end_session set_dbparams %session);
@EXPORT_OK   = qw(start_session end_session set_dbparams);
%EXPORT_TAGS = ( );
		

$COOKIE_NAME = 'sid';
$R           = Apache->request();
$DSN         = 'dbi:mysql:database=sessions:mysql_compression=1';
$DB_USER     = 'nobody';
$DB_PASS     = '';
$EXPIRE      = '+3600s';

sub set_dbparams
{
    my %args = (
		Username   => $DB_USER,
		Password   => $DB_PASS,
		DataSource => $DSN,
		@_
		);

    $DB_USER = $args{Username};
    $DB_PASS = $args{Password};
    $DSN     = $args{DataSource};
}

sub set_cookie_expire
{
    $EXPIRE = shift;
}

sub start_session
{
    my %args = (
		Expire    => '+3600s',
		@_,       # argument pair list goes here
		);

    ## Get the cookie
    my $cookie = Apache::Cookie->get($COOKIE_NAME);
    warn "cookie: '$cookie'\n" if $cookie;

    ## Get the path info
    my $pathinfo = $R->path_info();
    $pathinfo =~ s/^\///;
    warn "pathinfo: '$pathinfo'\n" if $pathinfo;


    ## Does cookie exist?
    if (!defined $cookie) {

	## Ok, does a query string session id exist?
	if (!defined $pathinfo || $pathinfo eq '') {

	    warn "no cookie, no pathinfo\n";

	    ## Last chance.. do we have a referer?
	    if (defined $ENV{HTTP_REFERER}) {
		warn "Referer: $ENV{HTTP_REFERER}\n";

		my $uri = $R->uri();
		if ($ENV{HTTP_REFERER} =~ /$uri/) {
		    my ($pathinfo) = $ENV{HTTP_REFERER} =~ /^.+\/(.+)$/;
		    
		    ## Great, we got it out of the referer
		    eval {
			tie %SESSION, 'Apache::Session::DBI', $pathinfo, {
			    DataSource => $DSN,
			    Username   => $DB_USER,
			    Password   => $DB_PASS
			    };
		    };
		    
		    if ($@ =~ /Object does not exist/) {
			## Ack, start a new session.  The one they passed doesn't exist!
			
			## Fashion our redirect URL
			my $url = $R->uri();
			
			## We seem to hang if we don't untie the session
			## shouldn't happen, but just in case! :)
			untie %SESSION if tied %SESSION;
			
			## Send redirect to get the cookie sid into query string
			redirect($url);
		    }
		} else {
		    redirect($R->uri());
		}
	
		
	    } else {

		## Well then, let's create a new session!
		tie %SESSION, 'Apache::Session::DBI', undef, {
		    DataSource => $DSN,
		    Username   => $DB_USER,
		    Password   => $DB_PASS
		    };
		
		warn "sid: $SESSION{_session_id}\n";
	    }


	    ## Update the cookie
	    send_cookie();
	    
	    ## And send a redirect to get session id in pathinfo
	    my $url = $R->uri() . "/$SESSION{_session_id}";
	    warn "Redirecting: $url\n";
	    
	    ## We seem to hang if we don't untie the session
	    untie %SESSION;
	    
	    ## Send redirect to get the cookie sid into query string
	    redirect($url);

	    ## Done

	} else {

	    warn "no cookie, pathinfo\n";

	    ## The pathinfo is set.  This person must not like cookies
	    ## or they're using an ancient browser that doesn't accept them

	    eval {
		warn "Tying session\n";
		tie %SESSION, 'Apache::Session::DBI', $pathinfo, {
		    DataSource => $DSN,
		    Username   => $DB_USER,
		    Password   => $DB_PASS
		    };
	    };

	    if ($@ =~ /Object does not exist/) {
		## Ack, start a new session.  The one they passed doesn't exist!

		## Fashion our redirect URL
		my $url = $R->uri();
		$url =~ s/\/$pathinfo//;

		## We seem to hang if we don't untie the session
		untie %SESSION;

		## Send redirect to get the cookie sid into query string
		redirect($url);
	    }

	    warn "sid: $SESSION{_session_id}\n";

	    ## Update the cookie
	    send_cookie();

	    ## Done
	}
    }

    ## The cookie *IS* set
    else {
	
	## If the pathinfo is not defined or the pathinfo
	## is set but it isn't equal to the cookie sid, do
	## the following
	if (!defined $pathinfo || ($pathinfo ne $cookie)) {
	    warn "cookie, no pathinfo or pathinfo not equal to cookie\n";	    
	    
	    ## Fashion our redirect URL
	    my $url = $R->uri();
	    $url =~ s/\/$pathinfo//;
	    $url .=  "/$cookie";
	    warn "Redirecting: $url\n";

	    ## We seem to hang if we don't untie the session
	    untie %SESSION;

	    ## Send redirect to get the cookie sid into query string
	    redirect($url);

	    ## Done

	} else {
	    warn "cookie, pathinfo\n";

	    warn "Tying session\n";

	    ## Start the session
	    tie %SESSION, 'Apache::Session::DBI', $cookie, {
		DataSource => $DSN,
		Username   => $DB_USER,
		Password   => $DB_PASS
		};

	    warn "Updating cookie\n";

	    ## Update the cookie
	    send_cookie();

	    ## Done
	}	   
    }

    $R->status(200);
    $R->content_type("text/html");
    $R->send_http_header;

    warn "Session Initialized!\n";
    return \%SESSION;
}

sub end_session
{
    tied(%SESSION)->delete;
    warn "Untied session";
}

sub redirect
{
    my $url = shift;

    $R->status(302);
    $R->header_out(Location => $url);	    
    $R->content_type("text/html");
    $R->send_http_header;
    $R->exit();
}

sub send_cookie
{
  Apache::Cookie->set(-name    => $COOKIE_NAME,
		      -value   => $SESSION{_session_id},
		      -expires => $EXPIRE);
    
}

sub end_session
{
    untie %SESSION;
}

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Apache::Stateful - Perl extension for simplistic HTTP state management under mod_perl

=head1 SYNOPSIS

  use Apache::Stateful qw(set_dbparams start_session end_session);

  set_dbparams(
    Username   => 'nobody',
    Password   => '',
    DataSource => 'dbi:mysql:database=sessions:mysql_compression=1');

  set_cookie_expire('+1h');

  my $sess = start_session();

  $sess->{count}++;

  end_session();

=head1 DESCRIPTION

A number of excellent modules have been released that make session management
easier to implement under mod_perl.  

This goal of this module is to tie together some of the existing modules 
(Apache::Session::DBI and Apache::Cookie) to perform simple database driven 
state for your mod_perl project.  

I've tried to keep it as simple as possible.  We keep state via cookies, pathinfo,
and/or HTTP_REFERER.  We'll prefer the cookie but in the absence of a cookie but
presence of pathinfo, we'll use that (in case the user doesn't accept them).  In
the event of an absolute link, we maintain the session id without cookies through
the HTTP_REFERER field.

You need to have a database with a 'sessions' table.  The table should contain the
following fields (per the Apache::Session::DBIStore POD):

  id char(16)
  length int(11)
  a_session text

=over 4

=head1 SUBROUTINES

=item set_dbparams HASH

This function sets the username, password, and DBI data source used to access the
database where session data is stored.  It accepts up to three named parameters,
'Username', 'Password', and 'DataSource'.  

Failure to pass a parameter results in the use of a default value.  The default 
values are provided in the B<SYNOPSIS> above.

=item set_cookie_expire STRING

The cookies expire by default in one hour.  If you would like to change this, 
call this function with an expire string.  See the POD for CGI::Cookie to get an
idea of how this works.  (e.g. '+1h' is one hour)

=item start_session

This function initializes the session and returns the hash reference that is the
session object.  Simply add keys to this hash and they will be stored to the database
for later retrieval.

=item end_session

You must call this function at the end of your code or the changed values in the
session hash will not be written back to the database.  

Apache children seem to hang if you don't call this function!

=head1 BUGS

To err is human.. if you find any, let me know.  I'm using this in production code
but YMMV.  There is no warranty express or implied but if you have problems, send me
an e-mail and I might be able to help.

=head1 AUTHOR

Benjamin R. Ginter, bginter@asicommunications.com

Copyright (c) 1999 Benjamin R. Ginter. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

mod_perl, Apache::Session, Apache::Cookie, perl(1).

=cut
