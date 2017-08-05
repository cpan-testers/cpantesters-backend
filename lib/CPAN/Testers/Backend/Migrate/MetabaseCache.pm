package CPAN::Testers::Backend::Migrate::MetabaseCache;
our $VERSION = '0.002';
# ABSTRACT: Migrate old metabase cache to new test report format

=head1 SYNOPSIS

    beam run <container> <service> [--force | -f]

=head1 DESCRIPTION

This task migrates the reports in the C<metabase.metabase> table to the
C<cpanstats.test_report> table. This will enable us to drop the C<metabase>
database altogether.

=cut

use CPAN::Testers::Backend::Base 'Runnable';
with 'Beam::Runnable';
use Getopt::Long qw( GetOptionsFromArray );
use Data::FlexSerializer;

=attr metabase_dbh

The L<DBI> object connected to the C<metabase> database.

=cut

has metabase_dbh => (
    is => 'ro',
    isa => InstanceOf['DBI::db'],
    required => 1,
);

=attr schema

The L<CPAN::Testers::Schema> to write reports to.

=cut

has schema => (
    is => 'ro',
    isa => InstanceOf['CPAN::Testers::Schema'],
    required => 1,
);

sub run( $self, @args ) {
    GetOptionsFromArray(
        \@args, \my %opt,
        'force|f',
    );
    my $sth;
    if ( $opt{force} && !@args ) {
        $LOG->info( '--force and no IDs specified: Re-processing all cache entries' );
        $sth = $self->find_entries;
    }
    elsif ( @args ) {
        $LOG->info( 'Re-processing ' . @args . ' cache entries from command-line' );
        $sth = $self->find_entries( @args );
    }
    else {
        $LOG->info( 'Processing all unprocessed cache entries' );
        $sth = $self->find_unprocessed_entries;
    }

    my $rs = $self->schema->resultset( 'TestReport' );
    while ( my $row = $sth->fetchrow_hashref ) {
        my $fact = $self->parse_metabase_report( $row );
        $rs->insert_metabase_fact( $fact );
    }
}

=method find_unprocessed_entries

    @rows = $self->find_unprocessed_rows;

Returns a L<DBI> statement handle on to a list of C<metabase.metabase>
row hashrefs for reports that are not in the main test report table
(managed by L<CPAN::Testers::Schema::Result::TestReport>).

=cut

sub find_unprocessed_entries( $self ) {
    my $sth = $self->metabase_dbh->prepare(
        "SELECT * FROM metabase WHERE guid NOT IN ( SELECT id FROM cpanstats.test_report )",
    );
    $sth->execute;
    return $sth;
}

=method find_entries

    @entries = $self->find_entries;
    @entries = $self->find_entries( @ids );

Find all the cache entries to be processed by this module, optionally
limited only to the IDs passed-in. Returns a list of row hashrefs.

=cut

sub find_entries( $self, @ids ) {
    my ( $where, @values );
    if ( @ids ) {
        $where = " WHERE guid IN (" . join( ', ', ( '?' x @ids ) ) . ")";
        @values = @ids;
    }
    my $sth = $self->metabase_dbh->prepare(
        "SELECT * FROM metabase" . $where
    );
    $sth->execute( @values );
    return $sth;
}

=method parse_metabase_report

This sub undoes the processing that CPAN Testers expects before it is
put in the database so we can ensure that the report was submitted
correctly.

This code is stolen from CPAN::Testers::Data::Generator sub load_fact

=cut

my $sereal_zipper = Data::FlexSerializer->new(
    detect_compression  => 1,
    detect_sereal       => 1,
    detect_json         => 1,
);

sub parse_metabase_report( $self, $row ) {
    if ( $row->{fact} ) {
        return $sereal_zipper->deserialize( $row->{fact} );
    }
    die "'fact' column not present";
}

1;
