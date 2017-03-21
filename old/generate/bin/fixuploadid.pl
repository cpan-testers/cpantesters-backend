#!/usr/bin/perl -w
use strict;

my $VERSION = '0.01';
$|++;

#----------------------------------------------------------------------------
# Library Modules

use Config::IniFiles;
use CPAN::Testers::Common::DBUtils;
use Getopt::Long;

#----------------------------------------------------------------------------
# Variables

my (%options,%uploads);

my %sql = (
    'uploads'           => 'SELECT uploadid,dist,version FROM uploads ORDER BY uploadid',

    'count_cpanstats'   => 'SELECT count(*) FROM cpanstats       WHERE uploadid=0',
    'count_release'     => 'SELECT count(*) FROM release_data    WHERE uploadid=0',
    'count_summary'     => 'SELECT count(*) FROM release_summary WHERE uploadid=0',
    'count_latest'      => 'SELECT count(*) FROM ixlatest        WHERE uploadid=0',

    'cpanstats'         => 'UPDATE cpanstats         SET uploadid=? WHERE dist=? AND version=?',
    'release'           => 'UPDATE release_data      SET uploadid=? WHERE dist=? AND version=?',
    'summary'           => 'UPDATE release_summary   SET uploadid=? WHERE dist=? AND version=?',
    'latest'            => 'UPDATE ixlatest          SET uploadid=? WHERE dist=? AND version=?',
);

#----------------------------------------------------------------------------
# Progam

init_options();
process();

# -------------------------------------
# Subroutines

sub process {
    my @rows = $options{CPANSTATS}->get_query('hash',$sql{uploads});
    for my $row (@rows) {
        print "$row->{uploadid},$row->{dist},$row->{version}\n";
        $uploads{$row->{dist}}{$row->{version}} = $row->{uploadid};

        #$options{CPANSTATS}->do_query($sql{cpanstats},$row->{uploadid},$row->{dist},$row->{version});
        $options{CPANSTATS}->do_query($sql{release},  $row->{uploadid},$row->{dist},$row->{version});
        #$options{CPANSTATS}->do_query($sql{summary},  $row->{uploadid},$row->{dist},$row->{version});
        #$options{CPANSTATS}->do_query($sql{latest},   $row->{uploadid},$row->{dist},$row->{version});
    }

    @rows = $options{CPANSTATS}->get_query('array',$sql{count_cpanstats});
    print "END: cpanstats = " . ($rows[0][0]||'done') . "\n";
    @rows = $options{CPANSTATS}->get_query('array',$sql{count_release});
    print "END: release_data = " . ($rows[0][0]||'done') . "\n";
    @rows = $options{CPANSTATS}->get_query('array',$sql{count_summary});
    print "END: release_summary = " . ($rows[0][0]||'done') . "\n";
    @rows = $options{CPANSTATS}->get_query('array',$sql{count_latest});
    print "END: ixlatest = " . ($rows[0][0]||'done') . "\n";
}

sub init_options {
    GetOptions( \%options,
        'config|c=s',
        'help|h',
        'version|v'
    ) or help(1);

    help(1) if($options{help});
    help(0) if($options{version});

    # load configuration
    my $cfg = Config::IniFiles->new( -file => $options{config} );

    # configure databases
    for my $db (qw(CPANSTATS)) {
        die "No configuration for $db database\n"   unless($cfg->SectionExists($db));
        my %opts = map {$_ => ($cfg->val($db,$_)||undef);} qw(driver database dbfile dbhost dbport dbuser dbpass);
        $options{$db} = CPAN::Testers::Common::DBUtils->new(%opts);
        die "Cannot configure $db database\n" unless($options{$db});
        $options{$db}->{'mysql_enable_utf8'} = 1 if($opts{driver} =~ /mysql/i);
    }
}

sub help {
    my $full = shift;

    if($full) {
        print <<HERE;

Usage: $0 [-c=<file> -id=<id>] [-h] [-v]

  -c=<file>      configuration file
  -id=<id>       id to start from
  -h             this help screen
  -v             program version

HERE

    }

    print "$0 v$VERSION\n";
    exit(0);
}

__END__

