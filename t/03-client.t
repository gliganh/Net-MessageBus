#!perl -T

use 5.006;
use strict;
use warnings;
use Test::More tests => 622;

use Net::MessageBus;
use Net::MessageBus::Server;

#use Log::Log4perl qw(:easy);
#Log::Log4perl->easy_init($DEBUG);
#my $logger = Log::Log4perl->get_logger;

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


{ #send / receive tests (group subscription) with 100 messages
 
 my $MessageBus1 = Net::MessageBus->new(sender => 'test1',group => 'test_group');
 my $MessageBus2 = Net::MessageBus->new(sender => 'test2',group => 'test_group');
 my $MessageBus3 = Net::MessageBus->new(sender => 'test3',group => 'test_group');
 
 ok($MessageBus2->subscribe(group => 'test_group'),'Subscribed to test group');
 ok($MessageBus3->subscribe(group => 'test_group'),'Subscribed to test group');
 
 
 foreach (1..100) {
    ok($MessageBus1->send(type => "test",payload => $_),"Message $_ sent ok");
 }
 
 sleep 1;
 
 my @messages = $MessageBus2->pending_messages();
 my @messages2 = $MessageBus3->pending_messages();
 
 is(scalar(@messages),100,'Client 2 received 100 messages');
 is(scalar(@messages2),100,'Client 3 received 100 messages');
 
 #my $count = 1;
 #foreach (1..100) {
 #   my $message = $MessageBus2->next_message();
 #   isa_ok($message,'Net::MessageBus::Message',"Message $_");
 #   is($message->payload,$_,"Message $_ in expected order");
 #}
 
}


{ #send / receive tests (group subscription) with 100 messages retrieved 1 by one
 
 my $MessageBus1 = Net::MessageBus->new(sender => 'test1',group => 'test_group');
 my $MessageBus2 = Net::MessageBus->new(sender => 'test2',group => 'test_group');
 my $MessageBus3 = Net::MessageBus->new(sender => 'test3',group => 'test_group');
 
 ok($MessageBus2->subscribe(group => 'test_group'),'Subscribed to test group');
 ok($MessageBus3->subscribe(group => 'test_group'),'Subscribed to test group');
 
 
 foreach (1..100) {
    ok($MessageBus1->send(type => "test",payload => $_),"Message $_ sent ok");
 }
 
 sleep 1;
 
 foreach (1..100) {
    my $message = $MessageBus2->next_message();
    isa_ok($message,'Net::MessageBus::Message',"Client 2 message $_");
    is($message->payload,$_,"client 2 message $_ in expected order");
 }
 
 foreach (1..100) {
    my $message = $MessageBus3->next_message();
    isa_ok($message,'Net::MessageBus::Message',"Client3 message $_");
    is($message->payload,$_,"Client 3 message $_ in expected order");
 }
 
}


{ #send / receive tests (big message)
 
 my $MessageBus1 = Net::MessageBus->new(sender => 'test1',group => 'test_group');
 my $MessageBus2 = Net::MessageBus->new(sender => 'test2',group => 'test_group');
 
 $MessageBus2->subscribe(sender => 'test1');
 
 my $test_data = <<END;
 asdf df 43q
 et
 ăâşţț’„”»«»––
END
 
 ok($MessageBus1->send(type => 'test',payload => $test_data),'Message sent');
 
 my $message; my $count = 5;
 while (! ($message = $MessageBus2->next_message()) && $count-- ) {
    sleep 1;
 }
 
 isa_ok($message,'Net::MessageBus::Message');
 is($message->type,'test','Message type ok');
 is($message->payload,$test_data,'Message payload ok');
 
}

$server->stop();

ok(! $server->is_running(),'Server stopped');

