#!/usr/bin/env perl
# vim: set ft=perl ts=4 sw=4:

# ======================================================================
# 03multiple.t
#
# Attempting to pass a multi-character format string will not work.
# This means that stringf will return the malformed format characters
# as they were passed in.
# ======================================================================

use strict;
use String::Format;

my ($orig, $target, $result);
BEGIN { print "1..3\n" };

# ======================================================================
# Test 1
# ======================================================================
$orig   = q(My %foot hurts.);
$target = q(My %foot hurts.);
$result = stringf $orig, { 'foot' => 'pretzel' };
unless ($result eq $target) {
    print "not ";
}
print "ok 1\n";

# ======================================================================
# Test 2, same as Test 1, but with a one-char format string.
# ======================================================================
$target = "My pretzeloot hurts.";
$result = stringf $orig, { 'f' => 'pretzel' };
unless ($result eq $target) {
    print "not ";
}
print "ok 2\n";

# ======================================================================
# Test 3
# ======================================================================
$orig   = 'I am %undefined';
$target = 'I am not ndefined';
$result = stringf $orig, { u => "not " };
unless ($result eq $target) {
    print "not ";
}
print "ok 3\n";
