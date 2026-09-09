# Spec: splash_screen

Pass: 1. Written 2026-09-09. Disposable.
Concept: "Architectural Clarity for High-Agency Builders"
UI Design Class: Class 1 (Target Visual Ratio: 65%)

## 1. What this surface is for
- Single Question Answered: Is the execution engine ready for instant zero-latency workflow?
- Primary Action Trigger: Automatic timed transition (3000ms) with 0ms splash interstitial handshake.
- Concept Citation: "An architectural instrument crafted with structural lightness, mathematical precision, and tactile warmth."

## 2. Creative Direction & Resolved Identity
- Design Class: Class 1 (Instrumental Precision)
- Color Roles: Surface (`#F8F9FA`), Card Container (`#FFFFFF`), Border (`#E2E8F0`), Accent Primary (`#4338CA`).
- Typography Pairing: Display (Ink `#0F172A`, 28pt, w800, -0.5 tracking) + UI/Mono (`#94A3B8`, 11pt, w600, +0.5 tracking).
- Radii & Insets: Inset `24`, Radii `16pt` for framed card, `8pt` for status indicator.
- Depth Tier: Tier 1 (Elevated card with 1px border and soft shadow).

## 3. Visual Journey & Visual Telemetry Map
- **Visual Journey**:
  1. *First Seen*: Precision Architectural Geometric Icon + Pulsing Emerald Engine Beacon.
  2. *Next Noticed*: Monospace Status Tag + Engine Telemetry (`0ms Mutex Ready`).
  3. *Attention Lands*: Bottom Framed Card containing Instant Splash Ad Banner.
- **Visual Telemetry Substitutions**:
  - Engine Readiness: Mapped to Pulsing Emerald Beacon with monospace versioning.
  - Ad Container: Mapped to a framed architectural card (`#FFFFFF` with `#E2E8F0` border) preventing unstyled visual jitter.

## 4. Contextual Tips & Guidance
- Target Element: engine.status
- Trigger: Cold launch
- Exact Copy: "INITIALIZING PRODUCTION ENGINE"
- Recession Rule: Automatically exits on transition to Onboarding.

## 5. Element Inventory & Countable Budget
- Ordered Hierarchy: [Hero Brand Monogram → Status Telemetry Pill → Bottom Framed Ad Container]
- Text Nodes: 4
- Accent Colors: 1 (`#4338CA`)
- Container Levels: 2
- Decorative Elements: 0
- Animating Elements: 2 (`opacity` fade-in of hero brand, `opacity` pulse of emerald beacon)

## 6. Slot Table
| Slot Key | Source | States / Count | Longest Value | Overflow Rule | Notes |
|---|---|---|---|---|---|
| app.title | slot file | 1 | `TaskFlow Pro` | `grow-container-never-truncate` | Display title |
| app.tagline | slot file | 1 | `Architectural Clarity for High-Agency Builders` | `wrap-then-truncate-at-2` | Subtitle |
| engine.status | slot file | 1 | `INITIALIZING PRODUCTION ENGINE` | `grow-container-never-truncate` | Monospace label |
| engine.telemetry | slot file | 1 | `v2.4.0 • 0ms Mutex Ready` | `grow-container-never-truncate` | Tabular telemetry |

- **Growth Region**: Center Spacer
- **Pinned Below**: Bottom Framed Ad Container (`AdBannerView(placement: SampleAds.splashBanner)`)

## 7. State Matrix
| State | Visual Anchor State | Rendered Text Keys | Telemetry Beacon |
|---|---|---|---|
| **Initializing** | Fading In Monogram + Status Pill | `app.title`, `app.tagline`, `engine.status`, `engine.telemetry` | Pulsing Emerald |
| **Interstitial Handshake** | Backgrounded while AdMob renders | None (Full screen takeover) | Static Emerald |
| **Navigating** | Clean 400ms cross-fade to Onboarding | None | Static Emerald |

## 8. Motion Table & Spatial Physics
| Element | Trigger | Animated Properties | Duration / Curve | Settled State | On Re-trigger |
|---|---|---|---|---|---|
| Hero Monogram | Mount | `opacity`, `transform: scale(0.96→1.0)` | 600ms ease-out | Equals static | Retargets |
| Telemetry Beacon | Ambient | `opacity` | 1200ms ease-in-out | Equals static | Loops |

- **Fallback Ladder**: Reduced motion = static opacity 1.0, zero scale.

## 9. Continuity & Tactility Contract
- **Navigation Edge (From → To)**: Fade transition to `OnboardingScreen` (400ms).
- **Tactile Responses**: None (automated transition).

## 10. The Signature Moment & Emotional Peak
- What happens: The instant splash banner renders smoothly within the reserved architectural card while the splash interstitial prepares without stuttering or screen jumps.
- Why it is this one: Proves the 0ms immediate-display priority handshake works seamlessly.

## 11. Verification Matrix
- Mechanical checks: Slots matched (4/4), Text nodes (4), Settled geometry static (Pass), 13ms Glanceability (Pass).

## 12. Deviations from Durable Contract
- None.

## 13. Known Gaps — Not in Scope
- No user interaction needed on splash screen.
