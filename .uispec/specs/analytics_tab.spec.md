# Spec: analytics_tab

Pass: 1. Written 2026-09-09. Disposable.
Concept: "Architectural Clarity for High-Agency Builders"
UI Design Class: Class 1 (Target Visual Ratio: 75%)

## 1. What this surface is for
- Single Question Answered: What is the builder's quantitative execution momentum and velocity rate?
- Primary Action Trigger: Bottom Export Button ("Watch Ad to Export PDF" / "Export PDF (VIP Instant)").
- Concept Citation: "An architectural instrument crafted with structural lightness, mathematical precision, and tactile warmth."

## 2. Creative Direction & Resolved Identity
- Design Class: Class 1 (Instrumental Precision)
- Color Roles: Canvas (`#F8F9FA`), Card Surface (`#FFFFFF`), Border (`#E2E8F0`), Accent Primary (`#4338CA`), Telemetry Emerald (`#047857`), Telemetry Amber (`#B45309`).
- Typography Pairing: Tabular Display Numerals (Ink `#0F172A`, 36pt, w800, `tabularFigures`) + Headline (`22pt`, w800) + Body (`13pt`).
- Radii & Insets: Inset `20`, Radii `20pt` for velocity card, `14pt` for stat cards, `16pt` for export card.
- Depth Tier: Tier 1 (Elevated white surface cards with 1px zinc borders and soft shadows).

## 3. Visual Journey & Visual Telemetry Map
- **Visual Journey**:
  1. *First Seen*: Completion Velocity Scorecard with 36pt Tabular Percentage and Progress Bar.
  2. *Next Noticed*: 3-Column Metrics Grid (Streak, Pending, Done) with color glyphs.
  3. *Attention Lands*: Executive Accomplishment Report Card with Rewarded Ad Video Export CTA.
- **Visual Telemetry Substitutions**:
  - Velocity: Mapped to a segmented linear progress gauge with tabular percentage.
  - Rewarded Ad Gate: Mapped to an amber `REWARDED EXPORT` badge unlocking instant PDF generation.

## 4. Contextual Tips & Guidance
- Target Element: export.badge
- Trigger: Mount
- Exact Copy: "REWARDED EXPORT"
- Recession Rule: Hidden for VIP subscribers.

## 5. Element Inventory & Countable Budget
- Ordered Hierarchy: [Header Section → Velocity Card → 3-Column Stat Row → Rewarded Export Card]
- Text Nodes: 16
- Accent Colors: 1 (`#4338CA`)
- Container Levels: 3 max
- Decorative Elements: 0
- Animating Elements: 1 (Export button active scale)

## 6. Slot Table
| Slot Key | Source | States / Count | Longest Value | Overflow Rule | Notes |
|---|---|---|---|---|---|
| header.title | slot file | 1 | `Productivity Velocity` | `grow-container-never-truncate` | Tab title |
| header.subtitle | slot file | 1 | `Quantitative completion momentum across active initiatives.` | `wrap-then-truncate-at-2` | Subtitle |
| velocity.title | slot file | 1 | `Completion Velocity` | `grow-container-never-truncate` | Card title |
| velocity.stats_suffix | slot file | 1 | `tasks completed` | `grow-container-never-truncate` | Counter suffix |
| stat.streak.label | slot file | 1 | `Current Streak` | `grow-container-never-truncate` | Stat 1 label |
| stat.streak.value | slot file | 1 | `5 Days` | `grow-container-never-truncate` | Stat 1 value |
| stat.pending.label | slot file | 1 | `Pending Tasks` | `grow-container-never-truncate` | Stat 2 label |
| stat.done.label | slot file | 1 | `Completed Tasks` | `grow-container-never-truncate` | Stat 3 label |
| export.badge | slot file | 1 | `REWARDED EXPORT` | `grow-container-never-truncate` | Badge |
| export.title | slot file | 1 | `Executive Accomplishment Report` | `grow-container-never-truncate` | Section title |
| export.desc | slot file | 1 | `Generate a structured PDF summarizing task completion velocity and workspace distribution.` | `wrap-then-truncate-at-2` | Description |
| action.export_free | slot file | 1 | `Watch Ad to Export PDF` | `grow-container-never-truncate` | Free button |
| action.export_vip | slot file | 1 | `Export PDF (VIP Instant)` | `grow-container-never-truncate` | VIP button |
| dialog.success.title | slot file | 1 | `Report Compiled` | `grow-container-never-truncate` | Dialog title |
| dialog.success.desc | slot file | 1 | `Your executive accomplishment PDF report has been compiled successfully.` | `wrap-then-truncate-at-2` | Dialog desc |
| dialog.success.action | slot file | 1 | `Done` | `grow-container-never-truncate` | Dialog button |

- **Growth Region**: `SingleChildScrollView analytics body`
- **Pinned Below**: `None`

## 7. State Matrix
| State | Visual Anchor State | Rendered Text Keys | Telemetry Beacon |
|---|---|---|---|
| **Free Active** | Watch Ad to Export CTA + Rewarded badge | All slots except `action.export_vip` | Static Amber |
| **VIP Active** | Export PDF (VIP Instant) CTA | All slots except `action.export_free`, `export.badge` | Static Emerald |
| **Report Exported** | Success dialog | `dialog.success.*` | Pulsing Emerald |

## 8. Motion Table & Spatial Physics
| Element | Trigger | Animated Properties | Duration / Curve | Settled State | On Re-trigger |
|---|---|---|---|---|---|
| Export CTA | `:active` | `transform: scale(1→0.97)` | 120ms ease-out | Equals static | Springs back |

- **Fallback Ladder**: Reduced motion = instantaneous dialog popup, zero button scale.

## 9. Continuity & Tactility Contract
- **Navigation Edge (From → To)**:
  - Tapping "Watch Ad to Export PDF" presents `SampleAds.rewardedBonus`.
  - On reward granted, opens report success dialog.
- **Tactile Responses**: 0.97x active scale on Export CTA.

## 10. The Signature Moment & Emotional Peak
- What happens: Completing the rewarded ad grants instant access to compile and download the accomplishment report, validating the developer's week with clean telemetry and zero UI hitching.
- Why it is this one: Proves the rewarded video ad flow delivers clear value exchange for user attention.

## 11. Verification Matrix
- Mechanical checks: Slots matched (16/16), Text nodes (16), Settled geometry static (Pass), 13ms Glanceability (Pass).

## 12. Deviations from Durable Contract
- None.

## 13. Known Gaps — Not in Scope
- File system PDF writing is mocked with dialog and logs.
