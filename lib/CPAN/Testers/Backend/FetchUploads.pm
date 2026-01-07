package CPAN::Testers::Backend::FetchUploads;
our $VERSION = '0.006';
# ABSTRACT: Fetch CPAN uploads from MetaCPAN

=head1 SYNOPSIS

    beam run <container> <task>

=head1 DESCRIPTION

This module is a L<Beam::Runnable> task that fetches a list of CPAN
releases from L<http://metacpan.org> and updates the C<uploads> database
table accordingly (via L<CPAN::Testers::Schema::Result::Upload>).

=cut

use v5.24;
use warnings;
use Moo;
use experimental qw( signatures postderef );
use Log::Any '$LOG';
use Types::Standard qw( InstanceOf );
with 'Beam::Runnable';
use Getopt::Long qw( GetOptionsFromArray );
use MetaCPAN::Client;
use DateTime::Format::ISO8601;
use CPAN::DistnameInfo;

=attr schema

A L<CPAN::Testers::Schema> object to access the database.

=cut

has schema => (
    is => 'ro',
    isa => InstanceOf['CPAN::Testers::Schema'],
    required => 1,
);

=attr metacpan

A L<MetaCPAN::Client> object to access MetaCPAN. Override this
to set MetaCPAN attributes.

=cut

has metacpan => (
    is => 'ro',
    isa => InstanceOf['MetaCPAN::Client'],
    lazy => 1,
    default => sub {
      MetaCPAN::Client->new(
        debug => 1,
      )
    },
);

=method run

The main method that processes job arguments and performs the task.
Called by L<Beam::Runner> or L<Beam::Minion>.

=cut

sub run( $self, @args ) {
    GetOptionsFromArray( \@args, \my %opt, 'since|s=s' );

    my @filter = ();
    # If we have any filters
    if ( $opt{since} ) {
        @filter = (
            filter => {
                and => [
                    # Specific filters added here
                    ( $opt{since} ? { range => { date => { gte => $opt{since} } } } : () ),
                ],
            },
        );
    }

    my $releases_rs = $self->metacpan->all('releases', {
        fields => [qw( author archive date )],
        @filter,
    });

    my $date_format = DateTime::Format::ISO8601->new;
    my $upload_rs = $self->schema->resultset( 'Upload' );
    my $total = $releases_rs->total;
    my $added = 0;
    my $skipped = 0;
    while ( my $release = $releases_rs->next ) {
        my $info = CPAN::DistnameInfo->new( $release->archive );
        my %upload = (
            dist => $info->dist,
            version => $info->version // 0,
            author => $release->author,
            filename => $info->filename,
            released => $date_format->parse_datetime( $release->date ),
            type => 'cpan',
        );
        if (!$info->dist) {
          $LOG->warnf('Unable to parse archive %s. Skipping!', $release->archive);
          next;
        }
        if ( $upload_rs->search({ %upload{qw( dist version author filename )} })->count ) {
            $skipped++;
        }
        else {
            $upload_rs->update_or_create( \%upload );
            $added++;
        }
    }

    say "Added $added, skipped $skipped of $total releases found";
    return 0;
}

1;
