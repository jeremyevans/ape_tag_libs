#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use ApeTag;

sub raises {
  my $file = shift;
  my $msg = shift;
  eval{ApeTag->new("t/test-files/" . $file)->fields};
  my $exception = $@;
  like($exception, qr/\AApeTag: $msg/, $file);
}

raises("corrupt-count-larger-than-possible.tag", qr/tag item count \(\d+\) larger than possible/);
raises("corrupt-count-mismatch.tag", qr/header item item_count \(\d+\) does not match footer item item_count/);
raises("corrupt-count-over-max-allowed.tag", qr/tag item count \(\d+\) larger than maximum allowed/);
raises("corrupt-data-remaining.tag", qr/data remaining after specified number of items parsed/);
raises("corrupt-duplicate-item-key.tag", qr/duplicate item key/);
raises("corrupt-finished-without-parsing-all-items.tag", qr/end of tag reached without parsing all items/);
raises("corrupt-footer-flags.tag", qr/bad APE footer flags/);
raises("corrupt-header.tag", qr/missing or corrupt tag header/);
raises("corrupt-item-flags-invalid.tag", qr/invalid item flags/);
raises("corrupt-item-length-invalid.tag", qr/invalid item length/);
raises("corrupt-key-invalid.tag", qr/invalid item key /);
raises("corrupt-key-too-short.tag", qr/item key too short/);
raises("corrupt-key-too-long.tag", qr/item key too long/);
raises("corrupt-min-size.tag", qr/tag size \(\d+\) smaller than minimum size/);
raises("corrupt-missing-key-value-separator.tag", qr/missing key-value separator/);
raises("corrupt-next-start-too-large.tag", qr/invalid item length/);
raises("corrupt-size-larger-than-possible.tag", qr/tag size \(\d+\) larger than possible /);
raises("corrupt-size-mismatch.tag", qr/header size \(\d+\) does not match footer size/);
raises("corrupt-size-over-max-allowed.tag", qr/tag size \(\d+\) larger than maximum allowed/);
raises("corrupt-value-not-utf8.tag", qr/non-UTF8 character found in item value/);

done_testing;
