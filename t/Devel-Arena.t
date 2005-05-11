#!perl -w
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Devel-Arena.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 8 };
use Devel::Arena;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $stats = Devel::Arena::sv_stats();
ok(ref $stats, "HASH");
foreach (sort keys %$stats) {
  print "# $_ $stats->{$_}\n";
}
ok($stats->{arenas}, qr/^\d+$/);
ok($stats->{total_slots}, qr/^\d+$/);
ok($stats->{free}, qr/^\d+$/);
ok($stats->{fakes}, qr/^\d+$/);
ok($stats->{free} <= $stats->{total_slots});
ok($stats->{fakes} <= $stats->{arenas});
