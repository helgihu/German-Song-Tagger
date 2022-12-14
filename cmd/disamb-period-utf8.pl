#!/usr/bin/perl

use utf8::all;
use strict;
use Getopt::Std;

our($opt_f, $opt_g, $opt_h, $opt_d, $opt_a, $opt_c, $opt_n, $opt_o);
getopts('acdf:hnog');

my $ucchars = 'A-ZÀ-Þ';
my $lcchars = 'a-zß-ÿ';
if (defined $opt_g) {
  $ucchars = 'A-Z¶¸¹º¼¾¿À-Þ';
  $lcchars = 'a-zÜÝÞßýà-ýÞþ';
}


if (!defined($opt_f) || defined($opt_h)) {
    print "\nUsage: $0 [options] -f <parameter file> ...files...\n";
    print "\nOptions:\n";
    print "-d: Print sentence initial words in lowercase, if the word is usually written in lowercase.\n";
    print "-a: Assume by default that words which are followed by a period and a lowercase word are abbreviations\n";
    print "-c: Cut off periods at the end of numbers.\n";
    print "-n: Ignore name information for disambiguation.\n";
    print "-o: Autoflush the output stream.\n";
    die;
}

open(FILE, $opt_f) or die "\nCan't open parameter file: $opt_f\n";

$| = 1 if defined $opt_o;

# read the parameter file
my $flag = 0;
my(%abbrev, %abbrev_suffix, %lowerprob, %kuerzel, %FUC, %Name, %PUC, %BN);
while (<FILE>) {
    chomp;
    next if /^ *>>>.*<<< *$/;  # Ignore comments
    my @F = split;
    if (length == 0) {
	$flag++;
    }
    elsif ($flag == 0) {
	die "Wrong format in line:\n$_" unless $#F == 2;
	$abbrev{$F[0]} = 1 unless $F[0] =~ /^[$ucchars]$/;
    }
    elsif ($flag == 1) {
	die "Wrong format" unless $#F == 2;
	$abbrev_suffix{$F[0]} = 1;
    }
    elsif ($flag == 2) {
	die "Wrong format" if $#F < 1 || $#F > 2;
	$lowerprob{$F[0]} = $F[1];
    }
    elsif ($flag == 3) {
	die "Wrong format" unless $#F == 1;
	$kuerzel{$F[0]} = $F[1];
    }
    elsif ($flag == 4) {
	die "Wrong format" unless $#F == 1;
	$FUC{$F[0]} = $F[1];
	$Name{$F[0]} = 1;
    }
    elsif ($flag == 5) {
	die "Wrong format" unless $#F == 1;
	$PUC{$F[0]} = $F[1];
	$Name{$F[0]} = 1;
    }
    elsif ($flag == 6) {
	die "Wrong format" unless $#F == 1;
	$BN{$F[0]} = $F[1];
    } 
    else {
	die "Wrong format";
    }
}
close(FILE);

my($w0, $w1, $w2, $w3, $w4);
$w0 = $w1 = $w2 = "";
my $preceding_number = 0;
my $preceding_upper = 0;
my $preceding_period = 0;
my $is_sb = 0;
my $is_sb1 = 1;
my $number_count = 0;
my $old_number_count = 0;

