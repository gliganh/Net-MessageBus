#!perl -T

use 5.006;
use strict;
use warnings;
use Test::More tests => 3;

use Net::MQ;
use Net::MQ::Server;

my $server = Net::MQ::Server->new();
$server->daemon();

ok($server->is_running(),'Server running');

{

my $mq = Net::MQ->new();

isa_ok($mq,"Net::MQ");


}

$server->stop();

ok(! $server->is_running(),'Server stopped');