#!/usr/bin/python3

import sys
import fileinput

final = False
empty_line_printed = False
for token in fileinput.input():
    token = token.strip()
    if token == '':
        if empty_line_printed:
            continue
        empty_line_printed = True
        final = False
    elif len(token) == 1 and token in '.!?':
        final = True
    elif len(token) == 1 and token in '")':
        pass
    elif final:
        print()
        final = False
    print(token)
    empty_line_printed = False
        
