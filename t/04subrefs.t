#!/usr/bin/env perl
# vim: set ft=perl ts=4 sw=4:

# ======================================================================
# 04subrefs.t
#
# The design of String::Format is such that you can pass a subroutine
# reference as a hash value, and it will be called in place.  Let's
# test that.
# ======================================================================

use strict;
use String::Format;
use POSIX qw(strftime); # for test 1
use Socket; # for test 3

my ($orig, $target, $result);
BEGIN { print "1..3\n" };

# ======================================================================
# Test 1
# Using strftime in a subroutine reference.
# ======================================================================
$orig   = q(It is now %{%Y/%m%d}d.);
$target = sprintf q(It is now %s.), strftime("%Y/%m/%d", localtime);
$result = stringf $orig, "d" => sub { strftime("%Y/%m/%d", localtime) };

unless ($result eq $target) {
    print "not ";
}
print "ok 1\n";

# ======================================================================
# Test 2
# using getpwuid
# ======================================================================
$orig   = "I am %u.";
$target = "I am " . getpwuid($<) . ".";
$result = stringf $orig, "u" => sub { getpwuid($<) };
unless ($result eq $target) {
    print "not ";
}
print "ok 2\n";

# ======================================================================
# Test 3
# hostname lookups
# ======================================================================
sub ip { inet_ntoa inet_aton $_[0] }
$orig   = q(The address for localhost is %{localhost}i.);
$target = q(The address for localhost is 127.0.0.1.);
$result = stringf $orig, "i" => \&ip;
unless ($result eq $target) {
    print "not ";
}
print "ok 3\n";

# ======================================================================
# Test 4
# ======================================================================
# more tests!
