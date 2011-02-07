#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use File::Copy;
use File::Compare;
use ApeTag;

sub fn {
  return "t/test-files/" . shift;
}

sub at {
  return ApeTag->new(fn(shift));
}

copy(fn("good-empty.tag"), fn('test.tag'));
is(at('test.tag')->remove_tag, 1, 'remove_tag returns 1 for removed tag');
is(compare(fn("missing-ok.tag"), fn('test.tag')), 0, 'remove_tag removes APE tag');

copy(fn("good-empty-id3.tag"), fn('test.tag'));
is(at('test.tag')->remove_tag, 1, 'remove_tag returns 1 for removed tag with id3');
is(compare(fn("missing-ok.tag"), fn('test.tag')), 0, 'remove_tag removes both APE and ID3 tags');

copy(fn("good-empty-id3-only.tag"), fn('test.tag'));
is(at('test.tag')->remove_tag, 1, 'remove_tag returns 1 for tag with only id3');
is(compare(fn("missing-ok.tag"), fn('test.tag')), 0, 'remove_tag removes ID3 tag');

copy(fn("missing-10k.tag"), fn('test.tag'));
is(at('test.tag')->remove_tag, 0, 'remove_tag returns 0 for file without tag');
is(compare(fn("missing-10k.tag"), fn('test.tag')), 0, 'remove_tag no-op for file with neither APE nor ID3 tag');

copy(fn("good-empty-id3.tag"), fn('test.tag'));
open my $fh, '+<', fn('test.tag');
is(ApeTag->new($fh)->remove_tag, 1, 'remove_tag returns 1 for removed tag with id3 with file handle');
is(compare(fn("missing-ok.tag"), fn('test.tag')), 0, 'remove_tag removes both APE and ID3 tags with file handle');
close $fh;

unlink(fn('test.tag'));

done_testing;

