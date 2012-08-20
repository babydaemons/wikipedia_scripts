#!/usr/bin/perl

my $input = $ARGV[0];
open(IN, '<', $input) or die "$0: $!: $input";
my $outdir_root = $input; $outdir_root =~ s/\.xml$//;
mkdir $outdir_root unless -d $outdir_root;
my $outdir_base = "$outdir_root/%04d";
my $output_base = "$outdir_base/%04d.xml";

my $i = 0;
my @lines;
while (<IN>) {
  s/  </</;
  if ($_ eq "<page>\n") {
    @lines = ();
  }
  push(@lines, $_);
  if ($_ eq "</page>\n") {
    my $n = int($i / 10000);
    my $m = int($i % 10000);
    my $outdir = sprintf($outdir_base, $n);
    my $output = sprintf($output_base, $n, $m);
    mkdir $outdir unless -d $outdir;
    open(OUT, '>', $output) or die "$0: $!: $output";
    print OUT join("" => @lines);
    ++$i;
    @lines = ();
  }
}
