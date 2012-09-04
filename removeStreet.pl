#!/usr/bin/perl -w
use strict;
use utf8;

my $input = $ARGV[0];
open(my $in, '<:utf8', $input) or die "$0: $!: $input";
binmode STDOUT, ":encoding(utf8)";

my $nums = "[0-9１２３４５６７８９０一二三四五六七八九〇万千百十]+";
my $sepalators1 = "(丁目|番地|[番号のノーｰ－-]){0,2}";
my $sepalators2 = "(番地|[番号のノーｰ－-]){0,2}";
my $regex = qr/$nums$sepalators1($nums$sepalators2){0,2}$/;

while (<$in>) {
  s/\s+$//;
  s/\s*<small>\s*$//;
  s/\s*\([^\(\)]+\)\s*$//;
  s/\s*（[^（）]+）\s*$//;
  s/[先他・\*]$//;
  my($id, $title, $address) = split(/\t/, $_);
  next if !defined($address);
  my @addresses = split(/\s+/, $address);
  $address = $addresses[0];
  $address =~ s/$regex//;
  print join("\t" => ($id, $title, $address)) . "\n";
}
