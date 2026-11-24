# score-parity

A shared corpus of public-domain scores, plus the checks every score-protocol format backend must pass on it: lossless MusicXML and `.mxl` round trips, the hymnal voice split, score → MIDI → score with and without unfolding, and two external oracles (MuseScore's re-export, the MusicXML 4.0 XSD).

**Status:** SC5 contract (0.1.0). The exact rules are in the file headers under `src/`, and the Rove suite under `tests/` is the spec; the code marked `%sc5-pending` lands through team-solve. The design is in the capability brief [cl-stack/docs/capabilities/score.md](https://github.com/egao1980/cl-stack/blob/main/docs/capabilities/score.md).

```sh
cl-repo test --system score-parity
```

```lisp
(asdf:load-system "score-parity")
(score-parity:print-matrix)          ; every check over the corpus, per feature
```

| Function | Does |
|----------|------|
| `corpus-pieces`, `corpus-path`, `piece-facts` | the corpus under `corpus/` and what each file holds |
| `voice-lines`, `lyric-lines`, `chord-symbol-rows`, `bar-lengths`, `score-features` | a score's content as plain lists |
| `content-facet`, `content-differences` | compare two scores on what both formats carry |
| `run-check` | one check on one piece → a `parity-result` (`:pass`, `:fail`, `:skip`, `:error`) |
| `parity-matrix`, `matrix-cells`, `print-matrix` | every check over the corpus, counted per notation feature, with a summary row |
| `find-musescore`, `musescore-convert`, `musicxml-schema`, `xmllint-validate` | the external tools |

The checks: `:musicxml` (read → write → read is `score-equal`, the second write byte-stable), `:mxl` (the same through `.mxl`, and the corpus archives), `:hymnal-split` (four voice lines from a hymn in hymnal layout), `:midi` and `:midi-unfold` (pitches, onsets, ends, verse 1, chord symbols and bar lengths survive a Standard MIDI File), `:musescore` and `:xsd` (the oracles).

score-parity hard-depends on score-protocol only; the format backends ([score-backend-musicxml](https://github.com/egao1980/score-backend-musicxml), [score-backend-midi](https://github.com/egao1980/score-backend-midi)) are loaded when installed, and a check whose backend is missing is skipped. The test system depends on both.

## Oracles

| Variable | Meaning |
|----------|---------|
| `MUSESCORE_BIN` | the MuseScore executable; else `mscore`, `musescore`, `MuseScore4` or `mscore4` on `PATH`. Without one, the MuseScore checks are skipped. |
| `MUSICXML_XSD` | a local `musicxml.xsd` (github.com/w3c/musicxml, `schema/` at tag v4.0, with `xml.xsd`, `xlink.xsd` and `catalog.xml` beside it). With `xmllint` installed, every written file is validated (`xmllint --nonet`); otherwise the XSD checks are skipped. |

MuseScore converts our MusicXML to MusicXML (`mscore -o out.musicxml in.musicxml`, `QT_QPA_PLATFORM=offscreen`), and the re-export must keep, per sounding voice, the spelled pitches, onsets and tied ends, the lyrics of every verse, and the bar lengths. Ids, voice numbers and names, rests, layout and everything else are outside the comparison (`src/checks.lisp`).

## Corpus

34 MusicXML files of 30 public-domain tunes, re-encoded by us (MIT): lead sheets with chord symbols and lyrics, four-part hymns hand-split and in hymnal layout, several verses, pickups, repeats and endings, D.C. and D.S. jumps, ties across barlines, tuplets, grace notes, key and meter changes. Provenance and how to regenerate: [corpus/PROVENANCE.md](corpus/PROVENANCE.md).

## License

MIT, see [LICENSE](LICENSE).
