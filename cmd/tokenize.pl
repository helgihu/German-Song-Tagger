#!/usr/bin/perl

use warnings;
use strict;
use utf8::all;

while (<>) {
    chomp;
    next if /^<.*>$/ or /^$/; # ignorieren
    
    $_ = " $_ ";

    # HTML-Entities umwandeln
    s/\s+/ /g;
    s/&quot;/"/g;
    s/&lt;/</g;
    s/&gt;/>/g;
    s/&amp;/&/g;
    tr/’/'/;

    # Fortsetzungspunkte: seh,...aus
    s/ *(\.\.\.+) */ $1 /g;
    
    # Tokeninterne Interpunktion: Arzt.hilft
    s/([A-ZÄÖÜa-zäöüß]{2})([.,;!?])([A-ZÄÖÜa-zäöüß]{2})/$1 $2 $3/g;

    while (s/([a-zäöüßA-Z][^ 0-9]*)(\. )/$1 $2/g ||     # Satzpunkte abtrennen
	   s/([^ ])([,;:!?…"“)\]] )/$1 $2/g || # sonstige Interpunktion am Tokenende abtrennen
	   s/ ([\[("„“])([^ ])/ $1 $2/g)       # Klammern etc am Tokenanfang abtrennen
    {}

    # englische klitische Ausdrücke
    s/ (i|you|we|they)'(d|re|ve|ll) / $1 '$2 /gi;
    s/ (he|she|there)'(s) / $1 '$2 /gi;
    s/ (i)'(m) / $1 '$2 /gi;

    s/^ +//;  # Leerzeichen am Zeilenanfang löschen
    tr/ /\n/; # ein Token pro Zeile
    
    print "$_\n";
}
