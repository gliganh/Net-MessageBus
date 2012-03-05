#!perl

use 5.006;
use strict;
use warnings;
use Test::More tests => 5;

use Net::MQ::Server;

my $mq_server = Net::MQ::Server->new();

isa_ok($mq_server,"Net::MQ::Server");

ok($mq_server->daemon(),'Server started');

ok($mq_server->is_running(),'Server is running');

ok($mq_server->stop(),'Stop command worked');

ok(! $mq_server->is_running(),'Server is not running anymore');