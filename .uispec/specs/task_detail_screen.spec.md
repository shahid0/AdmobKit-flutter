# Spec: task_detail_screen

Pass: 1. Written 2026-09-09. Disposable.
Concept: "Architectural Clarity for High-Agency Builders"
UI Design Class: Class 1 (Target Visual Ratio: 65%)

## 1. What this surface is for
- Single Question Answered: What are the deep specifications, priority context, and subtasks for this objective?
- Primary Action Trigger: Center Toggle Completion Button ("Mark Completed" / "Mark Incomplete").
- Concept Citation: "An architectural instrument crafted with structural lightness, mathematical precision, and tactile warmth."

## 2. Creative Direction & Resolved Identity
- Design Class: Class 1 (Instrumental Precision)
- Color Roles: Canvas (`#F8F9FA`), Card Surface (`#FFFFFF`), Border (`#E2E8F0`), Accent Primary (`#4338CA`), Action Danger (`#DC2626`).
- Typography Pairing: Display (Ink `#0F172A`, 20pt, w700, -0.3 tracking) + Body (`#475569`, 14pt, 1.5 leading) + Monospace Tags (`#94A3B8`, 11pt, w600).
- Radii & Insets: Inset `16`, Radii `16pt` for task detail card & big native ad card, `10pt` for action button.
- Depth Tier: Tier 1 (Elevated white surface cards with 1px zinc borders and soft shadows).

## 3. Visual Journey & Visual Telemetry Map
- **Visual Journey**:
  1. *First Seen*: Category & Priority Pills atop the Hero Task Specification Card.
  2. *Next Noticed*: Task Title & Description + Completion State Action Button.
  3. *Attention Lands*: Injected Big Native Ad Card framed in matching 16px architectural card.
- **Visual Telemetry Substitutions**:
  - Priority: Mapped to a colored status pill with a dot indicator.
  - Native Ad: Mapped to a dedicated 16px radius `TaskCard` container labeled `SPONSORED RECOMMENDATION`.

## 4. Contextual Tips & Guidance
- Target Element: ad.sponsored
- Trigger: Mount
- Exact Copy: "SPONSORED RECOMMENDATION"
- Recession Rule: Collapses when user is VIP.

## 5. Element Inventory & Countable Budget
- Ordered Hierarchy: [Top AppBar (Title + Delete) → Scrollable Body (Detail Card + Checklist + Native Ad)]
- Text Nodes: 8
- Accent Colors: 1 (`#4338CA`)
- Container Levels: 3 max
- Decorative Elements: 0
- Animating Elements: 1 (Button active scale)

## 6. Slot Table
| Slot Key | Source | States / Count | Longest Value | Overflow Rule | Notes |
|---|---|---|---|---|---|
| appbar.title | slot file | 1 | `Task Details` | `grow-container-never-truncate` | Header |
| action.delete | slot file | 1 | `Delete Task` | `grow-container-never-truncate` | Tooltip |
| badge.priority_suffix | slot file | 1 | `Priority` | `grow-container-never-truncate` | Tag suffix |
| desc.empty | slot file | 1 | `No additional description provided.` | `wrap-then-truncate-at-2` | Fallback desc |
| action.complete | slot file | 1 | `Mark Completed` | `grow-container-never-truncate` | Button label |
| action.incomplete | slot file | 1 | `Mark Incomplete` | `grow-container-never-truncate` | Button label |
| section.subtasks | slot file | 1 | `EXECUTION CHECKLIST` | `grow-container-never-truncate` | Section title |
| ad.sponsored | slot file | 1 | `SPONSORED RECOMMENDATION` | `grow-container-never-truncate` | Ad header |

- **Growth Region**: `SingleChildScrollView body`
- **Pinned Below**: `None`

## 7. State Matrix
| State | Visual Anchor State | Rendered Text Keys | Telemetry Beacon |
|---|---|---|---|
| **Pending Task** | Mark Completed button in Indigo `#4338CA` | `action.complete`, other slots | Static Slate |
| **Completed Task** | Title line-through + Mark Incomplete button | `action.incomplete`, other slots | Static Emerald |
| **VIP Active** | Ad container completely collapsed | All slots except `ad.sponsored` | Static Slate |

## 8. Motion Table & Spatial Physics
| Element | Trigger | Animated Properties | Duration / Curve | Settled State | On Re-trigger |
|---|---|---|---|---|---|
| Completion Button | `:active` | `transform: scale(1→0.97)` | 120ms ease-out | Equals static | Springs back |

- **Fallback Ladder**: Reduced motion = instantaneous state update, zero scale.

## 9. Continuity & Tactility Contract
- **Navigation Edge (From → To)**: Popping navigates back to `TasksListTab`.
- **Tactile Responses**: 0.97x active scale on button press.

## 10. The Signature Moment & Emotional Peak
- What happens: Completing or deleting a task provides crisp tactile feedback. The big native ad card loads inside an identical architectural surface without shifting adjacent elements.
- Why it is this one: Demonstrates layout-stable deep screen ad presentation.

## 11. Verification Matrix
- Mechanical checks: Slots matched (8/8), Text nodes (8), Settled geometry static (Pass), 13ms Glanceability (Pass).

## 12. Deviations from Durable Contract
- None.

## 13. Known Gaps — Not in Scope
- None.
