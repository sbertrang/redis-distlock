package Redis::DistLock;

use strict;
use warnings;

our $VERSION = '0.03';

use Digest::SHA qw( sha1_hex );
use MIME::Base64 qw( encode_base64 );
use Redis;
use Time::HiRes qw( time );

sub VERSION_CHECK()     { 1 }
sub RETRY_COUNT()       { 3 }
sub RETRY_DELAY()       { 0.2 }
sub DRIFT_FACTOR()      { 0.01 }
sub RELEASE_SCRIPT()    { '
if redis.call( "get", KEYS[1] ) == ARGV[1] then
    return redis.call( "del", KEYS[1] )
else
    return 0
end
' }
sub RELEASE_SHA1()      { sha1_hex( RELEASE_SCRIPT ) }

sub LOGGER {
    return sub {
        warn $_[0];
    }
}

sub DESTROY {
    my $self = shift;
    foreach (@{ ($self->{locks} || []) }) {
        $self->release($_);
    }
}

sub new
{
    my $class = shift;
    my %args = @_ == 1 && ref( $_[0] )
             ? %{ $_[0] }
             : @_
    ;

    my $version_check = exists( $args{version_check} )
                      ?         $args{version_check}
                      :               VERSION_CHECK
    ;

    my $logger = exists ( $args{logger} )
                      ?   $args{logger}
                      :         LOGGER

    my @servers;

    for my $server ( @{ $args{servers} } ) {
        my $redis = ref( $server )
                  ? $server
                  : Redis->new( server => $server )
        ;
        push( @servers, $redis );

        if ( $version_check ) {
            my $info = $redis->info();

            die( "FATAL: cannot find the right redis version (needs at least 2.6.12 -- $1, $2, $3)" )
                unless $info &&
                       $info->{redis_version} &&
                       $info->{redis_version} =~ m!\A ([0-9]+) \. ([0-9]+) \. ([0-9]+) \z!x &&
                       (
                         ( $1 >  2 ) ||
                         ( $1 == 2 && $2 >  6 ) ||
                         ( $1 == 2 && $2 == 6 && $3 >= 12 )
                       )
            ;
        }

        # load script on all servers
        my $sha1 = $redis->script_load( RELEASE_SCRIPT );

        # ensure the script is everywhere the same
        if ( $sha1 ne RELEASE_SHA1 ) {
            die( "FATAL: script load results in different checksum!" );
        }
    }

    my $self = bless( {
        servers        => \@servers,
        quorum        => ( @servers > 1 ? int(@servers / 2 + 1) : 1 ),
        retry_count    => $args{retry_count} || RETRY_COUNT,
        retry_delay    => $args{retry_delay} || RETRY_DELAY,
        locks          => [],
        logger         => $logger
    }, $class );

    return $self;
}

sub _get_random_id
{
    encode_base64( join( "", map chr( int( rand() * 256 ) ), 1 .. 24 ), "" );
}

sub lock
{
    my ( $self, $resource, $ttl, $value ) = @_;
    my $retry_count = $self->{retry_count};

    $value = _get_random_id()
        unless defined( $value );

    while ( $retry_count-- > 0 ) {
        my $start = time();
        my $ok = 0;

        for my $redis ( @{ $self->{servers} } ) {
            $ok += eval {
                $redis->set( $resource, $value, "NX", "PX", $ttl ) && 1
            };
            if ($@) {
                $self->{logger}->($@);
            }
        }

        my $drift = $ttl * DRIFT_FACTOR + 0.002;
        my $validity = $ttl - ( time() - $start ) - $drift;

        if ( $ok >= $self->{quorum} && $validity > 0 ) {
            my $l = {
                validity    => $validity,
                resource    => $resource,
                value        => $value,
            };
            push @{ $self->{locks} }, $l;
            return $l;
        }

        select( undef, undef, undef, rand( $self->{retry_delay} ) );
    }

    return undef;
}

sub release
{
    my ( $self, $lock ) = @_;

    return unless ref( $lock ) &&
               exists( $lock->{resource} ) &&
               exists( $lock->{value} )
    ;

    for my $redis ( @{ $self->{servers} } ) {
        $redis->evalsha( RELEASE_SHA1, 1, @$lock{ qw{ resource value } } );
    }
}

1;

__END__

=head1 NAME

Redis::DistLock - Distributed lock manager using Redis

=head1 SYNOPSIS

  use Redis::DistLock;
  my $rd = Redis::DistLock->new( servers => [qw[ localhost:6379 ]] );
  my $mutex = $rd->lock( "foo", 1000 );
  die( "failed to get a lock" )
    if ! $mutex;
  # ... critical section ...
  $rd->release( $mutex );

=head1 DESCRIPTION

This is an implementation of the Redlock algorithm using Redis for distributed
lock management.

B<NOTE>: This needs at least Redis version 2.6.12 which brings adds new options
to the SET command.

=head1 METHODS

=head2 new( ... )

=over 4

=item servers

Array reference with servers to connect to or L<Redis> objects to use.

=item retry_count

Maximum number of times to try to acquire the lock.

=item retry_delay

Maximum delay between retries in seconds.

=item version_check

Flag to check redis server version(s) in the constructor to ensure compatibility. Defaults to C<1>.

=item logger

An optional subroutine that will be called with errors as it's parameter, should and when they occur.
By default, errors are currently just warns.

=back

=head2 lock( $resource, $ttl [ $value ] )

Acquire the lock for the given resource with the given time to live (in seconds)
until the lock expires. Without a given value will generate a unique identifier.

=head2 release( $lock )

Release the previously acquired lock.

=head1 CAVEATS

Ctrl-C'ing a running Perl script does not call DESTROY().
This means you will have to wait for Redis to expire your locks for you if the script is killed manually.
Even if you do implement a signal handler, it can be quite unreliable in Perl and does not guarantee
the timeliness of your locks being released.

=head1 SEE ALSO

L<http://redis.io/topics/distlock>

=head1 AUTHORS

Simon Bertrang, E<lt>janus@cpan.orgE<gt>
Ryan Bastic, E<lt>ryan@bastic.net<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Simon Bertrang

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# vim: ts=4 sw=4 et:
