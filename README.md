# Tagger and Lemmatizer for German Song Texts

This software can be used to annotate German song texts and other
texts of a colloquial style with part-of-speech and lemma information.

Tagging and lemmatization are done with an adapted version of the
RNNTagger. The tokenizer is able to deal with apostrophes which are
used as elision markers as in: für's irgend'nem

The software can be freely used for all non-commercial purposes.

### Installation

In order to use the software, you have to install Python, PyTorch, and Perl.
The software uses shell scripts which do not work on Windows systems.

Usage: ./german-song-tagger.sh your-input-file

The input file must be encoded in UTF-8. The output is sent to the screen.
