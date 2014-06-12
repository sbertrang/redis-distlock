
use strict;
use warnings;

use Test::More;

use_ok( "Redis::DistLock" );


# version not recent enough
ok( ! eval {
    Redis::DistLock->new(
        servers => [ bless( { version => "1.2.3" }, "My::Redis" ) ]
    );
}, "version check fail" );

ok( eval {
    Redis::DistLock->new(
        servers => [ bless( { version => "1.2.3" }, "My::Redis" ) ],
        version_check => 0,
    );
}, "do no version check" );


# exact version match
ok( Redis::DistLock->new(
        servers => [ bless( { version => "2.6.12" }, "My::Redis" ) ],
), "version match" );

ok( Redis::DistLock->new(
        servers => [ bless( { version => "2.6.12" }, "My::Redis" ) ],
        version_check => 0,
), "version match without check" );


# higher version
ok( Redis::DistLock->new(
        servers => [ bless( { version => "12.34.56" }, "My::Redis" ) ],
), "version way " );

ok( Redis::DistLock->new(
        servers => [ bless( { version => "12.34.56" }, "My::Redis" ) ],
        version_check => 0,
), "version match without check" );


done_testing();

package My::Redis;

use strict;
use warnings;

sub info {
    return { redis_version => $_[0]{version} };
}

sub script_load {
    return Redis::DistLock::RELEASE_SHA1();
}

1;

# vim: ts=4 sw=4 et:
