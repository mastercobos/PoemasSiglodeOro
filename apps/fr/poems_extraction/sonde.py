#!/usr/bin/env python3
"""sonde.py PAGE... - what wikisource.py would see on a page: subpages, headed
verse segments, other article links. For choosing collections in recueils.py."""
import re, sys, urllib.parse
from wikisource import page_html, dom, liens, segments

for p in sys.argv[1:]:
    t, h = page_html(p)
    if h is None:
        print(f'== {p}: MISSING'); continue
    a = dom(h)
    sp = liens(h, t + '/')
    autres = []
    for n in a.iter():
        href = n.attrs.get('href') or ''
        if n.tag == 'a' and href.startswith('/wiki/') and 'redlink' not in href:
            x = urllib.parse.unquote(href[6:].split('#')[0]).replace('_', ' ')
            if ':' not in x.split('/')[0] and x not in autres and not x.startswith(t + '/'):
                autres.append(x)
    segs = segments(dom(h))
    print(f'== {p} -> {t}: {len(h)} B, {len(sp)} subpages, {len(segs)} segments, {len(autres)} other links, '
          f'{h.count("class=\"poem")} poem blocks, {len(re.findall(r"<h[1-6]", h))} headings')
    print('   sub:', sp[:5]); print('   seg:', [(s[0], len(s[1].splitlines()), len(s[2])) for s in segs[:6]]); print("   links:", autres[:8])
