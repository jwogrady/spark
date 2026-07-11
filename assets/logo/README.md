# Spark logo — usage

The mark is a prompt chevron igniting a four-point spark: your intent goes in,
finished software comes out. One drawing, three surfaces.

## Variants

| File | Use on | Notes |
|---|---|---|
| `spark-mark.svg` | Light backgrounds | Slate chevron, ember spark |
| `spark-mark-dark.svg` | Dark backgrounds | Off-white chevron, same spark |
| `spark-tile.svg` | Any background | Self-contained: app icons, favicons, avatars, marketplace icon |
| `spark-lockup.svg` / `spark-lockup-dark.svg` | Light / dark | Horizontal lockup with the wordmark |

PNG exports live in `png/`: marks at 256, the tile at 512/256/64/32/16
(favicon set), lockups at 600 wide, and `spark-social-preview.png`
(1280×640 — upload via the repo's Settings → Social preview; GitHub has no
API for it).

These are the approved variants. Don't recolor, outline, rotate, or add
effects; regenerate PNGs from the SVGs rather than scaling PNGs up.

## Colors

| Role | Hex |
|---|---|
| Spark (accent, both themes) | `#F97316` |
| Ink / tile (light theme, tile fill) | `#0F172A` |
| Ink on dark | `#F8FAFC` |

The spark stays `#F97316` in every variant; only the chevron/wordmark ink
swaps per theme.

## Spacing and minimum size

- Clear space: keep a margin of at least the spark's width (about ¼ of the
  mark's width) free on all sides.
- Minimum size: 16px for the tile, 24px for the bare mark, 120px wide for the
  lockup. Below those, use the tile.
- Validated: the tile is identifiable at 16px and 32px; both lockups pass
  contrast on their backgrounds (ink is ≥15:1; the spark is decorative, not
  text).

## Wordmark

The lockup sets "Spark" in Ubuntu Sans Bold with the system-font stack as
fallback (`Ubuntu Sans, DejaVu Sans, -apple-system, Segoe UI, sans-serif`).
For pixel-identical output use the exported lockup PNGs.

## README embed

```html
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/logo/spark-lockup-dark.svg">
  <img src="assets/logo/spark-lockup.svg" alt="Spark" width="320">
</picture>
```
