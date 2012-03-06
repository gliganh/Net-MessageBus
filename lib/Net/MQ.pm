package Net::MQ;

use 5.006;
use strict;
use warnings;

=head1 NAME

Net::MQ - Pure Perl simple message queue

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

use base 'Net::MQ::Base';

use Net::MQ::Message;

use IO::Socket::INET;
use IO::Select;
use JSON;

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Net::MQ;

    my $mq = Net::MQ->new(server => '127.0.0.1',
                          group => 'backend',
                          sender => 'machine1');
    
    $mq->subscribe_to_all();
    or
    $mq->subscribe(group => 'test');
    $mq->subscribe(sender => 'test_process_1');
    ...
    
    my @messages = $mq->pending_messages();
    or
    while (my $message = $mq->next_message()) {
        ...
    }

=head1 SUBROUTINES/METHODS

=head2 new

    Creates a new New::MQ object

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
                logger         => $params{logger} || Net::MQ::Base::create_default_logger(),
                group          => $params{group},
                sender         => $params{sender},
                username       => $params{username},
                password       => $params{password},
                msgqueue       => [],
                };
    
    bless $self, __PACKAGE__;
    
    $self->connect_to_server();
    
    return $self;
}

=head2 connect_to_server

   Creates a connection to the Net::MQ server 

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
								) || die "Cannot connect to Net::MQ server";
    
    $self->{server_sel} = IO::Select->new($self->{server_socket});
    
    $self->authenticate() || die "Authentication failed";
}

=head2 send

    Send a new messge to the message queue
    
    Usage :
    
    $mq->send( $message );
    or
    $mq->send( type => 'alert', payload => { a => 1, b => 2 }  );

=cut

sub send {
    my $self = shift;
    
    my $message;
    
    if (ref($_[0]) eq "Net::MQ::Message") {
        $message = $_[0];
    }
    elsif (ref($_[0]) eq "HASH") {
        $message = Net::MQ::Message->new({ sender => $self->{sender},
                                           group  => $self->{group},
                                           %{$_[0]},
                                         });
    }
    else {
        $message = Net::MQ::Message->new({ sender => $self->{sender},
                                           group  => $self->{group},
                                          @_,
                                         });
    }
    
    return $self->send_to_server(message => $message);
}


=head2 send_to_server

    Sends the given message to the server

=cut
sub send_to_server {
    my $self = shift;
    my ($type,$object) = @_;
    
    if (ref($object) eq "Net::MQ::Message") {
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

    Sends a authenication request to the server
    
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

    Reads all the messages received from the server and adds the to the message list

=cut
sub read_server_messages {
    my $self = shift;
    
    my @ready;
    
    local $/ = "\n";
     
    while ( @ready = $self->{server_sel}->can_read(0.01) ) {   
    
        foreach my $fh (@ready) {
            my $text = readline $fh;
            chomp $text;
            
            my $data = from_json($text);
            
            if (defined $data->{type} && $data->{type} eq 'message') {
                push @{$self->{msgqueue}}, Net::MQ::Message->new($data->{payload});
            }
            else {
                $self->{response} = $data;
            }
        }
        
    }
}

=head2 get_next_message

    Returns the message in received from the server
    
=cut
sub get_next_message {
    my $self = shift;
    
    $self->read_server_messages();
    
    return shift @{$self->{msgqueue}};
}


=head2 get_messages

    Returns all the messages received until now from the server
    
=cut
sub get_messages {
    my $self = shift;
    
    my @messages = @{$self->{msgqueue}};
    $self->{msgqueue} = [];
    
    return @messages;
}


=head1 AUTHOR

Horea Gligan, C<< <horea at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-mq at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-MQ>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::MQ


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-MQ>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-MQ>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-MQ>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-MQ/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Horea Gligan.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Net::MQ
