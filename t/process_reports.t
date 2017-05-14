use Log::Any::Test;
use Log::Any '$LOG';

use CPAN::Testers::Backend::Base 'Test';
use CPAN::Testers::Schema;
use CPAN::Testers::Backend::ProcessReports;

my $class = 'CPAN::Testers::Backend::ProcessReports';
my $schema = CPAN::Testers::Schema->connect( 'dbi:SQLite::memory:', undef, undef, { ignore_version => 1 } );
$schema->deploy;
my $pr = $class->new(schema => $schema, from => 'demo@test.com');

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
    my @to_process = $pr->find_unprocessed_reports;
    is @to_process, 1, 'one unprocessed result';
    is $to_process[0]->id, 'cfa81824-3343-11e7-b830-917e22bfee97', 'correct id to be processed';
};

subtest run => sub {
    subtest 'check that the initial scenario is valid' => sub {
        my $reports = $schema->resultset('TestReport')->count;
        my $stats   = $schema->resultset('Stats')->count;
        isnt $reports, $stats, 'test that stats and test reports are unequal in count';
        my @to_process = $pr->find_unprocessed_reports;
        isnt @to_process, 0, 'some reports are not processed';
    };

    # the lack of an upload causes a test report to skip migration
    $LOG->clear;
    $pr->run;

    subtest 'check that the skip works' => sub {
        $LOG->contains_ok(qr'found 1'i, 'found message was logged');
        $LOG->contains_ok(qr'skipping'i, 'individual skip message was logged');
        $LOG->contains_ok(qr'skipped 1'i, 'skipped message was logged');
        my $reports = $schema->resultset('TestReport')->count;
        my $stats   = $schema->resultset('Stats')->count;
        isnt $reports, $stats, 'test that stats and test reports are unequal in count';
        my @to_process = $pr->find_unprocessed_reports;
        isnt @to_process, 0, 'some reports are not processed';
    };

    $schema->resultset('Upload')->create({
        uploadid => 169497,
        type => 'cpan',
        author => 'YUKI',
        dist => 'Sorauta-SVN-AutoCommit',
        version => 0.02,
        filename => 'Sorauta-SVN-AutoCommit-0.02.tar.gz',
        released => 1327657454,
    });

    # now that the upload is created the run should fully process
    $LOG->clear;
    $pr->run;

    subtest 'check that the final scenario is correct' => sub {
        $LOG->contains_ok(qr'found 1'i, 'found message was logged');
        $LOG->does_not_contain_ok(qr'skip'i, 'no skip message was logged');
        my $reports = $schema->resultset('TestReport')->count;
        my $stats   = $schema->resultset('Stats')->count;
        is $reports, $stats, 'test that stats and tests are now equal in count';
        my @to_process = $pr->find_unprocessed_reports;
        is @to_process, 0, 'no reports remain to be processed';
    };
};

done_testing;


