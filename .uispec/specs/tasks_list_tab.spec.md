# Spec: tasks_list_tab

Pass: 1. Written 2026-09-09. Disposable.
Concept: "Architectural Clarity for High-Agency Builders"
UI Design Class: Class 1 (Target Visual Ratio: 70%)

## 1. What this surface is for
- Single Question Answered: What priority tasks are scheduled and ready for immediate execution?
- Primary Action Trigger: Floating Action Button ("New Task") anchored in the bottom right thumb zone.
- Concept Citation: "An architectural instrument crafted with structural lightness, mathematical precision, and tactile warmth."

## 2. Creative Direction & Resolved Identity
- Design Class: Class 1 (Instrumental Precision)
- Color Roles: Canvas (`#F8F9FA`), Card Surface (`#FFFFFF`), Border (`#E2E8F0`), Accent Primary (`#4338CA`), Badge Emerald (`#047857`).
- Typography Pairing: Display (Ink `#0F172A`, 24pt, w800, -0.4 tracking) + Filter Chips (`12pt`, w600) + Body (`14pt`).
- Radii & Insets: Inset `16`, Radii `14pt` for task cards, `16pt` for native ad cards, `12pt` for FAB.
- Depth Tier: Tier 1 (Elevated white cards over architectural chalk canvas).

## 3. Visual Journey & Visual Telemetry Map
- **Visual Journey**:
  1. *First Seen*: Top Header with Backlog Telemetry (`pending • done`) and Filter Segment Controls.
  2. *Next Noticed*: Task Feed with interactive circular checkboxes and priority indicators.
  3. *Attention Lands*: Injected Native Ad Card (Medium at index 1, Big at index 4) styled identically to user tasks + Pinned FAB.
- **Visual Telemetry Substitutions**:
  - Task completion: Mapped to interactive tactile circular checkbox with spring fill.
  - Native ads: Mapped to architectural 16px radius cards with subtle `SPONSORED` monospace tag and 1px border.

## 4. Contextual Tips & Guidance
- Target Element: ad.sponsored
- Trigger: Mount
- Exact Copy: "SPONSORED"
- Recession Rule: Collapses completely when VIP is active.

## 5. Element Inventory & Countable Budget
- Ordered Hierarchy: [Top Sticky Stats & Filters → Scrollable SliverList (Tasks + Native Ads) → Bottom Right FAB]
- Text Nodes: 10
- Accent Colors: 1 (`#4338CA`)
- Container Levels: 3 max
- Decorative Elements: 0
- Animating Elements: 2 (Checkbox completion animation, FAB active press scale)

## 6. Slot Table
| Slot Key | Source | States / Count | Longest Value | Overflow Rule | Notes |
|---|---|---|---|---|---|
| header.title | slot file | 1 | `My Tasks` | `grow-container-never-truncate` | Tab title |
| header.stats.template | slot file | 1 | `pending • done` | `grow-container-never-truncate` | Dynamic counter |
| filter.all | slot file | 1 | `All` | `grow-container-never-truncate` | Chip 1 |
| filter.pending | slot file | 1 | `Pending` | `grow-container-never-truncate` | Chip 2 |
| filter.completed | slot file | 1 | `Done` | `grow-container-never-truncate` | Chip 3 |
| badge.pro | slot file | 1 | `PRO ACTIVE` | `grow-container-never-truncate` | VIP chip |
| ad.sponsored | slot file | 1 | `SPONSORED` | `grow-container-never-truncate` | Native ad tag |
| action.create | slot file | 1 | `New Task` | `grow-container-never-truncate` | FAB label |
| empty.title | slot file | 1 | `No Tasks Found` | `grow-container-never-truncate` | Empty state |
| empty.desc | slot file | 1 | `All objectives clear. Tap New Task to architect your next goal.` | `wrap-then-truncate-at-2` | Empty desc |

- **Growth Region**: `SliverList task feed`
- **Pinned Below**: `Floating Action Button in thumb zone`

## 7. State Matrix
| State | Visual Anchor State | Rendered Text Keys | Telemetry Beacon |
|---|---|---|---|
| **Free Active** | Tasks + Medium Native Ad + Big Native Ad | All slots | Static Slate |
| **VIP Active** | Tasks only (all native ads collapsed) | `badge.pro` active, zero ads | Pulsing Emerald |
| **Empty Backlog** | Architectural empty canvas card | `empty.title`, `empty.desc` | Static Slate |

## 8. Motion Table & Spatial Physics
| Element | Trigger | Animated Properties | Duration / Curve | Settled State | On Re-trigger |
|---|---|---|---|---|---|
| FAB | `:active` | `transform: scale(1→0.97)` | 120ms ease-out | Equals static | Springs back |
| Checkbox | Tap | `opacity` | 180ms ease-out | Equals static | Retargets |

- **Fallback Ladder**: Reduced motion = static step updates, zero button scale.

## 9. Continuity & Tactility Contract
- **Navigation Edge (From → To)**:
  - Tapping task opens `TaskDetailScreen(taskId: task.id)`.
  - Tapping FAB opens `CreateTaskScreen()`.
  - Completing 3 tasks triggers `SampleAds.mainInterstitial` via `recordActionAndCheckInterval`.
- **Tactile Responses**: 0.97x active scale on task card tap and FAB press.

## 10. The Signature Moment & Emotional Peak
- What happens: Completing tasks gives an immediate tactile haptic pop. Every 3rd completion triggers an interval interstitial ad seamlessly without delaying the UI or dropping frames.
- Why it is this one: Demonstrates interval ad scheduling without forced cooldowns.

## 11. Verification Matrix
- Mechanical checks: Slots matched (10/10), Text nodes (10), Settled geometry static (Pass), 13ms Glanceability (Pass).

## 12. Deviations from Durable Contract
- None.

## 13. Known Gaps — Not in Scope
- None.
