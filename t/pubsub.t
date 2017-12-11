use strict;
use warnings;

use Test::More;
use Test::Fatal;

use Net::Async::Redis;
use IO::Async::Loop;
use Log::Any::Adapter qw(TAP);

plan skip_all => 'set NET_ASYNC_REDIS_HOST or NET_ASYNC_REDIS_URI env var to test' unless exists $ENV{NET_ASYNC_REDIS_HOST} or exists $ENV{NET_ASYNC_REDIS_URI};

my $loop = IO::Async::Loop->new;
sub redis {
    my ($msg) = @_;
    $loop->add(my $redis = Net::Async::Redis->new);
    is(exception {
        Future->needs_any(
            $redis->connect(
                host => $ENV{NET_ASYNC_REDIS_HOST} // '127.0.0.1',
            ),
            $loop->timeout_future(after => 5)
        )->get
    }, undef, 'can connect' . ($msg ? " for $msg" : ''));
    return $redis;
}

my $subscriber = redis('subscriber');
my $publisher = redis('publisher');
is($publisher->publish('test::nowhere', 'message')->get, 0, 'have no subscribers on initial publish');
isa_ok(my $sub = $subscriber->subscribe('test::somewhere')->get, 'Net::Async::Redis::Subscription');
is(exception {
    $subscriber->ping->get
}, undef, 'can still ping after subscribe');
like(exception {
        note 'start';
    $subscriber->get('test::random_key')->get;
        note 'end';
}, qr/pubsub/, 'but cannot GET while subscribed');

done_testing;


