package CPAN::Testers::Backend::Migrate::ToNewMetabase;
our $VERSION = '0.001';
# ABSTRACT: Migrate data from the old metabase to the new format

=head1 SYNOPSIS

    beam run <container> <service> [--start <start>] [--end <end>]

=head1 DESCRIPTION

This runnable object migrates data from the old metabase to a new one,
altering the data to be more-easily consumed on the way.

The new metabase is scanned for any missing records compared to the old
metabase, and then those missing records are migrated.

=head1 OPTIONS

=head2 start

Start from this ID. Defaults to finding the start from the last ID
loaded in the destination.

=head2 end

End at this ID. Defaults to finding the end from the last ID loaded in
the source.

=head1 SEE ALSO

L<beam>, L<CPAN::Testers::Schema::Result::TestReport>

=cut

use CPAN::Testers::Backend::Base;
use Moo;
with 'Beam::Runnable';
use Log::Any qw( $LOG );
use Log::Any::Adapter 'Syslog';
use Getopt::Long qw( GetOptionsFromArray );

sub run {
    my ( $class, @args ) = @_;

    GetOptionsFromArray( \@args, \my %opt,
        'start|s=i',
        'end|e=i',
    );

    if ( !$opt{start} ) {
        # Find start from destination
    }
    if ( !$opt{end} ) {
        # Find end from source
    }

    $LOG->infof( 'Migrating from start %d to end %d', $opt->@{qw( start end )} );

    # Copy from old metabase
    # Write to new metabase
    # In batches of 1000 or so?
}

1;
