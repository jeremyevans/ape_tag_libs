#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Data::Dumper;
use ApeTag;

sub fn {
  return "t/test-files/" . shift;
}

sub at {
  return ApeTag->new(fn(shift));
}

# has_id3
ok(!at("missing-ok.tag")->has_id3, 'missing both tags - no id3');
ok(!at("good-empty.tag")->has_id3, 'missing id3 tags - no id3');
ok(at("good-empty-id3-only.tag")->has_id3, 'missing ape tag - has id3');
ok(at("good-empty-id3.tag")->has_id3, 'have both tags - has id3');

# has_tag
ok(!at("missing-ok.tag")->has_tag, 'missing both tags - no ape');
ok(at("good-empty.tag")->has_tag, 'missing id3 tags - has ape');
ok(!at("good-empty-id3-only.tag")->has_tag, 'missing ape tag - no ape');
ok(at("good-empty-id3.tag")->has_tag, 'have both tags - has ape');

# filename
is(at("missing-ok.tag")->filename, 't/test-files/missing-ok.tag', 'filename');

# fields
my $fields = at("good-empty.tag")->fields;
is(scalar(keys %$fields), 0, 'fields length: 0');

$fields = at("good-simple-1.tag")->fields;
is(scalar(keys %$fields), 1, 'fields length: 1');
is(scalar(@{$fields->{name}}), 1, 'fields value array length: 1');
is($fields->{name}[0], 'value', 'fields value 1');

$fields = at("good-many-items.tag")->fields;
is(scalar(keys %$fields), 63, 'fields length: 63');
is($fields->{"0n"}[0], '', 'fields value 1/63');
is($fields->{"1n"}[0], 'a', 'fields value 2/63');
is($fields->{"62n"}[0], 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'fields value 63/63');

$fields = at("good-multiple-values.tag")->fields;
is(scalar(keys %$fields), 1, 'fields multiple value length: 1');
is(scalar(@{$fields->{name}}), 2, 'fields multiple value array length: 2');
is($fields->{name}[0], 'va', 'fields multiple value 1st entry');
is($fields->{name}[1], 'ue', 'fields multiple value 2nd entry');

# items
my $items = at("good-empty.tag")->items;
is(scalar(@$items), 0, 'items length: 0');

$items = at("good-simple-1.tag")->items;
is(scalar(@$items), 1, 'items length: 1');
is(scalar(@{$items->[0]->values}), 1, 'items value array length: 1');
is($items->[0]->key, 'name', 'items key 1');
is(@{$items->[0]->values}[0], 'value', 'items value 1');
is($items->[0]->read_only, 0, 'unset read only value parsed correctly');
is($items->[0]->type, 0, 'default type parsed correctly');

$items = at("good-simple-1-ro-external.tag")->items;
is(scalar(@$items), 1, 'items length: 1');
is($items->[0]->read_only, 1, 'read only value parsed correctly');
is($items->[0]->type, 2, 'type parsed correctly');

$items = at("good-many-items.tag")->items;
my @sitems = sort { length($a->values->[0]) <=> length($b->values->[0]) } @$items;
is(scalar(@sitems), 63, 'items length: 63');
is($sitems[0]->key, '0n', 'items key 1/63');
is(@{$sitems[0]->values}[0], '', 'items value 1/63');
is($sitems[1]->key, '1n', 'items key 2/63');
is(@{$sitems[1]->values}[0], 'a', 'items value 2/63');
is($sitems[62]->key, '62n', 'items key 63/63');
is(@{$sitems[62]->values}[0], 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'items value 63/63');

$items = at("good-multiple-values.tag")->items;
is(scalar(@$items), 1, 'items multiple value length: 1');
is(scalar(@{$items->[0]->values}), 2, 'items multiple value array length: 2');
is($items->[0]->key, 'name', 'items multiple value key');
is(@{$items->[0]->values}[0], 'va', 'items multiple value 1st entry');
is(@{$items->[0]->values}[1], 'ue', 'items multiple value 2nd entry');

open my $fh, '<', fn('good-simple-1.tag');
$fields = ApeTag->new($fh)->fields;
close $fh;
is(scalar(keys %$fields), 1, 'fh fields length: 1');
is(scalar(@{$fields->{name}}), 1, 'fh fields value array length: 1');
is($fields->{name}[0], 'value', 'fh fields value 1');

done_testing;
