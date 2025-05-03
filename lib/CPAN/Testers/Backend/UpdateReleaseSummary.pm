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

    # Get the max summary stat ID from the release data table
    # Get the stat rows from the max summary ID to the current latest
    # summary ID
    # Update the release table

}

1;
