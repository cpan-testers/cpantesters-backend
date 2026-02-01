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
    if (!$opt{clear}) {
      # Get the max summary stat ID from the release data table
      my $max_data_id = $data_rs->get_column('id')->max();
      my $max_summary_id = $summary_rs->get_column('id')->max();

      $LOG->info('Updating release_summary table from release_data', { max_data_id => $max_data_id, max_summary_id => $max_summary_id });
      $from_id = $max_summary_id;
    }
    else {
      $LOG->info('Rebuilding release_summary table from scratch');
    }

    my @total_cols = qw( pass fail na unknown );
    my $me = $data_rs->current_source_alias;
    $data_rs = $data_rs->search( { id => { '>', $from_id }}, {
        # The uploadid here is included to allow joins from the results
        group_by => [ map "$me.$_", qw( dist version oncpan distmat perlmat patched uploadid ) ],
        select => [
            qw( dist version oncpan distmat perlmat patched uploadid ),
            ( map { \"SUM($_) AS $_" } @total_cols ),
            ( \sprintf 'SUM(%s) AS total', join ' + ', @total_cols )
        ],
        as => [ qw( dist version oncpan distmat perlmat patched uploadid ), @total_cols, 'total' ],
        order_by => undef,
    } );

    my $written = 0;
    while (my $row = $data_rs->next) {
      my %row = $row->get_columns;
      my $summary_row = $summary_rs->find_or_create({%row{qw(dist version oncpan distmat perlmat patched uploadid)}});
      $summary_row->update({%row{qw(id guid pass fail na unknown)}});
      $written++;
    }

    $LOG->info('Finished', { written => $written });
}

1;
