package CPAN::Testers::Backend::Migrate::MetabaseCache;
our $VERSION = '0.003';
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
use JSON::MaybeXS qw( encode_json );
use CPAN::Testers::Report;
use CPAN::Testers::Fact::TestSummary;
use CPAN::Testers::Fact::LegacyReport;


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
    if ( $opt{force} && !@args ) {
        $LOG->info( '--force and no IDs specified: Re-processing all cache entries' );
        my $sth = $self->find_entries;
        $self->process_sth( $sth );
    }
    elsif ( @args ) {
        $LOG->info( 'Re-processing ' . @args . ' cache entries from command-line' );
        my $sth = $self->find_entries( @args );
        $self->process_sth( $sth );
    }
    else {
        $LOG->info( 'Processing all unprocessed cache entries' );
        my $sth = $self->find_unprocessed_entries;
        while ( my $count = $self->process_sth( $sth ) ) {
            $sth = $self->find_unprocessed_entries;
        }
    }
    return 0;
}

=method process_sth

Process the given statement handle full of reports. Returns the number
of reports processed

=cut

sub process_sth( $self, $sth ) {
    my $rs = $self->schema->resultset( 'TestReport' );
    my $count = 0;
    while ( my $row = $sth->fetchrow_hashref ) {
        my $fact = $self->parse_metabase_report( $row );
        $rs->insert_metabase_fact( $fact );
        $count++;
    }
    $LOG->info( 'Processed ' . $count . ' entries' );
    return $count;
}

=method find_unprocessed_entries

    $sth = $self->find_unprocessed_entries;

Returns a L<DBI> statement handle on to a list of C<metabase.metabase>
row hashrefs for reports that are not in the main test report table
(managed by L<CPAN::Testers::Schema::Result::TestReport>).

=cut

sub find_unprocessed_entries( $self ) {
    my @ids;
    my $i = 0;
    my $page = 10000;
    my $current_page = $self->metabase_dbh->selectcol_arrayref(
        'SELECT guid FROM metabase LIMIT ' . $page . ' OFFSET ' . $i
    );
    while ( @$current_page > 0 && @ids < $page ) {
        my %found = map {; $_ => 1 } $self->schema->resultset( 'TestReport' )->search( {
            id => {
                -in => $current_page,
            }
        } )->get_column( 'id' )->all;
        push @ids, grep !$found{ $_ }, @$current_page;
        $i += 1000;
        $current_page = $self->metabase_dbh->selectcol_arrayref(
            'SELECT guid FROM metabase LIMIT ' . $page . ' OFFSET ' . $i
        );
    }
    die "No unprocessed reports" unless @ids;
    $LOG->info( 'Found ' . (scalar @ids) . ' entries to process' );
    return $self->find_entries( @ids );
}

=method find_entries

    $sth = $self->find_entries;
    $sth = $self->find_entries( @ids );

Find all the cache entries to be processed by this module, optionally
limited only to the IDs passed-in. Returns a list of row hashrefs.

=cut

sub find_entries( $self, @ids ) {
    my ( $where, @values );
    if ( @ids ) {
        $where = " WHERE guid IN (" . join( ', ', ( '?' ) x @ids ) . ")";
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

my $zipper = Data::FlexSerializer->new(
    detect_compression  => 1,
    detect_sereal       => 1,
    detect_json         => 1,
);

sub parse_metabase_report( $self, $row ) {
    if ( $row->{fact} ) {
        return $zipper->deserialize( $row->{fact} );
    }

    my $data = $zipper->deserialize( $row->{report} );
    my $struct = {
        metadata => {
            core => {
                $data->{'CPAN::Testers::Fact::TestSummary'}{metadata}{core}->%*,
                guid => $row->{guid},
                type => 'CPAN-Testers-Report',
            },
        },
        content => encode_json( [
            $data->{'CPAN::Testers::Fact::LegacyReport'},
            $data->{'CPAN::Testers::Fact::TestSummary'},
        ] ),
    };
    #; use Data::Dumper;
    #; warn Dumper $struct;
    my $fact = CPAN::Testers::Report->from_struct( $struct );
    return $fact;
}

1;
