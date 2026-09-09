# Spec: main_tabs_screen

Pass: 1. Written 2026-09-09. Disposable.
Concept: "Architectural Clarity for High-Agency Builders"
UI Design Class: Class 1 (Target Visual Ratio: 65%)

## 1. What this surface is for
- Single Question Answered: How can the user navigate across all productivity workspaces with zero cognitive friction?
- Primary Action Trigger: 5-Hub Architectural Navigation Bar anchored in bottom thumb zone.
- Concept Citation: "An architectural instrument crafted with structural lightness, mathematical precision, and tactile warmth."

## 2. Creative Direction & Resolved Identity
- Design Class: Class 1 (Instrumental Precision)
- Color Roles: Canvas (`#F8F9FA`), Surface (`#FFFFFF`), Border (`#E2E8F0`), Active Tab (`#4338CA`), Inactive Tab (`#64748B`).
- Typography Pairing: Display (`#0F172A`, 18pt, w700, -0.3 tracking) + Navigation Label (`11pt`, w600).
- Radii & Insets: Top bar Inset `16`, Bottom bar `BorderRadius.zero` with top hairline border (`1px solid #E2E8F0`).
- Depth Tier: Tier 1 (Sticky bottom shell with 1px border and zero jitter).

## 3. Visual Journey & Visual Telemetry Map
- **Visual Journey**:
  1. *First Seen*: Top Architectural Header with Geometric Monogram and `TaskFlow` title.
  2. *Next Noticed*: Active Hub Screen content inside `IndexedStack`.
  3. *Attention Lands*: Bottom Navigation Bar with 5 tabs + sticky banner ad for free users.
- **Visual Telemetry Substitutions**:
  - Console Access: Monospace Live Diagnostic HUD trigger icon (`Icons.terminal_rounded`) in Indigo accent.
  - Sticky Ad: Framed cleanly above the navigation bar with 1px top/bottom border, collapsing to `SizedBox.shrink()` for VIP users.

## 4. Contextual Tips & Guidance
- Target Element: action.console
- Trigger: Mount
- Exact Copy: "Live Diagnostic HUD"
- Recession Rule: Always accessible via top right icon button.

## 5. Element Inventory & Countable Budget
- Ordered Hierarchy: [Top AppBar → IndexedStack Body → Framed Sticky Banner → 5-Hub Navigation Bar]
- Text Nodes: 7
- Accent Colors: 1 (`#4338CA`)
- Container Levels: 2 max
- Decorative Elements: 0
- Animating Elements: 1 (Tab selection indicator)

## 6. Slot Table
| Slot Key | Source | States / Count | Longest Value | Overflow Rule | Notes |
|---|---|---|---|---|---|
| app.brand | slot file | 1 | `TaskFlow` | `grow-container-never-truncate` | AppBar title |
| tab.tasks | slot file | 1 | `Tasks` | `grow-container-never-truncate` | Tab 1 label |
| tab.projects | slot file | 1 | `Projects` | `grow-container-never-truncate` | Tab 2 label |
| tab.focus | slot file | 1 | `Focus` | `grow-container-never-truncate` | Tab 3 label |
| tab.analytics | slot file | 1 | `Analytics` | `grow-container-never-truncate` | Tab 4 label |
| tab.settings | slot file | 1 | `Settings` | `grow-container-never-truncate` | Tab 5 label |
| action.console | slot file | 1 | `Live Diagnostic HUD` | `grow-container-never-truncate` | Tooltip label |

- **Growth Region**: `IndexedStack tab body`
- **Pinned Below**: `NavigationBar with sticky AdBannerView`

## 7. State Matrix
| State | Visual Anchor State | Rendered Text Keys | Telemetry Beacon |
|---|---|---|---|
| **Free Tier Active** | Sticky bottom AdBannerView visible | All slots | Static Slate |
| **VIP Active** | AdBannerView collapsed to `SizedBox.shrink()` | All slots | Static Emerald |

## 8. Motion Table & Spatial Physics
| Element | Trigger | Animated Properties | Duration / Curve | Settled State | On Re-trigger |
|---|---|---|---|---|---|
| Tab Indicator | Destination select | `opacity`, `transform: scaleX(0.8→1.0)` | 200ms ease-out | Equals static | Retargets |

- **Fallback Ladder**: Reduced motion = instantaneous tab swap, zero animation.

## 9. Continuity & Tactility Contract
- **Navigation Edge (From → To)**: Retains tab state in `IndexedStack`.
- **Tactile Responses**: Tab tap yields light haptic feedback.

## 10. The Signature Moment & Emotional Peak
- What happens: Upgrading to VIP in Settings instantly collapses the sticky banner ad with 0ms visual shift, transforming the entire shell into an unobstructed executive workspace.
- Why it is this one: Demonstrates reactive ad suppression across global app navigation.

## 11. Verification Matrix
- Mechanical checks: Slots matched (7/7), Text nodes (7), Settled geometry static (Pass), 13ms Glanceability (Pass).

## 12. Deviations from Durable Contract
- None.

## 13. Known Gaps — Not in Scope
- None.
