import json, sys, os
a, b = sys.argv[1], sys.argv[2]
for f in sorted(os.listdir(a)):
    A = json.load(open(os.path.join(a, f)))['sections']; B = json.load(open(os.path.join(b, f)))['sections']
    ka = {(s['title'], tuple(map(tuple, s['stanzas']))) for s in A}; kb = {(s['title'], tuple(map(tuple, s['stanzas']))) for s in B}
    solo_a = [s for s in A if (s['title'], tuple(map(tuple, s['stanzas']))) not in kb]
    solo_b = [s for s in B if (s['title'], tuple(map(tuple, s['stanzas']))) not in ka]
    print('%-26s base %4d  new %4d  changed: %d -> %d' % (f[:-5], len(A), len(B), len(solo_a), len(solo_b)))
