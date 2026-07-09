#!/usr/bin/env perl

use v5.36;
use FindBin;
use File::Spec;

# Deprecated launcher name; use bridgewebs-xml-editor after installation.
my $editor = File::Spec->catfile($FindBin::Bin, 'bridgewebs-xml-editor');
exec $editor, @ARGV or die "Could not run $editor: $!\n";
