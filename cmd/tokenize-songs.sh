#!/bin/sh

cmd/tokenize.pl $*  |
    perl -pe 's/^$/<>/' |
    cmd/disamb-period-utf8.pl -a -f lib/german-tokenizer |
    perl -pe 's/^(.*[^0-9].*[0-9]+)\.$/$1\n\./' | 
    cmd/disamb-num-period-utf8.pl -f lib/german-tokenizer.num |
    cmd/split-apostrophies.py |
    cmd/mwl-lookup.pl -f lib/german-mwls.txt |
    perl -pe 's/^<>$//' |
    cmd/sentence-split.py

