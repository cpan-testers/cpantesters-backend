package CPAN::Testers::Backend::Test;
# ABSTRACT: Test helpers for the CPAN::Testers::Backend

use CPAN::Testers::Backend::Base;
use CPAN::Testers::Backend qw( check_mysql );
use CPAN::Testers::Schema;
use Exporter qw( import );
use DBI;
use Test::More;

our @EXPORT_OK = qw( build_test_mysqld build_test_schema build_test_metabase );

sub build_test_mysqld() {
    eval { require Test::mysqld } or plan skip_all => 'Requires Test::mysqld';
    state $mysqld;
    if ( !$mysqld ) {
        $mysqld = Test::mysqld->new(
            my_cnf => {
                'skip-networking' => '', # no TCP socket
            },
        ) or plan skip_all => $Test::mysqld::errstr;

        my $mysql_dbh           = DBI->connect( $mysqld->dsn( dbname => 'test' ) );
        # require a MySQL or MariaDB version with JSON support
        eval { check_mysql( $mysql_dbh ) } or plan skip_all => $@;
    }
    return $mysqld;
}

sub build_test_schema() {
    my $mysqld = build_test_mysqld();
    my $schema = CPAN::Testers::Schema->connect(
        $mysqld->dsn(dbname => 'test'),
        undef, undef,
        { ignore_version => 1 },
    );
    $schema->deploy;
    return $schema;
}

sub build_test_metabase() {
    my $metabase_dbh = DBI->connect( 'dbi:SQLite::memory:', undef, undef, { RaiseError => 1 } );
    $metabase_dbh->do(q{
        CREATE TABLE `metabase` (
            `guid` CHAR(36) NOT NULL PRIMARY KEY,
            `id` INT(10) NOT NULL,
            `updated` VARCHAR(32) DEFAULT NULL,
            `report` BINARY NOT NULL,
            `fact` BINARY
        )
    });
    $metabase_dbh->do(q{
        CREATE TABLE `testers_email` (
            `id` INTEGER PRIMARY KEY,
            `resource` VARCHAR(64) NOT NULL,
            `fullname` VARCHAR(255) NOT NULL,
            `email` VARCHAR(255) DEFAULT NULL
        )
    });
    return $metabase_dbh;
}

1;
