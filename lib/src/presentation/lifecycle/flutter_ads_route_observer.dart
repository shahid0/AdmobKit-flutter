import 'package:flutter/widgets.dart';

/// Route observer that tracks the top-most active route for view-lifecycle-aware ads.
///
/// Ensures App Open and resume ads only trigger when the user returns to approved
/// screens, and never while inside sensitive modal dialogs, creation forms, or paywalls.
class FlutterAdsRouteObserver extends NavigatorObserver {
  Route<dynamic>? _currentRoute;
  final Set<String> _disallowedResumeRoutes = {};

  /// Currently active top-most route.
  Route<dynamic>? get currentRoute => _currentRoute;

  /// Name of the currently active route.
  String? get currentRouteName => _currentRoute?.settings.name;

  /// Registers route names where App Open / resume ads must be suppressed.
  void disallowResumeOn(Iterable<String> routeNames) {
    _disallowedResumeRoutes.addAll(routeNames);
  }

  /// Removes route names from the suppression list.
  void allowResumeOn(Iterable<String> routeNames) {
    _disallowedResumeRoutes.removeAll(routeNames);
  }

  /// Returns true if App Open / resume ads are permitted on the current route.
  bool get isResumeAdAllowed {
    final name = currentRouteName;
    if (name != null && _disallowedResumeRoutes.contains(name)) {
      return false;
    }
    // Also suppress if the top route is a modal popup/dialog
    if (_currentRoute is PopupRoute) {
      return false;
    }
    return true;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _currentRoute = route;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _currentRoute = previousRoute;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _currentRoute = newRoute;
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _currentRoute = previousRoute;
  }
}
