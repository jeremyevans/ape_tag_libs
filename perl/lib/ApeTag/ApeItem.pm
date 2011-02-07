#!/usr/bin/perl

package ApeTag::ApeItem;

use strict;
use warnings;
use autodie;

our $VERSION = "1.0";

=head1 NAME

ApeTag::ApeItem - APE item representation

=head1 SYNOPSIS

ApeTag::ApeItem is a simple representation of an APE item.

=head1 DESCRIPTION

ApeTag::ApeItem is not exposed to the end-user except
as the return value of ApeTag::items.  Such items can
be modified using the methods here, though it is recommended
to simply use ApeTag::remove_field and ApeTag::add_item instead.
This only documents the methods recommended for public use.

=cut

sub new {
  my $class = shift;
  my $self = bless({}, $class);
  $self->_init(@_);
  return $self;
}

sub _init {
  my $self = shift;
  $self->{key} = '' . shift;
  @{$self->{values}} = map {'' . $_} @_;
  $self->{read_only} = 0;
  $self->{type} = 0;
}

=head2 key

Returns the key of the APE item as a string.

=cut

sub key {
  my $self = shift;
  return $self->{key};
}

=head2 values

Returns a reference to an array of strings that make up this
APE item.

=cut

sub values {
  my $self = shift;
  return $self->{values};
}

=head2 type

Returns the type of the APE item.  This will be a number from 0-3:

=item 0: Text information in UTF-8 format.

=item 1: Binary information.

=item 2: Locator for external stored information, also in UTF-8 format.

=item 3: Reserved.

=cut

sub type {
  my $self = shift;
  return $self->{type};
}

=head2 read_only

Returns the read-only status of the APE item.  Note that this library
ignores the read-only status, allowing you to remove or modify
fields that are supposed to be read-only.

=cut

sub read_only {
  my $self = shift;
  return $self->{read_only};
}

=head1 COPYRIGHT

Copyright 2011 Jeremy Evans <code@jeremyevans.net>

Distributed under the MIT LICENSE.

=cut

sub check {
  my $self = shift;
  if ($self->type == 0 || $self->type == 2) {
    foreach (@{$self->values}) {
      unless (utf8::is_utf8($_)) {
        utf8::encode($_);
        utf8::upgrade($_);
      }
    }
  }
  die "ApeTag: invalid item key character" if $self->key =~ /[\0-\x1f\x80-\xff]|\A(?:id3|tag|oggs|mp\+)\z/io;
  die "ApeTag: item key too short" if length($self->key) < 2;
  die "ApeTag: item key too long" if length($self->key) > 255;
  die "ApeTag: invalid item read-only flag" if $self->read_only < 0 || $self->read_only > 1;
  die "ApeTag: invalid item type" if $self->type < 0 || $self->type > 3;
  return $self;
}

# Class method
sub from_parse {
  my $class = shift;
  my $flags = shift;
  my $key = shift;
  my $data = shift;
  my $item = $class->new($key, ($data eq '') ? '' : split(qr/\0/, $data));
  $item->set_read_only(($flags & 1) > 0);
  $item->set_type($flags >> 1);
  if ($item->type == 0 || $item->type == 2) {
    die "ApeTag: non-UTF8 character found in item value" unless utf8::decode($data);
  }
  $item->check;
  return $item;
}

sub raw {
  my $self = shift;
  my $values = join("\0", @{$self->values});
  return pack("VN", length($values), ($self->type << 1) + $self->read_only) . $self->key . "\0" . $values;
}

sub set_read_only {
  my $self = shift;
  $self->{read_only} = 0 + shift;
}

sub set_type {
  my $self = shift;
  $self->{type} = 0 + shift;
}

