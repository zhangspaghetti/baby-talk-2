# Care Entry golden-test font

`NotoSansSC-CareEntrySubset.otf` is a test-only subset of the static
`Noto Sans CJK SC Regular` font. It contains the Chinese glyphs rendered by the
Care Entry surface and its golden fixture, so screenshots verify real wrapping
instead of Flutter's square test glyphs.

Source: `notofonts/noto-cjk/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf`

License: SIL Open Font License 1.1; see `OFL-NotoSansSC.txt`.

The subset was produced with FontTools, with hinting removed. Regenerate it
when golden copy introduces a Chinese glyph that is not present in the subset.
