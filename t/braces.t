#!perl
use strict;
use warnings;
use Test::More tests => 1;

use String::Format;

my $unknown_fmt = "We know that %{nested {braces} rule}s.";
is(
  stringf($unknown_fmt, { s => sub { my $str = shift; return $str } }),
  "We know that nested {braces} rule.",
  "we allow braces inside braces",
);
