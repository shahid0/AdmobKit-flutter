import 'package:flutter/material.dart';

/// Architectural Light Theme design tokens for TaskFlow Pro.
abstract final class TaskColors {
  // Canvas & Surfaces
  static const Color canvasGround = Color(0xFFF8F9FA); // Architectural Chalk (Never flat #FFFFFF)
  static const Color surfaceCard = Color(0xFFFFFFFF); // Elevated Pure White Card
  static const Color surfaceSubtle = Color(0xFFF1F5F9); // Recessed Well / Track / Input fill
  static const Color borderSubtle = Color(0xFFE2E8F0); // 1px Hairline Slate Border
  static const Color borderStrong = Color(0xFFCBD5E1); // Focused / Active Border

  // Ink & Typography
  static const Color textInkPrimary = Color(0xFF0F172A); // Slate 900 Display Ink
  static const Color textSlateMedium = Color(0xFF475569); // Slate 600 Body
  static const Color textMutedCaption = Color(0xFF94A3B8); // Slate 400 Microcopy / Monospace labels

  // Brand & Interactive Accents
  static const Color accentPrimary = Color(0xFF4338CA); // Royal Indigo 700 (High contrast action)
  static const Color accentHover = Color(0xFF4F46E5); // Indigo 600
  static const Color accentSubtle = Color(0xFFEEF2FF); // Indigo 50 Fill wash

  // Semantic Badges & Telemetry
  static const Color emeraldText = Color(0xFF047857);
  static const Color emeraldSurface = Color(0xFFECFDF5);
  static const Color emeraldBorder = Color(0xFFA7F3D0);

  static const Color amberText = Color(0xFFB45309);
  static const Color amberSurface = Color(0xFFFFFBEB);
  static const Color amberBorder = Color(0xFFFDE68A);

  static const Color roseText = Color(0xFFB91C1C);
  static const Color roseSurface = Color(0xFFFEF2F2);
  static const Color roseBorder = Color(0xFFFECACA);

  static const Color slateText = Color(0xFF334155);
  static const Color slateSurface = Color(0xFFF1F5F9);
  static const Color slateBorder = Color(0xFFCBD5E1);

  // Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x040F172A),
      blurRadius: 1,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> modalShadow = [
    BoxShadow(
      color: Color(0x140F172A),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}

/// Global theme definition adhering to Architectural Light Theme invariants.
abstract final class TaskTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: TaskColors.canvasGround,
      colorScheme: const ColorScheme.light(
        primary: TaskColors.accentPrimary,
        onPrimary: Colors.white,
        surface: TaskColors.surfaceCard,
        onSurface: TaskColors.textInkPrimary,
        outline: TaskColors.borderSubtle,
        secondary: TaskColors.accentHover,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: TaskColors.canvasGround,
        foregroundColor: TaskColors.textInkPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: TaskColors.textInkPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: TaskColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: TaskColors.borderSubtle),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: TaskColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: TaskColors.textInkPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          height: 1.15,
        ),
        headlineMedium: TextStyle(
          color: TaskColors.textInkPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          height: 1.2,
        ),
        titleMedium: TextStyle(
          color: TaskColors.textInkPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        bodyMedium: TextStyle(
          color: TaskColors.textSlateMedium,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          color: TaskColors.textMutedCaption,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        labelSmall: TextStyle(
          color: TaskColors.textMutedCaption,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Tactile button wrapper that scales to 0.97 on press-down for instant haptic visual feedback.
class TactileButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final HitTestBehavior behavior;

  const TactileButton({
    super.key,
    required this.child,
    this.onTap,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Standard architectural surface card container adhering to concentric radii and 1px border.
class TaskCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Border? border;

  const TaskCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16,
    this.onTap,
    this.backgroundColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? TaskColors.surfaceCard,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(color: TaskColors.borderSubtle),
        boxShadow: TaskColors.cardShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      return TactileButton(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}

/// Semantic status badge with monospace tabular tag.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color surfaceColor;
  final Color borderColor;
  final Widget? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.textColor,
    required this.surfaceColor,
    required this.borderColor,
    this.icon,
  });

  factory StatusBadge.emerald(String label, {Widget? icon}) => StatusBadge(
        label: label,
        textColor: TaskColors.emeraldText,
        surfaceColor: TaskColors.emeraldSurface,
        borderColor: TaskColors.emeraldBorder,
        icon: icon,
      );

  factory StatusBadge.amber(String label, {Widget? icon}) => StatusBadge(
        label: label,
        textColor: TaskColors.amberText,
        surfaceColor: TaskColors.amberSurface,
        borderColor: TaskColors.amberBorder,
        icon: icon,
      );

  factory StatusBadge.rose(String label, {Widget? icon}) => StatusBadge(
        label: label,
        textColor: TaskColors.roseText,
        surfaceColor: TaskColors.roseSurface,
        borderColor: TaskColors.roseBorder,
        icon: icon,
      );

  factory StatusBadge.slate(String label, {Widget? icon}) => StatusBadge(
        label: label,
        textColor: TaskColors.slateText,
        surfaceColor: TaskColors.slateSurface,
        borderColor: TaskColors.slateBorder,
        icon: icon,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
