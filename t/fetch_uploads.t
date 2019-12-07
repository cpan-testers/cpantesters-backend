
=head1 DESCRIPTION

This test ensures that the right uploads are created from a mock MetaCPAN
client.

=head1 SEE ALSO

L<CPAN::Testers::Backend::FetchUploads>

=cut

use CPAN::Testers::Backend::Base 'Test';
use Mock::MonkeyPatch;
use CPAN::Testers::Schema;
use CPAN::Testers::Backend::FetchUploads;
use Path::Tiny qw( path );
use FindBin ();
use Data::Dumper;

my $SHARE_DIR = path( $FindBin::Bin, 'share' );

my $class = 'CPAN::Testers::Backend::FetchUploads';
my $schema = CPAN::Testers::Schema->connect( 'dbi:SQLite::memory:' );
$schema->deploy;

my $mock_all = Mock::MonkeyPatch->patch(
    'MetaCPAN::Client::all' => sub {
        require MetaCPAN::Client::ResultSet;
        return MetaCPAN::Client::ResultSet->new(
            type => 'release',
            items => [
                MetaCPAN::Client::Release->new(
                    name => 'CPAN-Testers-Backend',
                    date => '2019-05-01T00:00:00',
                    archive => 'CPAN-Testers-Backend-0.001.tar.gz',
                    author => 'PREACTION',
                    status => 'cpan',
                    maturity => 'released',
                    main_module => 'CPAN::Testers::Backend',
                    id => 1,
                    authorized => 1,
                ),
            ],
        );
    }
);

my $cmd = $class->new(
    schema => $schema,
);

$cmd->run(
    '--since' => '2019-04-30T00:00:00',
);

my $rs = $schema->resultset( 'Upload' );
$rs->result_class( 'DBIx::Class::ResultClass::HashRefInflator' );

is_deeply $rs->first,
    {
        uploadid => 1,
        type => 'cpan',
        dist => 'CPAN-Testers-Backend',
        version => '0.001',
        author => 'PREACTION',
        filename => 'CPAN-Testers-Backend-0.001.tar.gz',
        released => 1556668800, # epoch time
    },
    'Upload is correctly processed'
    ;

done_testing;
