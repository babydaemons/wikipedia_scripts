#!/usr/bin/perl
use strict;
use constant MAX => 0x7FFFFFFF;

sub get_page($) {
  my ($input) = @_;
  open(my $in, '<', $input) or die "$0: $!: $input";
  my $page; { local $/ = undef; $page = <$in>; }
  close($in);
  return $page;
}

sub get_title($) {
  my ($page) = @_;
  $page =~ m|<title>(.+)</title>|s;
  return $1;
}

sub get_text($) {
  my ($page) = @_;
  my $prefix = '<text xml:space="preserve">';
  my $start = index($page, $prefix) + length($prefix);
  my $suffix = '</text>';
  my $end = index($page, $suffix);
  my $len = $end - $start;
  my $text = substr($page, $start, $len);
  $text =~ s|&gt;|>|gm;
  $text =~ s|&lt;|<|gm;
  $text =~ s|&amp;|&|gm;
  $text =~ s|&quot;|"|gm;
  $text =~ s|</?\s*br\s*/?\s*>| |gmi;
  $text =~ s|<span\s*[^<>]*>([^<>]+)</span>|\1|gi;
  $text =~ s|<div\s*[^<>]*>([^<>]+)</div>|\1|gi;
  $text =~ s|<font\*[^<>]*>([^<>]+)</font>|\1|gm;
  $text =~ s|<center>([^<>]+)</center>|\1|gm;
  $text =~ s|<ref[^<>]*>([^<>]+)</ref>||gm;
  $text =~ s|<ref\s+[^<>]+\s*/\s*>||gm;
  $text =~ s|<!--.+-->||gs;
  return $text;
}

sub tie_templates($$$$$) {
  my ($ref_positions, $ref_templates, $ref_text, $N, $k) = @_;
  for (my $i = $k; $i < $N; ++$i) {
    my($sign1, $nest1, $pos1) = split(/,/, $ref_positions->[$i]);
    next if ($sign1 ne '{{');
    for (my $j = $i + 1; $j < $N; ++$j) {
      my($sign2, $nest2, $pos2) = split(/,/, $ref_positions->[$j]);
      next if ($sign2 ne '}}' || $nest1 != $nest2);
      my $template = substr($$ref_text, $pos1, $pos2 - $pos1 + 2);
      #print "$template\n";
      push(@$ref_templates, $template);
      return $i + 1;
    }
  }
  return -1;
}

sub get_templates($) {
  my ($text) = @_;
  my @positions = ();
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

  my $N = scalar(@positions);
  my $k = 0;
  my @templates = ();
  do {
    $k = tie_templates(\@positions, \@templates, \$text, $N, $k);
  } while ($k != -1);
  return @templates;
}

sub parse_links($) {
  my ($text) = @_;
  $text =~ s/\[\[(?:ファイル|File):[^\[\]]+\]\]//g;
  $text =~ s/\[\[[^\|\[\]]+\|([^\[\]]+)\]\]/\1/g;
  $text =~ s/\[\[([^\[\]]+)\]\]/\1/g;
  $text =~ s|\[http://\S+ (\S+?)\]|\1|g;
  return $text;
}

sub get_address($) {
  my ($ref_templates) = @_;
  for (@$ref_templates) {
    $_ = parse_links($_);
    next unless m/(?:[|]|{{)\s*[^|{}]*(?:所在地|都市)\s*=\s*([^|{}]+)/s;
    my $address = $1;
    $address =~ s/\s+/ /g;
    $address =~ s/(^\s+|\s+$)//g;
    $address =~ s/【.*?】//g;
    $address =~ s/（.*?）//g;
    $address =~ s/＜.*?＞//g;
    $address =~ s/'''.+?'''//g;
    $address =~ s/''.+?''//g;
    $address =~ s/〒\d{3}-\d{4}//g;
    $address =~ s|<ref\s*?>.+?</ref>||gi;
    $address =~ s/(^\s+|\s+$)//g;
    return $address;
  }
  return "";
}

for my $input (@ARGV) {
  my $page = get_page($input);
  my $title = get_title($page);
  my $text = get_text($page);
  my @templates = get_templates($text);
  my $address = get_address(\@templates);
  print "$input\t$title\t$address\n" if $address ne "";
}
