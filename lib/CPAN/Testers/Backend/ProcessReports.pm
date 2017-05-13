package CPAN::Testers::Backend::ProcessReports;
our $VERSION = 0.001;
# ABSTRACT: Process an incoming test report into useful statistics

=head1 SYNOPSIS
    # container.yml     - A Beam::Wire container file
    process_reports:
        $class: CPAN::Testers::Backend::ProcessReport
        schema:
            $class: CPAN::Testers::Schema
            $method: connect_from_file
    # Run with Beam::Runner
    $ beam run process_reports
    # Run with Beam::Minion
    $ beam minion run process_reports
=head1 DESCRIPTION
This module is a L<Beam::Runnable> task that reads incoming test reports
from testers and produces the basic stats needed for the common
reporting on the website and via e-mail. This is the first step in
processing test data: All other tasks require this step to be completed.
=head1 SEE ALSO
L<CPAN::Testers::Backend>, L<CPAN::Testers::Schema>, L<Beam::Runnable>
=cut

use v5.24;
use warnings;
use experimental 'signatures', 'postderef';
use Moo;
use Types::Standard qw( Str InstanceOf );
use Log::Any;
with 'Beam::Runnable';

=attr schema
A L<CPAN::Testers::Schema> object to access the database.
=cut

has schema => (
    is => 'ro',
    isa => InstanceOf['CPAN::Testers::Schema'],
    required => 1,
);

=attr cache
A L<DBI> database handle for the metabase cache. This is temporary
until all things can be told not to use the metabase cache.
=cut

has cache => (
    is => 'ro',
    isa => InstanceOf['DBI::db'],
    #required => 1,
    required => 0, # this is temporary for testing
);

=attr from
An e-mail address to use when sending an error back to the tester that
submitted a bad report.
=cut

has from => (
    is => 'ro',
    isa => Str,
    required => 1,
);

=attr log
To direct logs to a given place, use a L<Log::Any::Adapter> with
C<lifecycle: eager>. By default, logs are routed to syslog using
L<Log::Any::Adapter::Syslog>.
=cut

has log => (
    is => 'lazy',
    default => sub ( $self ) {
        return Log::Any->get_logger( blessed $self );
    },
);

#=attr _testers
#
# A map of metabase GUID to tester e-mail
#
#=cut

has _testers => (
    is => 'lazy',
    default => sub {

    },
);

=method run
The main method that processes job arguments and performs the task.
Called by L<Beam::Runner> or L<Beam::Minion>.
=cut

sub run( $self, @args ) {
    require Log::Any::Adapter;
    Log::Any::Adapter->set_adapter( 'Syslog' );

}

#=method _send_email
#
#   $self->_send_email(
#=cut

1;

