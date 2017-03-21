#!/usr/bin/perl -w
use strict;

# TODO:
# if gaps is bigger than 30mins split

use IO::File;
use Time::Local;
use Time::Piece;

my (%times,@diffs);

my $log = 'logs/cpanstats.log';
my $fh = IO::File->new($log,'r') or die "Cannot open file [$log]: $!\n";
while(<$fh>) {
    next if(/^\s*$/ || /^#/);

    # GUID [82d7d16c-7be5-11e1-9d6f-f6dbfa7543f5].. time [2012-04-01T10:29:07Z][2012-04-01T10:29:07Z].. stored.. cached
    next unless(/^GUID \S+ time \[([^\]]+)\]/);
    $times{$1}++;
}
$fh->close;

my @times = sort keys %times;
for my $inx (1 .. $#times) {
    my @t = ($times[$inx-1] =~ /(\d+)\-(\d+)\-(\d+)T(\d+):(\d+):(\d+)Z/);
    $t[1]--;
    my $t1 = timelocal(reverse @t);
    @t = ($times[$inx] =~ /(\d+)\-(\d+)\-(\d+)T(\d+):(\d+):(\d+)Z/);
    $t[1]--;
    my $t2 = timelocal(reverse @t);

    my $d = $t2 - $t1;

    if($d > 60) {
        push @diffs, { from => $t1, to => $t2, diff => $d };
    }
}

my @list;
my $diff = shift @diffs;
for my $item (@diffs) {
    if($diff->{to} == $item->{from}) {
        $diff->{to} = $item->{to};
        $diff->{diff} = $diff->{to} - $diff->{from};
    } else {
        my $t = Time::Piece->strptime($diff->{from},"%s");
        $diff->{fdate} = $t->strftime("%F %T");
        $t = Time::Piece->strptime($diff->{to},"%s");
        $diff->{tdate} = $t->strftime("%F %T");
        push @list, $diff;
        $diff = $item;
    }
}

my $t = Time::Piece->strptime($diff->{from},"%s");
$diff->{fdate} = $t->strftime("%F %T");
$t = Time::Piece->strptime($diff->{to},"%s");
$diff->{tdate} = $t->strftime("%F %T");
push @list, $diff;

for(@list) {
    $_->{fdate} =~ s/ /T/;
    $_->{fdate} .= 'Z';
    $_->{tdate} =~ s/ /T/;
    $_->{tdate} .= 'Z';

    print "$_->{fdate},$_->{tdate}\n";
}

=pod

printf "%s => %s [ %d => %d ] = %d\n",
    $_->{fdate} || '',
    $_->{tdate} || '',
    $_->{from},
    $_->{to},
    $_->{diff}
        for(@list);

=cut


