use utf8;

=head1 DESCRIPTION

This test ensures that the tester info command works correctly.

=head1 SEE ALSO

L<CPAN::Testers::Backend::Fix::TesterInfo>

=cut

use CPAN::Testers::Backend::Base 'Test';
use JSON::MaybeXS qw( encode_json );
use CPAN::Testers::Backend::Fix::TesterInfo;

my $class = 'CPAN::Testers::Backend::Fix::TesterInfo';
my $cmd = $class->new(
    schema => build_test_schema(),
    metabase_dbh => build_test_metabase(),
);

# Insert test data
$cmd->schema->populate(
    PerlVersion => [
        {
            version => '5.24.0',
            perl => '5.24.0',
            patch => 0,
            devel => 0,
        },
    ],
);
$cmd->schema->populate(
    Upload => [
        {
            type => 'cpan',
            dist => 'Yancy',
            version => '1.000',
            author => 'PREACTION',
            filename => 'Yancy-1.000.tar.gz',
            released => time(),
        },
    ],
);
$cmd->schema->populate(
    MetabaseUser => [
        {
            resource => 'metabase:user:11111111-1111-1111-1111-111111111111',
            fullname => 'Slaven Rezic',
            email => 'slaven@example.com',
        },
    ],
);
$cmd->schema->populate(
    TestReport => [
        {
            id => '11111111-1111-1111-1111-111111111111',
            report => encode_json({
                reporter => {
                    name => 'Slaven Rezic',
                    email => 'slaven@example.com',
                },
            }),
            created => '2020-01-01 00:00:00',
        },
    ],
);
$cmd->schema->populate(
    Stats => [
        {
            guid => '11111111-1111-1111-1111-111111111111',
            tester => 'Slaven Rezic <slaven@example.com>',
            postdate => '202001',
            fulldate => '202001010000',
            dist => 'Yancy',
            version => '1.000',
            platform => 'x86_64-linux',
            perl => '5.24.0',
            osname => 'Linux',
            osvers => '4.0.0',
            type => 2,
            uploadid => 1,
        },
    ],
);
$cmd->metabase_dbh->do(
    q{INSERT INTO testers_email ( resource, fullname, email ) VALUES ( ?, ?, ? )},
    {},
    'metabase:user:11111111-1111-1111-1111-111111111111', 'Slaven Rezic', 'slaven@example.com',
);

# Execute the command
$cmd->run(qw{ --like Slaven% srezic@example.com }, 'Slaven Rezi&#263;' );

# Test the results
ok my $row = $cmd->schema->resultset( 'MetabaseUser' )->find({ email => 'srezic@example.com' }),
    'MetabaseUser row is updated';
is $row->fullname, 'Slaven Rezi&#263;',
    'fullname field is updated';

ok $row = $cmd->schema->resultset( 'Stats' )->find({ tester => '"Slaven Rezi&#263;" <srezic@example.com>' }),
    'Stats row is updated';

ok $row = $cmd->schema->resultset( 'TestReport' )->find({
        report => \[ q{->>"$.reporter.email" = ? }, 'srezic@example.com' ],
    }),
    'TestReport row is updated';

ok $row = $cmd->metabase_dbh->selectrow_hashref(
    'SELECT * FROM testers_email WHERE email=?', undef, 'srezic@example.com',
), 'metabase testers_email row is updated';
is $row->{fullname}, 'Slaven Rezi&#263;', 'fullname field is updated';

done_testing;
