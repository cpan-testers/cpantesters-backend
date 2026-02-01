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
    $LOG->info('Starting', { class => __PACKAGE__ });

    # Get the max summary stat ID from the release data table
    my $release_rs = $self->schema->resultset('Release');
    my $max_release_data_id = $release_rs->get_column('id')->max();

    # Get the stat rows from the max summary ID to the current latest
    my $stats_rs = $self->schema->resultset('Stats');
    my $max_cpanstats_id = $stats_rs->get_column('id')->max();
    $LOG->info('Updating release_data table from cpanstats', { max_release_data_id => $max_release_data_id, max_cpanstats_id => $max_cpanstats_id });

    $stats_rs = $stats_rs->search({ id => { '>' => $max_release_data_id }}, { order_by => 'id'});
    my $written = 0;
    my $batch_size = 1000;
    my @batch;
    while (my $row = $stats_rs->next) {
        my %data = $row->get_columns;
        push @batch, {
            %data{qw(dist version id guid oncpan distmat perlmat patched uploadid)},
            lc $data{state} => 1,
        };
        if (@batch >= $batch_size) {
            $LOG->info('Writing batch', { batch_size => scalar @batch, batch_max_id => $batch[-1]{id} });
            $release_rs->populate(\@batch);
            $written += @batch;
            @batch = ();
        }
    }

    if (@batch) {
        $LOG->info('Writing batch', { batch_size => scalar @batch, batch_max_id => $batch[-1]{id} });
        $release_rs->populate(\@batch);
        $written += @batch;
    }

    $LOG->info('Finished', { written => $written });
}

1;
