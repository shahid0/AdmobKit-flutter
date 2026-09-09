# Spec: paywall_screen

Pass: 1. Written 2026-09-09. Disposable.
Concept: "Architectural Clarity for High-Agency Builders"
UI Design Class: Class 1 (Target Visual Ratio: 65%)

## 1. What this surface is for
- Single Question Answered: How does upgrading to VIP eliminate all distractions and unlock executive productivity?
- Primary Action Trigger: Bottom Pinned Tactile CTA ("Start 3-Day Free Trial"), 52pt height.
- Concept Citation: "Architectural focus without interruptions. Pure execution."

## 2. Creative Direction & Resolved Identity
- Design Class: Class 1 (Instrumental Precision)
- Color Roles: Surface (`#F8F9FA`), Card Container (`#FFFFFF`), Border (`#E2E8F0`), Active Tier Border (`#4338CA`), Accent Primary (`#4338CA`), Subtle Well (`#F1F5F9`).
- Typography Pairing: Display (Ink `#0F172A`, 26pt, w800, -0.4 tracking) + Body (`#475569`, 14pt) + Monospace Tags (`#94A3B8`, 11pt, w600).
- Radii & Insets: Inset `24`, Radii `16pt` for surface cards, `12pt` for action buttons, `6pt` for badges.
- Depth Tier: Tier 2 (Elevated modal view with prominent border and subtle drop shadows).

## 3. Visual Journey & Visual Telemetry Map
- **Visual Journey**:
  1. *First Seen*: Top Exit Guard Cross + Architectural VIP Emblem + `LIMITED ACCESS` badge.
  2. *Next Noticed*: 4-Point Feature Grid with clean geometric icons in `#4338CA` and `#ECFDF5`.
  3. *Attention Lands*: Bottom Selected Annual Pricing Card with `SAVE 50%` badge and the Primary Conversion Button.
- **Visual Telemetry Substitutions**:
  - Feature benefits: Mapped to architectural 16px white card rows with zinc borders and high-contrast micro-icons.
  - Pricing Tiers: Radio selection cards with active border highlighting in `#4338CA` and emerald savings badge.

## 4. Contextual Tips & Guidance
- Target Element: badge.offer
- Trigger: Mount
- Exact Copy: "LIMITED ACCESS"
- Recession Rule: Stays pinned to top header.

## 5. Element Inventory & Countable Budget
- Ordered Hierarchy: [Top Bar (Badge + Guarded Close) → Scrollable Body (Hero + Features + Tiers) → Bottom Pinned CTA]
- Text Nodes: 18
- Accent Colors: 1 (`#4338CA`)
- Container Levels: 3 max
- Decorative Elements: 0
- Animating Elements: 1 (Tactile CTA press scale)

## 6. Slot Table
| Slot Key | Source | States / Count | Longest Value | Overflow Rule | Notes |
|---|---|---|---|---|---|
| badge.offer | slot file | 1 | `LIMITED ACCESS` | `grow-container-never-truncate` | Top chip |
| hero.title | slot file | 1 | `TaskFlow Pro VIP` | `grow-container-never-truncate` | Hero title |
| hero.subtitle | slot file | 1 | `Architectural focus without interruptions. Pure execution.` | `wrap-then-truncate-at-2` | Subtitle |
| feature1.title | slot file | 1 | `100% Ad-Free Ecosystem` | `grow-container-never-truncate` | Feature 1 |
| feature1.desc | slot file | 1 | `Zero interstitials, banners, or video delays across all 15 workspaces.` | `wrap-then-truncate-at-2` | Feature 1 desc |
| feature2.title | slot file | 1 | `Unlimited Deep Workspaces` | `grow-container-never-truncate` | Feature 2 |
| feature2.desc | slot file | 1 | `Structure unbounded project hierarchies with instant filtering.` | `wrap-then-truncate-at-2` | Feature 2 desc |
| feature3.title | slot file | 1 | `Automated Accomplishment Reports` | `grow-container-never-truncate` | Feature 3 |
| feature3.desc | slot file | 1 | `Instant one-tap PDF exports without watching rewarded ads.` | `wrap-then-truncate-at-2` | Feature 3 desc |
| feature4.title | slot file | 1 | `0ms Priority Engine` | `grow-container-never-truncate` | Feature 4 |
| feature4.desc | slot file | 1 | `All executive features primed in memory with zero latency.` | `wrap-then-truncate-at-2` | Feature 4 desc |
| tier.annual.title | slot file | 1 | `Annual Membership` | `grow-container-never-truncate` | Tier title |
| tier.annual.price | slot file | 1 | `3-Day Free Trial, then $29.99/year` | `grow-container-never-truncate` | Tier price |
| tier.annual.badge | slot file | 1 | `SAVE 50%` | `grow-container-never-truncate` | Emerald badge |
| tier.monthly.title | slot file | 1 | `Monthly Membership` | `grow-container-never-truncate` | Tier title |
| tier.monthly.price | slot file | 1 | `$4.99/month` | `grow-container-never-truncate` | Tier price |
| action.purchase | slot file | 1 | `Start 3-Day Free Trial` | `grow-container-never-truncate` | Primary button |
| disclaimer.terms | slot file | 1 | `No commitment. Cancel anytime in App Store or Google Play.` | `grow-container-never-truncate` | Disclaimer |

- **Growth Region**: `SingleChildScrollView feature & tier body`
- **Pinned Below**: `Bottom Action Bar containing CTA + terms disclaimer`

## 7. State Matrix
| State | Visual Anchor State | Rendered Text Keys | Telemetry Beacon |
|---|---|---|---|
| **Annual Selected** | Annual card highlighted with 2px `#4338CA` border | All slots | Static Emerald |
| **Monthly Selected** | Monthly card highlighted with 2px `#4338CA` border | All slots | Static Slate |
| **Purchase Success** | Ad-free mode activated; instant dismissal | None | Pulsing Emerald |
| **Exit Cross Pressed** | AdPaywallGuard intercept | None | Static Rose |

## 8. Motion Table & Spatial Physics
| Element | Trigger | Animated Properties | Duration / Curve | Settled State | On Re-trigger |
|---|---|---|---|---|---|
| Bottom CTA | `:active` | `transform: scale(1→0.97)` | 120ms ease-out | Equals static | Springs back |
| Tier Selection | Tap | `opacity` | 150ms ease-out | Equals static | Retargets |

- **Fallback Ladder**: Reduced motion = static cards, zero CTA scale.

## 9. Continuity & Tactility Contract
- **Navigation Edge (From → To)**:
  - If from onboarding: replaces route with `MainTabsScreen()`.
  - If from in-app: pops route via `Navigator.of(context).maybePop()`.
  - Exit cross is wrapped in `AdPaywallGuard(placement: SampleAds.mainInterstitial, onDismiss: ...)`.
- **Tactile Responses**: 0.97x active scale on CTA and pricing cards.

## 10. The Signature Moment & Emotional Peak
- What happens: Tapping the close button cleanly triggers the AdPaywallGuard (presenting the interstitial if on free tier), while completing the purchase instantly upgrades TaskStore to VIP with zero ads and zero delays.
- Why it is this one: Demonstrates full enterprise monetization integrity and hardware back interception.

## 11. Verification Matrix
- Mechanical checks: Slots matched (18/18), Text nodes (18), Settled geometry static (Pass), 13ms Glanceability (Pass).

## 12. Deviations from Durable Contract
- None.

## 13. Known Gaps — Not in Scope
- In-App Purchase sandbox purchase simulation (toggles TaskStore premium).
