#!perl
use strict;
use warnings;
use Test::More tests => 3;

use String::Stringf stringf => {
  formats => { s => sub { "$_[0] - $_[1] - @{$_[2]}" } },
};

my $str = stringf('%{foo}s | %x | %{bar}s | %{baz}s', 1, 2, 3);

is(
  $str,
  "foo - 0 - 1 2 3 | %x | bar - 1 - 1 2 3 | baz - 2 - 1 2 3",
  "we get all the suspected parameters to format subs",
);

{
  my $formatter = String::Stringf->stringfactory({
    p => sub { $_[2]->[ $_[1] ] },
  });

  my $str = $formatter->("both %p and %p", qw(country western));
  is($str, "both country and western", "positional arg handling");
}

{
  my $formatter = String::Stringf->stringfactory({
    n => sub { $_[2]->[0]{ $_[0] } },
  });

  my $str = $formatter->(
    "both %{good}n and %{bad}n",
    {
      good => 'delicious',
      bad  => 'moldy',
    },
  );
  is($str, "both delicious and moldy", "named arg handling");
}
