#!/usr/bin/perl

package ApeTag;

use strict;
use warnings;
use autodie;
use ApeTag::ApeItem;

our $VERSION = "1.0";
our $PREAMBLE = "APETAGEX\xD0\x07\x00\x00";
our $HEADER_FLAGS = "\x00\x00\xA0";
our $FOOTER_FLAGS = "\x00\x00\x80";
our $MAX_SIZE = 8192;
our $MAX_ITEM_COUNT = 64;

my @ID3G = (
"Blues", "Classic Rock", "Country", "Dance", "Disco", "Funk", "Grunge",
"Hip-Hop", "Jazz", "Metal", "New Age", "Oldies", "Other", "Pop", "R & B", "Rap", "Reggae",
"Rock", "Techno", "Industrial", "Alternative", "Ska", "Death Metal", "Prank", "Soundtrack",
"Euro-Techno", "Ambient", "Trip-Hop", "Vocal", "Jazz + Funk", "Fusion", "Trance",
"Classical", "Instrumental", "Acid", "House", "Game", "Sound Clip", "Gospel", "Noise",
"Alternative Rock", "Bass", "Soul", "Punk", "Space", "Meditative", "Instrumental Pop",
"Instrumental Rock", "Ethnic", "Gothic", "Darkwave", "Techno-Industrial", "Electronic",
"Pop-Fol", "Eurodance", "Dream", "Southern Rock", "Comedy", "Cult", "Gangsta", "Top 40",
"Christian Rap", "Pop/Funk", "Jungle", "Native US", "Cabaret", "New Wave", "Psychadelic",
"Rave", "Showtunes", "Trailer", "Lo-Fi", "Tribal", "Acid Punk", "Acid Jazz", "Polka",
"Retro", "Musical", "Rock & Roll", "Hard Rock", "Folk", "Folk-Rock", "National Folk",
"Swing", "Fast Fusion", "Bebop", "Latin", "Revival", "Celtic", "Bluegrass", "Avantgarde",
"Gothic Rock", "Progressive Rock", "Psychedelic Rock", "Symphonic Rock", "Slow Rock",
"Big Band", "Chorus", "Easy Listening", "Acoustic", "Humour", "Speech", "Chanson", "Opera",
"Chamber Music", "Sonata", "Symphony", "Booty Bass", "Primus", "Porn Groove", "Satire",
"Slow Jam", "Club", "Tango", "Samba", "Folklore", "Ballad", "Power Ballad", "Rhytmic Soul",
"Freestyle", "Duet", "Punk Rock", "Drum Solo", "Acapella", "Euro-House", "Dance Hall",
"Goa", "Drum & Bass", "Club-House", "Hardcore", "Terror", "Indie", "BritPop", "Negerpunk",
"Polsk Punk", "Beat", "Christian Gangsta Rap", "Heavy Metal", "Black Metal",
"Crossover", "Contemporary Christian", "Christian Rock", "Merengue", "Salsa",
"Trash Meta", "Anime", "Jpop", "Synthpop");
my %ID3_GENRES_HASH;

for (my $i = 0; $i < scalar(@ID3G); $i++) {
  $ID3_GENRES_HASH{lc($ID3G[$i])} = $i;
}
our @ID3_GENRES = @ID3G;

=head1 NAME

ApeTag - An APEv2 tag reader/writer library

=head1 SYNOPSIS

ApeTag is a pure perl library for manipulating APEv2 tags.
It aims for standards compliance with the APEv2 spec. APEv2 is the standard
tagging format for Musepack (.mpc) and Monkey's Audio files (.ape), and it can
also be used with mp3s as an alternative to ID3v2.x (technically, it can be 
used on any file type and is not limited to storing just audio file metadata).

=head1 DESCRIPTION

ApeTag is designed to be easy to use, with a small list of OO methods,
and no external dependencies.  It is tested on perl 5.12.2.  It uses the
autodie pragma, and therefore is unlikely to work on perl versions older than
5.10.

=head2 new (class method)

ApeTag->new takes 1 or 2 arguments.  The first argument should be either
a filename string or a file handle.  The second argument is usually not used,
but controls whether to look for ID3 tags.  If the second argument is 0, ID3
tags will not be checked, so if a file has an ID3 tag and an APE tag, the
APE tag will not be found.  It also controls whether to write an ID3 tag when
updating if an APE tag is not already present.  If the second argument is 1,
an ID3 tag will be created with an APE tag when the file is updated.  If the
second argument is not given, the library will always check for an ID3 tag,
but will only add an ID3 tag if the filename ends with .mp3.

  ApeTag->new('file.ape');
  ApeTag->new('file.mp3', 0);
  ApeTag->new('file.mpc', 1);
  open my $fh, '<', 'file.ape';
  ApeTag->new($fh);

