package Net::MessageBus;

use 5.006;
use strict;
use warnings;

=head1 NAME

Net::MessageBus - Pure Perl simple message bus

=head1 VERSION

Version 0.03

=cut

our $VERSION = '0.03';

use base 'Net::MessageBus::Base';

use Net::MessageBus::Message;

use IO::Socket::INET;
use IO::Select;
use JSON;

$| = 1;

=head1 SYNOPSIS

This module implements the client side of the Message Bus.

    use Net::MessageBus;
    my $MessageBus = Net::MessageBus->new(
                        server => '127.0.0.1',
                        group => 'backend',
                        sender => 'machine1',
                        username => 'user',
                        password => 'password',
                        logger  => $logger_object,
                    );

On initialization the client authenticates with the Net::MessageBus::Server
after which it can start pushing messages to the bus.

In order to receive any messages from the bus the client must subscribe to :
    - one or more groups
    - one or more senders
    - all messages
    
    #each can be called multiple times
    $MessageBus->subscribe(group => 'test');
    $MessageBus->subscribe(sender => 'test_process_1');
    
    or
    
    $MessageBus->subscribe_to_all();
    
The client can unsubscribe at any time by calling the C<unsubscribe> method

    $MessageBus->unsubscribe();
    
    
To retrive the messages received from the bus, the client can call one of this
methods :

    my @messages = $MessageBus->pending_messages();
    
    or
    
    my $message = $MessageBus->next_message();
    

=head1 EXAMPLE

    use Net::MessageBus;

    my $MessageBus = Net::MessageBus->new(server => '127.0.0.1',
                          group => 'backend',
                          sender => 'machine1');
    
    $MessageBus->subscribe_to_all();
    or
    $MessageBus->subscribe(group => 'test');
    $MessageBus->subscribe(sender => 'test_process_1');
    ...
    
    my @messages = $MessageBus->pending_messages();
    or
    while (my $message = $MessageBus->next_message()) {
        print $message->type();
    }

=head1 SUBROUTINES/METHODS

=head2 new

    Creates a new New::MessageBus object
    
    B<Arguments>

=over 10

=item * server = The ip address of the server    

=item * port = The port on which the server is listening for connections

=item * group =  The group to which this client belogs to

=item * sender = A name for the current client

=item * username = User name that will be sent to the server for authentication

=item * password = The password that will be sent to the server for authentication

=item * logger = A object on which we can call the fallowing methods C<debug,info,warn,error>

=back

    B<Example>

        my $MessageBus = Net::MessageBus->new(
                            server => '127.0.0.1',
                            group => 'backend',
                            sender => 'machine1',
                            username => 'user',
                            password => 'password',
                            logger  => $logger_object,
                        );    

=cut
sub new {
    my $class = shift;
    
    my %params;
    if ((ref($_[0]) || '') eq "HASH") {
        %params = %{$_[0]};
    }
    else {
        %params = @_;
    }
    
    my $self = {
                server_address => $params{server} || '127.0.0.1',
                server_port    => $params{port} || '4500',
                logger         => $params{logger} || Net::MessageBus::Base::create_default_logger(),
                group          => $params{group},
                sender         => $params{sender},
                username       => $params{username},
                password       => $params{password},
                msgqueue       => [],
                buffer         => '',
                };
    
    bless $self, __PACKAGE__;
    
    $self->connect_to_server();
    
    return $self;
}


=head2 subscribe

    Subscribes the current Net::MessageBus client to the messages from the
    specified category. It can be called multiple times
    
    B<Example> :
    
        $MessageBus->subscribe(group => 'test');
        or 
        $MessageBus->subscribe(sender => 'test_process_1');
    
=cut
sub subscribe {
    my $self = shift;
    
    return $self->send_to_server('subscribe',{ @_ } );
}


=head2 send

    Send a new messge to the message queue.
    It has two forms in which it can be called :
        1. With a Net::MessageBus::Message object as argument
        2. With a hash ref containing the fallowing two keys :
            - type = The message type
            - payload = The actual information we want to send with the message.
                        It can be a scalar, array ref or hash ref and it cannot
                        contain any objects
    
    B<Example> :
    
        $MessageBus->send( $message ); #message must be a Net::MessageBus::Message object
        or
        $MessageBus->send( type => 'alert', payload => { a => 1, b => 2 }  );

