# NAME

Redis::DistLock - Distributed lock manager using Redis

# SYNOPSIS

    use Redis::DistLock;
    my $rd = Redis::DistLock->new( servers => [qw[ localhost:6379 ]] );
    my $mutex = $rd->lock( "foo", 10 );
    die( "failed to get a lock" )
        if ! $mutex;
    # ... critical section ...
    $rd->release( $mutex );

# DESCRIPTION

This is an implementation of the Redlock algorithm using Redis for distributed
lock management.

**NOTE**: This needs at least Redis version 2.6.12 which adds new options
to the `SET` command making this implementation possible.

# METHODS

## new( ... )

- servers

    Array reference with servers to connect to or [Redis](https://metacpan.org/pod/Redis) objects to use.

- retry\_count

    Maximum number of times to try to acquire the lock. Defaults to `3`.

- retry\_delay

    Maximum delay between retries in seconds. Defaults to `0.2`.

- version\_check

    Flag to check redis server version(s) in the constructor to ensure compatibility.
    Defaults to `1`.

- logger

    Optional subroutine that will be called with errors as parameter, should any occur.
    By default, errors are currently just warnings. To disable pass `undef`.

- auto\_release

    Flag to enable automatic release of all locks when the lock manager instance
    goes out of scope. Defaults to `0`.

    **CAVEAT**: Ctrl-C'ing a running Perl script does not call DESTROY().
    This means you will have to wait for Redis to expire your locks for you if the script is killed manually.
    Even if you do implement a signal handler, it can be quite unreliable in Perl and does not guarantee
    the timeliness of your locks being released.

## lock( $resource, $ttl \[ $value \] )

Acquire the lock for the resource with the given time to live (in seconds)
until the lock expires. Without a value will generate a unique identifier.

## release( $lock )

Release the previously acquired lock.

# SEE ALSO

[http://redis.io/topics/distlock](http://redis.io/topics/distlock)

# DISCLAIMER

This code implements an algorithm which is currently a proposal, it was not
formally analyzed. Make sure to understand how it works before using it in
production environments.

# ACKNOWLEDGMENT

This module was originally developed at Booking.com. With approval from
Booking.com, this module was released as open source, for which the author
would like to express his gratitude.

# AUTHORS

- Simon Bertrang, <janus@cpan.org>
- Ryan Bastic, <ryan@bastic.net>

# COPYRIGHT AND LICENSE

Copyright (C) 2014 by Simon Bertrang

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
