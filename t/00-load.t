use v5.36;
use Test::More tests => 2;

use_ok('BridgeWebs::Session');

my $session = BridgeWebs::Session->new();
ok(!$session->data, 'new session has no data');
