# Foundations: Design Tokens & Visual Architecture

## 1. Color Palette (Architectural Light Theme)

```dart
// Canvas & Surfaces
static const Color canvasGround     = Color(0xFFF8F9FA); // Architectural Chalk (Never flat #FFFFFF)
static const Color surfaceCard      = Color(0xFFFFFFFF); // Elevated Pure White Card
static const Color surfaceSubtle    = Color(0xFFF1F5F9); // Recessed Well / Track / Input fill
static const Color borderSubtle     = Color(0xFFE2E8F0); // 1px Hairline Slate Border
static const Color borderStrong     = Color(0xFFCBD5E1); // Focused / Active Border

// Ink & Typography
static const Color textInkPrimary   = Color(0xFF0F172A); // Slate 900 Display Ink
static const Color textSlateMedium  = Color(0xFF475569); // Slate 600 Body
static const Color textMutedCaption = Color(0xFF94A3B8); // Slate 400 Microcopy / Monospace labels

// Brand & Interactive Accents
static const Color accentPrimary    = Color(0xFF4338CA); // Royal Indigo 700 (High contrast action)
static const Color accentHover      = Color(0xFF4F46E5); // Indigo 600
static const Color accentSubtle     = Color(0xFFEEF2FF); // Indigo 50 Fill wash

// Semantic Badges & Telemetry
static const Color emeraldText      = Color(0xFF047857);
static const Color emeraldSurface   = Color(0xFFECFDF5);
static const Color emeraldBorder    = Color(0xFFA7F3D0);

static const Color amberText        = Color(0xFFB45309);
static const Color amberSurface     = Color(0xFFFFFBEB);
static const Color amberBorder      = Color(0xFFFDE68A);

static const Color roseText         = Color(0xFFB91C1C);
static const Color roseSurface      = Color(0xFFFEF2F2);
static const Color roseBorder       = Color(0xFFFECACA);

static const Color slateText        = Color(0xFF334155);
static const Color slateSurface     = Color(0xFFF1F5F9);
static const Color slateBorder      = Color(0xFFCBD5E1);
```

## 2. Elevation & Specular Shadows

```dart
// Card Shadow (Layer 1)
static const List<BoxShadow> cardShadow = [
  BoxShadow(
    color: Color(0x080F172A), // 3% opacity slate
    blurRadius: 8,
    offset: Offset(0, 2),
  ),
  BoxShadow(
    color: Color(0x040F172A),
    blurRadius: 1,
    offset: Offset(0, 1),
  ),
];

// Floating Modal / Sheet Shadow (Layer 2)
static const List<BoxShadow> modalShadow = [
  BoxShadow(
    color: Color(0x120F172A),
    blurRadius: 24,
    offset: Offset(0, 8),
  ),
];
```

## 3. Concentric Radii Formula

Strictly enforce $r_{\text{inner}} = r_{\text{outer}} - \text{padding}$:
- Outer Card: `BorderRadius.circular(16)` with `padding: EdgeInsets.all(12)` $\implies$ Inner Badge / Chip: `BorderRadius.circular(4)` ($16 - 12 = 4$).
- Outer Container: `BorderRadius.circular(20)` with `padding: EdgeInsets.all(16)` $\implies$ Inner Item: `BorderRadius.circular(4)` ($20 - 16 = 4$).
- Standalone Action Button: `BorderRadius.circular(12)`.
- Input Field: `BorderRadius.circular(10)`.

## 4. Kinetic Feedback & Motion

- **Active Press**: Scale to `0.97` on press-down with `120ms ease-out` curve. Return on release with `180ms ease-out`.
- **Properties Animated**: Exclusively `Transform.scale`, `Opacity`, `SlideTransition`. Height/width animation is strictly forbidden.
- **Settled Geometry**: Settled state must be identical to static layout.
