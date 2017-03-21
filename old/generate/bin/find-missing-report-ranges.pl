#!/usr/bin/perl -w
use strict;
$|++;

my $VERSION = '0.01';

# -------------------------------------
# Library Modules

use Config::IniFiles;
use CPAN::Testers::Common::DBUtils;
use Getopt::ArgvFile default=>1;
use Getopt::Long;
use IO::File;
use Time::Local;
use Time::Piece;
use DateTime;
use DateTime::Duration;

# -------------------------------------
# Variables

my (%options,$dbi);
my (%times,@diffs);

my $DIFF = 30;         # max difference allowed in seconds
my $MINS = 15;         # split time in minutes
my $SECS = 60 * $MINS; # split time in seconds

# -------------------------------------
# Program

##### INITIALISE #####

init_options();

##### MAIN #####

my @where;
push @where, "updated >= '$options{from}'" if($options{from});
push @where, "updated <= '$options{to}'"   if($options{to});
my $where = @where ? 'WHERE ' . join(' AND ', @where) : '';
my $sql = "SELECT updated FROM metabase $where ORDER BY updated";

#print "$sql\n";
#exit;

my ($from,$to) = ($options{from},'');
my $next = $dbi->iterator('hash',$sql);
while( my $row = $next->() ) {
    unless($from) {
        $from = $row->{updated};
        next;
    }

    my $this = $row->{updated};
    unless($to) {
        if(diff($from,$this) >= $DIFF) {
            $to = $this;
        } else {
            $from = $this;
            $to   = '';
        }
        next;
    }

    if(diff($to,$this) >= $DIFF) {
        $to = $this;
        next;
    }

    if(diff($from,$to) > $SECS) {
        while($from lt $to) {
            my @from = $from =~ /(\d+)\-(\d+)\-(\d+)T(\d+):(\d+):(\d+)/;
            my $dt = DateTime->new(
                year => $from[0], month => $from[1], day => $from[2],
                hour => $from[3], minute => $from[4], second => $from[5],
            );
            $dt->add( DateTime::Duration->new( minutes => $MINS ) );
            my $split = sprintf "%sT%sZ", $dt->ymd, $dt->hms;
#print STDERR "# $from,$split,$to\n";
            if($split lt $to) {
                print "$from,$split\n";
            } else {
                print "$from,$to\n";
            }

            $from = $split;
        }

    } else {
        print "$from,$to\n";
    }

    $from = $this;
    $to   = '';
}

$to = $options{to};
#print "from=$from, to=$to\n";

if($from && $to && diff($from,$to) >= $DIFF) {
    if(diff($from,$to) > $SECS) {
        while($from lt $to) {
            my @from = $from =~ /(\d+)\-(\d+)\-(\d+)T(\d+):(\d+):(\d+)/;
            my $dt = DateTime->new(
                year => $from[0], month => $from[1], day => $from[2],
                hour => $from[3], minute => $from[4], second => $from[5],
            );
            $dt->add( DateTime::Duration->new( minutes => $MINS ) );
            my $split = sprintf "%sT%sZ", $dt->ymd, $dt->hms;
#print STDERR "# $from,$split,$to\n";
            if($split lt $to) {
                print "$from,$split\n";
            } else {
                print "$from,$to\n";
            }

            $from = $split;
        }

    } else {
        print "$from,$to\n";
    }
}

sub diff {
    my ($d1,$d2) = @_;

    my @t = ($d1 =~ /(\d+)\-(\d+)\-(\d+)T(\d+):(\d+):(\d+)Z/);
    $t[1]--;
    my $t1 = timelocal(reverse @t);
    @t = ($d2 =~ /(\d+)\-(\d+)\-(\d+)T(\d+):(\d+):(\d+)Z/);
    $t[1]--;
    my $t2 = timelocal(reverse @t);

    return $t2 - $t1;
}

# -------------------------------------
# Subroutines

sub init_options {
    GetOptions( \%options,
        'config|c=s',
        'from|f=s',
        'to|t=s',
        'help|h'
    );

    help(1) if($options{help});

    help(1,"Must specify the configuration file")              unless($options{config});
    help(1,"Configuration file [$options{config}] not found")   unless(-f $options{config});

    # load configuration
    my $cfg = Config::IniFiles->new( -file => $options{config} );

    # configure databases
    my $db = 'METABASE';
    die "No configuration for $db database\n"   unless($cfg->SectionExists($db));
    my %opts = map {$_ => $cfg->val($db,$_);} qw(driver database dbfile dbhost dbport dbuser dbpass);
    $dbi = CPAN::Testers::Common::DBUtils->new(%opts);
    die "Cannot configure $db database\n" unless($dbi);

    if(defined $options{from} && (!$options{from} || $options{from} !~ /^\d{4}\-\d{2}\-\d{2}T\d{2}:\d{2}:\d{2}Z$/)) {
        help(1,"invalid 'from' format");
    }
    if(defined $options{to} && (!$options{to} || $options{to} !~ /^\d{4}\-\d{2}\-\d{2}T\d{2}:\d{2}:\d{2}Z$/)) {
        help(1,"invalid 'to' format");
    }
}

sub help {
    my ($full,$mess) = @_;

    print "\n$mess\n\n" if($mess);

    if($full) {
        print <<HERE;

Usage: $0
     --config=<file>                  - configuration file

    [--from|-f=CCYY-MM-DDThh:mm:ssZ]  - from date
    [--to  |-t=CCYY-MM-DDThh:mm:ssZ]  - to date

    [--help|-h]                       - this screen

HERE

    }

    print "$0 v$VERSION\n";
    exit(0);
}

__END__

