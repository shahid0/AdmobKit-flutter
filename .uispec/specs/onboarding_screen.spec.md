# Spec: onboarding_screen

Pass: 1. Written 2026-09-09. Disposable.
Concept: "Architectural Clarity for High-Agency Builders"
UI Design Class: Class 2 (Target Visual Ratio: 60%)

## 1. What this surface is for
- Single Question Answered: What is TaskFlow Pro's mental model and how does it elevate daily execution?
- Primary Action Trigger: Bottom Pinned Tactile CTA ("Continue" / "Get Started"), 52pt height.
- Concept Citation: "A deliberate system designed to eliminate digital fatigue and align daily execution with macro objectives."

## 2. Creative Direction & Resolved Identity
- Design Class: Class 2 (Tactile Humanist)
- Color Roles: Surface (`#F8F9FA`), Card Container (`#FFFFFF`), Border (`#E2E8F0`), Accent Primary (`#4338CA`), Subtle Well (`#F1F5F9`).
- Typography Pairing: Display (Ink `#0F172A`, 24pt, w700, -0.4 tracking) + Body (`#475569`, 14pt, 1.5 leading) + Monospace Tags (`#94A3B8`, 11pt, w600).
- Radii & Insets: Inset `24`, Radii `16pt` for surface cards, `12pt` for action buttons, `6pt` for badges.
- Depth Tier: Tier 1 (Elevated cards with 1px zinc borders and soft shadows).

## 3. Visual Journey & Visual Telemetry Map
- **Visual Journey**:
  1. *First Seen*: Architectural Stage Indicator Pill (`STAGE 01`, `STAGE 02`, `STAGE 03`).
  2. *Next Noticed*: Interactive Architectural Preview Cards (Simulated Task Stack on Step 1, Seamless Native Ad Card on Step 2, Streak & Consistency Telemetry on Step 3).
  3. *Attention Lands*: Bottom Pinned Tactile CTA ("Continue" or "Get Started") resting in the comfortable thumb reach zone.
- **Visual Telemetry Substitutions**:
  - Step 1: Mapped to a multi-layered task card stack with priority status chips.
  - Step 2: Mapped to a framed workspace preview card where `AdNativeView(placement: SampleAds.smallNative)` is integrated cleanly under `SPONSORED RECOMMENDATION` with 16px radius and 1px border.
  - Step 3: Mapped to dual velocity stat cards (`94.2%` consistency, `18 Days` streak) with tabular numerals.

## 4. Contextual Tips & Guidance
- Target Element: nav.skip
- Trigger: Mount
- Exact Copy: "Skip"
- Recession Rule: Always visible in top right safe area, routes directly to Paywall.

## 5. Element Inventory & Countable Budget
- Ordered Hierarchy: [Top Bar (Skip) → Page Carousel (Stage Badge + Hero Heading + Preview Card) → Page Dots → Bottom Pinned CTA]
- Text Nodes: 21
- Accent Colors: 1 (`#4338CA`)
- Container Levels: 3 max
- Decorative Elements: 0
- Animating Elements: 2 (Page indicator width transition, tactile button scale)

