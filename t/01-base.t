#!perl -T

use 5.006;
use strict;
use warnings;
use Test::More tests => 1;

use Net::MQ::Base;

SKIP: {
    skip('Log::Log4Perl is not installed',1) unless eval('use Log::Log4perl;1');
    
    my $logger = Net::MQ::Base::create_default_logger();
    isa_ok($logger,'Log::Log4perl::Logger','Default logger created ok '. ref($logger));
}