#!perl -w
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Devel-Arena.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 57 };
use Devel::Arena;
use Config;
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

ok(ref $stats->{sizes}, 'HASH');

my $bad = 0;
foreach (values %{$stats->{sizes}}) {
  $bad++ unless /^\d+$/;
}
ok($bad, 0, "All the sizes are numbers");

ok(ref $stats->{types}, 'HASH');
# There should be at least 1 PV
ok($stats->{types}{IV}, qr/^\d+$/);

# PVHV returns more detailed stats
ok(ref $stats->{types}{PVHV}, 'HASH');
ok($stats->{types}{PVHV}{total}, qr/^\d+$/);
ok($stats->{types}{PVHV}{has_eiter}, qr/^\d+$/);

ok(ref $stats->{types}{PVHV}{names}, 'HASH');

my $fail = 0;
my $names;
while (my ($name, $count) = each %{$stats->{types}{PVHV}{names}}) {
  $names += $count;
  if ($count !~ qr/^\d+$/) {
    $fail++;
    print STDERR "# '$name' => '$count'\n";
  }
}
ok ($fail, 0);
# Not all the hashes are stashes
ok($names < $stats->{types}{PVHV}{total});

# There will always be a MG entry
ok(ref $stats->{types}{PVHV}{mg}, 'HASH');
# There will always be at least one has with no magic (as we're using them)
ok($stats->{types}{PVHV}{mg}{0}, qr/^\d+$/);

foreach my $type (qw(PVHV PVMG PVAV)) {
  my $total;
  $total += $_ foreach (values %{$stats->{types}{$type}{mg}});
  # we counted every item?
  ok($total, $stats->{types}{$type}{total});
}

ok($stats->{types}{PVAV}{has_arylen}, qr/^\d+$/);

ok(ref $stats->{types}{PVIO}, 'HASH');
ok($stats->{types}{PVIO}{total}, qr/^\d+$/);
ok($stats->{types}{PVIO}{has_stash}, qr/^\d+$/);

ok(ref $stats->{types}{PVGV}, 'HASH');
ok(ref $stats->{types}{PVGV}{objects}, 'HASH');
ok($stats->{types}{PVGV}{objects}{IO}, qr/^\d+$/);
ok(ref $stats->{types}{PVGV}{thingies}, 'HASH');
my %count;
foreach (qw(SCALAR ARRAY HASH CODE IO)) {
  ok(ref $stats->{types}{PVGV}{thingies}{$_}, 'HASH');
  my $fail = 0;
  while (my ($type, $count) = each %{$stats->{types}{PVGV}{thingies}{$_}}) {
    if ($count !~ /^\d+$/) {
      $fail++;
      print STDERR "# '$type' => '$count'\n";
    }
    $count{$type} += $count
  }
  ok ($fail, 0);
}
# Every IO is an object
ok($stats->{types}{PVGV}{objects}{IO}, $count{PVIO});

ok($stats->{types}{PVGV}{null_name}, qr/^\d+$/);
# Our exported subroutine should be in there somwhere.
ok($stats->{types}{PVGV}{names}{sv_stats}, qr/^\d+$/);
# As should Test's &ok
ok($stats->{types}{PVGV}{names}{ok}, qr/^\d+$/);

################

my $nostorable = "Storable is not installed";
unless (eval {
    require Storable;
    $nostorable = "";
    1;
}) {
    die $@ unless $@ =~ /Can't locate Storable/;
}


my $morestats = $nostorable || Devel::Arena::_write_stats_at_END();

if (@ARGV) {
    eval { require Data::Dumper };
    if ($@) {
	print "# no Data::Dumper in this build\n";
    }
    else {
	print "# displaying Devel::Arena output\n";
	Data::Dumper->import;
	# Avoid used only once warnings.
	$Data::Dumper::Sortkeys = $Data::Dumper::Sortkeys = 1;
	$Data::Dumper::Indent = $Data::Dumper::Indent = 1;
	print Dumper($morestats);
    }
}

skip($nostorable, ref $morestats->{info}, 'HASH');
skip($nostorable, ref $morestats->{info}{args}, 'ARRAY');
skip($nostorable, ref $morestats->{info}{inc}, 'ARRAY');

my $sizes = Devel::Arena::sizes();
ok(ref $sizes, "HASH");
ok($sizes->{'void *'}, $Config{ptrsize});
ok($sizes->{'hek_key offset'}, qr/^\d+$/);
my $sst = Devel::Arena::shared_string_table();
ok(ref $sst, "HASH");
ok($sst->{main}, qr/^\d+$/);
my $hek_size = Devel::Arena::HEK_size("perl rocks");
ok($hek_size > (length ("perl rocks") + $sizes->{'hek_key offset'}));
