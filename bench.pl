use strict;
use 5.010;
use lib 'lib';

use Benchmark;
use String::Format;
use String::Formatter;
use Template;

my $hash = {
  a => 'apples',
  b => 'bananas',
};

my $fmt = String::Formatter->new({
  codes => $hash,
});

my $index_format = String::Format->stringfactory($hash);

my $tt2 = Template->new;

say $index_format->("I like to eat %a and %b.");
say $fmt->format("I like to eat %a and %b.");

$tt2->process(\'I like to eat [%a%] and [%b%].', $hash, \my $str);
say $str;

timethese(100_000, {
  dlc  => sub { $index_format->("I like to eat %a and %b.") },
  rjbs => sub { $fmt->format("I like to eat %a and %b.") },
  # tt2  => sub {
  #   $tt2->process(\'I like to eat [%a%] and [%b%].', $hash, \my $str);
  # },
  perl => sub { sprintf("I like to eat %s and %s.", qw(apples bananas)) },
});
