# 00_Asset_Gaps_Backlog

## Status

Recorded for later resolution. Do not solve asset gaps until all page designs have been discussed and approved.

## Decision

Asset production is deferred until the full app design pass is complete. Current page specs may reference missing assets, but implementation should not invent replacements beyond the fallback explicitly stated in each page spec.

## Missing Asset Categories

| Asset | Current Status | Temporary Rule |
|-------|----------------|----------------|
| 小禾老师头像 | missing | Use initials circle `小禾`; do not use random avatar, emoji, or cropped prototype image. |
| 花园嫩芽/种子插画 | missing | Hide decorative sprout art or use text-only state; do not use emoji or Material flower icon as final visual. |
| 植物线稿装饰 | missing | Omit decorative botanical lines until approved SVG exists. |
| 场景 SVG：睡前、喂奶、洗澡、换尿布、安抚、出门 | missing | Use explicit Flutter IconData mapping in page specs for v1; replace later with approved SVG set. |
| 宝宝反应图标 | missing as custom assets | Use explicit Flutter IconData mapping in page specs; no emoji. |
| `我说了` seed/star particle animation | missing | Use confirmation-pill opacity pulse until approved Lottie/custom painter spec exists. |
| 小花园阶段插画：种子、发芽、生长、开花、盛放 | missing | Discuss during Garden/Growth design; do not create ad hoc assets now. |

## Risks To Revisit Later

- Whether to add `flutter_svg` to `mobile/pubspec.yaml`.
- Whether custom assets should be SVG, PNG, Lottie, or Flutter CustomPainter.
- Whether all line icons should remain Flutter `Icons.*` for v1 or move to a custom icon set.
- Whether the generated prototype style is achievable with available assets.

