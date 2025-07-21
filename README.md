# XMLParser
**Script shell** care citeste un fisier din, respectiv in format **XML**.
## Motivatia
Acest script a fost realizat ca un exercitiu, atat pentru scriptarea in shell, cat si pentru utilizarea 
expresiilor regulate (RegEx) pentru a parsa, substitui si extrage continut text dupa formatul standard XML.
## Scopul
Scopul acestui script este sa primeasca ca input numele unui fisier de tip XML aflat pe sistem, ca apoi
sa-l „parseze” intr-o structura definita de noi, care apoi va fi folosita pentru a reconstrui continutul
fisierului.
## Functionalitate
- Scriptul a fost conceput sa mearga pe orice tip de shell care respecta standardul POSIX. In
alte cuvinte, este portabil.
- Modul in care scriptul primeste argumente este unul conventional, definit de Ghidul de Sintaxa pentru
Argumente Utilitare POSIX (POSIX Utility Argument Syntax Guidelines), care permite utilizatorilor sa
foloseasca atat switch-uri pentru a schimba comportamentul programului (ex: -h, -g, -q, -gq, -o
output.xml) cat si argumente pozitionale (ex: xml_file1.xml xml_file2.xml … xml_fileN.xml).
- Astfel, poate fi utilizat fara a fi nevoie de inputul utilizatorului in timpul rularii programului (poate fi
utilizat fara probleme prin piping, de la STDIN la STDOUT)
- Scriptul poate fi utilizat pe post de „pretty printer”, pentru a reformata fisierul primit ca input intr-un
mod foarte lizibil pentru oameni (cu indentari, formatarea atributelor, eliminarea liniilor goale
s.a.m.d.), prin reconstruirea fisierului dupa reprezentarea interna (parsarea a eliminat posibilele
formatari problematice)
## Mecanisme software / algoritmi folositi
- Fisierul XML a fost mai intai pre-procesat:
Toate indentarile (si spatii inutile de la final) au fost curatate, iar continutul tagurilor (ex: <tag>text</tag>) a fost pus pe o linie
separata. Astfel, dintr-un fisier de forma:
```xml
<tag1>
<tag2>text</tag2>
</tag1>
```
Dupa pre-procesare, a ajuns de forma
```xml
<tag1>
<tag2>
text
</tag2>
</tag1>
```
Astfel, continutul de pe linii este foarte predictibil si usor de parcurs liniar
- Apoi, linie cu linie, s-a construit un arbore de sintaxa (evident sub forma de string) prin tokenizarea elementelor de pe
linii separate, avand structura unei liste de adiacenta
- Exemplu: pentru fisierul de mai sus, graful va arata asa:
```
tag1[]: tag2[ _text="text"]
tag2[ _text="text"]:
```
( caracterul : de fapt delimiteaza tatal de copiii lui )
- Odata ce acest arbore a fost construit si se afla in memorie, pentru ca fisierul XML sa fie reconstruit, arborele este parcurs in adancime.
