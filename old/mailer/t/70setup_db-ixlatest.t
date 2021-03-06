#!perl

use strict;
use warnings;
use Test::More tests => 1;
use DBI;
#use DBD::SQLite;
use File::Spec;
use File::Path;
use File::Basename;

my $f = File::Spec->catfile('t','_DBDIR','test.db');
#unlink $f if -f $f;
mkpath( dirname($f) );

my $dbh = DBI->connect("dbi:SQLite:dbname=$f", '', '', {AutoCommit=>1});
$dbh->do(q{
    CREATE TABLE `ixlatest` (
      `dist`        text    NOT NULL,
      `version`     text    NOT NULL,
      `released`    int		NOT NULL,
      `author`      text    NOT NULL,
      PRIMARY KEY  (`dist`)
    );
});

while(<DATA>){
  chomp;
  $dbh->do('INSERT INTO ixlatest ( dist, version, released, author ) VALUES ( ?, ?, ?, ? )', {}, split(/\|/,$_) );
}

my ($ct) = $dbh->selectrow_array('select count(*) from ixlatest');

$dbh->disconnect;

is($ct, 43, "row ct");


#select * from ixlatest where author in ('LBROCARD', 'DRRHO', 'VOISCHEV', 'INGY', 'ISHIGAKI', 'SAPER', 'ZOFFIX', 'GARU', 'JESSE', 'JETEVE', 'JJORE', 'JBRYAN', 'JALDHAR', 'JHARDING', 'ADRIANWIT');
#dist|version|released|author
__DATA__
Acme-Scurvy-Whoreson-BilgeRat|1.1|1098737924|DCANTRELL
Acme-Pony|1.1.2|994748837|DCANTRELL
Acme-Licence|1.0|1032427132|DCANTRELL
App-Rsnapshot|1.999_00002|1237752266|DCANTRELL
Bryar|3.1|1243547561|DCANTRELL
Class-CanBeA|1.2|1135721806|DCANTRELL
CPU-Emulator-Memory|1.1001|1204241017|DCANTRELL
CPU-Emulator-Z80|1.0|1213390005|DCANTRELL
Class-DBI-ClassGenerator|1.02|1234279020|DCANTRELL
CPAN-ParseDistribution|1.1|1238841917|DCANTRELL
CPAN-FindDependencies|2.32|1240846285|DCANTRELL
Data-Compare|1.2101|1241534586|DCANTRELL
Data-Transactional|1.02|1213628931|DCANTRELL
DBIx-Class-SingletonRows|0.11|1214501602|DCANTRELL
Devel-AssertLib|0.1|1192375350|DCANTRELL
Data-Hexdumper|2.01|1236112173|DCANTRELL
Devel-CheckOS|1.61|1240658305|DCANTRELL
Devel-CheckLib|0.6|1242827231|DCANTRELL
File-Find-Rule-Permissions|2.0|1234393200|DCANTRELL
File-Overwrite|1.1|1239376506|DCANTRELL
Games-Dice-Advanced|1.1|1158083466|DCANTRELL
NestedMap|1.0|1056616457|DCANTRELL
Palm-TreoPhoneCallDB|1.1|1185831423|DCANTRELL
Number-Phone-UK-DetailedLocations|1.3|1173904230|DCANTRELL
Net-Random|2.0|1176419823|DCANTRELL
Palm-SMS|0.03|1231604443|DCANTRELL
Palm-ProjectGutenberg|1.0|1238100499|DCANTRELL
Palm-Treo680MessagesDB|1.01|1239374790|DCANTRELL
Number-Phone|1.7002|1240426027|DCANTRELL
Pony|1.01|986377728|DCANTRELL
Sort-MultipleFields|1.0|1217282145|DCANTRELL
Statistics-ChiSquare|0.5|1068995421|DCANTRELL
Statistics-SerialCorrelation|1.1|1074882312|DCANTRELL
Sub-WrapPackages|1.2|1154526137|DCANTRELL
Tie-Hash-Rank|1.0.1|992462581|DCANTRELL
Tie-Hash-Transactional|1.0|994749035|DCANTRELL
Tie-Scalar-Decay|1.1.1|990483493|DCANTRELL
Tie-Hash-Longest|1.1|1069101730|DCANTRELL
Tie-STDOUT|1.0401|1237457580|DCANTRELL
WWW-Facebook-Go-SGF|1.0|1235769360|DCANTRELL
XML-DoubleEncodedEntities|1.0|1173731580|DCANTRELL
XML-Tiny|2.02|1237907700|DCANTRELL
XML-Tiny-DOM|1.0|1238088168|DCANTRELL
