# Corpus provenance

Everything here is MIT (see [LICENSE](../LICENSE)). The music and texts are in the public domain; every file was re-encoded by us from tune data in [generate-corpus.py](generate-corpus.py). Nothing is copied from another corpus or edition: no CPDL files, no music21 corpus files. music21 is used only to check what the script wrote (below). Regenerate with the script rather than hand-edit:

```sh
uv run --with music21==10.5.2 python -I corpus/generate-corpus.py
```

The corpus holds 34 MusicXML files: 30 distinct public-domain tunes, three of them also in a second layout (a hand-split hymn and the same hymn in hymnal layout), plus a four-part hymnal setting of the tune of the `amazing-grace` lead sheet.

| File | Source | Version | SPDX | How |
|------|--------|---------|------|-----|
| the 22 files marked *score-backend-musicxml 0.1.0* in the table below | that backend's MIT corpus (`tests/fixtures/corpus/`), written by its `generate-sc2.py` | score-backend-musicxml 0.1.0 (commit 6b46d92 of the script) | MIT | `generate-corpus.py` carries that script's tune data and corpus writer and writes 21 of them byte for byte. `old-hundredth.musicxml` differs: the backend's copy repeats the soprano's hairpin in the other three voices, because the script there gave the events of every voice the same ids; here each voice's ids are its own, so the hairpin is the soprano's only. |
| the files marked *new* | public-domain tunes and texts named below, re-encoded by us; harmonies, bass lines, chord symbols and structure marks ours | — | MIT | `generate-corpus.py`, `NEW_TUNES` and `SHARED` |
| `adeste-fideles.mxl`, `jingle-bells.mxl` | the `.musicxml` of the same name in a compressed archive as other programs write one: deflated entries, a PDF rendition listed first in `container.xml`, the score under `music/` | — | MIT | `generate-corpus.py` (`mxl_archive`), with Python's `zipfile` |
| `facts.sexp` | per file, what score-parity's facet rules give for it (voice lines, lyric lines, chord-symbol onsets, bar lengths, features; for hymns the four voice lines of the hand-split tune) | music21 10.5.2 (checker only) | MIT (generated facts) | `generate-corpus.py`, a second implementation of `src/facets.lisp` on its own model of each file. It stops unless music21 reads, per part, the same sounding notes (ties merged), lyrics, measure lengths and chord-symbol onsets. |

Melodies are first phrases, re-encoded from memory of the public-domain tunes. Structure marks some pieces carry (the endings of *Jingle Bells*, the D.S. al Fine of *Aura Lee*, the repeats of the *Minuet in G* and *The Irish Washerwoman*, the D.S. al Coda of *Camptown Races*, the endings of *Yankee Doodle*, the key change of *Hymn to Joy*, the meter changes of *Shenandoah*) are ours, there to exercise the backends. Every text is Latin-1, the character set of MIDI text events.

Hymnal layout (`shared_stems`): per staff and measure, the two voices of a four-part tune become shared-stem chords where their rhythms agree (a single note where they sing the same pitch) and stay two voices where they don't. The facts give, for every hymn, the four lines of the hand-split tune, which a hymnal split must recover.

