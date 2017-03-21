#!/usr/bin/perl -w
use strict;

use JSON::XS;
use IO::File;

for my $file (@ARGV) {
    print "file=$file\n";

    my $fh = IO::File->new($file,'r') or return;
    local $/ = undef;
    my $json = <$fh>;
    $fh->close;

#    $json =~ s/\}/}\n/gs;
#    print "json=$json";

    eval {
        my $data = decode_json($json);
    };

    print "result=$@\n";
}

