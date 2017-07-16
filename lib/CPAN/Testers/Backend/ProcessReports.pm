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
use Moo;
use experimental 'signatures', 'postderef';
use Types::Standard qw( Str InstanceOf );
use Log::Any '$LOG';
use Log::Any::Adapter 'Syslog';
with 'Beam::Runnable';
use JSON::MaybeXS qw( decode_json );

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
        my $stat;
        my $success = eval { $stat = $stats->insert_test_report($report); 1 };
        unless ($success) {
            my $guid = $report->id;
            $LOG->warn("Unable to process report GUID $guid. Skipping.");
            $LOG->debug("Error: $@");
            $skipped++;
            next;
        }
        $self->write_metabase_cache( $report, $stat );
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
        id => {
            -not_in => $stats->get_column('guid')->as_query,
        },
        report => \[ "->> '\$.environment.language.name'=?", 'Perl 5' ],
    });
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
        'INSERT INTO metabase (guid,id,updated,report,fact) VALUES (?,?,?,?,?)',
        {},
        $guid, $id, $created_epoch, $report_zip, $fact_zip,
    );

    return;
}

1;

