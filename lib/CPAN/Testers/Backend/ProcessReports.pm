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
use experimental 'signatures', 'postderef';
use Types::Standard qw( Str InstanceOf );
use Log::Any '$LOG';
with 'Beam::Runnable';
use JSON::MaybeXS qw( decode_json );
use Getopt::Long qw( GetOptionsFromArray );

=attr schema

A L<CPAN::Testers::Schema> object to access the database.

=cut

has schema => (
    is => 'ro',
    isa => InstanceOf['CPAN::Testers::Schema'],
    required => 1,
);

=attr metabase_dbh

A L<DBI> object connected to the Metabase cache. This is a legacy database
needed for some parts of the web app and backend. When these parts are
updated to use the new test reports, we can remove this attribute.

=cut

has metabase_dbh => (
    is => 'ro',
    isa => InstanceOf['DBI::db'],
    required => 1,
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

    my @reports;
    if ( $opt{force} && !@args ) {
        $LOG->info( '--force and no IDs specified: Re-processing all reports' );
        @reports = $self->find_reports;
    }
    elsif ( @args ) {
        $LOG->info( 'Processing ' . @args . ' reports from command-line' );
        @reports = $self->find_reports( @args );
    }
    else {
        $LOG->info( 'Processing all unprocessed reports' );
        @reports = $self->find_unprocessed_reports;
        $LOG->info('Found ' . @reports . ' unprocessed report(s)');
    }

    my $stats = $self->schema->resultset('Stats');
    my $skipped = 0;

    for my $report (@reports) {
        local $@;
        my $stat;
        my $success = eval { $stat = $stats->insert_test_report($report); 1 };
        my $error = $@;
        unless ($success) {
            my $guid = $report->id;
            $LOG->warn("Unable to process report GUID $guid. Skipping.");
            $LOG->debug("Error: $error");
            $skipped++;
            next;
        }
        $self->write_metabase_cache( $report, $stat );
        $self->write_builder_update( $stat );
    }

    $LOG->info("Skipped $skipped unprocessed report(s)") if $skipped;
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
    my $reports = $self->schema->resultset( 'TestReport' )->search({
        report => \[ "->> '\$.environment.language.name'=?", 'Perl 5' ],
    });
    if ( @ids ) {
        $reports = $reports->search({
            id => {
                -in => \@ids,
            },
        });
    }
    return $reports->all;
}

=method write_metabase_cache

    $self->write_metabase_cache( $report_row, $stat_row );

Write the report to the legacy metabase cache. This cache is used for
some of the web apps and some of the backend processes. Until those
processes are changed to use the new test report format, we need to
maintain the old metabase cache.

Once the legacy metabase cache is removed, this method can be removed

=cut

sub write_metabase_cache( $self, $report_row, $stat_row ) {
    my $guid = $report_row->id;
    my $id = $stat_row->id;
    my $created_epoch = $report_row->created->epoch;
    my $report = $report_row->report;

    my $distname = $report->{distribution}{name};
    my $distversion = $report->{distribution}{version};

    my $upload_row = $self->schema->resultset( 'Upload' )->search({
        dist => $distname,
        version => $distversion,
    })->first;
    my $author = $upload_row->author;
    my $distfile = sprintf '%s/%s-%s.tar.gz', $author, $distname, $distversion;

    my %report = (
        grade => $report->{result}{grade},
        osname => $report->{environment}{system}{osname},
        osversion => $report->{environment}{system}{osversion},
        archname => $report->{environment}{language}{archname},
        perl_version => $report->{environment}{language}{version},
        textreport => (
            $report->{result}{output}{uncategorized} ||
            join "\n\n", grep defined, $report->{result}{output}->@{qw( configure build test install )},
        ),
    );

    # These imports are here so they can be easily removed later
    use Metabase::User::Profile;
    my %creator = (
        full_name => $report->{reporter}{name},
        email_address => $report->{reporter}{email},
    );
    my $creator;
    my ( $creator_row ) = $self->metabase_dbh->selectall_array(
        'SELECT * FROM testers_email WHERE email=?',
        { Slice => {} },
        $creator{email_address},
    );
    if ( !$creator_row ) {
        $creator = Metabase::User::Profile->create( %creator );
        $self->metabase_dbh->do(
            'INSERT INTO testers_email ( resource, fullname, email ) VALUES ( ?, ?, ? )',
            {},
            $creator->core_metadata->{resource},
            $creator{ full_name },
            $creator{ email_address },
        );
    }

    use CPAN::Testers::Report;
    my $metabase_report = CPAN::Testers::Report->open(
        resource => 'cpan:///distfile/' . $distfile,
        creator => $creator_row->{resource},
    );
    $metabase_report->add( 'CPAN::Testers::Fact::LegacyReport' => \%report);
    $metabase_report->add( 'CPAN::Testers::Fact::TestSummary' =>
        [$metabase_report->facts]->[0]->content_metadata()
    );
    $metabase_report->close();

    # Encode it to JSON
    my %facts;
    for my $fact ( $metabase_report->facts ) {
        my $name = ref $fact;
        $facts{ $name } = $fact->as_struct;
        $facts{ $name }{ content } = decode_json( $facts{ $name }{ content } );
    }

    # Serialize it to compress it using Data::FlexSerializer
    # "report" gets serialized with JSON
    use Data::FlexSerializer;
    my $json_zipper = Data::FlexSerializer->new(
        detect_compression  => 1,
        detect_json         => 1,
        output_format       => 'json'
    );
    my $report_zip = $json_zipper->serialize( \%facts );

    # "fact" gets serialized with Sereal
    my $sereal_zipper = Data::FlexSerializer->new(
        detect_compression  => 1,
        detect_sereal       => 1,
        output_format       => 'sereal'
    );
    my $fact_zip = $sereal_zipper->serialize( $metabase_report );

    $self->metabase_dbh->do(
        'REPLACE INTO metabase (guid,id,updated,report,fact) VALUES (?,?,?,?,?)',
        {},
        $guid, $id, $created_epoch, $report_zip, $fact_zip,
    );

    return;
}

=method write_builder_update

    $self->write_builder_update( $stat_row );

Write entries to the C<page_requests> table to tell the legacy webapp
report builders that they need to update the static data caches for this
distribution and this distribution's author.

=cut

sub write_builder_update( $self, $stat ) {
    my $upload_row = $self->schema->resultset( 'Upload' )->search({
        dist => $stat->dist,
        version => $stat->version,
    })->first;
    my $sql = 'INSERT INTO page_requests ( type, name, weight, id ) VALUES ( ?, ?, ?, ? )';
    my $sub = sub( $storage, $dbh, @values ) {
        $dbh->do( $sql, {}, @values );
    };
    my $storage = $self->schema->storage;
    $storage->dbh_do( $sub, 'author', $upload_row->author, 1, $stat->id );
    $storage->dbh_do( $sub, 'distro', $stat->dist, 1, $stat->id );
}

1;

