#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use File::Copy;
use File::Compare;
use Data::Dumper;
use ApeTag;

sub fn {
  return "t/test-files/" . shift;
}

sub at {
  return ApeTag->new(fn(shift));
}

sub update_raises {
  my $tag = shift;
  my $msg = shift;
  my $error_msg = shift;
  eval{$tag->update};
  my $exception = $@;
  like($exception, qr/\AApeTag: $msg/, $error_msg);
}

sub add_field_raises {
  my $tag = shift;
  my $msg = shift;
  my $error_msg = shift;
  my @a = @_;
  eval{$tag->add_field(@a)};
  my $exception = $@;
  like($exception, qr/\AApeTag: $msg/, $error_msg);
}

copy(fn("good-empty.tag"), fn('test.tag'));
at('test.tag')->update;
is(compare(fn("good-empty.tag"), fn('test.tag')), 0, 'update with unmodified tag has no change');

copy(fn("missing-ok.tag"), fn('test.tag'));
at('test.tag')->update;
is(compare(fn("good-empty.tag"), fn('test.tag')), 0, 'update writes tag where there was none before');

copy(fn("good-empty.tag"), fn('test.tag'));
my $tag = at('test.tag');
$tag->add_field('name', 'value');
$tag->update;
is(compare(fn("good-simple-1.tag"), fn('test.tag')), 0, 'update writes correct tag after adding field');

$tag->remove_field('name');
$tag->update;
is(compare(fn("good-empty.tag"), fn('test.tag')), 0, 'update writes correct tag after removing field');

$tag->add_item(1, 2, 'name', 'value');
$tag->update;
is(compare(fn("good-simple-1-ro-external.tag"), fn('test.tag')), 0, 'update writes correct tag after adding item');

copy(fn("missing-ok.tag"), fn('test.tag'));
$tag = at('test.tag');
for(my $i = 0; $i < 63; $i++) {
  $tag->add_field("${i}n", 'a' x $i);
}
$tag->update;
is(compare(fn("good-many-items.tag"), fn('test.tag')), 0, 'update writes correct tag after adding many fields');

$tag->remove_tag;
$tag->add_field("name", "va", "ue");
$tag->update;
is(compare(fn("good-multiple-values.tag"), fn('test.tag')), 0, 'update writes correct tag after adding field with multiple values');

$tag->add_field("NAME", "value");
$tag->update;
is(compare(fn("good-simple-1-uc.tag"), fn('test.tag')), 0, 'add_field overwrites key in case insensitive manner');

copy(fn("missing-ok.tag"), fn('test.tag'));
$tag = at('test.tag');
$tag->add_field("name", "v\xc2\xd5");
$tag->update;
is(compare(fn("good-simple-1-utf8.tag"), fn('test.tag')), 0, 'update converts Latin-1 strings to UTF8');

copy(fn("missing-ok.tag"), fn('test.tag'));
$tag = at('test.tag');
my $u8 = "v\xC3\x82\xC3\x95";
utf8::upgrade($u8);
$tag->add_field("name", $u8);
$tag->update;
is(compare(fn("good-simple-1-utf8.tag"), fn('test.tag')), 0, 'update does not convert UTF8 strings');

$tag->remove_tag;
for(my $i = 0; $i < 65; $i++) {
  $tag->add_field("${i}n", 'a');
}
update_raises($tag, qr/tag has more than max allowed items/, 'too many items raises exception');

copy(fn("missing-ok.tag"), fn('test.tag'));
$tag = at('test.tag');
$tag->add_field("xn", 'a' x 8118);
update_raises($tag, qr/tag is larger than max allowed size/, 'too large tag raises exception');

copy(fn("missing-ok.tag"), fn('test.tag'));
$tag = at('test.tag');
add_field_raises($tag, qr/item key too short/, 'too large tag raises exception', 'n', 'a');
add_field_raises($tag, qr/invalid item key character/, 'invalid key character 1', "a\0", 'a');
add_field_raises($tag, qr/invalid item key character/, 'invalid key character 2', "a\x1f", 'a');
add_field_raises($tag, qr/invalid item key character/, 'invalid key character 3', "a\x80", 'a');
add_field_raises($tag, qr/invalid item key character/, 'invalid key character 4', "a\xff", 'a');

copy(fn("good-empty.tag"), fn('test.tag'));
open my $fh, '+<', fn('test.tag');
$tag = ApeTag->new($fh);
$tag->add_field('name', 'value');
$tag->update;
close $fh;
is(compare(fn("good-simple-1.tag"), fn('test.tag')), 0, 'update works correctly with file handles');

unlink(fn('test.tag'));

done_testing;

