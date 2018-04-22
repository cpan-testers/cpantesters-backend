package CPAN::Testers::Backend::ProcessPerlVersion;
our $VERSION = '0.06';
# ABSTRACT: Load Perl versions from CPAN mirror

=head1 SYNOPSIS

    beam run <container> <task>

=head1 DESCRIPTION

=head1 SEE ALSO

L<CPAN::Testers::Schema::Result::PerlVersion>

=cut

use CPAN::Testers::Backend::Base 'Runnable';
use Types::Path::Tiny qw( AbsPath );

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

=method run

The main method that processes job arguments and performs the task.
Called by L<Beam::Runner> or L<Beam::Minion>.

=cut

sub run( $self, @args ) {
    my $rs = $self->schema->resultset( 'PerlVersion' );
    # Read the src/5.0 directory for tar.gz files
    for my $file ( $self->cpan_root->child( 'src', '5.0' )->children ) {
        next unless $file->basename( '.tar.gz' ) =~ m{^perl-(5\.\d+\.\d+)(?:-RC(\d+))?};
        my $version = $1;
        my $rc = $2;
        if ( $rc ) {
            $version .= ' RC' . $rc;
        }
        $rs->find_or_create({ version => $version });
    }
}

1;
