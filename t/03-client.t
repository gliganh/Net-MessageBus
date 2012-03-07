#!perl -T

use 5.006;
use strict;
use warnings;
use Test::More tests => 12;

use Net::MessageBus;
use Net::MessageBus::Server;

my $server = Net::MessageBus::Server->new();
$server->daemon();

ok($server->is_running(),'Server running');

{ #actual client tests

my $MessageBus = Net::MessageBus->new(sender => 'test',group => 'test_group');

isa_ok($MessageBus,"Net::MessageBus");

ok($MessageBus->send(type => 123, payload => 'test message'), 'Message 1 sent');

my @messages = $MessageBus->pending_messages();

is_deeply(\@messages, [], 'no messages received yet');

}

{ #send / receive tests (sender subscription)
 
 my $MessageBus1 = Net::MessageBus->new(sender => 'test1',group => 'test_group');
 my $MessageBus2 = Net::MessageBus->new(sender => 'test2',group => 'test_group');
 
 $MessageBus2->subscribe(sender => 'test1');
 
 ok($MessageBus1->send(type => 'test',payload => 123),'Message sent');
 
 my $message; my $count = 5;
 while (! ($message = $MessageBus2->next_message()) && $count-- ) {
    sleep 1;
 }
 
 isa_ok($message,'Net::MessageBus::Message');
 is($message->type,'test','Message type ok');
 is($message->payload,123,'Message payload ok');
 
}


{ #send / receive tests (group subscription)
 
 my $MessageBus1 = Net::MessageBus->new(sender => 'test1',group => 'test_group');
 my $MessageBus2 = Net::MessageBus->new(sender => 'test2',group => 'test_group');
 
 $MessageBus2->subscribe(sender => 'test1');
 
 $MessageBus1->send(type => 'test',payload => 123);
 
 my $message; my $count = 5;
 while (! ($message = $MessageBus2->next_message()) && $count-- ) {
    sleep 1;
 }
 
 isa_ok($message,'Net::MessageBus::Message');
 is($message->type,'test','Message type ok');
 is($message->payload,123,'Message payload ok');
 
}


$server->stop();

ok(! $server->is_running(),'Server stopped');

