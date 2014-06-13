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
        quorum         => int( @servers > 1 ? @servers / 2 + 1 : 1 ),
        retry_count    => $args{retry_count} || RETRY_COUNT,
        retry_delay    => $args{retry_delay} || RETRY_DELAY,
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
                $redis->set( $resource, $value, "NX", "PX", $ttl * 1000 ) && 1
            } || 0;
        }

        my $drift = $ttl * DRIFT_FACTOR + 0.002;
        my $validity = $ttl - ( time() - $start ) - $drift;

        if ( $ok >= $self->{quorum} && $validity > 0 ) {
            return {
                validity    => $validity,
                resource    => $resource,
                value        => $value,
            };
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
  my $mutex = $rd->lock( "foo", 10 );
  die( "failed to get a lock" )
      if ! $mutex;
  # ... critical section ...
  $rd->release( $mutex );

=head1 DESCRIPTION

This is an implementation of the Redlock algorithm using Redis for distributed
lock management.

B<NOTE>: This needs at least Redis version 2.6.12 which adds new options
to the C<SET> command making this implementation possible.

=head1 METHODS

=head2 new( ... )

=over 4

=item servers

Array reference with servers to connect to or L<Redis> objects to use.

=item retry_count

Maximum number of times to try to acquire the lock. Defaults to C<3>.

=item retry_delay

Maximum delay between retries in seconds. Defaults to C<0.2>.

=item version_check

Flag to check redis server version(s) in the constructor to ensure compatibility.
Defaults to C<1>.

=back

=head2 lock( $resource, $ttl [ $value ] )

Acquire the lock for the resource with the given time to live (in seconds)
until the lock expires. Without a value will generate a unique identifier.

=head2 release( $lock )

Release the previously acquired lock.

=head1 SEE ALSO

L<http://redis.io/topics/distlock>

=head1 DISCLAIMER

This code implements an algorithm which is currently a proposal, it was not
formally analyzed. Make sure to understand how it works before using it in
production environments.

=head1 ACKNOWLEDGMENT

This module was originally developed at Booking.com. With approval from
Booking.com, this module was released as open source, for which the author
would like to express his gratitude.

=head1 AUTHOR

Simon Bertrang, E<lt>janus@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Simon Bertrang

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# vim: ts=4 sw=4 et:
