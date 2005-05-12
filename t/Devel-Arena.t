#!perl -w
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Devel-Arena.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 15 };
use Devel::Arena;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $stats = Devel::Arena::sv_stats();
ok(ref $stats, "HASH");
foreach (sort keys %$stats) {
  my $val = $stats->{$_};
  print "# $_ $val\n";
  if (ref $val eq 'HASH') {
    local $^W = 0;
    foreach my $key (sort {$a <=> $b || $a cmp $b} keys %$val) {
      print "#   $key  \t$val->{$key}\n";
    }
  }
}
ok($stats->{arenas}, qr/^\d+$/);
ok($stats->{total_slots}, qr/^\d+$/);
ok($stats->{free}, qr/^\d+$/);
ok($stats->{fakes}, qr/^\d+$/);
ok($stats->{'sizeof(SV)'}, qr/^\d+$/);
ok($stats->{'sizeof(SV)'} < 128);
ok($stats->{'nice_chunk_size'}, qr/^\d+$/);

ok($stats->{free} <= $stats->{total_slots});
ok($stats->{fakes} <= $stats->{arenas});

ok(ref $stats->{sizes} eq 'HASH');

my $bad = 0;
foreach (values %{$stats->{sizes}}) {
  $bad++ unless /^\d+$/;
}
ok($bad, 0, "All the sizes are numbers");

ok(ref $stats->{types} eq 'HASH');
# There has to be at least 1 hash because we're using it internally.
ok($stats->{types}{PVHV}, qr/^\d+$/);
