#!/usr/bin/perl
use strict;
$|++;

my $VERSION = '0.01';

#----------------------------------------------------------------------------


# -------------------------------------
# Library Modules

use Config::IniFiles;
use CPAN::Testers::Common::DBUtils;
use File::Basename;
use File::Path;
use Getopt::Long;
use HTML::Entities;
use IO::File;

# -------------------------------------
# Variables

my ($dbh,%options,$address);

# -------------------------------------
# Program

init_options();
postdate()  if($options{postdate});
update()    if($options{update});
renew()     if($options{renew});
check()     if($options{check});

# -------------------------------------
# Subroutines

=head1 FUNCTIONS

=over 4

=cut

sub renew {
    _log("START renew");
    _update( 'SELECT distinct(postdate) as postdate FROM cpanstats' );
    _log("STOP renew");
}

sub postdate {
    _log("START postdate = $options{postdate}");
    _update( "SELECT '$options{postdate}' as postdate" );
    _log("STOP postdate");
}

sub update {
    _log("START update");
    _update( 'SELECT distinct(postdate) as postdate FROM cpanstats ORDER BY postdate DESC LIMIT 3' );
    _log("STOP update");
}

sub _update {
    my $sql1 = shift;
    my $sql2 = 'SELECT osname,tester,COUNT(id) AS count FROM cpanstats '.
                'WHERE postdate=? AND type=2 '.
                'GROUP BY osname,tester ORDER BY tester,osname';
    my $sql3 = 'REPLACE leaderboard SET postdate=?,osname=?,tester=?,score=?';
    my $sql4 = 'DELETE FROM leaderboard WHERE postdate=?';

    my @rows = $dbh->get_query('hash',$sql1);
    for my $row (@rows) {
        _log("postdate = $row->{postdate}");

        $dbh->do_query($sql4,$row->{postdate});

        my (%hash,%names);
        my $next = $dbh->iterator('hash',$sql2,$row->{postdate});
        while(my $row2 = $next->()) {
            my $name = _tester_name($row2->{tester});

            #_log( sprintf "%s,%s,%d", lc $row2->{osname}, $name, $row2->{count} );
            $hash{lc $row2->{osname}}{$name} += $row2->{count};
            #_log( sprintf "%s,%s,%d", lc $row2->{osname}, $name, $hash{lc $row2->{osname}}{$name} );
        }

        for my $osname (keys %hash) {
            for my $name (keys %{ $hash{$osname} }) {
                $dbh->do_query($sql3, $row->{postdate}, $osname, $name, $hash{$osname}{$name});
                #$names{$name} += $hash{$osname}{$name};
            }
        }

        #for my $name (sort {$a cmp $b} keys %names) {
        #    _log( "$name,$names{$name}" );
        #}
    }
}

