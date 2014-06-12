
use strict;
use warnings;

use Test::More;

BEGIN {
    plan skip_all => "needs TEST_SERVER variable for server testing"
        unless $ENV{TEST_SERVER};
}

use_ok( "Redis::DistLock" );

my $rd = Redis::DistLock->new(
    servers => [ split( m!,!, $ENV{TEST_SERVER} ) ],
);

# no / wrong content
$rd->release( undef );
$rd->release( 42 );
$rd->release( {} );
$rd->release( { non => "sense" } );

# invalid type
ok( ! eval { $rd->release( [] ) }, "invalid lock data type" );

done_testing();

# vim: ts=4 sw=4 et:
