package CPAN::Testers::Backend::ProcessUploads;
our $VERSION = '0.006';
# ABSTRACT: Process CPAN uploads into database rows

=head1 SYNOPSIS

    beam run <container> <task>

=head1 DESCRIPTION

This module is a L<Beam::Runnable> task that scans the local CPAN mirror
for new uploads and deleted files and updates the C<uploads> database
table accordingly (via L<CPAN::Testers::Schema::Result::Upload>).

This uses L<CPAN::DistnameInfo> to parse the CPAN file path into the
distribution name, version, and author.

=cut

use v5.24;
use warnings;
use Moo;
use experimental 'signatures', 'postderef';
use Log::Any '$LOG';
use Types::Standard qw( InstanceOf RegexpRef );
use Types::Path::Tiny qw( AbsPath );
with 'Beam::Runnable';
use CPAN::DistnameInfo;

=attr schema

A L<CPAN::Testers::Schema> object to access the database.

=cut

has schema => (
    is => 'ro',
    isa => InstanceOf['CPAN::Testers::Schema'],
    required => 1,
);

=attr cpan_root

The path to the CPAN mirror root directory. Must be absolute.

=cut

has cpan_root => (
    is => 'ro',
    isa => AbsPath,
    coerce => AbsPath->coercion,
    required => 1,
);

=attr backpan_root

The path to the BackPAN mirror root directory. Must be absolute.

=cut

has backpan_root => (
    is => 'ro',
    isa => AbsPath,
    coerce => AbsPath->coercion,
    required => 1,
);

=attr dist_ext

The available extentions for a CPAN distribution. A regular expression.
Defaults to allowing: C<.tar.gz>, C<.tar.bz2>, C<.tgz>, and C<.zip>.

=cut

has dist_ext => (
    is => 'ro',
    isa => RegexpRef,
    default => sub { qr{\.(tar\.(gz|bz2)|tgz|zip)$} },
);

=method run

The main method that processes job arguments and performs the task.
Called by L<Beam::Runner> or L<Beam::Minion>.

=cut

sub run( $self, @args ) {

    # Get the current list of CPAN uploads
    # Add new uploads
    # Mark missing uploads as BackPAN'd
    # Update the ixlatest table?

}

1;
