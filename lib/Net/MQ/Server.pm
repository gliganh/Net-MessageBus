package Net::MQ::Server;

use 5.006;
use strict;
use warnings;

=head1 NAME

Net::MQ::Server - The great new Net::MQ::Server!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

use base qw(Net::MQ::Base);

use JSON;
use IO::Socket::INET;

#handle gracefully the death of child ssh processes
use POSIX ":sys_wait_h";

=head1 SYNOPSIS

This module creates a new Net::MQ server running on the specified address/port

Usage :

    use Net::MQ::Server;

    my $mq_server = Net::MQ::Server->new(
                        address => '127.0.0.1',
                        port    => '15000',
                        logger  => $logger,
                        authenticate => \&authenticate_method,
                    );
                    
    $mq_server->start();
    
    or
    
    $mq_server->daemon() || die "Cannot run NetMQ in background!"
    ...
    $mq_server->stop(); #if started as a daemon.
    

=head1 SUBROUTINES/METHODS

=head2 new

    Creates a new server object.
    It does not automatically start the server, you have to start it using the
    start() method.
    
    Arguments :
        address
            The address on which the server should bind , 127.0.0.1 by dafault
            
        port
            The port on which the server should listen , 4500 by default
            
        logger
            Any object that supports the fallowing methods : debug, info, warn,
            error
            
        authenticate
            A code ref to a method that returns true if the authentication is
            successfull and false otherwise
            Example :
                sub authenticate_method {
                    my ($username, $password) = @_;
                    
                    return 1 if ($username eq "john" && $password eq "1234");
                    return 0;
                }

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
                address => $params{address} || '127.0.0.1',
                port    => $params{port} || '4500',
                logger  => $params{logger} || Net::MQ::Base::create_default_logger(),
                authenticate => $params{autenticate} || sub {return 1},
                };
    
    bless $self, __PACKAGE__;
    
    return $self;
}

=head2 create_server_socket

    Starts the TCP socket that to which the clients will connect

=cut

sub create_server_socket {
    my $self = shift;
    
    my $server_sock= IO::Socket::INET->new(
                                LocalHost => $self->{address},
                                LocalPort => $self->{port},
                                Proto     => 'tcp',
                                Listen    => 10,
                                ReuseAddr => 1,
                                Blocking  => 1,
                    ) || die "Cannot listen on ".$self->{address}.
                              ":".$self->{port}.", Error: $!";
                              
    $self->logger->info("$0  server v$VERSION - Listening on ".
                  $self->{address}.":".$self->{port} );                              
    
    return $server_sock;
    
}

=head2 start

    Starts the server

=cut
sub start {
    my $self = shift;
    
    $self->{server_socket} = $self->create_server_socket();
    
    my $server_sel = IO::Select->new($self->{server_socket});
    
    my $cache = {};
    
    $self->{run} = 1;
    
    while ($self->{run} == 1) {
    
        my @exceptions = $server_sel->has_exception(0);
        foreach my $broken_socket (@exceptions) {
             eval {
                 $server_sel->remove($broken_socket);
                 close($broken_socket);
             };
        }
     
        my @ready = $server_sel->can_read(0.01);
 
        next unless scalar(@ready);
 
        foreach my $fh (@ready) {
            
            if( $fh == $self->{server_socket} ) {
                # Accept the incoming socket.
                my $new = $fh->accept;
                
                next unless $new; #in case the ssl connection failed
                
                my $straddr = $self->get_peer_address($new);
                
                $self->logger->info("Accepted from : $straddr\n");
                
                $server_sel->add($new);
                
            } else {
                # Process socket
                local $\ = "\n";
                my $text =  readline($fh);
                
                my $straddr = 'unknown';
                eval {
                    $straddr = $self->get_peer_address($fh);
                };

                if ($text) {

                    $self->logger->debug("Request from $straddr : '$text'");
                    
                                    
                }
                else {
                   $self->logger->info("Peear $straddr closed connection\n");
                   delete $cache->{$fh} if defined $cache->{$fh};
                   $server_sel->remove($fh);
                   close ($fh);
                }
            }
        }
        
    }
}

=head2 daemon

    Starts the server in background

=cut
sub daemon {
    my $self = shift;
    
    if ( defined $self->{pid} && kill(0,$self->{pid}) ) {
        $self->logger->error('An instance of the server is already running!');
    }
    
    $SIG{CHLD} = sub {
    
        # don't change $! and $? outside handler
        local ( $!, $? );
        
        while ( my $pid = waitpid( -1, WNOHANG ) > 0 ) {
           #Wait for the child processes to exit 
        }
        return 1;
    };
    
    my $pid;
    
    if ( $pid = fork() ) {
        $self->{pid} = $pid;
    }
    else {
        $SIG{INT} = $SIG{HUP} = sub {
                                    $self->{run} = 0;
                                    $self->{server_socket}->close();
                                };
        $self->start();
        exit(0);
    }
    
    return 1;
}

=head2 stop

    Stops a previously started daemon
    
=cut
sub stop {
    my $self = shift;
    
    if (! defined $self->{pid} || ! kill(0,$self->{pid}) ) {
        $self->logger->error('No Net::MQ::Server is running (pid : '.$self->{pid}.')!');
        return 0;
    }
    
    kill 15, $self->{pid};
    
    sleep 1;
        
    if ( kill(0,$self->{pid}) ) {
        $self->logger->error('Failed to stop the Net::MQ::Server (pid : '.$self->{pid}.')! ');
        return 0;
    }
    
    delete $self->{pid};
    
    return 1;
}


=head2 is_running

    Stops a previously started daemon
    
=cut
sub is_running {
    my $self = shift;
    
    if (! defined $self->{pid} || ! kill(0,$self->{pid}) ) {
        return 0;
    }
    
    return 1;
}

=head2 get_peer_address

    Returns the ip address for the given connection
    
=cut    
sub get_peer_address {
    my ($self, $fh) = @_;

    my $sockaddr = getpeername($fh);
    
    my ($port, $iaddr) = sockaddr_in($sockaddr);
    my $straddr = inet_ntoa($iaddr);
    
    return $straddr;
}

=head1 AUTHOR

Horea Gligan, C<< <horea at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-mq at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-MQ>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::MQ::Server


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

1; # End of Net::MQ::Server
