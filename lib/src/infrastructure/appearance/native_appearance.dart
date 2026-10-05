import 'dart:math';

import '../../domain/models/ad_placement.dart';
import '../../domain/models/native_ad_style.dart';
import 'native_appearance.g.dart';

/// Owns appearance for one session, including requests whose native view has
/// not been created yet. The host receives complete, ordered render manifests.
final class NativeAppearance {
  final NativeAppearanceHost _host;
  final String sessionId = '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
  NativeAdStyle _defaults;
  final _overrides = <String, NativeAdStyle>{};
  final _renders = <String, NativePlacement>{};
  Future<void> _tail = Future.value();
  Future<void>? _start;
  bool _disposed = false;
  int _revision = 0;
  int _nextRender = 0;

  NativeAppearance({NativeAdStyle defaults = const NativeAdStyle(), NativeAppearanceHost? host})
    : _defaults = defaults,
      _host = host ?? NativeAppearanceHost() {
    defaults.validate();
  }

  Future<void> start() {
    if (_disposed) {
      return Future.error(StateError('Native appearance session is disposed.'));
    }
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
    final snapshot = <String, NativeStyleData>{
      for (final entry in _renders.entries)
        entry.key: _data((_overrides[entry.value.id] ?? entry.value.style).over(_defaults)),
    };
    return _enqueue(() async {
      if (_disposed) throw StateError('Native appearance session is disposed.');
      await _host.applyStyle(sessionId, revision, snapshot);
    });
  }

  /// Replaces overrides at one level. Empty style restores inheritance.
  /// The returned future reports host failures; retained intent is retried by
  /// the next update/request's complete snapshot.
  Future<void> setStyle(NativeAdStyle style, {NativePlacement? placement}) async {
    style.validate();
    if (_disposed) throw StateError('Native appearance session is disposed.');
    if (placement == null) {
      _defaults = style;
    } else {
      _overrides[placement.id] = style;
    }
    await start();
    await _publish();
  }

  /// Reserves identity before SDK loading, so updates also cover pending views.
  Future<String> reserve(NativePlacement placement) async {
    placement.style.validate();
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

  /// Configures and measures the SDK view using native layout before mounting.
  Future<double> layout(String renderId, NativeLayoutRequest request) {
    if (_disposed || !_renders.containsKey(renderId)) {
      return Future.error(StateError('Native render is no longer available.'));
    }
    return _enqueue(() {
      if (_disposed || !_renders.containsKey(renderId)) {
        throw StateError('Native render is no longer available.');
      }
      return _host.layoutNativeAd(sessionId, renderId, request);
    });
  }

  Future<void> dispose() {
    if (_disposed) return _tail;
    _disposed = true;
    _renders.clear();
    if (_start == null) return Future.value();
    return _enqueue(() => _host.endSession(sessionId));
  }

  static NativeStyleData _data(NativeAdStyle style) => NativeStyleData(
    background: style.background,
    headline: style.headline,
    body: style.body,
    callToActionBackground: style.callToActionBackground,
    callToActionText: style.callToActionText,
    callToActionCornerRadius: style.callToActionCornerRadius,
  );
}
