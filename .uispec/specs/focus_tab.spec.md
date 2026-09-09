# Spec: focus_tab

Pass: 1. Written 2026-09-09. Disposable.
Concept: "Architectural Clarity for High-Agency Builders"
UI Design Class: Class 1 (Target Visual Ratio: 75%)

## 1. What this surface is for
- Single Question Answered: How much deep work time remains in the current execution block?
- Primary Action Trigger: Center Start/Pause Tactile Action Button.
- Concept Citation: "An architectural instrument crafted with structural lightness, mathematical precision, and tactile warmth."

## 2. Creative Direction & Resolved Identity
- Design Class: Class 1 (Instrumental Precision)
- Color Roles: Surface (`#F8F9FA`), Card Container (`#FFFFFF`), Border (`#E2E8F0`), Timer Ring Track (`#F1F5F9`), Timer Ring Fill (`#4338CA`), Accent Booster (`#D97706`).
- Typography Pairing: Tabular Display Numerals (Ink `#0F172A`, 48pt, w800, `tabularFigures`) + Display Headline (`#0F172A`, 22pt, w700) + Monospace Status (`#94A3B8`, 11pt, w600).
- Radii & Insets: Inset `20`, Radii `20pt` for timer card, `16pt` for booster card, `12pt` for action buttons.
- Depth Tier: Tier 1 (Elevated cards with 1px zinc borders and soft shadows).

## 3. Visual Journey & Visual Telemetry Map
- **Visual Journey**:
  1. *First Seen*: Circular Architectural Countdown Ring Gauge with 48pt Tabular Timer.
  2. *Next Noticed*: Start / Pause / Reset tactile controls in the thumb reach zone.
  3. *Attention Lands*: AI Flow State Booster Card with `SampleAds.rewardedInterstitial` unlock CTA.
- **Visual Telemetry Substitutions**:
  - Countdown: Mapped to a 200px circular progress arc with tabular monospace numerals (`25:00`).
  - Rewarded Ad Gate: Mapped to an amber booster card rewarding the user with 45-min flow state upon ad completion.

## 4. Contextual Tips & Guidance
- Target Element: booster.badge
- Trigger: Mount
- Exact Copy: "REWARDED BOOST"
- Recession Rule: Always visible until booster unlocked.

## 5. Element Inventory & Countable Budget
- Ordered Hierarchy: [Hero Header → Circular Timer Card → Timer Controls → Rewarded Booster Card]
- Text Nodes: 13
- Accent Colors: 1 (`#4338CA`)
- Container Levels: 3 max
- Decorative Elements: 0
- Animating Elements: 2 (Timer circular arc progress, button active press scale)

## 6. Slot Table
| Slot Key | Source | States / Count | Longest Value | Overflow Rule | Notes |
|---|---|---|---|---|---|
| hero.title | slot file | 1 | `Deep Work Engine` | `grow-container-never-truncate` | Header |
| hero.subtitle | slot file | 1 | `Interval focus sessions calibrated for peak cognitive output.` | `wrap-then-truncate-at-2` | Subtitle |
| timer.mode | slot file | 1 | `POMODORO BLOCK` | `grow-container-never-truncate` | Monospace chip |
| timer.display | slot file | 1 | `25:00` | `grow-container-never-truncate` | Tabular display |
| timer.status | slot file | 1 | `Ready for Deep Work` | `grow-container-never-truncate` | Status label |
| action.start | slot file | 1 | `Start Focus Session` | `grow-container-never-truncate` | Button label |
| action.pause | slot file | 1 | `Pause Session` | `grow-container-never-truncate` | Button label |
| action.reset | slot file | 1 | `Reset Timer` | `grow-container-never-truncate` | Button label |
| booster.badge | slot file | 1 | `REWARDED BOOST` | `grow-container-never-truncate` | Chip label |
| booster.title | slot file | 1 | `AI Flow State Booster` | `grow-container-never-truncate` | Booster title |
| booster.desc | slot file | 1 | `Unlock extended 45-min flow state with AI ambient frequency audio.` | `wrap-then-truncate-at-2` | Booster desc |
| action.unlock_booster | slot file | 1 | `Unlock Booster (Free Ad)` | `grow-container-never-truncate` | Rewarded CTA |
| booster.active | slot file | 1 | `Flow State Booster Active (+45m)` | `grow-container-never-truncate` | Unlocked status |

- **Growth Region**: `SingleChildScrollView center area`
- **Pinned Below**: `None`

## 7. State Matrix
| State | Visual Anchor State | Rendered Text Keys | Telemetry Beacon |
|---|---|---|---|
| **Idle** | 25:00 on Ring Gauge | `hero.*`, `timer.*`, `action.start`, `booster.*` | Static Slate |
| **Running** | Smoothly depleting ring arc | `timer.display`, `action.pause`, `action.reset` | Pulsing Emerald |
| **Booster Unlocked** | Amber glow on timer ring | `booster.active` | Pulsing Amber |

## 8. Motion Table & Spatial Physics
| Element | Trigger | Animated Properties | Duration / Curve | Settled State | On Re-trigger |
|---|---|---|---|---|---|
| Timer Arc | Timer tick | `opacity` | 1000ms linear | Equals static | Retargets |
| Action Button | `:active` | `transform: scale(1→0.97)` | 120ms ease-out | Equals static | Springs back |

- **Fallback Ladder**: Reduced motion = static step updates, zero button scale.

## 9. Continuity & Tactility Contract
- **Navigation Edge (From → To)**: Retains timer state when switching tabs.
- **Tactile Responses**: 0.97x active scale on action triggers.

## 10. The Signature Moment & Emotional Peak
- What happens: Tapping "Unlock Booster (Free Ad)" presents `SampleAds.rewardedInterstitial`. Upon ad completion, `onRewardGranted` awards the 45-min flow state booster, updating the UI with an amber telemetry ring and instant confirmation.
- Why it is this one: Demonstrates high-value rewarded interstitial ad orchestration in a real productivity context.

## 11. Verification Matrix
- Mechanical checks: Slots matched (13/13), Text nodes (13), Settled geometry static (Pass), 13ms Glanceability (Pass).

## 12. Deviations from Durable Contract
- None.

## 13. Known Gaps — Not in Scope
- Ambient audio playback is simulated via visual state and logs.
