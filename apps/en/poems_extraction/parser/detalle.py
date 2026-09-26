import json, sys, os
a, b, f = sys.argv[1], sys.argv[2], sys.argv[3]
A = json.load(open(os.path.join(a, f + '.json')))['sections']; B = json.load(open(os.path.join(b, f + '.json')))['sections']
k = lambda s: (s['title'], tuple(map(tuple, s['stanzas'])))
ka = {k(s) for s in A}; kb = {k(s) for s in B}
def show(s, tag):
    L = [l for st in s['stanzas'] for l in st]
    print('  %s %s | %d lines | %s ... %s' % (tag, s['title'][:50], len(L), L[0][:40] if L else '', L[-1][:50] if L else ''))
print('== only in base'); [show(s, '-') for s in A if k(s) not in kb]
print('== only in new'); [show(s, '+') for s in B if k(s) not in ka]
