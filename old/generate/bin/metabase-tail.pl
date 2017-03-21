#!/usr/bin/perl -w
use strict;

use WWW::Mechanize;

my @guids;
my $mech = WWW::Mechanize->new();
my $tail = 'http://metabase.cpantesters.org/tail/log.txt';

$mech->get($tail);
if($mech->success()) {
    my $text = $mech->content();

    my @lines = split(/\n/,$text);
    for my $line (@lines) {

# [2012-10-18T06:25:04Z] [Chris Williams (BINGOS)] [pass] [AMBS/Lingua-Identify-CLD-0.05.tar.gz] [i86pc-solaris-thread-multi] [perl-v5.10.1] [8df4b520-18ec-11e2-bdcc-373e3b6b8117] [2012-10-18T06:25:04Z]
        my ($date,$tester,$grade,$distro,$platform,$perl,$guid,$date2)
            = $line =~ /^
                \[ ([\dTZ:-]+)      \] \s+      # date
                \[ ([^\]]+)         \] \s+      # tester
                \[ (\w+)            \] \s+      # grade
                \[ ([^\]]+)         \] \s+      # distro
                \[ ([^\]]+)         \] \s+      # platform
                \[ ([^\]]+)         \] \s+      # perl
                \[ ([\w-]+)         \] \s+      # guid
                \[ ([^\]]+)         \] \s*      # date2
            $/xi;

        if($guid) {
            push @guids, $guid;
            next;
        }

        print STDERR "ERROR: $line\n";
    }

    print "$_\n" for(@guids);
}

