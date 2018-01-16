package CPAN::Testers::Backend::ViewMetabaseCache;
our $VERSION = '0.005';
# ABSTRACT: View an entry from the old metabase cache

=head1 SYNOPSIS

    beam run <container> <service> [--force | -f]

=head1 DESCRIPTION

This task allows viewing the data in the C<metabase.metabase> table to
make sure it's accurate and correct.

=cut

use CPAN::Testers::Backend::Base 'Runnable';
with 'Beam::Runnable';
use Getopt::Long qw( GetOptionsFromArray );
use Data::FlexSerializer;
use JSON::MaybeXS qw( encode_json );
use CPAN::Testers::Report;
use CPAN::Testers::Fact::TestSummary;
use CPAN::Testers::Fact::LegacyReport;
use CPAN::Testers::Backend::Migrate::MetabaseCache;
use Data::Dumper;

=attr metabase_dbh

The L<DBI> object connected to the C<metabase> database.

=cut

has metabase_dbh => (
    is => 'ro',
    isa => InstanceOf['DBI::db'],
    required => 1,
);

sub run( $self, @args ) {

    my $row = $self->metabase_dbh->selectrow_hashref(
        "SELECT * FROM metabase WHERE guid=?", {}, $args[0],
    );
    my $migrate = "CPAN::Testers::Backend::Migrate::MetabaseCache";

    say "----- Fact column";
    my $fact = $migrate->parse_metabase_report( {
        fact => $row->{fact},
        guid => $row->{guid},
        id => $row->{id},
        updated => $row->{updated},
    } );
    say Dumper $fact;

    say "----- Report column";
    my $report = $migrate->parse_metabase_report( {
        report => $row->{report},
        guid => $row->{guid},
        id => $row->{id},
        updated => $row->{updated},
    } );
    say Dumper $report;
}

1;
