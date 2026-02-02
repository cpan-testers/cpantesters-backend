package CPAN::Testers::Backend::UpdateReleaseSummary;
our $VERSION = '0.006';
# ABSTRACT: Update the release summary information

=head1 SYNOPSIS

=head1 DESCRIPTION

This module is a L<Beam::Runnable> task that updates the release
data (via L<CPAN::Testers::Schema::Result::Release>).

=head1 SEE ALSO

=cut

use v5.24;
use warnings;
use Moo;
use experimental qw( signatures postderef );
use Log::Any '$LOG';
use Types::Standard qw( InstanceOf );
use Getopt::Long qw( GetOptionsFromArray );
use Log::Any::Adapter Stderr =>;
with 'Beam::Runnable';

=attr schema

A L<CPAN::Testers::Schema> object to access the database.

=cut

has schema => (
    is => 'ro',
    isa => InstanceOf['CPAN::Testers::Schema'],
    required => 1,
);

=method run

The main method that processes job arguments and performs the task.
Called by L<Beam::Runner> or L<Beam::Minion>.

=cut

sub run( $self, @args ) {
    GetOptionsFromArray( \@args, \my %opt, 'clear' );
    $LOG->info('Starting', { class => __PACKAGE__, clear => $opt{clear} });

    my $data_rs = $self->schema->resultset('ReleaseStat');
    my $summary_rs = $self->schema->resultset('Release');

    my $from_id = 0;
    my $max_data_id = $data_rs->get_column('id')->max();
    if (!$opt{clear}) {
      # Get the max summary stat ID from the release data table
      my $max_summary_id = $summary_rs->get_column('id')->max();

      $LOG->info('Updating release_summary table from release_data', { max_data_id => $max_data_id, max_summary_id => $max_summary_id });
      $from_id = $max_summary_id;
    }
    else {
      $summary_rs->delete;
      $from_id = $data_rs->get_column('id')->min();
      $LOG->info('Rebuilding release_summary table from scratch', { max_data_id => $max_data_id, min_data_id => $from_id });
    }

    my $batch_size = 1_000_000;
    my $written = 0;

    my @total_cols = qw( pass fail na unknown );
    my $me = $data_rs->current_source_alias;
    while ($from_id <= $max_data_id) {
      my $to_id = $from_id + $batch_size;
      $LOG->info('Fetching batch of data', { from_id => $from_id, to_id => $to_id });
      my $data_rs = $self->schema->resultset('ReleaseStat')->search( { id => { '>', $from_id, '<=', $to_id }}, {
          # The uploadid here is included to allow joins from the results
          group_by => [ map "$me.$_", qw( dist version oncpan distmat perlmat patched uploadid ) ],
          select => [
              qw( dist version oncpan distmat perlmat patched uploadid ),
              ( map { \"SUM($_) AS $_" } @total_cols ),
              ( \sprintf 'SUM(%s) AS total', join ' + ', @total_cols ),
              \"MAX(id) AS id", \"MAX(guid) AS guid",
          ],
          as => [ qw( dist version oncpan distmat perlmat patched uploadid ), @total_cols, 'total', 'id', 'guid' ],
          order_by => undef,
      });

      while (my $row = $data_rs->next) {
        my %row = $row->get_columns;
        my $summary_row = $summary_rs->find_or_create({%row{qw(id guid dist version oncpan distmat perlmat patched uploadid)}}, {key => 'summary'});
        $summary_row->update({
            %row{qw(id guid )},
            map { $_ => $row{$_} + ($summary_row->$_ // 0) } @total_cols,
        });
        $written++;
      }
      $from_id = $to_id;
    }

    $LOG->info('Finished', { written => $written });
}

1;