=cut

sub new {
  my $class = shift;
  my $self = bless({}, $class);
  $self->_init(@_);
  $self;
}

sub _init {
  my $self = shift;
  my $fn = shift;
  $self->{check_id3} = shift;
  if (ref($fn)) {
    $self->{fh} = $fn;
  } else {
    $self->{filename} = $fn;
  }
}

=head2 filename

The filename that this ApeTag operates on.  If a file handle was given to
the new class method, returns undef.

  ApeTag->new('file.mpc')->filename; # 'file.mpc'
  open my $fh, '<', 'file.ape';
  ApeTag->new($fh)->filename # undef;

=cut

sub filename {
  my $self = shift;
  $self->{filename};
}

=head2 has_id3

Whether the file being operated on already has an ID3 tag.
This is also used as the length of the ID3 tag (128) if the
tag is present.

  ApeTag->new('file.mp3')->has_id3; # 0
  ApeTag->new('file.mpc')->has_id3; # 128

=cut

sub has_id3 {
  my $self = shift;
  $self->_get_info unless (exists $self->{got_info});
  exists($self->{has_id3}) ? $self->{has_id3} : 0;
}

=head2 has_tag

Whether the file being operated on already has an APEv2 tag.

  ApeTag->new('without_tag.ape')->has_tag; # 1
  ApeTag->new('with_tag.mp3')->has_tag; # 0

=cut

sub has_tag {
  my $self = shift;
  $self->_get_info unless (exists $self->{got_info});
  exists($self->{has_tag}) ? $self->{has_tag} : 0;
}

=head2 fields

A reference to a hash where the keys are APE item
keys and values are references to arrays of APE item
values.  As most APE items have only a single value,
most of the value references will reference single
element arrays.

  ApeTag->new('file.mp3')->fields; # {key => [value, ...]}

=cut

sub fields {
  my $self = shift;
  $self->_parse unless (exists $self->{got_parse});
  my ($h, $k, $v);
  $h = {};
  if (exists($self->{fields})) {
    while(($k, $v) = each(%{$self->{fields}})) {
      $h->{$v->key} = $v->values;
    }
  }
  $h;
}

=head2 items

A reference to an array of ApeTag::ApeItem objects
representing the individual APE items.

  ApeTag->new('file.mp3')->items; # [ApeTag::ApeItem->new(...), ...]

=cut

sub items {
  my $self = shift;
  $self->_parse unless (exists $self->{got_parse});
  my @items = values(%{$self->{fields}});
  \@items;
}

=head2 remove_tag

Removes the APE tag (and ID3 tag if checking for ID3 tags)
from the file.  Returns 1 if the file already had an
APE or ID3 tag, and 0 if not.

  my $at = ApeTag->new('file.mp3');
  $at->has_tag; # true
  $at->remove_tag; 
  $at->has_tag; # false

=cut

sub remove_tag {
  my $self = shift;
  $self->_get_info unless (exists $self->{got_info});
  if ($self->has_tag || $self->has_id3) {
    if (exists($self->{fh})) {
      truncate $self->{fh}, $self->{tag_start};
    } else {
      truncate $self->filename, $self->{tag_start};
    }
    $self->_clear;
    1;
  } else {
    0;
  }
}

=head2 remove_field

Removes the APE item from the fields.  Takes a
single string argument and removes it from the
fields. The changes to the tag are not written
until update is called.

  my $at = ApeTag->new('file.mp3');
  exists($at->fields->{key}); # true
  $at->remove_field('key'); 
  exists($at->fields->{key}); # false 

=cut

sub remove_field {
  my $self = shift;
  my $key = lc('' . shift);
  $self->_parse unless (exists $self->{got_parse});
  delete(${self}->{fields}->{$key});
}

=head2 add_field

Add an APE item to the fields.  The first argument
is used as the APE item key, and all of the rest
of the arguments are used as the APE item values.
The changes to the tag are not written
until update is called.  This is just a shortcut
to add_item, and it creates items that are not read
only and have the default UTF-8 type.

  my $at = ApeTag->new('file.mp3');
  exists($at->fields->{key}); # false
  $at->add_field('key', 'value1', ...); 
  exists($at->fields->{key}); # true

=cut

sub add_field {
  my $self = shift;
  $self->add_item(0, 0, @_);
}

=head2 add_item

