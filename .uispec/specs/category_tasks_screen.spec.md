# Spec: category_tasks_screen

Pass: 1. Written 2026-09-09. Disposable.
Concept: "Architectural Clarity for High-Agency Builders"
UI Design Class: Class 1 (Target Visual Ratio: 70%)

## 1. What this surface is for
- Single Question Answered: What tasks belong specifically to this isolated category workspace?
- Primary Action Trigger: Task Tiles in feed with tactile completion checkbox.
- Concept Citation: "An architectural instrument crafted with structural lightness, mathematical precision, and tactile warmth."

## 2. Creative Direction & Resolved Identity
- Design Class: Class 1 (Instrumental Precision)
- Color Roles: Canvas (`#F8F9FA`), Card Surface (`#FFFFFF`), Border (`#E2E8F0`), Accent Primary (`#4338CA`).
- Typography Pairing: Display (Ink `#0F172A`, 18pt, w700) + Body (`14pt`) + Monospace Tags (`11pt`, w600).
- Radii & Insets: Inset `16`, Radii `14pt` for task cards, `16pt` for medium native ad card.
- Depth Tier: Tier 1 (Elevated cards with 1px zinc borders and soft shadows).

## 3. Visual Journey & Visual Telemetry Map
- **Visual Journey**:
  1. *First Seen*: Top Category Monogram and Workspace Title in AppBar.
  2. *Next Noticed*: Filtered Task List with interactive checkboxes.
  3. *Attention Lands*: Bottom Pinned Medium Native Ad Card in 16px architectural container.
- **Visual Telemetry Substitutions**:
  - Native Ad: Mapped to a framed 16px radius `TaskCard` container labeled `SPONSORED RECOMMENDATION`.

## 4. Contextual Tips & Guidance
- Target Element: ad.sponsored
- Trigger: Mount
- Exact Copy: "SPONSORED RECOMMENDATION"
- Recession Rule: Collapses when user is VIP.

## 5. Element Inventory & Countable Budget
- Ordered Hierarchy: [AppBar (Category Icon + Title) → Scrollable Task List → Bottom Framed Medium Native Ad]
- Text Nodes: 3
- Accent Colors: 1 (`#4338CA`)
- Container Levels: 3 max
- Decorative Elements: 0
- Animating Elements: 1 (Checkbox completion animation)

## 6. Slot Table
| Slot Key | Source | States / Count | Longest Value | Overflow Rule | Notes |
|---|---|---|---|---|---|
| empty.title | slot file | 1 | `No tasks in this workspace` | `grow-container-never-truncate` | Empty title |
| empty.desc | slot file | 1 | `All objectives clear. Tap the floating action button to create objectives under this category.` | `wrap-then-truncate-at-2` | Empty desc |
| ad.sponsored | slot file | 1 | `SPONSORED RECOMMENDATION` | `grow-container-never-truncate` | Ad header |

- **Growth Region**: `ListView filtered tasks`
- **Pinned Below**: `Bottom Framed Medium Native Ad`

## 7. State Matrix
| State | Visual Anchor State | Rendered Text Keys | Telemetry Beacon |
|---|---|---|---|
| **Free Active** | Tasks + Medium Native Ad | All slots | Static Slate |
| **VIP Active** | Tasks only (ad collapsed) | All slots except `ad.sponsored` | Static Emerald |
| **Empty** | Architectural empty canvas card | `empty.title`, `empty.desc` | Static Slate |

## 8. Motion Table & Spatial Physics
| Element | Trigger | Animated Properties | Duration / Curve | Settled State | On Re-trigger |
|---|---|---|---|---|---|
| Task Card | `:active` | `transform: scale(1→0.97)` | 120ms ease-out | Equals static | Springs back |

- **Fallback Ladder**: Reduced motion = instantaneous tap routing, zero scale.

## 9. Continuity & Tactility Contract
- **Navigation Edge (From → To)**:
  - Tapping task opens `TaskDetailScreen(taskId: task.id)`.
  - Popping returns to `CategoriesTab`.
- **Tactile Responses**: 0.97x active scale on task card tap.

## 10. The Signature Moment & Emotional Peak
- What happens: The workspace displays exclusively relevant tasks with full architectural polish, while the medium native ad remains framed and stable.
- Why it is this one: Preserves clean domain boundaries without layout shifts.

## 11. Verification Matrix
- Mechanical checks: Slots matched (3/3), Text nodes (3), Settled geometry static (Pass), 13ms Glanceability (Pass).

## 12. Deviations from Durable Contract
- None.

## 13. Known Gaps — Not in Scope
- None.
