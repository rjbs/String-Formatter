#!/usr/bin/env perl
# vim: set ft=perl ts=4 sw=4:

# ======================================================================
# This is your basic "Do I compile?" test.
# ======================================================================

my $loaded;
BEGIN { print "1..1\n" };
END   { 
    print "not " unless $loaded;
    print "ok 1\n";
}

use String::Format;
$loaded++;