Add an APE item to the fields.  The first argument
is used as the read_only status of the item (0 or 1), the
second argument as the type of the item (0 to 3), the third
argument as th key of the item, and the rest 
of the arguments are used as the item values.
The changes to the tag are not written
until update is called.

  my $at = ApeTag->new('file.mp3');
  exists($at->fields->{key}); # false
  $at->add_item(1, 2, 'key', 'value1', ...); 
  exists($at->fields->{key}); # true

=cut

sub add_item {
  my $self = shift;
  $self->_parse unless (exists $self->{got_parse});
  my $read_only = shift;
  my $type = shift;
  my $item = ApeTag::ApeItem->new(@_);
  my $lc_key = lc($item->key);
  $item->set_read_only($read_only);
  $item->set_type($type);
  my $h = $self->{fields};
  $h->{$lc_key} = $item->check;
}

=head2 update

Write the changes to the backing file.  In general,
add_field, add_item, and/or remove_field should be
called first.

  my $at = ApeTag->new('file.mp3');
  $at->add_item(1, 2, 'key', 'value1', ...); 
  $at->update;

=cut

sub update {
  my $self = shift;
  $self->_parse unless (exists $self->{got_parse});
  my $raw = $self->_raw_ape . $self->_raw_id3;
  $self->_fh("+<", sub {
    my $fh = shift;
    seek $fh, $self->{tag_start}, 0;
    print $fh $raw;
    truncate $fh, tell($fh);
  });
  $self->_clear;
}

=head1 COPYRIGHT

Copyright 2011 Jeremy Evans <code@jeremyevans.net>

Distributed under the MIT LICENSE.

=cut


sub _clear {
  my $self = shift;
  my %h = ();
  $h{check_id3} = $self->{check_id3};
  $h{filename} = $self->{filename} if exists($self->{filename});
  $h{fh} = $self->{fh} if exists($self->{fh});
  %$self = %h;
}

sub _fh {
  my $self = shift;
  my $mode = shift;
  my $fun = shift;
  if (exists $self->{fh}) {
    $fun->($self->{fh});
  } else {
    open my $fh, $mode, $self->filename or die "cannot read ${$self->filename}";
    eval{$fun->($fh)};
    my $exception = $@;
    close $fh;
    die $exception if $exception;
  }
}

sub _get_info {
  my $self = shift;
$self->_fh("<", sub {
  my $fh = shift;
  my $tmp = "";
  $self->{got_info} = 1;

  seek $fh, 0, 2;
  $self->{file_size} = tell $fh;
  if ($self->{file_size} < 64) {
    $self->{has_tag} = 0;
    $self->{has_id3} = 0;
    $self->{tag_start} = $self->{file_size};
    return;
  }

  if ($self->{file_size} < 128 || (defined $self->{check_id3} && $self->{check_id3} == 0)) {
    $self->{has_id3} = 0;
  } else {
    seek $fh, -128, 2;
    read($fh, $tmp, 3);
    $self->{has_id3} = ($tmp eq 'TAG') ? 128 : 0;
    if ($self->has_id3 && ($self->{file_size} < 192)) {
      $self->{has_tag} = 0;
      $self->{tag_start} = $self->{file_size} - $self->{has_id3};
      return;
    }
  }

  seek $fh, -32 - $self->{has_id3}, 2;
  read($fh, $tmp, 32);
  if ($tmp !~ /\A$PREAMBLE/o) {
    $self->{tag_start} = $self->{file_size} - $self->{has_id3};
    $self->{has_tag} = 0;
    return;
  }

  die "ApeTag: bad APE footer flags" if (substr($tmp, 20, 4) !~ /\A(\x00|\x01)${FOOTER_FLAGS}/o);

  my ($size, $item_count);
  ($size, $item_count) = unpack("VV", substr($tmp, 12, 8));
  $self->{size} = $size + 32;
  $self->{item_count} = $item_count;

  die "ApeTag: tag size ($self->{size}) smaller than minimum size" if $self->{size} < 64;
  die "ApeTag: tag size ($self->{size}) larger than maximum allowed" if $self->{size} > $MAX_SIZE;
  die "ApeTag: tag size ($self->{size}) larger than possible" if $self->{size} + $self->has_id3 > $self->{file_size};
  die "ApeTag: tag item count ($self->{item_count}) larger than maximum allowed" if $self->{item_count} > $MAX_ITEM_COUNT;
  die "ApeTag: tag item count ($self->{item_count}) larger than possible" if $self->{item_count} > ($self->{size} - 64)/11;

  seek $fh, -32 - $size - $self->{has_id3}, 2;
  $self->{tag_start} = tell $fh;
  read($fh, $tmp, 32);
  ($size, $item_count) = unpack("VV", substr($tmp, 12, 8));
  $size += 32;

  die "ApeTag: missing or corrupt tag header" if ($tmp !~ /\A$PREAMBLE/o or substr($tmp, 20, 4) !~ /\A(\x00|\x01)${HEADER_FLAGS}/o);
  die "ApeTag: header size ($size) does not match footer size ($self->{size})" if $self->{size} != $size;
  die "ApeTag: header item item_count ($item_count) does not match footer item item_count ($self->{item_count})" if $self->{item_count} != $item_count;

  read($fh, $tmp, $size - 64);
  $self->{tag_data} = $tmp;
  $self->{has_tag} = 1;
});
}

