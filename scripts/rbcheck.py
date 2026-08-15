# -*- coding: utf-8 -*-
"""Crude Ruby block-balance check for the scripts in this folder.

    python rbcheck.py              # every .rb here and in wr_tools/
    python rbcheck.py foo.rb       # just these

USE rbparse.py INSTEAD. It is a REAL parser and this one is not.

rbparse.py drives the CRuby 3.2 shared library that ships inside SketchUp, so
it gives a genuine parse — the same one SketchUp performs at load. This file
predates the discovery that that library could be driven from here, and it is
kept only because it needs nothing but Python and runs anywhere.

THIS IS NOT A PARSER AND WILL NOT CATCH A TYPO. It strips strings, heredocs and
comments, then matches block openers against `end`. That catches the one class
of error that actually happens when hand-editing a long file: a missing or
extra `end`. It cannot see a syntax error that happens to balance, and
`a = 1 +` followed by `end` balances perfectly.

A clean run means the blocks balance. It does not mean the script parses, and
it certainly does not mean the script works. Never report a clean run here as
evidence that a file is syntactically valid — run rbparse.py for that.
"""
import os
import re
import sys

SQ  = re.compile(r"'(?:\\.|[^'\\])*'")
DQ  = re.compile(r'"(?:\\.|[^"\\])*"')
CMT = re.compile(r'#.*$')
END = re.compile(r'(?<![.:\w])\bend\b')
HEREDOC = re.compile(r"<<[-~]?['\"]?(\w+)")

# A block opener is the keyword at the start of a line, or after an assignment
# or an opening bracket — `dir = case axis` and `@dlg ||= begin` both open one.
# A trailing modifier (`puts x if y`) matches none of those, which is the point.
OPEN = re.compile(
    r'(?:^|=\s*|\(\s*|\|\|\s*|&&\s*|\bthen\s+)'
    r'(module|class|def|begin|case|if|unless|while|until)\b'
)
DO = re.compile(r'\bdo\s*(\|[^|]*\|)?\s*$')


def check(path):
    stack, problems, here = [], [], None
    with open(path, encoding='utf-8') as fh:
        for n, raw in enumerate(fh, 1):
            if here:
                if raw.strip() == here:
                    here = None
                continue
            line = DQ.sub('""', SQ.sub("''", raw))
            m = HEREDOC.search(line)
            if m:
                here = m.group(1)
            line = CMT.sub('', line)
            s = line.strip()
            if not s:
                continue
            for m in OPEN.finditer(s):
                stack.append((m.group(1), n))
            if DO.search(s):
                stack.append(('do', n))
            for _ in END.finditer(s):
                if stack:
                    stack.pop()
                else:
                    problems.append((n, 'unmatched end'))
    return stack, problems


def main():
    args = sys.argv[1:]
    if not args:
        here = os.path.dirname(os.path.abspath(__file__))
        args = sorted(
            os.path.join(here, f) for f in os.listdir(here) if f.endswith('.rb')
        )
        sub = os.path.join(here, 'wr_tools')
        if os.path.isdir(sub):
            args += sorted(
                os.path.join(sub, f) for f in os.listdir(sub) if f.endswith('.rb')
            )

    bad = 0
    for path in args:
        stack, problems = check(path)
        ok = not stack and not problems
        bad += 0 if ok else 1
        print('%-34s %s' % (os.path.basename(path), 'balanced' if ok else '** CHECK **'))
        if stack:
            print('    unclosed: %s' % (stack[:6],))
        if problems:
            print('    problems: %s' % (problems[:6],))
    print('')
    print('%d file(s), %d to look at' % (len(args), bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
