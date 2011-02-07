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
  return ApeTag->new(fn(shift), @_);
}

copy(fn("missing-ok.tag"), fn('test.tag'));
my $tag = at('test.tag');
$tag->update;
is(compare(fn("good-empty.tag"), fn('test.tag')), 0, 'no id3 tag added by default if not already present');

copy(fn("missing-ok.tag"), fn('test.mp3'));
$tag = at('test.mp3');
$tag->update;
is(compare(fn("good-empty-id3.tag"), fn('test.mp3')), 0, 'id3 tag added by default for mp3 files');

copy(fn("missing-ok.tag"), fn('test.mp3'));
$tag = at('test.mp3', 0);
$tag->update;
is(compare(fn("good-empty.tag"), fn('test.mp3')), 0, 'no id3 tag added by default for mp3 files if check_id3 is false');

copy(fn("missing-ok.tag"), fn('test.tag'));
$tag = at('test.tag', 1);
$tag->update;
is(compare(fn("good-empty-id3.tag"), fn('test.tag')), 0, 'id3 tag added by default if check_id3 flag is true');

copy(fn("good-empty-id3-only.tag"), fn('test.tag'));
$tag = at('test.tag');
$tag->update;
is(compare(fn("good-empty-id3.tag"), fn('test.tag')), 0, 'id3 tag kept if already present');

copy(fn("missing-ok.tag"), fn('test.tag'));
$tag = at('test.tag', 1);
$tag->add_field('track', '1');
$tag->add_field('genre', 'Game');
$tag->add_field('year', '1999');
$tag->add_field('title', 'Test Title');
$tag->add_field('artist', 'Test Artist');
$tag->add_field('album', 'Test Album');
$tag->add_field('comment', 'Test Comment');
$tag->update;
is(compare(fn("good-simple-4.tag"), fn('test.tag')), 0, 'id3 tag updated correctly with fields');

copy(fn("missing-ok.tag"), fn('test.tag'));
$tag = at('test.tag', 1);
$tag->add_field('track', '1');
$tag->add_field('genre', 'Game');
$tag->add_field('date', '12/31/1999');
$tag->add_field('title', 'Test Title');
$tag->add_field('artist', 'Test Artist');
$tag->add_field('album', 'Test Album');
$tag->add_field('comment', 'Test Comment');
$tag->update;
is(compare(fn("good-simple-4-date.tag"), fn('test.tag')), 0, 'id3 tag updated correctly with date field');

copy(fn("missing-ok.tag"), fn('test.tag'));
$tag = at('test.tag', 1);
$tag->add_field('track', '1');
$tag->add_field('genre', 'Game');
$tag->add_field('year', '1999' x 2);
$tag->add_field('title', 'Test Title' x 5);
$tag->add_field('artist', 'Test Artist' x 5);
$tag->add_field('album', 'Test Album' x 5);
$tag->add_field('comment', 'Test Comment' x 5);
$tag->update;
is(compare(fn("good-simple-4-long.tag"), fn('test.tag')), 0, 'id3 tag updated correctly with long field lengths');

is(at('good-empty-id3.tag', 0)->has_id3, 0, 'has_id3 false if not checking for id3');
is(at('good-empty-id3.tag', 0)->has_tag, 0, 'has_tag false if id3 present at end of file and not checking for id3');

unlink(fn('test.tag'));
unlink(fn('test.mp3'));

done_testing;

