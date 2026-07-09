use v5.36;
use Test::More tests => 8;

use BridgeWebs::Session;

is(BridgeWebs::Session->calculate_bridge_score('PASS', 0, 'N'), 0, 'pass scores zero');
is(BridgeWebs::Session->calculate_bridge_score('3NT', 9, 'N'), 400, '3NT making 9 by NS');
is(BridgeWebs::Session->calculate_bridge_score('3NT', 9, 'E'), -400, '3NT making 9 by EW');
is(BridgeWebs::Session->calculate_bridge_score('4H', 10, 'S'), 420, '4H game non-vul');
is(BridgeWebs::Session->calculate_bridge_score('4H', 9, 'S'), -100, '4H down one non-vul');
is(BridgeWebs::Session->calculate_bridge_score('2CX', 7, 'W', 'EW'), 300, 'doubled down one vul EW');
is(BridgeWebs::Session->get_xml_text({ content => 'hello' }), 'hello', 'hash content text');
is(BridgeWebs::Session->get_xml_text('plain'), 'plain', 'plain text');
