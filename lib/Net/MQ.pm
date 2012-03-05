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
use IO::Socket::INET;
use IO::Select;

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Net::MQ;

    my $mq = Net::MQ->new(server => '127.0.0.1');
    
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
                username       => $params{username},
                password       => $params{password},
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
}

=head2 function2

=cut

sub send {
    my $self = shift;
    
    my $message;
    
    if (ref($_[0]) eq "Net::MQ::Message") {
        $message = $_[0];
    }
    elsif (ref($_[0]) eq "HASH") {
        $message = Net::MQ::Message->new($_[0]);
    }
    else {
        $message = Net::MQ::Message->new(\%{@_});
    }
    
    return $self->send_to_server($message);
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