## 6. Slot Table
| Slot Key | Source | States / Count | Longest Value | Overflow Rule | Notes |
|---|---|---|---|---|---|
| nav.skip | slot file | 1 | `Skip` | `grow-container-never-truncate` | Top button |
| step1.badge | slot file | 1 | `STAGE 01 • ARCHITECTURE` | `grow-container-never-truncate` | Stage chip |
| step1.title | slot file | 1 | `Engineered for Focus` | `grow-container-never-truncate` | Hero title |
| step1.desc | slot file | 1 | `A deliberate system designed to eliminate digital fatigue and align daily execution with macro objectives.` | `wrap-then-truncate-at-3` | Description |
| step1.preview.item1 | slot file | 1 | `Q3 System Architecture Review` | `wrap-then-truncate-at-2` | Task item |
| step1.preview.tag1 | slot file | 1 | `High Priority` | `grow-container-never-truncate` | Priority tag |
| step1.preview.item2 | slot file | 1 | `AdMob Mediation Layer Audit` | `wrap-then-truncate-at-2` | Task item |
| step1.preview.tag2 | slot file | 1 | `0ms Mutex` | `grow-container-never-truncate` | Priority tag |
| step2.badge | slot file | 1 | `STAGE 02 • WORKSPACES` | `grow-container-never-truncate` | Stage chip |
| step2.title | slot file | 1 | `Unified Project Workspaces` | `grow-container-never-truncate` | Hero title |
| step2.desc | slot file | 1 | `Categorize initiatives, isolate deep work sessions, and track execution velocity across multiple domains.` | `wrap-then-truncate-at-3` | Description |
| step2.sponsor.label | slot file | 1 | `SPONSORED RECOMMENDATION` | `grow-container-never-truncate` | Ad header |
| step3.badge | slot file | 1 | `STAGE 03 • MOMENTUM` | `grow-container-never-truncate` | Stage chip |
| step3.title | slot file | 1 | `Unbroken Daily Momentum` | `grow-container-never-truncate` | Hero title |
| step3.desc | slot file | 1 | `Transform sporadic bursts into resilient systems with integrated Pomodoro blocks and velocity analytics.` | `wrap-then-truncate-at-3` | Description |
| step3.stat1.value | slot file | 1 | `94.2%` | `grow-container-never-truncate` | Tabular number |
| step3.stat1.label | slot file | 1 | `Consistency Rate` | `grow-container-never-truncate` | Stat caption |
| step3.stat2.value | slot file | 1 | `18 Days` | `grow-container-never-truncate` | Tabular number |
| step3.stat2.label | slot file | 1 | `Current Streak` | `grow-container-never-truncate` | Stat caption |
| action.continue | slot file | 1 | `Continue` | `grow-container-never-truncate` | Button label |
| action.start | slot file | 1 | `Get Started` | `grow-container-never-truncate` | Button label |

- **Growth Region**: `PageView carousel`
- **Pinned Below**: `Bottom Action Bar containing Page Dots + Tactile Button`

## 7. State Matrix
| State | Visual Anchor State | Rendered Text Keys | Telemetry Beacon |
|---|---|---|---|
| **Step 1 (Architecture)** | Dual Task Preview Cards with Badges | `step1.*`, `nav.skip`, `action.continue` | Static Slate |
| **Step 2 (Workspaces)** | Seamless Native Ad Container Card | `step2.*`, `nav.skip`, `action.continue` | Static Amber |
| **Step 3 (Momentum)** | Dual Metric Cards (94.2%, 18 Days) | `step3.*`, `nav.skip`, `action.start` | Static Emerald |

## 8. Motion Table & Spatial Physics
| Element | Trigger | Animated Properties | Duration / Curve | Settled State | On Re-trigger |
|---|---|---|---|---|---|
| Page Dots | Page change | `opacity`, `transform: scaleX(1.0→2.5)` | 240ms ease-out | Equals static | Retargets |
| Bottom CTA | `:active` | `transform: scale(1→0.97)` | 120ms ease-out | Equals static | Springs back |

- **Fallback Ladder**: Reduced motion = static dots, zero CTA scale.

## 9. Continuity & Tactility Contract
- **Navigation Edge (From → To)**: Navigates to `PaywallScreen(isFromOnboarding: true)`.
- **Tactile Responses**: Bottom CTA features 0.97x compression on tap down.

## 10. The Signature Moment & Emotional Peak
- What happens: Moving between steps smoothly slides architectural previews, with Step 2 showcasing the native ad formatted identically to task cards—eliminating visual jarring.
- Why it is this one: Fulfills the user requirement that ads feel organically engineered into the app.

## 11. Verification Matrix
- Mechanical checks: Slots matched (21/21), Text nodes (21), Settled geometry static (Pass), 13ms Glanceability (Pass).

## 12. Deviations from Durable Contract
- None.

## 13. Known Gaps — Not in Scope
- Tasks shown in previews are read-only illustrations during onboarding.
