#!perl -T

use Test::More tests => 4;

BEGIN {
    use_ok( 'Net::MQ::Base' )   || print "Bail out!\n";
    use_ok( 'Net::MQ' )         || print "Bail out!\n";
    use_ok( 'Net::MQ::Server' ) || print "Bail out!\n";
    use_ok( 'Net::MQ::Message' ) || print "Bail out!\n";
}

diag( "Testing Net::MQ $Net::MQ::VERSION, Perl $], $^X" );