sub print_token {
    
    $old_number_count = $number_count;
    $number_count = 0;
    my $preceding_sb = $is_sb1;
    $is_sb1 = $is_sb;
    $is_sb = 0;
    if ($w2 ne "") {
	if ($w2 ne ".") {
	    if ($w2 eq "...") {
		if (exists($abbrev{$w1})) {
		    print ".\n...";
		}
		else {
		    print "\n...";
		}
	    }
	    # print telephone numbers on one line
	    elsif ($old_number_count < 5 &&
		   (($w1 =~ /[0-9][0-9]*$/ &&    # preceding token is number
		     ($w2 =~ /^[0-9][0-9\/-]*\.?$/ ||   # current token is number
		      ($w2 =~ /^[-\/]$/ && $w3 =~ /^[0-9][0-9\/-]*\.?/)) # - number
		    ) ||
		    ($preceding_number && $w1 =~ /^[-\/]$/ && 
		     $w2 =~ /^[0-9][0-9\/-]*/))) {
		print " $w2";
		$number_count = $old_number_count+1;
	    }
	    elsif ($w1 ne "") {
		print "\n$w2";
	    }
	    else {
		print $w2;
	    }
	}
	elsif ($w1 =~ /[0-9]/ && $w1 !~ /[$ucchars$lcchars]/) {
	    # Numbers are not handled here
	    if (defined($opt_c)) {
		if ($w3 =~ /^[,;:\!?$lcchars]/) {
		    # : 1. ,
		    print ".";
		}
		else {
		    print "\n.";
		}
	    }
	    else {
		print ".";
	    }
	}

	# abbreviations which precede numbers
	elsif (exists($BN{$w1."."}) && $w3 =~ /^[0-9]/) {
	    # No. 1
	    print ".";
	}

	# title and name abbreviations
	elsif (!$opt_n &&
	       $w1 !~ /^[$ucchars]$/ &&   # not a single upper-case letter
	       exists($Name{$w1."."}) && 
	       exists($Name{$w3})) 
	{ # Mr. Jones
	    my $p1 = ($FUC{$w1."."} + 3)/($PUC{$w1."."} + 3);
	    my $p2 = ($PUC{$w3} + 3)/($FUC{$w3} + 3);
	    if ($p1 * $p2 > 5) {
		print ".\n.";  # sentence boundary
	    }
	    else {
		print ".";     # name
	    }
	}
	elsif (!$opt_n &&
	       $w1 !~ /^[$ucchars]$/ && 
	       exists($Name{$w1."."}) && 
	       ($w4 eq "." && exists($Name{$w3."."})))
	{ # U.S. Gen.
	    my $p1 = ($FUC{$w1."."} + 1)/($PUC{$w1."."} + 1);
	    my $p2 = ($PUC{$w3."."} + 1)/($FUC{$w3."."} + 1);
	    if ($p1 * $p2 > 10) {
		print ".\n.";  # sentence boundary
	    }
	    else {
		print ".";     # name
	    }
	}
	elsif (!$opt_n &&
	       $w1 !~ /^[$ucchars]$/ &&   # not a single upper-case letter
	       exists($Name{$w1."."}) && 
	       $w3 =~ /^[$ucchars]/ && !exists($lowerprob{$w3}))
	{ # Mr. Hlajdlasjl
	    my $p1 = ($FUC{$w1."."} + 3)/($PUC{$w1."."} + 3);
	    if ($p1 > 5) {
		print ".\n.";  # sentence boundary
	    }
	    else {
		print ".";     # name
	    }
	}
	elsif (!$opt_n &&
	       (exists($Name{$w1."."}) || $w1 =~ /^([$ucchars]\.)*[$ucchars]$/) && 
	       (exists($Name{$w3}) || ($w4 eq "." && 
				       (exists($Name{$w3."."}) || $w3 =~ /^([$ucchars]\.)*[$ucchars]$/))))
	{
	    # Mrs. Long
	    print ".";
	}
	elsif (!$opt_n &&
	       $w1 =~ /^[$ucchars]$/ &&
	       (exists($Name{$w0}) || $w0 =~ /^([$ucchars]\.)*[$ucchars]$/) &&
	       $w3 =~ /^[$ucchars]/) {
	    # Edward H. Able
	    print ".";
	}

	# other potential abbreviations
	else {

	    $w1 =~ s/^.*[-\/]([^0-9-])/\1/; # "Michael-Stumpf-Str" is mapped to "Str"
	    
	    if ($w1 =~ /^(\w\.)+\w$/ || 
		exists($abbrev{$w1}) ||
		exists($abbrev_suffix{lowercase(substr($w1,-5))}) ||
		exists($abbrev_suffix{lowercase(substr($w1,-4))}) ||
		exists($abbrev_suffix{lowercase(substr($w1,-3))}) ||
		exists($abbrev_suffix{lowercase(substr($w1,-2))}))
	    {
		if (($lowerprob{$w3} > 0.8 && $w4 ne ".")|| 
		    $w3 =~ /^<.*>$/ ||
		    ($w3 =~ /^[\'\`\"{}()¨´­«»-]*$/ && $lowerprob{$w4} > 0.8)) 
		{
		    print ".\n.";
		    if ($opt_d) {
			$w3 = lowercasefirst($w3);
		    }
		    $is_sb = 1;
		} 
		else {
		    print ".";
		}
	    } 
	    elsif ($w1 =~ /^[$ucchars$lcchars]$/) { # A. w
		if ($lowerprob{$w3} > 0.8 || $w3 =~ /^<.*>$/ ||
		    ($w3 =~ /^[\'\`\"{}()¨´­«»-]*$/ && $lowerprob{$w4} > 0.8)) {
		    # heuristic
		    if ($preceding_period) { # Frankfurt A. M. Auf
			print ".\n.";
			$is_sb = 1;
		    }
		    # heuristic
		    elsif ($preceding_number || $preceding_upper) {  # Klasse 10 B. Auf
			print "\n.";
			$is_sb = 1;
		    }
		    else { # Anhang A. Auf
			print "\n.";
			$is_sb = 1;
		    }
		    if ($opt_d) {
			$w3 = lowercasefirst($w3);
		    }
		} 
		else { # e. V.
		    print ".";
		}
	    }
	    elsif ($lowerprob{$w3} > 0.7 || $w3 =~ /^<.*>$/ ||
		   ($w3 =~ /^[\'\`\"{}()¨´­«»-]*$/ && $lowerprob{$w4} > 0.7)) {
		print "\n.";
		if ($opt_d) {
		    $w3 = lowercasefirst($w3);
		}
		$is_sb = 1;
	    }
	    elsif ($w1 =~ /^[BCDFGHJKLMNPQRSTVWX]?[bcdfghjklmnpqrstvwx]*$/) {
		print ".";  # no vowel
	    }
	    elsif ($w3 =~ /^[,;:?]$/) {  # following punctuation
		print ".";
	    }
	    elsif (defined($opt_a) &&
		   $w3 =~ /^[,;:$lcchars]/ && 
		   $w3 !~ /-[$ucchars]/ && !exists($kuerzel{$w3})) {
		print ".";
	    }
	    else {
		print "\n.";
		$is_sb = 1;
	    }
	}
    }
    
    if ($w1 eq ".") {
	$preceding_period = 1;
    }
    else {
	$preceding_period = 0;
    }

    if ($w1 =~ /^[0-9][0-9]*$/) {
	$preceding_number = 1;
    }
    elsif ($w1 !~ /^[\/-]$/) {
	$preceding_number = 0;
    }

    if ($w1 =~ /^[$ucchars]/ && !exists($lowerprob{$w1})) {
	$preceding_upper = 1;
    }
    else {
	$preceding_upper = 0;
    }

    if ($w2 =~ /^[\?\!:;]$/) {
	$is_sb = 1;
    }

    $w0 = $w1; 
    $w1 = $w2; 
    $w2 = $w3;
}

$w4 = <>;
chomp($w4);
while (<>) {
    chomp;
    tr/\240/ /;
    $w3 = $w4;
    $w4 = $_;
    print_token();
}

$w3 = $w4;
$w4 = "";
print_token();

$w3 = "";
print_token();
print "\n";

#############################
# case conversion functions #
#############################

sub lowercase {
    my $string=shift;

    $string =~ tr/A-Z¶¸¹º¼¾¿À-Þ/a-zÜÝÞßüýþà-þ/;
    return $string;
}

sub uppercase {
    my $string=shift;

    $string =~ tr/a-zÜÝÞßýà-ýÞþ/A-Z¶¸¹º¾À-Ý¹¿/;
    return $string;
}

sub lowercasefirst {
    my $string=shift;

    return lowercase(substr($string,0,1)).substr($string,1);
}

sub uppercasefirst {
    my $string=shift;

    return uppercase(substr($string,0,1)).substr($string,1);
}
