use strict;
use 5.010;
use lib 'lib';

use Benchmark;
# use String::Format;
use String::Formatter;

my $fmt = String::Formatter->new({
  codes => {
    a => "apples",
    b => "bannanas",
  },
});

# my $index_format = String::Format->stringfactory({
#   a => "apples",
#   b => "bannanas",
# });

# say $index_format->("I like to eat %a and %b.");
say $fmt->format("I like to eat %a and %b.");

timethese(100_000, {
  # dlc  => sub { $index_format->("I like to eat %a and %b.") },
  rjbs => sub { $fmt->format("I like to eat %a and %b.") },
});