sub _parse {
  my $self = shift;
  $self->{'got_parse'} = 1;
  unless ($self->has_tag) {
    $self->{fields} = {};
    return;
  }

  my $fields = {};
  my ($length, $flags, $key_end, $next_start, $key, $item);
  my $offset = 0;
  my $data = $self->{tag_data};
  my $data_len = length($data);
  my $last_item_start = $data_len - 11;

  for(my $item_count = $self->{item_count}; $item_count > 0; $item_count--, $offset = $next_start) {
    die "ApeTag: end of tag reached without parsing all items (offset: $offset)" if $offset > $last_item_start;
    ($length, $flags) = unpack("VN", substr($data, $offset, 8));
    die "ApeTag: invalid item length (offset: $offset, length: ${length})" if $length + $offset + 11 > $data_len;
    die "ApeTag: invalid item flags (offset: $offset)" if $flags > 7;
    $offset += 8;
    $key_end = index($data, "\0", $offset);
    die "ApeTag: missing key-value separator (offset: $offset)" if ($key_end < $offset);
    $next_start = $length + $key_end + 1;
    die "ApeTag: invalid item length (offset: $offset)" if $next_start > $data_len;
    $key = substr($data, $offset, $key_end - $offset);
    die "ApeTag: duplicate item key (offset: $offset)" if exists($fields->{lc($key)});
    $fields->{lc($key)} = ApeTag::ApeItem->from_parse($flags, $key, substr($data, $key_end + 1, $next_start - ($key_end + 1)));
  }
  die "ApeTag: data remaining after specified number of items parsed (offset: $offset, length: $data_len)" if $offset != $data_len;

  $self->{fields} = $fields;
}

sub _raw_id3 {
  my $self = shift;
  my $f = $self->{fields};
  my %h;
  my $x;

  unless ($self->has_id3) {
    # APE tag present without ID3 never adds ID3
    return '' if $self->has_tag;

    if (defined $self->{check_id3}) {
      # If not checking for ID3, never add it
      return '' if $self->{check_id3} == 0;
    } else {
      # If working with an mp3 file, add it by default, otherwise don't
      return '' unless $self->filename =~ /\.mp3\z/;
    }
  }

  $h{year} = $1 if exists($f->{date}) && (@{$f->{date}->values}[0] =~ /(\d{4})/);

  foreach ("title", "artist", "album", "year", "comment") {
    $h{$_} = join(', ', @{$f->{$_}->values}) if exists($f->{$_});
  }

  $h{genre} = chr($ID3_GENRES_HASH{lc(@{$f->{genre}->values}[0])}) if exists($f->{genre});
  $h{genre} = "\xff" unless defined $h{genre};

  $h{track} = 0 + $1 if exists($f->{track}) && (@{$f->{track}->values}[0] =~ /(\d+)/);
  $h{track} = 0 if !defined($h{track}) || $h{track} > 255;
  $h{track} = chr($h{track});

  foreach ("title", "artist", "album", "year", "comment", "track") {
    $h{$_} = '' unless defined($h{$_});
  }

  pack("a3a30a30a30a4a28a1a1a1", 'TAG', $h{title}, $h{artist}, $h{album}, $h{year}, $h{comment}, "\0", $h{track}, $h{genre});
}

sub _raw_ape {
  my $self = shift;
  my @items = sort {(length($a->raw) <=> length($b->raw)) || ($a->key cmp $b->key)} values(@{$self->items});
  my $raw_items = join('', map {$_->raw} @items);
  my $raw_size = length($raw_items) + 32;
  my $item_count = scalar(@items);
  my $start = $PREAMBLE . pack('VV', $raw_size, $item_count);
  my $end = "\0\0\0\0\0\0\0\0";
  die "ApeTag: tag is larger than max allowed size ($raw_size)" if $raw_size + 32 > $MAX_SIZE;
  die "ApeTag: tag has more than max allowed items ($item_count)" if $item_count > $MAX_ITEM_COUNT;
  $start . "\0" . $HEADER_FLAGS . $end . $raw_items . $start . "\0" . $FOOTER_FLAGS . $end;
}

1;
