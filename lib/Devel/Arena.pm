package Devel::Arena;

use 5.005;
use strict;

require Exporter;
require DynaLoader;
use vars qw($VERSION @ISA @EXPORT_OK @EXPORT_FAIL);
@ISA = qw(Exporter DynaLoader);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.


@EXPORT_OK = qw(sv_stats write_stats_at_END);
@EXPORT_FAIL = qw(write_stats_at_END);

sub _write_stats_at_END {
    my $file = $$ . '.sv_stats';
    my $stats = {sv_stats => &sv_stats};
    require Storable;
    Storable::lock_nstore($stats, $file);
}

sub export_fail {
    shift;
    grep {$_ ne 'write_stats_at_END' ? 1
	      : do {eval "END {_write_stats_at_END}; 1" or die $@; 0;}} @_;
}

$VERSION = '0.10';

bootstrap Devel::Arena $VERSION;

# Preloaded methods go here.

1;
__END__

=head1 NAME

Devel::Arena - Perl extension for inspecting the core's arena structures

=head1 SYNOPSIS

  use Devel::Arena 'sv_stats';
  # Get hash ref describing the arenas for SV heads
  $sv_stats = sv_stats;

=head1 DESCRIPTION

Inspect the arena structures that perl uses for SV allocation.

HARNESS_PERL_SWITCHES=-MDevel::Arena=write_stats_at_END make test

=head2 EXPORT

None by default.

=over 4

=item * sv_stats

Returns a hashref giving stats derived from inspecting the SV heads via the
arena pointers. Details of the contents of the hash subject to change.

=item * write_stats_at_END

Not really a function, but if you import C<write_stats_at_END> then
Devel::Arena will write out a Storable dump of all stats at C<END> time.
The file is written into a file into a file in the current directory named
C<$$ . '.sv_stats'>. This allows you to do things such as

    HARNESS_PERL_SWITCHES=-MDevel::Arena=write_stats_at_END make test

to analyse the resource usage in regression tests.

=back

=head1 SEE ALSO

F<sv.c> in the perl core.

=head1 AUTHOR

Nicholas Clark, E<lt>nick@talking.bollo.cxE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Nicholas Clark

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut
