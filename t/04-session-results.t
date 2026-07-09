use v5.36;
use Test::More;
use File::Spec;
use FindBin;

use BridgeWebs::Session;

my $sample = File::Spec->catfile($FindBin::Bin, 'data', 'sample.xml');
plan tests => 6;

my $session = BridgeWebs::Session->load_file($sample);
my $count = $session->recalculate_session_results();
cmp_ok($count, '>', 0, 'ranked pairs');

my $pairs = $session->data->{EVENT}{PARTICIPANTS}{PAIR};
my ($first) = grep { ($_->{PAIR_NUMBER} // '') eq '1' } @$pairs;
ok($first, 'pair 1 exists');
like($first->{PLACE}, qr/^\d/, 'pair 1 has place');
like($first->{PERCENTAGE}, qr/^\d+\.\d{2}$/, 'pair 1 has percentage');

if ($session->master_points_enabled()) {
    ok($session->get_pair_mp_awarded($first) ne '', 'pair 1 has master points');
}
else {
    pass('master points disabled in sample');
}

my %names = $session->get_pair_names_map();
like($names{'1'}, qr/Harry Kear & Grace Martyn/, 'pair 1 name map');
