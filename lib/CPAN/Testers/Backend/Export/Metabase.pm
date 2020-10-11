package CPAN::Testers::Backend::Export::Metabase;
our $VERSION = '0.006';
# ABSTRACT: Export rows from the old Metabase cache

=head1 SYNOPSIS

    beam run <container> <service> [--interval <interval>] [<start> [<end>]]

=head1 DESCRIPTION

This task allows exporting rows from the metabase cache as YAML.

=head1 ARGUMENTS

=head2 start

The numeric ID of the first entry to export. Defaults to the lowest ID in the database.

=head2 end

The numeric ID of the last entry to export. Defaults to the highest ID in the database.

=head1 OPTIONS

=head2 interval

The size of each page to fetch. Defaults to C<100_000>. Larger page
sizes will take forever for the database to fetch.

=cut

use CPAN::Testers::Backend::Base 'Runnable';
with 'Beam::Runnable';
use Getopt::Long qw( GetOptionsFromArray );
use YAML;
use Log::Any qw( $LOG );
use Log::Any::Adapter qw( Stderr );
use Time::Piece qw( localtime );

=attr metabase_dbh

The L<DBI> object connected to the C<metabase> database.

=cut

has metabase_dbh => (
    is => 'ro',
    isa => InstanceOf['DBI::db'],
    required => 1,
);

sub run( $self, @args ) {
    GetOptionsFromArray( \@args, \my %opt,
        'interval|i=i',
    );
    my $interval = $opt{interval} || 100_000;
    my ( $min, $max ) = $self->metabase_dbh->selectrow_array( 'SELECT MIN(id), MAX(id) FROM metabase' );
    if ( $args[1] ) { $max = $args[1] }
    my $start = $args[0] || ( $min - ( $min % $interval ) );
    my $end = $start + $interval;
    my $sth = $self->metabase_dbh->prepare( "SELECT * FROM metabase WHERE id >= ? AND id < ?" );
    while ( $start <= $max ) {
        $LOG->info( localtime->datetime, "$start - $end" );
        $LOG->info( localtime->datetime, 'Executing...' );
        $sth->execute( $start, $end );
        $LOG->info( localtime->datetime, 'Fetching...' );
        open my $fh, '>', "metabase.$start.yaml";
        while ( my $row = $sth->fetchrow_hashref ) {
            say { $fh } YAML::Dump( $row );
        }
        close $fh;
        $LOG->info( localtime->datetime, 'Compressing...' );
        system "gzip metabase.$start.yaml";
        $start = $end;
        $end = $start + $interval;
    }
}

1;
