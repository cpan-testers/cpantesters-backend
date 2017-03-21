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

my %options;

my $select = 'SELECT id,osname,dist,version FROM cpanstats WHERE id >= ?';
my $update = 'UPDATE cpanstats SET osname=? WHERE id=?';

#----------------------------------------------------------------------------
# Progam

init_options();
process();

# -------------------------------------
# Subroutines

sub process {
    my $iterator = $options{CPANSTATS}->iterator('hash',$select,$options{id});
    while(my $row = $iterator->()) {
        next    unless($row->{osname});

        next    if($options{OSNAMES}{ $row->{osname} } && $options{OSNAMES}{ $row->{osname} } eq $row->{osname});

        if(my $osname = $options{OSNAMES}{ lc $row->{osname} }) {
            update($osname, $row);
        } elsif(my $osname = $options{OSTITLES}{ $row->{osname} }) {
            update($osname, $row);
        } else {
            print "UNKNOWN: $row->{id},$row->{osname},$row->{dist},$row->{version}\n";
        }
    }
}

sub update {
    my ($osname,$row) = @_;

    $options{CPANSTATS}->do_query($update,$osname,$row->{id});
    $options{LITESTATS}->do_query($update,$osname,$row->{id});

    my $author = _get_author($row->{dist},$row->{version});
    $options{CPANSTATS}->do_query("INSERT INTO page_requests (type,name,weight,id) VALUES ('author',?,1,?)",$author,$row->{id})  if($author);
    $options{CPANSTATS}->do_query("INSERT INTO page_requests (type,name,weight,id) VALUES ('distro',?,1,?)",$row->{dist},$row->{id});

    print "FIXED: $row->{id},$osname,$row->{dist},$row->{version} was => $row->{osname}\n";
}

sub init_options {
    GetOptions( \%options,
        'config|c=s',
        'id=s',
        'help|h',
        'version|v'
    ) or help(1);

    help(1) if($options{help});
    help(0) if($options{version});

    help(1) unless($options{id});

    # load configuration
    my $cfg = Config::IniFiles->new( -file => $options{config} );

    # configure databases
    for my $db (qw(CPANSTATS LITESTATS)) {
        die "No configuration for $db database\n"   unless($cfg->SectionExists($db));
        my %opts = map {$_ => ($cfg->val($db,$_)||undef);} qw(driver database dbfile dbhost dbport dbuser dbpass);
        $options{$db} = CPAN::Testers::Common::DBUtils->new(%opts);
        die "Cannot configure $db database\n" unless($options{$db});
        $options{$db}->{'mysql_enable_utf8'} = 1 if($opts{driver} =~ /mysql/i);
    }

    load_authors();
    load_osnames($cfg);
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

sub load_authors {
    my @rows = $options{CPANSTATS}->get_query('hash','SELECT author,dist,version FROM ixlatest');
    for my $row (@rows) {
        $options{author}{$row->{dist}}{$row->{version}} = $row->{author};
    }
}

sub _get_author {
    my ($dist,$vers) = @_;
    my $author = $options{author}{$dist}{$vers} || '';
    return $author;
}

sub load_osnames {
    my $cfg = shift;

    # build OS names map
    my @osnames  = $options{CPANSTATS}->get_query('hash','SELECT osname,ostitle FROM osname');
    my %osnames  = map {lc $_->{osname} => lc $_->{osname}} @osnames;
    my %ostitles = map {  $_->{ostitle} => lc $_->{osname}} @osnames;

    $options{OSNAMES}  = \%osnames;
    $options{OSTITLES} = \%ostitles;

    return unless($cfg);

    if($cfg->SectionExists('OSNAMES')) {
        for my $param ($cfg->Parameters('OSNAMES')) {
            $options{OSNAMES}{lc $param} ||= lc $cfg->val('OSNAMES',$param);
        }
    }
}

__END__

