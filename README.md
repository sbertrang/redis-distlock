Redis::DistLock - Distributed lock manager using Redis 

SYNOPSIS 

	use Redis::DistLock; 
	my $rd = Redis::DistLock->new( servers => [qw[ localhost:6379 ]] );
    my $mutex = $rd->lock( "foo", 1000 );
    die( "failed to get a lock" )
        if ! $mutex;
    # ... critical section ...
    $rd->release( $mutex );

DESCRIPTION

    This is an implementation of the Redlock algorithm using Redis for
    distributed lock management.

    NOTE: This needs at least Redis version 2.6.12 which brings adds new
    options to the SET command.

METHODS

    new( ... )
      servers
          Array reference with servers to connect to or Redis objects to use.

      retry_count
          Maximum number of times to try to acquire the lock.

      retry_delay
          Maximum delay between retries in seconds.
  
      version_check
          Flag to check redis server version(s) in the constructor to ensure
          compatibility. Defaults to 1.
  
      lock( $resource, $ttl [ $value ] )
          Acquire the lock for the given resource with the given time to live (in
          seconds) until the lock expires. Without a given value will generate a
          unique identifier.
  
      release( $lock )
         Release the previously acquired lock.

SEE ALSO

    <http://redis.io/topics/distlock>

AUTHORS

    Simon Bertrang, <janus@cpan.org>
    Ryan Bastic, <ryan@bastic.net>

COPYRIGHT AND LICENSE

    Copyright (C) 2014 by Simon Bertrang, Ryan Bastic.

    This library is free software; you can redistribute it and/or modify it
    under the same terms as Perl itself.

