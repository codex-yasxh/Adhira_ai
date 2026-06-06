# Dashboard Screen (Flutter)

## Location
- Screen file: `mobile_flutter/lib/pages/dashboard_page.dart`
- Notes file: `mobile_flutter/markdowns/dashboard.md`

## Current Scope
This dashboard is implemented as a polished Flutter UI with local state-driven data editing. Backend integration for dynamic metric interpretation is not wired yet.

## Visual System
- Background intentionally matches chat screen language:
  - Base: `#050510`
  - Soft diagonal dark gradient
  - Subtle top-right radial blue glow
- Mobile-first compact spacing and typography.

## Header (Current)
- Title: `Health Dashboard`
- Subtitle: `Monitor your health metrics`
- `Last updated` moved inline in the subtitle row (small muted timestamp) to reduce vertical space.
- `Edit` button retained in top-right with compact sizing.

## Grid Layout (Current)
- Metric tiles use **2 columns** on normal phone widths.
- Very large widths can use 3 columns.
- Tile internals were compacted to reduce dead space:
  - smaller paddings
  - smaller icon badges
  - tighter value/unit/trend spacing
- Goal: keep the full metric set visible earlier, with `Weight` and `BMI` near bottom of metric block.

## Metrics Included
1. Blood Pressure
2. Blood Sugar
3. Heart Rate
4. Sleep Hours
5. Steps
6. Body Temperature
7. SpO2
8. Respiratory Rate
9. Weight
10. BMI

## Health Stats Section
- Toggle button: `Get Health Stats` / `Hide Health Stats`
- Button is intentionally spaced lower so it appears after slight scroll.
- Expanded panel renders a custom radar-style chart (`CustomPainter`).
- Axis labels are now shown around the radar (shortened where needed):
  - BP, Sugar, Heart, Sleep, Steps, Temp, etc.

## Chart Scoring Logic (Important Update)
Earlier chart logic was magnitude-based (`higher value => better`), which is medically misleading.

Now chart normalization is health-aware:
- In healthy range => higher score
- Too low/too high => lower score

Applied to all metrics including the original web metrics and added metrics.

## Edit Metrics Behavior
- Edit action opens a modal bottom sheet.
- Values are editable and saved to local screen state.
- No backend write yet from this screen.

## Known Limitation (Current)
- Tile `status`, `trend`, and `change` are currently static metadata.
- Changing a value (e.g., Sleep from 7 to 4) updates numeric value but does not auto-recompute trend/status text/icon yet.
- This is currently frontend behavior (both web and Flutter patterns as implemented now).

## Suggested Next Step
Implement local recalculation rules on save to update:
- `status` (`normal/warning/danger`)
- `trend` (`up/down/stable`)
- `change` (delta label)
based on health ranges per metric.
