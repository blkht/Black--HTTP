# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Black-HTTP.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Data::Dump qw-dump-;

use Test::More tests => 1;
BEGIN { use_ok('Black::HTTP') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

print STDERR "\n", '_'x100, "\n";
my $obj = Black::HTTP->new('url'=>'http://localhost/x/1.php/2?a=123&b=456#top_of_page');
dump $obj;
print STDERR '_'x100, "\n";
