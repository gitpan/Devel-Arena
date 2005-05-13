package Devel::Arena;

use 5.005;
use strict;

require Exporter;
require DynaLoader;
use vars qw($VERSION @ISA @EXPORT_OK);
@ISA = qw(Exporter DynaLoader);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.


@EXPORT_OK = qw(sv_stats);

$VERSION = '0.06';

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

=head2 EXPORT

None by default.

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
