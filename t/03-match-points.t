use v5.36;
use Test::More tests => 5;

use BridgeWebs::Session;

my $session = BridgeWebs::Session->new({
    EVENT => {
        BOARD => [],
    },
});

my $board = {
    TRAVELLER_LINE => [
        { SCORE => 400, NS_PAIR_NUMBER => 1, EW_PAIR_NUMBER => 2 },
        { SCORE => 100, NS_PAIR_NUMBER => 3, EW_PAIR_NUMBER => 4 },
        { SCORE => -100, NS_PAIR_NUMBER => 5, EW_PAIR_NUMBER => 6 },
    ],
};

my $updated = $session->recalculate_board_match_points($board);
is($updated, 3, 'updated three lines');

is($board->{TRAVELLER_LINE}[0]{NS_MATCH_POINTS}, 2, 'top score NS MP');
is($board->{TRAVELLER_LINE}[0]{EW_MATCH_POINTS}, 0, 'top score EW MP');
is($board->{TRAVELLER_LINE}[2]{NS_MATCH_POINTS}, 0, 'bottom score NS MP');
is($board->{TRAVELLER_LINE}[2]{EW_MATCH_POINTS}, 2, 'bottom score EW MP');
