# Spec: create_task_screen

Pass: 1. Written 2026-09-09. Disposable.
Concept: "Architectural Clarity for High-Agency Builders"
UI Design Class: Class 1 (Target Visual Ratio: 65%)

## 1. What this surface is for
- Single Question Answered: How does the builder declare and configure a new actionable work unit?
- Primary Action Trigger: Bottom Pinned Save Button ("Save Task"), 52pt height.
- Concept Citation: "An architectural instrument crafted with structural lightness, mathematical precision, and tactile warmth."

## 2. Creative Direction & Resolved Identity
- Design Class: Class 1 (Instrumental Precision)
- Color Roles: Canvas (`#F8F9FA`), Input Surface (`#FFFFFF`), Border (`#E2E8F0`), Active Focus Border (`#4338CA`), Accent Primary (`#4338CA`).
- Typography Pairing: Display (Ink `#0F172A`, 18pt, w700, -0.3 tracking) + Section Labels (`#94A3B8`, 11pt, w700, +0.6 tracking) + Input text (`15pt`).
- Radii & Insets: Inset `20`, Radii `12pt` for text fields, `8pt` for category chips, `10pt` for priority blocks, `14pt` for Save CTA.
- Depth Tier: Tier 1 (Light architectural form with focused borders).

## 3. Visual Journey & Visual Telemetry Map
- **Visual Journey**:
  1. *First Seen*: Task Title Input Field with crisp focused border.
  2. *Next Noticed*: Category Chips with color icons + 3-tier Priority Selector.
  3. *Attention Lands*: Bottom Pinned "Save Task" Tactile Action Button.
- **Visual Telemetry Substitutions**:
  - Route Guarding: This route is marked as protected from App Open ads to ensure zero interruption while typing.

## 4. Contextual Tips & Guidance
- Target Element: error.empty_title
- Trigger: Save attempt with empty title
- Exact Copy: "Please enter a task title"
- Recession Rule: Dismisses via SnackBar.

## 5. Element Inventory & Countable Budget
- Ordered Hierarchy: [Top AppBar → Form Fields (Title + Notes + Category + Priority) → Bottom Save CTA]
- Text Nodes: 9
- Accent Colors: 1 (`#4338CA`)
- Container Levels: 2 max
- Decorative Elements: 0
- Animating Elements: 1 (CTA active scale)

## 6. Slot Table
| Slot Key | Source | States / Count | Longest Value | Overflow Rule | Notes |
|---|---|---|---|---|---|
| appbar.title | slot file | 1 | `Create New Task` | `grow-container-never-truncate` | Header |
| field.title.label | slot file | 1 | `TASK TITLE` | `grow-container-never-truncate` | Monospace label |
| field.title.hint | slot file | 1 | `e.g. Implement Paywall Close Guard` | `wrap-then-truncate-at-2` | Placeholder |
| field.desc.label | slot file | 1 | `DESCRIPTION & NOTES` | `grow-container-never-truncate` | Monospace label |
| field.desc.hint | slot file | 1 | `Add technical specifications, acceptance criteria, or reminders...` | `wrap-then-truncate-at-2` | Placeholder |
| section.category | slot file | 1 | `CATEGORY` | `grow-container-never-truncate` | Monospace label |
| section.priority | slot file | 1 | `PRIORITY LEVEL` | `grow-container-never-truncate` | Monospace label |
| action.save | slot file | 1 | `Save Task` | `grow-container-never-truncate` | CTA button |
| error.empty_title | slot file | 1 | `Please enter a task title` | `grow-container-never-truncate` | SnackBar error |

- **Growth Region**: `SingleChildScrollView form body`
- **Pinned Below**: `Bottom Save Action Button`

## 7. State Matrix
| State | Visual Anchor State | Rendered Text Keys | Telemetry Beacon |
|---|---|---|---|
| **Default Form** | Focused Title Input | All slots except error | Static Slate |
| **Validation Error** | Error SnackBar | `error.empty_title` | Hazard Amber |

## 8. Motion Table & Spatial Physics
| Element | Trigger | Animated Properties | Duration / Curve | Settled State | On Re-trigger |
|---|---|---|---|---|---|
| Save Button | `:active` | `transform: scale(1→0.97)` | 120ms ease-out | Equals static | Springs back |

- **Fallback Ladder**: Reduced motion = instantaneous save, zero scale.

## 9. Continuity & Tactility Contract
- **Navigation Edge (From → To)**: Closes via `Navigator.pop(context)` returning to task list.
- **Tactile Responses**: 0.97x active scale on Save CTA.

## 10. The Signature Moment & Emotional Peak
- What happens: The creation sheet provides a disturbance-free drafting canvas. Route-aware ad observation suppresses App Open ads so the user's train of thought is never broken.
- Why it is this one: Demonstrates lifecycle-guarded modal route awareness.

## 11. Verification Matrix
- Mechanical checks: Slots matched (9/9), Text nodes (9), Settled geometry static (Pass), 13ms Glanceability (Pass).

## 12. Deviations from Durable Contract
- None.

## 13. Known Gaps — Not in Scope
- None.
