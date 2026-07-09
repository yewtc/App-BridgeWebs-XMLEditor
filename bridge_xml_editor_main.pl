#!/usr/bin/env perl

use v5.36;

# Add the lib directory to the module search path
use lib 'lib';

# Use the BridgeXMLEditor module
use BridgeXMLEditor;

# Check if we have a display
if (!defined($ENV{DISPLAY}) && !defined($ENV{WAYLAND_DISPLAY})) {
    die "No display available. Please ensure you have a graphical environment running.\n";
}

# Create and run the application
eval {
    my $xml_file = @ARGV ? $ARGV[0] : undef;
    my $app = BridgeXMLEditor->new($xml_file);
    $app->run();
};
if ($@) {
    die "Error running application: $@\n";
}
