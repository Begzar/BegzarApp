/// Counts taps that come in quick succession, and says when enough have.
///
/// A tap more than [gap] after the one before starts the count again, so the
/// hidden action behind the wordmark is reached on purpose and not by a
/// reader tapping it now and then.
class TapStreak {
  TapStreak({this.needed = 7, this.gap = const Duration(milliseconds: 700)});

  final int needed;
  final Duration gap;

  int _count = 0;
  DateTime? _last;

  /// Records a tap at [now]. True on the tap that completes the streak,
  /// which also starts the count again.
  bool tap(DateTime now) {
    final last = _last;
    _count = last != null && now.difference(last) <= gap ? _count + 1 : 1;
    _last = now;
    if (_count < needed) return false;
    _count = 0;
    _last = null;
    return true;
  }
}
