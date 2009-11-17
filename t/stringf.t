#!perl
use strict;

use Test::More tests => 3;
use Test::Exception;

use String::Formatter
  stringf => {
    -as => 'pos_stringf',
    codes           => {
      f => sub { $_ },
      r => sub { scalar reverse $_ },
    },
  },
  stringf => {
    -as => 'named_stringf',
    input_processor => 'require_named_input',
    string_replacer => 'named_replace',
    codes           => {
      f => sub { $_ },
      r => sub { scalar reverse $_ },
    },
  },
  named_stringf => {
    -as => 'ns2',
    codes           => {
      f => sub { $_ },
      r => sub { scalar reverse $_ },
    },
  },
;

{
  my $have = pos_stringf(
    q(do it %f way and %r way),
    qw(this that),
  );
  my $want = 'do it this way and taht way';

  is($have, $want, "positional args via conversions");
}

{
  my $have = named_stringf(
    q(do it %{alfa}f way and %{beta}r way),
    { alfa => 'this', beta => 'that' },
  );
  my $want = 'do it this way and taht way';

  is($have, $want, "named args via conversions");
}

{
  my $have = ns2(
    q(do it %{alfa}f way and %{beta}r way),
    { alfa => 'this', beta => 'that' },
  );
  my $want = 'do it this way and taht way';

  is($have, $want, "named args via conversions (named_stringf import)");
}

