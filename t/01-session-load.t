use v5.36;
use Test::More;
use File::Spec;
use FindBin;

use BridgeWebs::Session;

my $sample = File::Spec->catfile($FindBin::Bin, 'data', 'sample.xml');
plan tests => 6;

ok(-f $sample, 'sample fixture exists');

my $session = BridgeWebs::Session->load_file($sample);
isa_ok($session, 'BridgeWebs::Session');

my $data = $session->data;
ok($data->{EVENT}, 'loaded event');
ok($data->{EVENT}->{BOARD}, 'loaded boards');
is($session->filename, $sample, 'filename recorded');

my $pairs = $data->{EVENT}->{PARTICIPANTS}{PAIR};
cmp_ok(scalar @$pairs, '>', 0, 'has pairs');
