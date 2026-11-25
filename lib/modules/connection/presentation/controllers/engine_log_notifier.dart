import 'dart:async';
import 'dart:ui';

import 'package:begzar/modules/connection/di/connection_providers.dart';
import 'package:begzar/modules/connection/domain/entities/engine_log_line.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the log viewer shows.
class EngineLogState {
  const EngineLogState({
    this.lines = const [],
    this.filter,
    this.unavailable = false,
    this.dropped = false,
    this.busy = false,
  });

  /// Every line read since the viewer opened, oldest first.
  final List<EngineLogLine> lines;

  /// The one component shown, or null for all of them.
  final EngineLogComponent? filter;

  /// The last read failed: the engine did not answer. The lines already read
  /// stay on screen.
  final bool unavailable;

  /// Lines were pushed out of the engine's ring before they could be read.
  final bool dropped;

  /// A clear or an export is under way.
  final bool busy;

  List<EngineLogLine> get visible {
    final filter = this.filter;
    if (filter == null) return lines;
    return [
      for (final line in lines)
        if (line.component == filter) line,
    ];
  }

  EngineLogState copyWith({
    List<EngineLogLine>? lines,
    EngineLogComponent? Function()? filter,
    bool? unavailable,
    bool? dropped,
    bool? busy,
  }) {
    return EngineLogState(
      lines: lines ?? this.lines,
      filter: filter != null ? filter() : this.filter,
      unavailable: unavailable ?? this.unavailable,
      dropped: dropped ?? this.dropped,
      busy: busy ?? this.busy,
    );
  }
}

/// Keeps the log viewer's lines current while it is open.
///
/// It reads everything the engine kept when the viewer opens, then asks again
/// as soon as each read answers. Each read asks the engine to hold it for up
/// to [waitForLines] when nothing is new, and the engine answers the moment a
/// line is written, so lines appear as they happen rather than at the next
/// tick. It stops when the viewer closes: nothing reads the log while no one
/// is looking at it.
class EngineLogNotifier extends Notifier<EngineLogState> {
  /// How long one read may be held waiting for a line.
  static const waitForLines = Duration(milliseconds: 1500);

  /// The pace when reads come back at once with nothing: an engine that
  /// cannot hold a read, or no tunnel to ask on iOS. Also the pause after a
  /// read the engine did not answer.
  static const pollInterval = Duration(seconds: 1);

  /// The least time between two reads, so a stream of lines is read in
  /// batches rather than one round trip per line.
  static const minGap = Duration(milliseconds: 100);

  /// As many lines as the engine keeps, so the viewer never holds more than
  /// the engine could give it again.
  static const maxLines = 5000;

  bool _closed = false;
  bool _reading = false;

  /// Moves on with every clear, so a read that was under way when the log
  /// was cleared cannot put the cleared lines back.
  int _generation = 0;

  @override
  EngineLogState build() {
    _closed = false;
    ref.onDispose(() => _closed = true);
    Future.microtask(_follow);
    return const EngineLogState();
  }

  Future<void> _follow() async {
    await _poll(fromStart: true);
    while (!_closed) {
      final watch = Stopwatch()..start();
      final outcome = await _poll(wait: waitForLines);
      if (_closed) return;
      await Future<void>.delayed(_gapAfter(outcome, watch.elapsed));
    }
  }

  static Duration _gapAfter(_PollOutcome outcome, Duration took) {
    switch (outcome) {
      case _PollOutcome.lines:
        return minGap;
      case _PollOutcome.failed:
        return pollInterval;
      case _PollOutcome.nothing:
        // A read that was held came back late; one that came back at once
        // was not held, and asking again at once would only spin.
        final rest = pollInterval - took;
        return rest > minGap ? rest : minGap;
    }
  }

  Future<_PollOutcome> _poll({
    bool fromStart = false,
    Duration wait = Duration.zero,
  }) async {
    if (_reading) return _PollOutcome.nothing;
    _reading = true;
    final generation = _generation;
    try {
      final result = await ref
          .read(engineLogRepositoryProvider)
          .read(fromStart: fromStart, wait: wait);
      if (!ref.mounted || generation != _generation) {
        return _PollOutcome.nothing;
      }
      return result.match<_PollOutcome>(
        (_) {
          state = state.copyWith(unavailable: true);
          return _PollOutcome.failed;
        },
        (batch) {
          final base = fromStart ? const <EngineLogLine>[] : state.lines;
          state = state.copyWith(
            lines: _capped([...base, ...batch.lines]),
            unavailable: false,
            dropped: state.dropped || batch.dropped,
          );
          return batch.lines.isEmpty
              ? _PollOutcome.nothing
              : _PollOutcome.lines;
        },
      );
    } finally {
      _reading = false;
    }
  }

  /// One read now, without waiting for lines, rather than when the loop
  /// next asks.
  @visibleForTesting
  Future<void> pollNow() async {
    // A read the loop has under way would make this one a no-op.
    while (_reading) {
      await Future<void>.delayed(Duration.zero);
    }
    await _poll();
  }

  static List<EngineLogLine> _capped(List<EngineLogLine> lines) =>
      lines.length <= maxLines ? lines : lines.sublist(lines.length - maxLines);

  /// Shows only [component], or every component when null.
  void showOnly(EngineLogComponent? component) {
    state = state.copyWith(filter: () => component);
  }

  /// Empties the engine's log and the viewer. The failure's key, or null.
  Future<String?> clear() async {
    _generation++;
    state = state.copyWith(busy: true);
    final result = await ref.read(engineLogRepositoryProvider).clear();
    if (!ref.mounted) return null;
    return result.match(
      (failure) {
        state = state.copyWith(busy: false);
        return failure.userFacingKey;
      },
      (_) {
        // Again, for a read that began before the engine had cleared.
        _generation++;
        state = state.copyWith(lines: const [], dropped: false, busy: false);
        return null;
      },
    );
  }

  /// Exports the lines on screen, filter included.
  Future<({EngineLogExportOutcome? outcome, String? failureKey})> export({
    Rect? shareOrigin,
  }) async {
    state = state.copyWith(busy: true);
    final result = await ref
        .read(engineLogRepositoryProvider)
        .export(state.visible, shareOrigin: shareOrigin);
    if (ref.mounted) state = state.copyWith(busy: false);
    return result.match(
      (failure) => (outcome: null, failureKey: failure.userFacingKey),
      (outcome) => (outcome: outcome, failureKey: null),
    );
  }
}

final engineLogProvider =
    NotifierProvider.autoDispose<EngineLogNotifier, EngineLogState>(
      EngineLogNotifier.new,
    );

enum _PollOutcome { lines, nothing, failed }