sub _tester_name {
    my ($name) = @_;

    $address ||= do {
        my (%address_map,%known);
        my $fh = IO::File->new($options{address})    or die "Cannot open address file [$options{address}]: $!";
        while(<$fh>) {
            chomp;
            my ($source,$target) = (/(.*),(.*)/);
            next    unless($source && $target);
            $address_map{$source} = $target;
            $known{$target}++;
        }
        $fh->close;
        \%address_map;
    };

    my $addr = ($address->{$name} && $address->{$name} =~ /\&\#x?\d+\;/)
                ? $address->{$name}
                : encode_entities( ($address->{$name} || $name) );

    $addr = lc $addr    if($addr =~ /\@/);

    $addr =~ s/\./ /g if($addr =~ /\@/);
    $addr =~ s/\@/ \+ /g;
    $addr =~ s/</&lt;/g;
    return $addr;
}

sub check {
    my $sql1 = 
            'SELECT postdate,COUNT(id) AS qty FROM cpanstats '.
            'WHERE type=2 '.
            'GROUP BY postdate';
    my $sql2 =
            'SELECT postdate,SUM(score) AS qty FROM leaderboard '.
            'GROUP BY postdate '.
            'ORDER BY postdate';

    my %hash;
    my @rows = $dbh->get_query('hash',$sql1);
    for my $row (@rows) {
        $hash{ $row->{postdate} } = $row->{qty};
    }

    @rows = $dbh->get_query('hash',$sql2);
    for my $row (@rows) {
        next if($hash{ $row->{postdate} } == $row->{qty});
        my $str = sprintf "%s, %d, %d", $row->{postdate}, $hash{ $row->{postdate} }, $row->{qty};
        _log($str);
        print "$str\n";
    }
}

=item init_options

Prepare command line options

=cut

sub init_options {
    GetOptions( \%options,
        'config=s',
        'logfile=s',
        'logclean=i',
        
        'renew',
        'update',
        'check',
        'postdate=s',
        
        'help|h',
        'version|v'
    ) or help(1);

    help(1) if($options{help});
    help(0) if($options{version});

    $options{update} = 1    unless($options{renew} || $options{update} || $options{check} || $options{postdate});

    # ensure we have a configuration file
    die "Must specify the configuration file\n"             unless(   $options{config});
    die "Configuration file [$options{config}] not found\n" unless(-f $options{config});

    # load configuration file
    my $cfg;
    local $SIG{'__WARN__'} = \&_alarm_handler;
    eval { $cfg = Config::IniFiles->new( -file => $options{config} ); };
    die "Cannot load configuration file [$options{config}]\n"  unless($cfg && !$@);

    # configure databases
    for my $db (qw(CPANSTATS)) {
        die "No configuration for $db database\n"   unless($cfg->SectionExists($db));
        my %opts = map {my $v = $cfg->val($db,$_); defined($v) ? ($_ => $v) : () }
                        qw(driver database dbfile dbhost dbport dbuser dbpass);
        $dbh = CPAN::Testers::Common::DBUtils->new(%opts);
        die "Cannot configure $db database\n" unless($dbh);
    }

    # store known OS names
    my @rows = $dbh->get_query('array',q{SELECT osname,ostitle FROM osname ORDER BY id});
    for my $row (@rows) {
        $options{osnames}{lc $row->[0]} ||= $row->[1];
    }

    $options{address}  = _defined_or( $options{address},    $cfg->val('MASTER','address'   ) );
    $options{logfile}  = _defined_or( $options{logfile},    $cfg->val('MASTER','logfile'   ) );
    $options{logclean} = _defined_or( $options{logclean},   $cfg->val('MASTER','logclean'  ), 0 );

    _log("address   =".($options{address}  || ''));
    _log("logfile   =".($options{logfile}  || ''));
    _log("logclean  =".($options{logclean} || ''));
}

sub help {
    my $full = shift;

    if($full) {
        print "\n";
        print "Usage:$0 --config=<file> \\\n";
        print "         [--logfile=<file> [--logclean=<1|0>]] \\\n";
        print "         [--renew] [--update] \\\n";
        print "         [--help|h] [--version|v] \n\n";

#              12345678901234567890123456789012345678901234567890123456789012345678901234567890
        print "This program builds the CPAN Testers Statistics website.\n";

        print "\nFunctional Options:\n";
        print "  [--config=<file>]          # path to config file [required]\n";
        print "  [--logfile=<file>]         # path to logfile\n";
        print "  [--logclean]		        # overwrite log if specified\n";

        print "\nRun Mode Options:\n";
        print "  [--renew]                  # renew leaderboard\n";
        print "  [--update]                 # update leaderboard\n";

        print "\nOther Options:\n";
        print "  [--version]                # program version\n";
        print "  [--help]                   # this screen\n";

        print "\nFor further information type 'perldoc $0'\n";
    }

    print "$0 v$VERSION\n";
    exit(0);
}

sub _alarm_handler () { return; }

sub _log {
    my $log = $options{logfile} or return;
    mkpath(dirname($log))   unless(-f $log);

    my $mode = $options{logclean} ? 'w+' : 'a+';
    $options{logclean} = 0;

    my @dt = localtime(time);
    my $dt = sprintf "%04d/%02d/%02d %02d:%02d:%02d", $dt[5]+1900,$dt[4]+1,$dt[3],$dt[2],$dt[1],$dt[0];

    my $fh = IO::File->new($log,$mode) or die "Cannot write to log file [$log]: $!\n";
    print $fh "$dt ", @_, "\n";
    $fh->close;
}

sub _defined_or {
    while(@_) {
        my $value = shift;
        return $value   if(defined $value);
    }

    return;
}

__END__

DROP TABLE IF EXISTS leaderboard;
CREATE TABLE leaderboard (
    postdate    varchar(8)      NOT NULL,
    osname      varchar(255)    NOT NULL,
    tester      varchar(255)    NOT NULL,  
    score       int(10)         DEFAULT 0,
    PRIMARY KEY (postdate,osname,tester),
    KEY IXOS   (osname),
    KEY IXTEST (tester)
);

