# Spec: settings_tab

Pass: 1. Written 2026-09-09. Disposable.
Concept: "Architectural Clarity for High-Agency Builders"
UI Design Class: Class 1 (Target Visual Ratio: 70%)

## 1. What this surface is for
- Single Question Answered: How can the engineer verify ad lifecycles, inspect AdMob adapters, and simulate subscription states?
- Primary Action Trigger: Action Tiles in list with tactile feedback.
- Concept Citation: "An architectural instrument crafted with structural lightness, mathematical precision, and tactile warmth."

## 2. Creative Direction & Resolved Identity
- Design Class: Class 1 (Instrumental Precision)
- Color Roles: Canvas (`#F8F9FA`), Surface (`#FFFFFF`), Border (`#E2E8F0`), Accent Primary (`#4338CA`), VIP Emerald (`#047857`).
- Typography Pairing: Display (Ink `#0F172A`, 22pt, w800, -0.4 tracking) + Tile Title (`14pt`, w600) + Monospace Labels (`#94A3B8`, 11pt, w600).
- Radii & Insets: Inset `16`, Radii `16pt` for VIP status card, `12pt` for action tiles.
- Depth Tier: Tier 1 (Elevated white surface cards with 1px zinc borders and soft shadows).

## 3. Visual Journey & Visual Telemetry Map
- **Visual Journey**:
  1. *First Seen*: VIP Subscription Switcher Card with dynamic state border and toggle.
  2. *Next Noticed*: Monospace Section Tag `MONETIZATION & ADS VERIFICATION`.
  3. *Attention Lands*: 7 Tool Action Tiles (Paywall, Interstitial, Rewarded, App Open, Inspector, UMP, Console).
- **Visual Telemetry Substitutions**:
  - Subscription State: Mapped to an elevated architectural card with live reactive Switch.
  - Verification Tools: Mapped to 12px radius list tiles with distinct color badges and chevron navigation hints.

## 4. Contextual Tips & Guidance
- Target Element: section.monetization
- Trigger: Mount
- Exact Copy: "MONETIZATION & ADS VERIFICATION"
- Recession Rule: Always visible as section header.

## 5. Element Inventory & Countable Budget
- Ordered Hierarchy: [Header Section → VIP Switcher Card → Section Label → 7 Action Tiles]
- Text Nodes: 22
- Accent Colors: 1 (`#4338CA`)
- Container Levels: 3 max
- Decorative Elements: 0
- Animating Elements: 1 (Switch toggle animation)

## 6. Slot Table
| Slot Key | Source | States / Count | Longest Value | Overflow Rule | Notes |
|---|---|---|---|---|---|
| header.title | slot file | 1 | `Settings & Ad Controls` | `grow-container-never-truncate` | Header |
| header.subtitle | slot file | 1 | `Enterprise monetization diagnostics and subscription simulation.` | `wrap-then-truncate-at-2` | Subtitle |
| vip.title_active | slot file | 1 | `TaskFlow PRO Active` | `grow-container-never-truncate` | VIP active title |
| vip.title_free | slot file | 1 | `Free Ad-Supported Tier` | `grow-container-never-truncate` | VIP free title |
| vip.desc_active | slot file | 1 | `All ads suppressed globally with zero latency.` | `wrap-then-truncate-at-2` | VIP active desc |
| vip.desc_free | slot file | 1 | `Toggle switch to test instant VIP ad suppression.` | `wrap-then-truncate-at-2` | VIP free desc |
| section.monetization | slot file | 1 | `MONETIZATION & ADS VERIFICATION` | `grow-container-never-truncate` | Section label |
| tile.paywall.title | slot file | 1 | `View Paywall Screen` | `grow-container-never-truncate` | Tile 1 title |
| tile.paywall.desc | slot file | 1 | `Test paywall close guard & back press ad interception` | `wrap-then-truncate-at-2` | Tile 1 desc |
| tile.interstitial.title | slot file | 1 | `Test Interstitial Ad` | `grow-container-never-truncate` | Tile 2 title |
| tile.interstitial.desc | slot file | 1 | `Verify that dismissing does NOT trigger an App Open ad` | `wrap-then-truncate-at-2` | Tile 2 desc |
| tile.rewarded.title | slot file | 1 | `Watch Ad: Unlock Executive Theme` | `grow-container-never-truncate` | Tile 3 title |
| tile.rewarded.desc | slot file | 1 | `Watch short video ad to unlock custom styling` | `wrap-then-truncate-at-2` | Tile 3 desc |
| tile.rewarded.unlocked | slot file | 1 | `Theme Unlocked (Reward Granted)` | `grow-container-never-truncate` | Tile 3 unlocked |
| tile.appopen.title | slot file | 1 | `Show App Open Ad Directly` | `grow-container-never-truncate` | Tile 4 title |
| tile.appopen.desc | slot file | 1 | `Present primed App Open ad on demand` | `wrap-then-truncate-at-2` | Tile 4 desc |
| tile.inspector.title | slot file | 1 | `Open AdMob Inspector` | `grow-container-never-truncate` | Tile 5 title |
| tile.inspector.desc | slot file | 1 | `Validate adapters, SDK initialization, and test ads` | `wrap-then-truncate-at-2` | Tile 5 desc |
| tile.privacy.title | slot file | 1 | `Privacy & GDPR Consent Options` | `grow-container-never-truncate` | Tile 6 title |
| tile.privacy.desc | slot file | 1 | `Present Google UMP consent form` | `wrap-then-truncate-at-2` | Tile 6 desc |
| tile.console.title | slot file | 1 | `Live Ad Console & Event Feed` | `grow-container-never-truncate` | Tile 7 title |
| tile.console.desc | slot file | 1 | `Inspect analytics impressions, revenue paid events & diagnostics` | `wrap-then-truncate-at-2` | Tile 7 desc |

- **Growth Region**: `ListView settings body`
- **Pinned Below**: `None`

## 7. State Matrix
| State | Visual Anchor State | Rendered Text Keys | Telemetry Beacon |
|---|---|---|---|
| **Free Mode** | Free VIP Card with inactive switch | `vip.title_free`, `vip.desc_free`, tool slots | Static Slate |
| **VIP Mode** | Emerald VIP Card with active switch | `vip.title_active`, `vip.desc_active`, tool slots | Pulsing Emerald |

## 8. Motion Table & Spatial Physics
| Element | Trigger | Animated Properties | Duration / Curve | Settled State | On Re-trigger |
|---|---|---|---|---|---|
| Action Tile | `:active` | `transform: scale(1→0.97)` | 120ms ease-out | Equals static | Springs back |

- **Fallback Ladder**: Reduced motion = instantaneous tap routing, zero scale.

## 9. Continuity & Tactility Contract
- **Navigation Edge (From → To)**:
  - Paywall tile opens `PaywallScreen()`.
  - Console tile opens `AppDrawerConsole.show(context)`.
- **Tactile Responses**: 0.97x active scale on action tiles.

## 10. The Signature Moment & Emotional Peak
- What happens: Toggling the VIP switch updates global state immediately, and running the "Test Interstitial Ad" proves that dismissing fullscreen ads produces zero App Open ad collisions.
- Why it is this one: Live on-device proof of the 0ms lifecycle fix and zero forced delay.

## 11. Verification Matrix
- Mechanical checks: Slots matched (22/22), Text nodes (22), Settled geometry static (Pass), 13ms Glanceability (Pass).

## 12. Deviations from Durable Contract
- None.

## 13. Known Gaps — Not in Scope
- None.
