# Spec: categories_tab

Pass: 1. Written 2026-09-09. Disposable.
Concept: "Architectural Clarity for High-Agency Builders"
UI Design Class: Class 1 (Target Visual Ratio: 70%)

## 1. What this surface is for
- Single Question Answered: How are executive objectives partitioned across professional and personal domains?
- Primary Action Trigger: Grid Category Cards with tactile active compression.
- Concept Citation: "An architectural instrument crafted with structural lightness, mathematical precision, and tactile warmth."

## 2. Creative Direction & Resolved Identity
- Design Class: Class 1 (Instrumental Precision)
- Color Roles: Canvas (`#F8F9FA`), Card Surface (`#FFFFFF`), Border (`#E2E8F0`), Accent Primary (`#4338CA`).
- Typography Pairing: Display (Ink `#0F172A`, 22pt, w800, -0.4 tracking) + Category Title (`15pt`, w700) + Subtitle (`13pt`).
- Radii & Insets: Inset `16`, Radii `16pt` for category cards & native ad card, `10pt` for category icon circle.
- Depth Tier: Tier 1 (Elevated white cards with 1px zinc borders and soft shadows).

## 3. Visual Journey & Visual Telemetry Map
- **Visual Journey**:
  1. *First Seen*: Section Header and Subtitle declaring workspace separation.
  2. *Next Noticed*: 2-Column Grid of Architectural Category Cards with vibrant icon beacons.
  3. *Attention Lands*: Bottom Pinned Small Native Ad framed in a matching 16px architectural card.
- **Visual Telemetry Substitutions**:
  - Categories: Mapped to 2-column cards displaying live task counters.
  - Native Ad: Mapped to a framed 16px radius `TaskCard` container labeled `SPONSORED RECOMMENDATION`.

## 4. Contextual Tips & Guidance
- Target Element: ad.sponsored
- Trigger: Mount
- Exact Copy: "SPONSORED RECOMMENDATION"
- Recession Rule: Collapses when user is VIP.

## 5. Element Inventory & Countable Budget
- Ordered Hierarchy: [Header Section → 2-Column GridView → Bottom Framed Small Native Ad]
- Text Nodes: 4
- Accent Colors: 1 (`#4338CA`)
- Container Levels: 3 max
- Decorative Elements: 0
- Animating Elements: 1 (Category card active scale)

## 6. Slot Table
| Slot Key | Source | States / Count | Longest Value | Overflow Rule | Notes |
|---|---|---|---|---|---|
| header.title | slot file | 1 | `Categories & Workspaces` | `grow-container-never-truncate` | Header title |
| header.subtitle | slot file | 1 | `Isolate cognitive context across focused domains.` | `wrap-then-truncate-at-2` | Subtitle |
| meta.task_suffix | slot file | 1 | `tasks` | `grow-container-never-truncate` | Counter suffix |
| ad.sponsored | slot file | 1 | `SPONSORED RECOMMENDATION` | `grow-container-never-truncate` | Ad header |

- **Growth Region**: `GridView category area`
- **Pinned Below**: `Bottom Framed Small Native Ad`

## 7. State Matrix
| State | Visual Anchor State | Rendered Text Keys | Telemetry Beacon |
|---|---|---|---|
| **Free Active** | Grid of categories + Small Native Ad | All slots | Static Slate |
| **VIP Active** | Grid of categories (ad container collapsed) | All slots except `ad.sponsored` | Static Emerald |

## 8. Motion Table & Spatial Physics
| Element | Trigger | Animated Properties | Duration / Curve | Settled State | On Re-trigger |
|---|---|---|---|---|---|
| Category Card | `:active` | `transform: scale(1→0.97)` | 120ms ease-out | Equals static | Springs back |

- **Fallback Ladder**: Reduced motion = instantaneous tap routing, zero scale.

## 9. Continuity & Tactility Contract
- **Navigation Edge (From → To)**: Navigates to `CategoryTasksScreen(category: cat)`.
- **Tactile Responses**: 0.97x active scale on category card tap.

## 10. The Signature Moment & Emotional Peak
- What happens: Tapping a category card compresses tactually and transitions seamlessly to the filtered category view.
- Why it is this one: Demonstrates spatial domain isolation with zero friction.

## 11. Verification Matrix
- Mechanical checks: Slots matched (4/4), Text nodes (4), Settled geometry static (Pass), 13ms Glanceability (Pass).

## 12. Deviations from Durable Contract
- None.

## 13. Known Gaps — Not in Scope
- None.
