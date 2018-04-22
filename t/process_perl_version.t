
=head1 DESCRIPTION

This test ensures that Perl versions can be read from the local CPAN mirror
and written to the database.

=head1 SEE ALSO

L<CPAN::Testers::Backend::ProcessPerlVersion>

=cut

use CPAN::Testers::Backend::Base 'Test';
use CPAN::Testers::Schema;
use CPAN::Testers::Backend::ProcessPerlVersion;
use Path::Tiny qw( path );
use FindBin ();

my $SHARE_DIR = path( $FindBin::Bin, 'share' );

my $class = 'CPAN::Testers::Backend::ProcessPerlVersion';
my $schema = CPAN::Testers::Schema->connect( 'dbi:SQLite::memory:' );
$schema->deploy;

my $cmd = $class->new(
    schema => $schema,
    cpan_root => $SHARE_DIR->child( 'CPAN' ),
);

$cmd->run;

my @versions = $schema->resultset( 'PerlVersion' )->all;
is scalar @versions, 3, '3 versions found';
my ( $stable ) = grep { $_->version eq '5.22.0' } @versions;
is $stable->perl, '5.22.0', 'stable perl correct';
is $stable->devel, 0, 'stable perl not devel perl';
my ( $devel ) = grep { $_->version eq '5.9.5' } @versions;
is $devel->perl, '5.9.5', 'devel perl correct';
is $devel->devel, 1, 'devel perl labelled as devel';
my ( $rc ) = grep { $_->version eq '5.20.3 RC1' } @versions;
is $rc->perl, '5.20.3', 'rc perl correct';
is $rc->devel, 1, 'rc perl labelled as devel';

done_testing;
