package CPAN::Testers::Backend::ProcessReports;
our $VERSION = '0.006';
# ABSTRACT: Process an incoming test report into useful statistics

=head1 SYNOPSIS

    beam run <container> <task> [--force | -f] [<reportid>...]

=head1 DESCRIPTION

This module is a L<Beam::Runnable> task that reads incoming test reports
from testers and produces the basic stats needed for the common
reporting on the website and via e-mail. This is the first step in
processing test data: All other tasks require this step to be completed.

=head1 ARGUMENTS

=head2 reportid

The IDs of reports to process. If specified, the report will be
processed whether or not it was processed already (like C<--force>
option).

=head1 OPTIONS

=head2 --force | -f

Force re-processing of all reports. This will process all of the test
reports again, so it may be prudent to limit to a set of test reports
using the C<reportid> argument.

=head1 SEE ALSO

L<CPAN::Testers::Backend>, L<CPAN::Testers::Schema>, L<Beam::Runnable>

=cut

use v5.24;
use warnings;
use Moo;
use experimental qw( signatures postderef );
use Types::Standard qw( Maybe Str InstanceOf );
use Log::Any '$LOG';
with 'Beam::Runnable';
use JSON::MaybeXS qw( decode_json );
use Getopt::Long qw( GetOptionsFromArray );
use HTTP::Tiny;
use Scalar::Util qw( blessed );
use Time::Piece;

=attr schema

A L<CPAN::Testers::Schema> object to access the database.

=cut

has schema => (
    is => 'ro',
    isa => InstanceOf['CPAN::Testers::Schema'],
    required => 1,
);

=attr collector

A URL to a collector to look for reports. Defaults to the value of the 
C<COLLECTOR_URL> environment variable.

=cut

has collector => (
    is => 'ro',
    isa => Maybe[Str],
    default => sub { $ENV{COLLECTOR_URL} },
);

=attr http_client

An L<HTTP::Tiny> to use to talk to the collector.

=cut

has http_client => (
  is => 'ro',
  isa => InstanceOf['HTTP::Tiny'],
  default => sub {
    HTTP::Tiny->new(
      agent => 'CPAN::Testers::Backend/' . $VERSION . ' ',
      verify_SSL => 0,
    );
  },
);

=method run

The main method that processes job arguments and performs the task.
Called by L<Beam::Runner> or L<Beam::Minion>.

=cut

sub run( $self, @args ) {
    GetOptionsFromArray(
        \@args, \my %opt,
        'force|f',
    );
    my $skipped = 0;

    my @reports;
    if ( $opt{force} && !@args ) {
        $LOG->info( '--force and no IDs specified: Re-processing all reports' );
        @reports = $self->find_reports;
    }
    elsif ( @args ) {
        $LOG->info( 'Processing ' . @args . ' reports from command-line' );
        for my $id ( @args ) {
          if (my $url = $self->collector) {
            my $res = $self->http_client->get($url . '/v1/report/' . $id);
            if ($res->{success}) {
              my $report = decode_json($res->{content});
              $report->{id} ||= $id;
              $LOG->info( 'Got report from collector', { guid => $id, created => $report->{created} } );
              if (!$report->{created}) {
                $LOG->warn( 'No created data, defaulting to now', { guid => $id } );
                $report->{created} = Time::Piece->new(scalar gmtime)->datetime . 'Z';
              }
              push @reports, $report;
              next;
            }
            else {
              $LOG->error( 'Got error from collector', { guid => $id, %{$res}{qw( status reason content )} } );
            }
          }
          push @reports, $self->find_reports($id);
        }
        $skipped = @args - @reports;
        $LOG->info('Got reports to process', { report_count => scalar @reports, arg_count => scalar @args, missing => $skipped });
    }
    else {
        $LOG->info( 'Processing all unprocessed reports' );
        @reports = $self->find_unprocessed_reports;
        $LOG->info('Found ' . @reports . ' unprocessed report(s)');
    }

    my $processed = 0;
    my $stats = $self->schema->resultset('Stats');
    for my $report (@reports) {
        my $guid = blessed $report ? $report->id : $report->{id};
        local $@;
        eval {
          if (blessed $report) {
            $stats->insert_test_report($report);
          }
          else {
            $stats->insert_test_data($report);
          }
        };
        if (my $error = $@) {
            $LOG->error("Error processing report", { guid => $guid, error => $error});
            $skipped++;
            next;
        }
        $LOG->info('Added stats from report', { guid => $guid });
        $processed++;
    }

    $LOG->info("Finished processing reports", { processed => $processed, skipped => $skipped});
    return $skipped ? 1 : 0;
}

=method find_unprocessed_reports

Returns a list of L<CPAN::Testers::Schema::Result::TestReport>
objects for reports that are not in the cpanstats table.

=cut

sub find_unprocessed_reports( $self ) {
    my $schema = $self->schema;
    my $stats = $schema->resultset('Stats');
    my $reports = $schema->resultset('TestReport')->search({
        id => {
            -not_in => $stats->get_column('guid')->as_query,
        },
        report => \[ "->> '\$.environment.language.name'=?", 'Perl 5' ],
    });
    return $reports->all;
}

=method find_reports

    @reports = $self->find_reports;
    @reports = $self->find_reports( @ids );

Find all the test reports to be processed by this module, optionally
limited only to the IDs passed-in. Returns a list of
L<CPAN::Testers::Schema::Result::TestReport> objects.

=cut

sub find_reports( $self, @ids ) {
    my $reports = $self->schema->resultset( 'TestReport' );
    if ( @ids ) {
        $reports = $reports->search({
            report => \[ "->> '\$.environment.language.name'=?", 'Perl 5' ],
            id => {
                -in => \@ids,
            },
        });
    }
    return $reports->all;
}

1;
