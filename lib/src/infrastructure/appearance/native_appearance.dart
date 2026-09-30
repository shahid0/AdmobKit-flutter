import 'dart:math';

import '../../domain/models/ad_placement.dart';
import '../../domain/models/native_ad_colors.dart';
import 'native_appearance.g.dart';

/// Owns appearance for one session, including requests whose native view has
/// not been created yet. The host receives complete, ordered render manifests.
final class NativeAppearance {
  final NativeAppearanceHost _host;
  final String sessionId = '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
  NativeAdColors _defaults;
  final _overrides = <String, NativeAdColors>{};
  final _renders = <String, NativePlacement>{};
  Future<void> _tail = Future.value();
  Future<void>? _start;
  bool _disposed = false;
  int _revision = 0;
  int _nextRender = 0;

  NativeAppearance({NativeAdColors defaults = const NativeAdColors(), NativeAppearanceHost? host})
    : _defaults = defaults,
      _host = host ?? NativeAppearanceHost() {
    defaults.validate();
  }

  Future<void> start() {
    if (_disposed) return Future.error(StateError('Native appearance session is disposed.'));
    final existing = _start;
    if (existing != null) return existing;
    final starting = _enqueue(() {
      if (_disposed) throw StateError('Native appearance session is disposed.');
      return _host.startSession(sessionId);
    });
    _start = starting;
    starting.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {
        if (identical(_start, starting)) _start = null;
      },
    );
    return starting;
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    // Observe internal errors without swallowing errors on the returned future.
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _publish() {
    final revision = ++_revision;
    final snapshot = <String, NativePalette>{
      for (final entry in _renders.entries)
        entry.key: _palette((_overrides[entry.value.id] ?? entry.value.colors).over(_defaults)),
    };
    return _enqueue(() async {
      if (_disposed) throw StateError('Native appearance session is disposed.');
      await _host.applyColors(sessionId, revision, snapshot);
    });
  }

  /// Replaces overrides at one level. Empty colors restore inheritance.
  /// The returned future reports host failures; retained intent is retried by
  /// the next update/request's complete snapshot.
  Future<void> setColors(NativeAdColors colors, {NativePlacement? placement}) async {
    colors.validate();
    if (_disposed) throw StateError('Native appearance session is disposed.');
    if (placement == null) {
      _defaults = colors;
    } else {
      _overrides[placement.id] = colors;
    }
    await start();
    await _publish();
  }

  /// Reserves identity before SDK loading, so updates also cover pending views.
  Future<String> reserve(NativePlacement placement) async {
    placement.colors.validate();
    await start();
    if (_disposed) throw StateError('Native appearance session is disposed.');
    final renderId = '${++_nextRender}';
    _renders[renderId] = placement;
    try {
      await _publish();
      if (_disposed) throw StateError('Native appearance session is disposed.');
      return renderId;
    } catch (_) {
      _renders.remove(renderId);
      rethrow;
    }
  }

  Future<void> release(String renderId) {
    if (_disposed || _renders.remove(renderId) == null) return Future.value();
    return _publish();
  }

  Future<void> dispose() {
    if (_disposed) return _tail;
    _disposed = true;
    _renders.clear();
    if (_start == null) return Future.value();
    return _enqueue(() => _host.endSession(sessionId));
  }

  static NativePalette _palette(NativeAdColors colors) => NativePalette(
    background: colors.background,
    headline: colors.headline,
    body: colors.body,
    callToActionBackground: colors.callToActionBackground,
    callToActionText: colors.callToActionText,
  );
}
