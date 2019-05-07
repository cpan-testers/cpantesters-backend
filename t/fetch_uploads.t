
=head1 DESCRIPTION

This test ensures that the right uploads are created from a mock MetaCPAN
client.

=head1 SEE ALSO

L<CPAN::Testers::Backend::FetchUploads>

=cut

use CPAN::Testers::Backend::Base 'Test';
use CPAN::Testers::Schema;
use CPAN::Testers::Backend::FetchUploads;
use Path::Tiny qw( path );
use FindBin ();
use Data::Dumper;

my $SHARE_DIR = path( $FindBin::Bin, 'share' );

my $class = 'CPAN::Testers::Backend::FetchUploads';
my $schema = CPAN::Testers::Schema->connect( 'dbi:SQLite::memory:' );
$schema->deploy;

my $cmd = $class->new(
    schema => $schema,
);

$cmd->run(
    '--since' => '2019-04-30T00:00:00',
);

#say Dumper [ $schema->resultset( 'Upload' )->first ];

done_testing;
