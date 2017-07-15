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
use Log::Any '$LOG';
use Log::Any::Adapter 'Syslog';
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
    my $stats = $self->schema->resultset('Stats');
    my @reports = $self->find_unprocessed_reports;
    $LOG->info('Found ' . @reports . ' unprocessed report(s)');
    my $skipped = 0;

    for my $report (@reports) {
        local $@;
        my $success = eval { $stats->insert_test_report($report); 1 };
        unless ($success) {
            my $guid = $report->id;
            $LOG->warn("Unable to process report GUID $guid. Skipping.");
            $skipped++;
        }
    }

    $LOG->info("Skipped $skipped unprocessed report(s)") if $skipped;
}

=method find_unprocessed_reports

Returns a list of L<CPAN::Testers::Schema::ResultSet::TestReport>
objects for reports that are not in the cpanstats table.

=cut

sub find_unprocessed_reports( $self ) {
    my $schema = $self->schema;
    my $stats = $schema->resultset('Stats');
    my $reports = $schema->resultset('TestReport')->search({
        id => { -not_in => $stats->get_column('guid')->as_query },
    });
    return $reports->all;
}

1;

