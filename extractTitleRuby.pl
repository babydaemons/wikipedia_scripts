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
  $text =~ s/&gt;/</gm;
  $text =~ s/&lt;/>/gm;
  $text =~ s/&amp;/&/gm;
  return $text;
}

sub parse_links($) {
  my ($text) = @_;
  $text =~ s/\[\[[^\|\[\]]+\|([^\[\]]+)\]\]/\1/g;
  $text =~ s/\[\[([^\[\]]+)\]\]/\1/g;
  return $text;
}

sub get_content($$$) {
  my ($text, $prefix, $suffix) = @_;
  my $start = index($text, $prefix);
  return "" if $start == -1;
  $start += length($prefix);
  my $end = index($text, $suffix, $start);
  return "" if $end == -1;
  return substr($text, $start, $end - $start);
}

sub get_title_ruby($$) {
  my ($text, $title) = @_;
  $text = parse_links($text);
  $title =~ s/[_ ]\([^\(\)_ ]+\)$//;
  my $key = "'''" . $title . "'''";
  my $target = get_content($text, $key, '。');
  my $title_ruby = get_content($target, '（', '）');
  $title_ruby = get_content($target, '(', ')') if ($title_ruby eq "");
  $title_ruby = $1 if ($title_ruby =~ m/'''(.+)'''/);
  $title_ruby = $1 if ($title_ruby eq "" && $text =~ m/{デフォルトソート:([^{}]+)}/m);
  return $title_ruby;
}

my $page = get_page($ARGV[0]);
my $title = get_title($page);
my $text = get_text($page);
my $title_ruby = get_title_ruby($text, $title);
print "$title_ruby\n"
