#!/usr/bin/perl

use strict;
use Test::More tests => 51;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;

my $server = new_memcached();
my $sock = $server->sock;


## Output looks like this:
##
## STAT pid 16293
## STAT uptime 7
## STAT time 1174419597
## STAT version 1.2.1
## STAT pointer_size 32
## STAT rusage_user 0.012998
## STAT rusage_system 0.119981
## STAT curr_items 0
## STAT total_items 0
## STAT bytes 0
## STAT curr_connections 1
## STAT total_connections 2
## STAT connection_structures 2
## STAT cmd_get 0
## STAT cmd_set 0
## STAT get_hits 0
## STAT get_misses 0
## STAT delete_misses 0
## STAT delete_hits 4
## STAT incr_misses 1
## STAT incr_hits 2
## STAT decr_misses 1
## STAT decr_hits 1
## STAT evictions 0
## STAT bytes_read 7
## STAT bytes_written 0
## STAT limit_maxbytes 67108864

my $stats = mem_stats($sock);

# Test number of keys
is(scalar(keys(%$stats)), 28, "28 stats values");

# Test initial state
foreach my $key (qw(curr_items total_items bytes cmd_get cmd_set get_hits evictions get_misses bytes_written delete_hits delete_misses incr_hits incr_misses decr_hits decr_misses)) {
    is($stats->{$key}, 0, "initial $key is zero");
}

# Do some operations

print $sock "set foo 0 0 6\r\nfooval\r\n";
is(scalar <$sock>, "STORED\r\n", "stored foo");
mem_get_is($sock, "foo", "fooval");

my $stats = mem_stats($sock);

foreach my $key (qw(total_items curr_items cmd_get cmd_set get_hits)) {
    is($stats->{$key}, 1, "after one set/one get $key is 1");
}

my $cache_dump = mem_stats($sock, " cachedump 1 100");
ok(defined $cache_dump->{'foo'}, "got foo from cachedump");

print $sock "delete foo\r\n";
is(scalar <$sock>, "DELETED\r\n", "deleted foo");

my $stats = mem_stats($sock);
is($stats->{delete_hits}, 1);
is($stats->{delete_misses}, 0);

print $sock "delete foo\r\n";
is(scalar <$sock>, "NOT_FOUND\r\n", "shouldn't delete foo again");

my $stats = mem_stats($sock);
is($stats->{delete_hits}, 1);
is($stats->{delete_misses}, 1);

# incr stats

sub check_incr_stats {
    my ($ih, $im, $dh, $dm) = @_;
    my $stats = mem_stats($sock);

    is($stats->{incr_hits}, $ih);
    is($stats->{incr_misses}, $im);
    is($stats->{decr_hits}, $dh);
    is($stats->{decr_misses}, $dm);
}

print $sock "incr i 1\r\n";
is(scalar <$sock>, "NOT_FOUND\r\n", "shouldn't incr a missing thing");
check_incr_stats(0, 1, 0, 0);

print $sock "decr d 1\r\n";
is(scalar <$sock>, "NOT_FOUND\r\n", "shouldn't decr a missing thing");
check_incr_stats(0, 1, 0, 1);

print $sock "set n 0 0 1\r\n0\r\n";
is(scalar <$sock>, "STORED\r\n", "stored n");

print $sock "incr n 3\r\n";
is(scalar <$sock>, "3\r\n", "incr works");
check_incr_stats(1, 1, 0, 1);

print $sock "decr n 1\r\n";
is(scalar <$sock>, "2\r\n", "decr works");
check_incr_stats(1, 1, 1, 1);


