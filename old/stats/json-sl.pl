#!/usr/bin/perl

use strict;
use warnings;

use JSON::SL;
use IO::File;

my $p = JSON::SL->new;
my ($store1,$store2);

#look for everthing past the first level (i.e. everything in the array)
$p->set_jsonpointer(["/^"]);

local $/ = \4096; #read only 4k at a time
my $fh = IO::File->new('cpanstats.json','r');
while (my $buf = <$fh>) {
print "======\n$buf\n-----\n";
print "found unexpected character ($1)\n" if($buf =~ /([^\w:\-"\s\[\]\{\},.]+)/);

    $p->feed($buf); #parse what you can
    #fetch anything that completed the parse and matches the JSON Pointer
    while (my $obj = $p->fetch) {
        for(qw(testers lastid)) {
            next unless $obj->{Value}{$_};
print "found $_\n";
            $store1->{$_} = $obj->{Value}{$_};
        }
        for(qw(stats dists fails perls pass platform osys osname build counts count xrefs xlast)) {
            next unless $obj->{Value}{$_};
print "found $_\n";
            $store2->{$_} = $obj->{Value}{$_};
        }
    }
}

$fh->close;

print "done\n";

