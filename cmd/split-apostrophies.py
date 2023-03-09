#!/usr/bin/python3

import sys
from collections import defaultdict, Counter
import fileinput

# replacements operations for '
apo_prob = {" da":1, " eine":1,
            " e":0.01, " ei":0.01, " de":0.01, "e ":0.01, "e":0.01, "ei":0.01, "e e":0.01,
            "'":0.0001}
# input of the data (1 token per line)
all_tokens = [line.rstrip() for line in fileinput.input()]


### tokenizer training    

# non-empty tokens    
tokens = [token.lower() for token in all_tokens if token]
pair_freq = Counter(zip([''] + tokens, tokens + ['']))

def estimate_prob(freq):
    total = sum(freq.values())
    prob = {elem: f/total for elem, f in freq.items()}
    return defaultdict(float, prob)

def compute_discount(freq):
    N1, N2 = 0, 0
    for f in freq.values():
        if f <= 1:
            N1 += 1
        elif f <= 2:
            N2 += 1
    return N1 / (N1 + 2 * N2)

def estimate_probs(pair_freq, apo_freq=None):

    # prior word probabilities
    word_freq = defaultdict(int)
    for (_, word), f in pair_freq.items():
        word_freq[word] += f
    
    # discounting
    discount = compute_discount(word_freq)
    discounted_freq = {word: max(0.01, f-discount) for word, f in word_freq.items()}
    word_prob = estimate_prob(discounted_freq)

    # estimation of conditional probabilities using Kneser-Ney smoothing
    context_freq = defaultdict(int)
    for (word, _), f in pair_freq.items():
        context_freq[word] += f
    discount = compute_discount(pair_freq)
    cond_prob = defaultdict(float)
    for (x,y), f in pair_freq.items():
        if f > discount:
            cond_prob[x,y] = (f - discount) / context_freq[x]
    
    # computation of backoff factors
    backoff = defaultdict(lambda: 1.0)
    for (x,y), p in cond_prob.items():
        backoff[x] -= p

    # estimation of backoff probabilities
    backoff_freq = defaultdict(int)
    for (x,y) in pair_freq:
        backoff_freq[y] += 1  # Kneser-Ney smoothing
    backoff_prob = estimate_prob(backoff_freq)

    if apo_freq is None:
        return word_prob, cond_prob, backoff, backoff_prob

    # computation of the replacement probabilities
    for seq in apo_freq:
        freq = sum(apo_freq[seq].values())  # expected frequency of x ' y
        total = 0.0                         # expected frequency of x seq y and x ' y
        for elem, f in apo_freq[seq].items():
            if ' ' in seq:
                elem1, elem2 = elem.split(' ')
                total += pair_freq[elem1, elem2]
            else:
                total += word_freq[elem]
        apo_prob[seq] = freq / total
    return word_prob, cond_prob, backoff, backoff_prob, apo_prob


# initial M step
word_prob, cond_prob, backoff, backoff_prob = estimate_probs(pair_freq)

# computation of the probability of a replacement operation
def get_prob(elem):
    elem = elem.lower()
    if elem in word_prob: # always true after the first EM iteration
        return word_prob[elem]
    if ' ' not in elem:
        return 0.0
    e1, e2 = elem.split(" ")
    p = word_prob[e1] * (cond_prob[e1, e2] + backoff[e1] * backoff_prob[e2])
    return p

for _ in range(2): # EM iterations

    # E-step: computation of expected frequencies
    # for words, word pairs and replacement operations
    apo_freq = {seq: defaultdict(float) for seq in apo_prob}
    pair_freq = defaultdict(float)
    prev = ''  # previous token for counting word pair frequencies
    for token in tokens:
        elems = token.split("'")
        if len(elems) == 1 or elems[0] == "" or elems[-1] == "":
            pair_freq[prev, token] += 1
        else:
            # compute the posterior probability of each replacement operation
            elem1 = "'".join(elems[:-1])
            elem2 = elems[-1]
            option_prob = {seq: get_prob(elem1 + seq + elem2) * apo_p
                           for seq, apo_p in apo_prob.items()}
            total = sum(option_prob.values())
            option_prob = {seq: p / total for seq, p in option_prob.items()}
            for seq, p in option_prob.items():
                elem = elem1 + seq + elem2
                apo_freq[seq][elem] += p
                parts = elem.split(" ")
                if len(parts) == 1:
                    pair_freq[prev, elem] += p
                else:
                    e1, e2 = parts
                    pair_freq[prev, e1] += p
                    pair_freq[e1, e2] += p
        prev = token  # problematic if previous token contains an apostrophe

    # M Step
    word_prob, cond_prob, backoff, backoff_prob, apo_prob = estimate_probs(pair_freq, apo_freq)
    
### tokenization
for token in all_tokens:
    elems = token.split("'")
    if len(elems) == 1 or elems[0] == "" or elems[-1] == "":
        print(token)
    else:
        elem1 = "'".join(elems[:-1])
        elem2 = elems[-1]
        option_prob = {seq: get_prob(elem1 + seq + elem2) * apo_p
                       for seq, apo_p in apo_prob.items()}
        best_seq = max(option_prob.keys(), key=option_prob.get)
        if best_seq[0] == ' ':
            print(f"{elem1}\n'{elem2}")
        elif best_seq[-1] == ' ':
            print(f"{elem1}'\n{elem2}")
        elif ' ' in best_seq:
            print(f"{elem1}'\n'{elem2}")
        else:
            print(token)
        
