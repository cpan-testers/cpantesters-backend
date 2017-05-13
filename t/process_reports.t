use CPAN::Testers::Backend::Base 'Test';
use CPAN::Testers::Schema;
use CPAN::Testers::Backend::ProcessReports;

my $class = 'CPAN::Testers::Backend::ProcessReports';
my $schema = CPAN::Testers::Schema->connect( 'dbi:SQLite::memory:', undef, undef, { ignore_version => 1 } );
$schema->deploy;

$schema->resultset('Stats')->create({
    id => 82067962,
    guid => 'd0ab4d36-3343-11e7-b830-917e22bfee97',
    state => 'fail',
    postdate => 201705,
    tester => 'andreas.koenig.gmwojprw@franz.ak.mind.de ((Andreas J. Koenig))',
    dist => 'Sorauta-SVN-AutoCommit',
    version => '0.02',
    platform => 'x86_64-linux',
    perl => '5.22.2',
    osname => 'linux',
    osvers => '4.8.0-2-amd64',
    fulldate => 201705071640,
    type => 2,
    uploadid => 169497,
});

$schema->resultset('TestReport')->create({
    id => 'd0ab4d36-3343-11e7-b830-917e22bfee97',
    report => {
        reporter => {
            name  => 'Andreas J. Koenig',
            email => 'andreas.koenig.gmwojprw@franz.ak.mind.de',
        },
        environment => {
            system => {
                osname => 'linux',
                osversion => '4.8.0-2-amd64',
            },
            language => {
                name => 'Perl 5',
                version => '5.22.2',
                archname => 'x86_64-linux',
            },
        },
        distribution => {
            name => 'Sorauta-SVN-AutoCommit',
            version => '0.02',
        },
        result => {
            grade => 'FAIL',
        },
    },
});

$schema->resultset('TestReport')->create({
    id => 'cfa81824-3343-11e7-b830-917e22bfee97',
    report => {
        reporter => {
            name  => 'Andreas J. Koenig',
            email => 'andreas.koenig.gmwojprw@franz.ak.mind.de',
        },
        environment => {
            system => {
                osname => 'linux',
                osversion => '4.8.0-2-amd64',
            },
            language => {
                name => 'Perl 5',
                version => '5.20.1',
                archname => 'x86_64-linux-thread-multi',
            },
        },
        distribution => {
            name => 'Sorauta-SVN-AutoCommit',
            version => '0.02',
        },
        result => {
            grade => 'FAIL',
        },
    },
});

subtest find_unprocessed_reports => sub {
    my $pr = $class->new(schema => $schema, from => 'demo@test.com');
    my @to_process = $pr->find_unprocessed_reports;
    is @to_process, 1, 'one unprocessed result';
    is $to_process[0]->id, 'cfa81824-3343-11e7-b830-917e22bfee97', 'correct id to be processed';
};

done_testing;