=cut

sub send {
    my $self = shift;
    
    my $message;
    
    if (ref($_[0]) eq "Net::MessageBus::Message") {
        $message = $_[0];
    }
    elsif (ref($_[0]) eq "HASH") {
        $message = Net::MessageBus::Message->new({ sender => $self->{sender},
                                           group  => $self->{group},
                                           %{$_[0]},
                                         });
    }
    else {
        $message = Net::MessageBus::Message->new({ sender => $self->{sender},
                                           group  => $self->{group},
                                          @_,
                                         });
    }
    
    return $self->send_to_server(message => $message);
}


=head2 next_message

    Returns the next message from the queue of messages we received from the
    server. The message is a Net::MessageBus::Message object.
    
=cut
sub next_message {
    my $self = shift;
    
    $self->read_server_messages();
    
    return shift @{$self->{msgqueue}};
}


=head2 pending_messages

    Returns all the messages received until now from the server. Each message is
    a Net::MessageBus::Message object.
    
=cut
sub pending_messages {
    my $self = shift;
    
    $self->read_server_messages();
    
    my @messages = @{$self->{msgqueue}};
    $self->{msgqueue} = [];
    
    return @messages;
}


=head1 Private methods

B<This methods are for internal use and should not be called manually>

=head2 connect_to_server

   Creates a connection to the Net::MessageBus server and authenticates the user

=cut

sub connect_to_server {
    my $self = shift;
    
    $self->{server_socket} = IO::Socket::INET->new(
                                PeerHost => $self->{server_address},
                                PeerPort => $self->{server_port},
                                Proto    => 'tcp',
								Timeout  => 1,
	                            ReuseAddr => 1,
                                Blocking  => 1,
								) || die "Cannot connect to Net::MessageBus server";
    
    $self->{server_sel} = IO::Select->new($self->{server_socket});
    
    $self->authenticate() || die "Authentication failed";
}



=head2 send_to_server

    Handles the actual comunication with the server

=cut
sub send_to_server {
    my $self = shift;
    my ($type,$object) = @_;
    
    if (ref($object) eq "Net::MessageBus::Message") {
        $object = $object->serialize();
    }
    
    local $\ = "\n";
    local $/ = "\n";
    
    my $socket = $self->{server_socket};
    
    eval {
        print $socket to_json( {type => $type, payload => $object} );
    };
    
    if ($@) {
        $self->logger->error("Message could not be sent! : $@");
        return 0;
    }
    
    my $response = $self->get_response();
    
    if (! $response->{status}) {
        $self->logger->error('Error received from server: '.$response->{status_message});
        return 0;
    }
    
    return 1;
}


=head2 authenticate

    Sends a authenication request to the server and waits for the response
    
=cut
sub authenticate {
    my $self = shift;
    
    return $self->send_to_server('authenticate',
                                    {
                                        username => $self->{username},
                                        password => $self->{password},
                                    }
                                 );
}

=head2 get_response

    Returns the response received from the server for the last request

=cut
sub get_response {
    my $self = shift;
    
    while (! defined $self->{response}) {
        $self->read_server_messages();
    }
    
    return delete $self->{response};
}


=head2 read_server_messages

    Reads all the messages received from the server and adds the to the internal
    message queue

=cut
sub read_server_messages {
    my $self = shift;
    
    local $/ = "\n";
    local $\ = "\n";
    
    while ( 1 ) {
        
        my @ready = $self->{server_sel}->can_read(0.01);
        last unless scalar(@ready);
        
        my $buffer;
        sysread($ready[0],$buffer,8192);
        
        $self->{buffer} .= $buffer;
        
        while ( $self->{buffer} =~ s/(.*?\n)// ) {
        
            my $text = $1;

            chomp $text;
            
            my $data = from_json($text);
        
            if (defined $data->{type} && $data->{type} eq 'message') {
                push @{$self->{msgqueue}}, Net::MessageBus::Message->new($data->{payload});
            }
            else {
                $self->{response} = $data;
            }
        }
        
    }
}




=head1 AUTHOR

Horea Gligan, C<< <gliganh at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-MessageBus at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-MessageBus>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::MessageBus


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-MessageBus>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-MessageBus>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-MessageBus>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-MessageBus/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Horea Gligan.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Net::MessageBus
