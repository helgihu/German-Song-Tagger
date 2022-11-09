#!/usr/bin/python3

import sys
from collections import defaultdict, Counter
import fileinput

# replacements operations for '
op_prob = {op: 0.125 for op in ("e","e "," e"," ei"," eine"," de"," da","ei")}
op_prob["'"] = 0.00001  # preference for replacing '

# input of the data
all_tokens = [line.rstrip() for line in fileinput.input()]

# non-empty tokens    
tokens = [token.lower() for token in all_tokens if token]

# estimation of word and word pair probabilities
freq = Counter(tokens)
N = sum(freq.values())
prob = defaultdict(float, {x: f/N for x, f in freq.items()})

# estimation of conditional probabilities using Kneser-Ney smoothing
freq2 = Counter(zip(tokens[:-1], tokens[1:]))
N1 = sum(1 for f in freq2.values() if f == 1)
N2 = sum(1 for f in freq2.values() if f == 2)
discount = N1 / (N1 + 2 * N2)
cond_prob = {(x,y): (f - discount) / freq[x] for (x,y), f in freq2.items()}
cond_prob = defaultdict(float, cond_prob)
backoff = defaultdict(lambda: 1.0)
for (x,y), p in cond_prob.items():
    backoff[x] -= p
freq1 = defaultdict(int)
for (x,y) in freq2:
    freq1[y] += 1
total = sum(freq1.values())
backoff_prob = defaultdict(float, {y: f/total for y, f in freq1.items()})

# computation of the probability of a replacement operation
def get_prob(elem):
    elem = elem.lower()
    if elem in prob: # always true after the first EM iteration
        return prob[elem]
    if ' ' not in elem:
        return 0.0
    e1, e2 = elem.split(" ")
    p = prob[e1]
    p *= cond_prob[e1, e2] + backoff[e1] * backoff_prob[e2]
    return p

def increment_freq(elem, f):
    freq[elem.lower()] += p

prev = ''  # previous token for counting word pair frequencies

for _ in range(2): # EM iterations
    
    # E-step: computation of expected frequencies
    # for words, word pairs and replacement operations
    freq = defaultdict(float)
    op_freq = defaultdict(float)
    for token in tokens:
        elems = token.split("'")
        if len(elems) == 1 or elems[0] == "" or elems[-1] == "":
            increment_freq(token, 1)
            increment_freq(f"{prev} {token}", p)
        else:
            elem1 = "'".join(elems[:-1])
            elem2 = elems[-1]
            option_prob = {op: get_prob(elem1 + op + elem2) * op_p
                           for op, op_p in op_prob.items()}
            total = sum(option_prob.values())
            for op, p in option_prob.items():
                elem = elem1 + op + elem2
                p /= total # normalize the probabilities to sum to 1
                op_freq[op] += p
                parts = elem.split(" ")
                if len(parts) == 1:
                    increment_freq(elem, p)
                    increment_freq(f"{prev} {elem}", p)
                else:
                    e1, e2 = parts
                    increment_freq(e1, p)
                    increment_freq(e2, p)
                    increment_freq(f"{e1} {e2}", p)
                    increment_freq(f"{prev} {e1}", p)
                prev = parts[-1]
    # M-step
    total = sum(op_freq.values())
    op_prob = {op: f/total for op, f in op_freq.items()}
    prob = {x: f/N for x, f in freq.items()}

# tokenization    
for token in all_tokens:
    elems = token.split("'")
    if len(elems) == 1 or elems[0] == "" or elems[-1] == "":
        print(token)
    else:
        elem1 = "'".join(elems[:-1])
        elem2 = elems[-1]
        option_prob = {op: get_prob(elem1 + op + elem2) * op_p
                       for op, op_p in op_prob.items()}
        best_option = max(option_prob.keys(), key=option_prob.get)
        if best_option[0] == ' ':
            print(f"{elem1}\n'{elem2}")
        elif best_option[-1] == ' ':
            print(f"{elem1}'\n{elem2}")
        else:
            print(token)
        
