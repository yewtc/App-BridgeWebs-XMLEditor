use v5.36;
use Test::More;

BEGIN {
    eval { require Gtk3; 1 } or plan skip_all => 'Gtk3 not installed';
}

plan tests => 2;

use_ok('App::BridgeWebs::XMLEditor');
use_ok('BridgeXMLEditor');
