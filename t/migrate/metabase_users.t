
=head1 DESCRIPTION

This tests the L<CPAN::Testers::Backend::Migrate::MetabaseUsers> module
to make sure that users are migrated correctly and only the last record
is kept.

=head1 SEE ALSO

L<CPAN::Testers::Backend::Migrate::MetabaseUsers>

=cut

use CPAN::Testers::Backend::Base 'Test';
use CPAN::Testers::Backend::Migrate::MetabaseUsers;

my $class = 'CPAN::Testers::Backend::Migrate::MetabaseUsers';
my $schema = CPAN::Testers::Schema->connect( 'dbi:SQLite::memory:', undef, undef, { ignore_version => 1 } );
$schema->deploy;

my $dbh = DBI->connect( 'dbi:SQLite::memory' );
$dbh->do( 'CREATE TABLE `metabase` (
  `guid` char(36) NOT NULL,
  `id` int(10) unsigned NOT NULL,
  `updated` varchar(32) DEFAULT NULL,
  `report` longblob NOT NULL,
  `fact` longblob,
  PRIMARY KEY (`guid`),
  KEY `id` (`id`),
  KEY `updated` (`updated`)
' );
$dbh->do( 'CREATE TABLE `testers_email` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `resource` varchar(64) NOT NULL,
  `fullname` varchar(255) NOT NULL,
  `email` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `resource` (`resource`)
');

$dbh->do( 'INSERT INTO testers_email (resource, fullname, email ) VALUES (
    "metabase:user:12345678-1234-1234-1234-123456789012",
    "Doug Bell",
    "doug@preaction.me"
)' );
$dbh->do( 'INSERT INTO testers_email (resource, fullname, email ) VALUES (
    "metabase:user:11111111-1111-1111-1111-111111111111",
    "Chris Williams",
    "root@klanker.net"
)' );

subtest 'migrate users' => sub {

};

$dbh->do( 'INSERT INTO testers_email (resource, fullname, email ) VALUES (
    "metabase:user:11111111-1111-1111-1111-111111111111",
    "Chris Williams",
    "real@fake.email"
)' );
$dbh->do( 'INSERT INTO testers_email (resource, fullname, email ) VALUES (
    "metabase:user:22222222-2222-2222-2222-222222222222",
    "Ray Mamnarelli",
    "raytestinger@yahoo.com"
)' );

subtest 'migrate users again' => sub {

};

done_testing;