| Corpus file | Piece and source | Origin |
|-------------|------------------|--------|
| `adeste-fideles.musicxml` | *Adeste Fideles*: John Francis Wade (c. 1751); English text Frederick Oakeley (1841); harmony ours; hymnal layout (shared stems) | new |
| `amazing-grace.musicxml` | *Amazing Grace*: tune New Britain (1829); text John Newton (1779) | score-backend-musicxml 0.1.0 |
| `auld-lang-syne.musicxml` | *Auld Lang Syne*: Scots traditional tune; text Robert Burns (1788) | score-backend-musicxml 0.1.0 |
| `aura-lee.musicxml` | *Aura Lee*: George R. Poulton (1861); text W. W. Fosdick (1861) | new |
| `battle-hymn.musicxml` | *Battle Hymn of the Republic*: tune attributed to William Steffe (c. 1856); text Julia Ward Howe (1861) | new |
| `camptown-races.musicxml` | *Camptown Races*: Stephen Foster (1850) | score-backend-musicxml 0.1.0 |
| `clementine.musicxml` | *Oh My Darling, Clementine*: Percy Montrose (1884) | new |
| `frere-jacques.musicxml` | *Frère Jacques*: French traditional round, 18th century | score-backend-musicxml 0.1.0 |
| `greensleeves.musicxml` | *Greensleeves*: English, 16th century; text from the 1580 broadside | score-backend-musicxml 0.1.0 |
| `hark-the-herald.musicxml` | *Hark! the Herald Angels Sing*: Felix Mendelssohn (1840), adapted by William H. Cummings (1856); text Charles Wesley (1739); harmony ours; hymnal layout (shared stems) | new |
| `home-on-the-range.musicxml` | *Home on the Range*: Daniel E. Kelley, text Brewster M. Higley (1872) | score-backend-musicxml 0.1.0 |
| `hymn-shared.musicxml` | *Tallis's Canon*: Thomas Tallis (1567); text Thomas Ken (1674); harmony ours; hymnal layout (shared stems) | score-backend-musicxml 0.1.0 |
| `hymn-split.musicxml` | *Tallis's Canon*: Thomas Tallis (1567); text Thomas Ken (1674); harmony ours; four voices on two staves (hand-split) | score-backend-musicxml 0.1.0 |
| `hymn-to-joy.musicxml` | *Hymn to Joy*: Ludwig van Beethoven (1824); text Friedrich Schiller (1785); harmony ours; four voices on two staves (hand-split) | score-backend-musicxml 0.1.0 |
| `hymn-to-joy-shared.musicxml` | *Hymn to Joy*: Ludwig van Beethoven (1824); text Friedrich Schiller (1785); harmony ours; hymnal layout (shared stems) | new |
| `irish-washerwoman.musicxml` | *The Irish Washerwoman*: Irish traditional jig, printed in the late 18th century | new |
| `jingle-bells.musicxml` | *Jingle Bells*: James Lord Pierpont (1857) | new |
| `joy-to-the-world.musicxml` | *Joy to the World*: arranged by Lowell Mason (1839); text Isaac Watts (1719) | score-backend-musicxml 0.1.0 |
| `londonderry-air.musicxml` | *Londonderry Air*: Irish traditional air, printed by George Petrie (1855) | score-backend-musicxml 0.1.0 |
| `minuet-in-g.musicxml` | *Minuet in G*: Christian Petzold (c. 1725), from the 1725 Notebook for Anna Magdalena Bach; bass line ours | new |
| `new-britain.musicxml` | *New Britain (Amazing Grace)*: tune New Britain, as printed in Southern Harmony (1835); text John Newton (1779); harmony ours; hymnal layout (shared stems) | new |
| `oh-susanna.musicxml` | *Oh! Susanna*: Stephen Foster (1848) | score-backend-musicxml 0.1.0 |
| `old-hundredth.musicxml` | *Old Hundredth*: Genevan Psalter (1551); text William Kethe (1561); harmony ours; four voices on two staves (hand-split) | score-backend-musicxml 0.1.0 |
| `old-hundredth-shared.musicxml` | *Old Hundredth*: Genevan Psalter (1551); text William Kethe (1561); harmony ours; hymnal layout (shared stems) | new |
| `pop-goes-the-weasel.musicxml` | *Pop! Goes the Weasel*: English traditional, printed in the 1850s | new |
| `red-river-valley.musicxml` | *Red River Valley*: North American traditional song, published 1896 | score-backend-musicxml 0.1.0 |
| `scarborough-fair.musicxml` | *Scarborough Fair*: English traditional ballad, as printed in the 19th century | score-backend-musicxml 0.1.0 |
| `shenandoah.musicxml` | *Shenandoah*: American traditional (sea shanty), 19th century | score-backend-musicxml 0.1.0 |
| `silent-night.musicxml` | *Silent Night*: Franz Xaver Gruber (1818); English text John Freeman Young (1859) | score-backend-musicxml 0.1.0 |
| `simple-gifts.musicxml` | *Simple Gifts*: Joseph Brackett (1848) | score-backend-musicxml 0.1.0 |
| `swing-low.musicxml` | *Swing Low, Sweet Chariot*: African-American spiritual, attributed to Wallace Willis (before 1862) | score-backend-musicxml 0.1.0 |
| `twinkle-twinkle.musicxml` | *Twinkle, Twinkle, Little Star*: French melody Ah! vous dirai-je, maman (1761); text Jane Taylor (1806) | score-backend-musicxml 0.1.0 |
| `when-the-saints.musicxml` | *When the Saints Go Marching In*: African-American spiritual, early 20th-century form | score-backend-musicxml 0.1.0 |
| `yankee-doodle.musicxml` | *Yankee Doodle*: American traditional, 18th century | score-backend-musicxml 0.1.0 |
