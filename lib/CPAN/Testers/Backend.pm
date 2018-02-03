package CPAN::Testers::Backend;
our $VERSION = '0.006';
# ABSTRACT: Backend processes for CPAN Testers data and operations

=head1 DESCRIPTION

This distribution contains various backend scripts (inside runnable
modules) that process CPAN Testers data to support the APIs and website.

The runnable modules are all in the C<CPAN::Testers::Backend::> namespace,
and are configured into executable tasks by L<Beam::Wire> configuration files
located in C<etc/container>. The tasks are run using L<Beam::Runner>, which
contains the L<beam> command.

=head1 OVERVIEW

=head2 Logging

All processes should use L<Log::Any> to log important information. Logs will
be directed to syslog using L<Log::Any::Adapter::Syslog>, configured by
C<etc/container/common.yml>.

=head1 SEE ALSO

L<Beam::Runner>, L<Beam::Wire>

=cut

use strict;
use warnings;



1;

