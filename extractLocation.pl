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

sub get_location($) {
  my ($text) = @_;
  my @templates = get_templates($text);
  for (@templates) {
    $_ = parse_links($_);
    if (m/^{{(?:ウィキ座標.*?|[Cc]oord|[Cc]oor\s+(?:title\s+)?dms)\|(\d+)\|(\d+)\|([\d\.]+)\|([NS])\|(\d+)\|(\d+)\|([\d\.]+)\|([EW])\|.*}}$/s) {
      my $lat = $1 + ($2 / 60) + ($3 / 3600); $lat = -$lat if $4 eq 'S';
      my $lng = $5 + ($6 / 60) + ($7 / 3600); $lng = -$lng if $8 eq 'W';
      return "$lat\t$lng";
    }
    if (m/^{{日本の位置情報\|(\d+)\|(\d+)\|([\d\.]+)\|(\d+)\|(\d+)\|([\d\.]+)\|.*}}$/s) {
      my $lat = $1 + ($2 / 60) + ($3 / 3600);
      my $lng = $4 + ($5 / 60) + ($6 / 3600);
      return "$lat\t$lng";
    }
    if (m/^{{(?:[Cc]oord|Mapplot)\|(-?\d+\.\d+)\|(-?\d+\.\d+)\|.*}}$/s) {
      my $lat = $1;
      my $lng = $2;
      return "$lat\t$lng";
    }
    if (m/^{{[Cc]oord\|(-?\d+\.\d+)\|[NS]\|(-?\d+\.\d+)\|[EW]\|.*}}$/s) {
      my $lat = $1; $lat = -$lat if $2 eq 'S';
      my $lng = $3; $lng = -$lng if $4 eq 'S';
      return "$lat\t$lng";
    }
    if (m/^{{[Cc]oord\|(\d+)\|([\d\.]+)\|([NS])\|(\d+)\|([\d\.]+)\|([EW])\|.*}}$/s) {
      my $lat = $1 + ($2 / 60); $lat = -$lat if $3 eq 'S';
      my $lng = $4 + ($5 / 60); $lng = -$lng if $6 eq 'W';
      return "$lat\t$lng";
    }
    next unless m/(?:緯度度|lat_deg)\s*=\s*(-?\d+)/s;
    my $lat_deg = $1;
    next unless m/(?:経度度|lon_deg)\s*=\s*(-?\d+)/s;
    my $lng_deg = $1;
    my $lat_min = (m/(?:緯度分|lat_min)\s*=\s*([\d\.]+)/s) ? $1 : 0;
    my $lng_min = (m/(?:経度分|lon_min)\s*=\s*([\d\.]+)/s) ? $1 : 0;
    my $lat_sec = (m/(?:緯度秒|lat_sec)\s*=\s*([\d\.]+)/s) ? $1 : 0;
    my $lng_sec = (m/(?:経度秒|lon_sec)\s*=\s*([\d\.]+)/s) ? $1 : 0;
    my $lat_dir = (m/(?:N\(北緯\)及びS\(南緯\)|lat_dir)\s*=\s*([NS])/s && $1 eq 'S') ? -1 : 1;
    my $lng_dir = (m/(?:E\(東経\)及びW\(西経\)|lon_dir)\s*=\s*([EW])/s && $1 eq 'S') ? -1 : 1;
    my $lat = $lat_dir * ($lat_deg + ($lat_min / 60) + ($lat_sec / 3600));
    my $lng = $lng_dir * ($lng_deg + ($lng_min / 60) + ($lng_sec / 3600));
    return "$lat\t$lng";
  }
  return "";
}

for my $input (@ARGV) {
  my $page = get_page($input);
  my $title = get_title($page);
  my $text = get_text($page);
  my $location = get_location($text);
  print "$input\t$title\t$location\n" if $location ne "";
}
