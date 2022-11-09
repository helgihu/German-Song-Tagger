#!/bin/sh

TMP=/tmp/rnn-tagger$$

cmd/tokenize-songs.sh $1 > $TMP.tok
python3 PyRNN/rnn-annotate.py lib/german-tagger $TMP.tok > $TMP.tagged
cmd/reformat.pl $TMP.tagged > $TMP.reformatted
python3 PyNMT/nmt-translate.py --print_source lib/german-lemmatizer $TMP.reformatted > $TMP.lemmas
cmd/lemma-lookup.pl $TMP.lemmas $TMP.tagged 

rm $TMP.tok  $TMP.tagged  $TMP.reformatted $TMP.lemmas
