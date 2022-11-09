#!/usr/bin/perl

use Getopt::Std;
use strict;
use utf8::all;

our($opt_d, $opt_h, $opt_f);
getopt('dhf:');

# This perl script recognizes multi word units in the input stream
# and puts them on one line. Input must have one-word-per-line format.
# The multi word units are listed in the parameter file with POS tags.
# Each line contains one multi word unit where the individual words
# are separated by blanks followed by a tab character and the blank-
# separated list of POS tags.
# Author: Helmut Schmid, IMS, Uni Stuttgart

if (!defined($opt_f) || defined($opt_h)) {
    $0 =~ s/.*\///;
    print "
Usage: $0 [-d del] -f mwl-file ...files...

Options:
-d del : Use del as delimiter rather than a blank

";
  die;
}

open(FILE, $opt_f) or
    die "\nCan't open mwl file: ",$opt_f,"\n";
my $del = (defined($opt_d))? $opt_d : " ";

my(%arc, %final);
my $N = 1;
while (<FILE>) {
  chomp();
  my @G = split("\t");
  my @F = split(/\s+/,$G[0]);
  my $state = 0;
  for(my $i=0; $i<=$#F; $i++) {
    if (!exists($arc{$state,$F[$i]})) {
      $arc{$state,$F[$i]} = $N++;
    }
    $state = $arc{$state,$F[$i]};
   }
  $final{$state} = $G[1];
}
close(FILE);

my($last, $match, $last_match);
$last = $match = $last_match = 0;
my $state = 0;
my @token;
for (;;) {
  if ($match == $last) {
      if (!($token[$last] = <>)) {
	  my $i;
      if ($last_match > 0) {
	print $token[0];
	for ($i=1; $i<=$last_match; $i++) {
	  print $del,$token[$i];
	}
	print "\n";
      } else {
	$i=0;
      }
      for (; $i<$last; $i++) {
	print $token[$i],"\n";
      }
      last;
    }
    chomp($token[$last++]);
  }
  my($s, $last_tag);
  if (($s = $arc{$state, $token[$match]}) ||
      ($s = $arc{$state, lc($token[$match])}) ||
      ($s = $arc{$state, ucfirst(lc($token[$match]))})) {
    if (exists($final{$s})) {
      $last_match = $match;
      $last_tag = $final{$s};
    }
    $state = $s;
    $match++;
  } else {
    if ($last_match > 0) {
      print $token[0];
      for(my $i=1; $i<=$last_match; $i++) {
	print $del,$token[$i];
      }
      print "\t$last_tag" if $last_tag ne '';
      print "\n";
    } else {
      print $token[0],"\n";
    }
    for(my $i=0, my $k=$last_match+1; $k<$last; ) {
      $token[$i++] = $token[$k++];
    }
    $last = $last - $last_match - 1;
    $last_match = $match = 0;
    $state = 0;
  }
}
