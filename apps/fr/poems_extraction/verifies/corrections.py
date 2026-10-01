"""The corrections behind verifies/*.txt: each hand-checked poem is its
Wikisource OCR (corpus/cache/non_relus.json, dumped by wikisource.py) with
these fixes, each read off the poem's scan pages (listed in the report's
"Checked by hand" section and in non_relus.json's `scans`). Every fix must
match exactly once. Run from poems_extraction/; writes only the files that
are missing, since once a poem is let in it leaves non_relus.json.

    python3 verifies/corrections.py
"""
import json,re
N=json.load(open('corpus/cache/non_relus.json'))
nb=lambda s: re.sub(r' ([:;!?»])',' \\1',s)
FIX=[
 ('Ronsard','Quand vous serez bien vieille','ronsard-quand-vous-serez-bien-vieille.txt',
  [('vieille accroupie.','vieille accroupie,')]),
 ('Ronsard','Comme on voit sur la branche','ronsard-comme-on-voit-sur-la-branche.txt',
  [('d’odeur :\n\nMais','d’odeur :\nMais'),('honoraient','honoroient')]),
 ('Ronsard','Je vous envoye un bouquet','ronsard-je-vous-envoye-un-bouquet.txt',
  [("Que j'ai ourdy","Que j'ay ourdy"),('epanies:','epanies,'),('ma Dame:\n\nLas!','ma Dame,\nLas!'),("morts n'en","morts, n'en")]),
 ('Ronsard','Je n’ay plus que les os','ronsard-je-n-ay-plus-que-les-os.txt',
  [('despoûillé','despoüillé'),('mouillé','moüillé')]),
 ('Ronsard','O Fontaine Bellerie','ronsard-o-fontaine-bellerie.txt',
  [('la Mémoire\n\nQue','la Memoire\nQue'),('ne brûle.','ne brule,'),('et drue','et druë'),('des parcs.','des parcs,'),('Moy célébrant','Moy celebrant'),('rocher perse,','rocher persé,')]),
 ('Ronsard','Quand je suis vingt ou trente mois','ronsard-quand-je-suis-vingt-ou-trente-mois.txt',
  [('vagabondes.','vagabondes,'),('souci.','souci,'),('ainsi.','ainsi,'),('jeunesse fuit.','jeunesse fuit,'),('qui me suit.','qui me suit,'),('d’après','d’apres'),('se renouvelle.','se renouvelle,'),('les genous.','les genous,'),('le mur »','le mur'),('promenez.','promenez,'),('ne séjourne','ne sejourne'),('long séjour','long sejour'),('de jour.','de jour,'),('ou bois.','ou bois,')]),
 ('Hugo','Oh ! combien de marins','hugo-oceano-nox.txt',
  [('l’esquif','l’esqüif'),('Ô flots','O flots')]),
 ('Hugo','Puisque j’ai mis ma lèvre','hugo-puisque-j-ai-mis-ma-levre.txt',
  [('encor pleine ;','encor pleine,'),('front pâli ;','front pâli,'),('l’ombre enseveli ;','l’ombre enseveli,'),('mystérieux ;','mystérieux,'),('voilé toujours ;','voilé toujours,'),('à tes jours ;','à tes jours,'),('- Passez ! Passez toujours','— Passez ! passez toujours'),('à vieillir ;','à vieillir !')]),
 ('Hugo','XLIII\n\nL’été, lorsque le jour','hugo-nuits-de-juin.txt',
  [('XLIII\n\n',''),('entrouverte','entr’ouverte')]),
 ('Hugo','X\n\nDans les vieilles forêts','hugo-a-albert-durer.txt',
  [('X\n\nDans','Dans'),('pensif !\n\nOn','pensif !\nOn'),('Ô mon maître Albert Dure','O mon maître Albert Düre'),('Ô végétation','O végétation'),('erré,\n\nMaître','erré,\nMaître'),('remplissent les bois\n\n20 avril 1837','remplissent les bois.')]),
 ('Hugo','XXXIV\n\nTRISTESSE','hugo-tristesse-d-olympio.txt',
  [("XXXIV\n\nTRISTESSE D'OLYMPIO\n\n",''),("l’amour,\n\nEt, remuant","l’amour,\nEt, remuant"),
   ('sautent le fossé !','sautent le fossé.'),('du tombeau ;','du tombeau,'),('vous pourriez','vous pourrez'),
   ('profonds et sourds\n','profonds et sourds,\n'),('nos amours !\n','nos amours ;\n'),('par les larmes ;','par les larmes.'),
   ('sous un voile…','sous un voile… —'),('souvenir ! "','souvenir !\u00a0»'),('Ô douleur','O douleur'),('Ô nature abritée','O nature abritée'),
   ('\n"Mais toi','\n«\u00a0Mais toi'),('REPLACE_QUOTES','')]),
 ('Hugo','Jeanne était au pain sec','hugo-jeanne-etait-au-pain-sec.txt',
  [('de la société\n','de la société,\n'),('voix douce :\n\n—','voix douce :\n—'),('À chaque instant','A chaque instant')]),
 ('Ronsard','Marie, levez-vous','ronsard-marie-levez-vous.txt', []),
]
for a,start,f,fx in FIX:
    h=[p for p in N if a in p['autor'] and (p['texto'].startswith(start) or p['texto'].startswith(nb(start)))]
    import os
    if os.path.exists('verifies/'+f): continue
    assert h,(a,start); p=h[0]; t=p['texto']
    for old,new in fx:
        if old == 'REPLACE_QUOTES':  # the opening quote of each stanza, printed «
            t = re.sub(r'(?m)^" ', '«\u00a0', t)
            continue
        if old not in t: old,new=nb(old),nb(new)
        n=t.count(old); assert n==1,(f,old,n)
        t=t.replace(old,new)
    open('verifies/'+f,'w').write(t+'\n'); print(f, len(t.split('\n')),'lines |',p['titulo'])
