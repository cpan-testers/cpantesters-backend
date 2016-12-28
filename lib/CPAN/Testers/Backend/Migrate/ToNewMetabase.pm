package CPAN::Testers::Backend::Migrate::ToNewMetabase;
our $VERSION = '0.001';
# ABSTRACT: Migrate data from the old metabase to the new format

=head1 SYNOPSIS

    beam run <container> <service>

=head1 DESCRIPTION

This runnable object migrates data from the old metabase to a new one,
altering the data to be more-easily consumed on the way.

The new metabase is scanned for any missing records compared to the old
metabase, and then those missing records are migrated.

=head1 SEE ALSO

L<beam>, L<CPAN::Testers::Schema::Result::TestReport>

=cut

use CPAN::Testers::Backend::Base;
use Moo;
with 'Beam::Runnable';

sub run {
    my ( $class, @args ) = @_;

}

1;
