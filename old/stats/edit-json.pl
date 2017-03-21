#!/usr/bin/perl -w
use strict;

use IO::File;

for my $file (@ARGV) {
    my $fh = IO::File->new($file,'r') or return;
    local $/ = undef;
    my $json = <$fh>;
    $fh->close;

    $json =~ s/\}/}\n/gs;
    print "$json";
}

