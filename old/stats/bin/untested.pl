#!/usr/bin/perl -w
use strict;

$|++;

my $VERSION = '0.01';

# -------------------------------------
# Library Modules

use lib qw(./lib ../lib);

use Config::IniFiles;
use CPAN::Testers::Common::DBUtils;
use DBI;
use IO::File;
use Getopt::Long;

# -------------------------------------
# Variables

my ($dbi,%options);
my %phrasebook = (
    'OSNAMES'   => q{   SELECT * FROM osname},
    'DISTS'     => q{   SELECT * FROM ixlatest ORDER BY released DESC},
    'LIST'      => q{   SELECT osname,count(*) AS count
                        FROM cpanstats
                        WHERE dist=? AND version=? 
                        GROUP BY osname},
);

# -------------------------------------
# Program

##### INITIALISE #####

init_options();


##### MAIN #####

check_distros();

# -------------------------------------
# Subroutines

sub check_distros {
    my (%osnames,%osnew,%dists);
    my @rows = $dbi->get_query('hash',$phrasebook{OSNAMES});
    for my $row (@rows) {
        $osnames{$row->{osname}} = 1;
    }

    @rows = $dbi->get_query('hash',$phrasebook{DISTS});
    for my $row (@rows) {
        next if($dists{$row->{dist}});
        for my $osname (keys %osnames) {
            $dists{$row->{dist}}{$row->{version}}{$osname} = 1;
        }
    }

    for my $dist (keys %dists) {
        for my $version (keys %{$dists{$dist}}) {
            @rows = $dbi->get_query('hash',$phrasebook{LIST},$dist,$version);
            for my $row (@rows) {
                delete $dists{$dist}{$version}{$row->{osname}};
            }

            my @osnames = keys %{$dists{$dist}{$version}};
            if(@osnames) {
                print "$dist,$version,$_,NO REPORTS\n"  for(@osnames);
            } else {
                print "$dist,$version,FULLY TESTED\n";
            }
        }
    }
}

sub init_options {
    GetOptions( \%options,
        'config=s',
        'verbose|v',
        'help|h'
    );

    _help(1) if($options{help});

    _help(1,"Must specify the configuration file")               unless(   $options{config});
    _help(1,"Configuration file [$options{config}] not found")   unless(-f $options{config});

    # load configuration
    my $cfg = Config::IniFiles->new( -file => $options{config} );

    # configure databases
    my $db = 'CPANSTATS';
    die "No configuration for $db database\n"   unless($cfg->SectionExists($db));
    my %opts = map {$_ => $cfg->val($db,$_);} qw(driver database dbfile dbhost dbport dbuser dbpass);
    $dbi = CPAN::Testers::Common::DBUtils->new(%opts);
    die "Cannot configure $db database\n" unless($dbi);
}

sub _help {
    my ($full,$mess) = @_;

    print "\n$mess\n\n" if($mess);

    if($full) {
        print "\n";
        print "Usage:$0 [--help|h] [--version|v] \\\n";
        print "          --config|c=<file> \n\n";

#              12345678901234567890123456789012345678901234567890123456789012345678901234567890
        print "This program checks untested distributions on specific platforms.\n";

        print "\nFunctional Options:\n";
        print "   --config=<file>           # path/file to configuration file\n";

        print "\nOther Options:\n";
        print "  [--verbose]                # turn on verbose messages\n";
        print "  [--help]                   # this screen\n";

        print "\nFor further information type 'perldoc $0'\n";
    }

    print "$0 v$VERSION\n";
    exit(0);
}


