#!/usr/local/bin/perl -w

##-------------------------------------------------------------------------
## Import our Apache::Stateful functions.  Actually, they're exported by
## default so you don't need the qw() stuff.
##-------------------------------------------------------------------------
use Apache::Stateful qw(set_dbparams start_session end_session);

##-------------------------------------------------------------------------
## Set database parameters
##-------------------------------------------------------------------------
set_dbparams(Username   => 'username',
	     Password   => 'password',
	     DataSource => 'dbi:mysql:database=sessions:mysql_compression=1');

##-------------------------------------------------------------------------
## Start session.  Returns $sess, a hash reference.  
##  ** Note there should be no output before this is called! **
##-------------------------------------------------------------------------
my $sess = start_session();

##-------------------------------------------------------------------------
## Let's increment a counter
##-------------------------------------------------------------------------
$sess->{count}++;

##-------------------------------------------------------------------------
## An absolute link.  Turn off cookies in your browser and you'll see that
## we can still get the session id out of the HTTP_REFERER field
##-------------------------------------------------------------------------
print qq|<A HREF="test.pl">Reload session</A><BR>|;

##-------------------------------------------------------------------------
## And let's dump the contents of the session hash
##-------------------------------------------------------------------------
print qq|
<TABLE CELLSPACING=0 CELLPADDING=4 BORDER=1>
|;

while (my ($key, $value) = each %{$sess}) {
    print qq|<TR><TD BGCOLOR="#CDCDCD">$key</TD><TD>$value</TD></TR>\n|;
}

print "</TABLE>\n";

##-------------------------------------------------------------------------
## When you're done with the page, just call end_session and we'll
## write any changed data back to the database and untie our hash
##-------------------------------------------------------------------------
end_session();
