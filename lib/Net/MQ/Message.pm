package Net::MQ::Message;

use 5.006;
use strict;
use warnings;

=head1 NAME

Net::MQ::Message - Pure Perl generic message queue

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

use base qw(Class::Accessor);

__PACKAGE__->mk_ro_accessors(qw(type group sender payload));


=head1 SYNOPSIS

This module implements a pure perl message queue that aloows

Perhaps a little code snippet.

    use Net::MQ::Message;

    my $foo = Net::MQ::Message->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 new

    Creates a new Net::MQ::Message object

=cut

sub new {
    my $class = shift;
    my %params = %{shift()};
    
    my $self = __PACKAGE__->SUPER::new({%params});
    
    return $self;
}

=head2 serialize

=cut

sub serialize {
    my $self = shift;
    
    return {
            sender => $self->sender(),
            group  => $self->group(),
            type   => $self->type(),
            payload => $self->payload()
           };
}

=head1 AUTHOR

Horea Gligan, C<< <horea at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-mq at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-MQ>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::MQ::Message


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

1; # End of Net::MQ::Message
