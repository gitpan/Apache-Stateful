use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

use strict;

my $missing_modules = 0;

print "Checking for Apache::Session..........";
eval {
    require Apache::Session;
};

if ($@) {
    print "no\n";
    print "Apache::Session v1.0 must be installed\n";
    $missing_modules++;
} else {
    if ($Apache::Session::VERSION >= 1.0) {
	print "ok\n";
    } else {
	print "You have $Apache::::VERSION\n";
    }
}

print "Checking for Apache::Cookie...........";
eval {
    require Apache::Cookie;
};

if ($@) {
    print "no\n";
    print "Apache::Cookie v0.1 must be installed\n";
    $missing_modules++;
} else {
    print "ok\n";
}


if (!$missing_modules) {
    WriteMakefile(
		  'NAME'	=> 'Apache::Stateful',
		  'VERSION_FROM' => 'Stateful.pm', # finds $VERSION
		  );
} else {
    print "Install the required modules are rerun Makefile.PL\n";
}
