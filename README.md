# NAME

Redis::DistLock - Distributed lock manager using Redis

# SYNOPSIS

    use Redis::DistLock;
    my $rd = Redis::DistLock->new( servers => [qw[ localhost:6379 ]] );
    my $mutex = $rd->lock( "foo", 1000 );
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

    Maximum number of times to try to acquire the lock.

- retry\_delay

    Maximum delay between retries in seconds.

- version\_check

    Flag to check redis server version(s) in the constructor to ensure compatibility.
    Defaults to `1`.

## lock( $resource, $ttl \[ $value \] )

Acquire the lock for the given resource with the given time to live (in seconds)
until the lock expires. Without a given value will generate a unique identifier.

## release( $lock )

Release the previously acquired lock.

# SEE ALSO

[http://redis.io/topics/distlock](http://redis.io/topics/distlock)

# ACKNOWLEDGMENT

This module was originally developed at Booking.com. With approval from
Booking.com, this module was released as open source, for which the author
would like to express his gratitude.

# AUTHOR

Simon Bertrang, <janus@cpan.org>

# COPYRIGHT AND LICENSE

Copyright (C) 2014 by Simon Bertrang

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
