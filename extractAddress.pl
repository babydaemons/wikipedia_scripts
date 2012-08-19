#!/usr/bin/perl
use strict;

use constant MAX => 0x7FFFFFF;

sub get_text($) {
  my ($page) = @_;
  my $prefix = '<text xml:space="preserve">';
  my $start = index($page, $prefix) + length($prefix);
  my $suffix = '</text>';
  my $end = index($page, $suffix);
  my $len = $end - $start;
  my $text = substr($page, $start, $len);
  return $text;
}

sub get_templates($) {
  my ($text) = @_;
  my @positions;
  my $offset = 0;
  my $nest = 0;
  my $start = 0;
  my $end = 0;
  do {
    $start = index($text, '{{', $offset); $start = MAX if $start == -1;
    $end = index($text, '}}', $offset);   $end   = MAX if $end   == -1;
    #print "$start, $end\n";
    if ($start < $end) {
      $offset = $start + 2;
      push(@positions, "{{,$nest,$start");
      ++$nest;
    }
    else {
      --$nest;
      $offset = $end + 2;
      push(@positions, "}},$nest,$end");
    }
  } while ($start != MAX && $end != MAX);
  #print join("\n" => @positions) . "\n";

  my $N = $#positions;
  my @templates;
  sub tie_templates($) {
    my ($k) = @_;
    for (my $i = $k; $i < $N; ++$i) {
      my($sign1, $nest1, $pos1) = split(',', $positions[$i]);
      next if ($sign1 ne '{{');
      for (my $j = $i + 1; $j < $N; ++$j) {
        my($sign2, $nest2, $pos2) = split(',', $positions[$j]);
        next if ($sign2 ne '}}' || $nest1 != $nest2);
        my $template = substr($text, $pos1, $pos2 - $pos1 + 2);
        #print "$template\n";
        push(@templates, $template);
        return $i + 1;
      }
    }
    return -1;
  }
  my $k = 0;
  do {
    $k = tie_templates($k);
  } while ($k != -1);
  return @templates;
}

sub parse_links($) {
  my ($text) = @_;
  $text =~ s/\[\[[^\|\[\]]+\|([^\[\]]+)\]\]/\1/g;
  $text =~ s/\[\[([^\[\]]+)\]\]/\1/g;
  return $text;
}

sub get_address($) {
  my ($text) = @_;
  my @templates = get_templates($text);
  for (@templates) {
    $_ = parse_links($_);
    next unless m/(?:[|]|{{)\s*[^|{}]*(?:所在地|都市)\s*=\s*([^|{}]+)/s;
    my $address = $1;
    $address =~ s/\s+//g;
    return $address;
  }
}

my $input = $ARGV[0];
open(IN, '<', $input) or die "$0: $!: $input";
my $page; { local $/ = undef; $page = <IN>; }
my $text = get_text($page);
my $address = get_address($text);
print "$address\n"