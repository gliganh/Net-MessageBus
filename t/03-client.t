#!perl -T

use 5.006;
use strict;
use warnings;
use Test::More tests => 4;

use Net::MQ;
use Net::MQ::Server;

my $server = Net::MQ::Server->new();
$server->daemon();

ok($server->is_running(),'Server running');

{ #actual client tests

my $mq = Net::MQ->new(sender => 'test',group => 'test_group');

isa_ok($mq,"Net::MQ");

ok($mq->send(type => 123, payload => 'test message'), 'Message 1 sent');


}

$server->stop();

ok(! $server->is_running(),'Server stopped');

