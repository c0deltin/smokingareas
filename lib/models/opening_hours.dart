/// Opening hours in a small structured form, read from the OSM
/// `opening_hours` syntax or from the Japanese wording of the official
/// lists ("月曜日から金曜日（祝日除く）の9時から17時まで"), so the app can show
/// them in the UI language. Pure Dart (tested); anything that is not
/// understood for sure yields null and the original text is shown instead.
library;

/// Days 1 (Monday) … 7 (Sunday).
const _allDays = [1, 2, 3, 4, 5, 6, 7];

/// One rule: on [days] (and public holidays when [holidays]) open during
/// [spans], or closed when [off].
class HoursRule {
  const HoursRule({
    this.days = _allDays,
    this.holidays = false,
    this.spans = const [],
    this.off = false,
  });

  /// Weekdays 1 (Mo) … 7 (Su); empty with [holidays] = only public holidays.
  final List<int> days;
  final bool holidays;

  /// Minutes since midnight; the end may pass midnight (e.g. 25:00 = 1500).
  final List<(int, int)> spans;
  final bool off;

  @override
  bool operator ==(Object other) =>
      other is HoursRule &&
      _eq(other.days, days) &&
      other.holidays == holidays &&
      _eq(other.spans, spans) &&
      other.off == off;

  @override
  int get hashCode => Object.hash(Object.hashAll(days), holidays,
      Object.hashAll(spans), off);

  @override
  String toString() => 'HoursRule($days, ph: $holidays, $spans, off: $off)';
}

bool _eq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class OpeningHours {
  const OpeningHours({
    this.always = false,
    this.rules = const [],
    this.closedNewYear = false,
  });

  /// Open around the clock, every day.
  final bool always;
  final List<HoursRule> rules;

  /// Closed over the New Year holidays (年末年始, usually Dec 29 – Jan 3).
  final bool closedNewYear;

  static final _parsed = <String, OpeningHours?>{};

  /// OSM syntax or Japanese wording (cached per text); null when not
  /// understood for sure.
  static OpeningHours? parse(String raw) => _parsed.putIfAbsent(
      raw, () => parseOsm(raw) ?? parseJapanese(raw));

  /// Whether the place is open at the wall-clock time [t] in Japan.
  bool isOpenAt(DateTime t, {required bool Function(DateTime) isHoliday}) {
    final day = DateTime(t.year, t.month, t.day);
    final minute = t.hour * 60 + t.minute;
    if (closedNewYear && _isNewYear(day)) return false;
    if (always) return true;
    bool within(HoursRule? r, int m) =>
        r != null && !r.off && r.spans.any((s) => s.$1 <= m && m < s.$2);
    // Today's spans, or yesterday's spans running past midnight.
    final yesterday = DateTime(day.year, day.month, day.day - 1);
    return within(_ruleFor(day, isHoliday), minute) ||
        (!(closedNewYear && _isNewYear(yesterday)) &&
            within(_ruleFor(yesterday, isHoliday), minute + 24 * 60));
  }

  /// The next time the open/closed state changes after [t] (within a week),
  /// null when it does not change.
  DateTime? nextChange(DateTime t,
      {required bool Function(DateTime) isHoliday}) {
    final now = isOpenAt(t, isHoliday: isHoliday);
    final start = DateTime(t.year, t.month, t.day, t.hour, t.minute);
    for (var m = 1; m <= 7 * 24 * 60; m++) {
      final at = start.add(Duration(minutes: m));
      if (isOpenAt(at, isHoliday: isHoliday) != now) return at;
    }
    return null;
  }

  /// The rule for a calendar day: as in OSM, a later rule replaces an
  /// earlier one for the days it names; public holidays match "PH" rules.
  HoursRule? _ruleFor(DateTime day, bool Function(DateTime) isHoliday) {
    final holiday = isHoliday(day);
    HoursRule? out;
    for (final r in rules) {
      if ((holiday && r.holidays) || r.days.contains(day.weekday)) out = r;
    }
    return out;
  }

  static bool _isNewYear(DateTime d) =>
      (d.month == 12 && d.day >= 29) || (d.month == 1 && d.day <= 3);

  static const _osmDays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  /// The OSM `opening_hours` value.
  String toOsm() {
    final parts = <String>[
      if (always) '24/7',
      for (final r in rules) _ruleToOsm(r),
      if (closedNewYear) 'Dec 29-Jan 03 off',
    ];
    return parts.join('; ');
  }

  static String _ruleToOsm(HoursRule r) {
    final sel = [
      if (r.days.isNotEmpty && (r.days.length < 7 || r.holidays))
        _daysToOsm(r.days),
      if (r.holidays) 'PH',
    ].join(',');
    final what = r.off
        ? 'off'
        : r.spans.map((s) => '${_hhmm(s.$1)}-${_hhmm(s.$2)}').join(',');
    return sel.isEmpty ? what : '$sel $what';
  }

  static String _daysToOsm(List<int> days) {
    // Consecutive runs: Mo-Fr, Mo,Tu,Th-Sa …
    final out = <String>[];
    var i = 0;
    while (i < days.length) {
      var j = i;
      while (j + 1 < days.length && days[j + 1] == days[j] + 1) {
        j++;
      }
      out.add(j - i >= 2
          ? '${_osmDays[days[i] - 1]}-${_osmDays[days[j] - 1]}'
          : [for (var k = i; k <= j; k++) _osmDays[days[k] - 1]].join(','));
      i = j + 1;
    }
    return out.join(',');
  }

  static String _hhmm(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  // -----------------------------------------------------------------------
  // OSM syntax (the common subset)
  // -----------------------------------------------------------------------

  static final _osmTime = RegExp(r'^(\d{1,2}):(\d{2})-(\d{1,2}):(\d{2})$');

  /// Parses the usual OSM forms ("24/7", "Mo-Fr 08:00-18:00; Sa 10:00-14:00",
  /// "PH off", "Dec 29-Jan 03 off"); null for anything else.
  static OpeningHours? parseOsm(String value) {
    var always = false;
    var newYear = false;
    final rules = <HoursRule>[];
    for (final raw in value.split(';')) {
      final part = raw.trim();
      if (part.isEmpty) continue;
      if (part == '24/7') {
        always = true;
        continue;
      }
      if (part == 'Dec 29-Jan 03 off' || part == 'Dec 29-Jan 3 off') {
        newYear = true;
        continue;
      }
      final words = part.split(RegExp(r'\s+'));
      List<int> days = _allDays;
      var holidays = false;
      var rest = words;
      if (words.length == 2) {
        final sel = _parseOsmDays(words.first);
        if (sel == null) return null;
        (days, holidays) = sel;
        rest = words.sublist(1);
      } else if (words.length != 1) {
        return null;
      }
      if (rest.single == 'off' || rest.single == 'closed') {
        rules.add(HoursRule(days: days, holidays: holidays, off: true));
        continue;
      }
      final spans = <(int, int)>[];
      for (final t in rest.single.split(',')) {
        final m = _osmTime.firstMatch(t);
        if (m == null) return null;
        final from = int.parse(m[1]!) * 60 + int.parse(m[2]!);
        var to = int.parse(m[3]!) * 60 + int.parse(m[4]!);
        if (to <= from) to += 24 * 60; // past midnight
        spans.add((from, to));
      }
      if (spans.length == 1 &&
          spans.single == (0, 24 * 60) &&
          days.length == 7 &&
          !holidays) {
        always = true;
        continue;
      }
      rules.add(HoursRule(days: days, holidays: holidays, spans: spans));
    }
    if (!always && rules.isEmpty && !newYear) return null;
    return OpeningHours(always: always, rules: rules, closedNewYear: newYear);
  }

  static (List<int>, bool)? _parseOsmDays(String sel) {
    final days = <int>{};
    var holidays = false;
    for (final item in sel.split(',')) {
      if (item == 'PH') {
        holidays = true;
        continue;
      }
      final range = item.split('-');
      final from = _osmDays.indexOf(range.first) + 1;
      final to = _osmDays.indexOf(range.last) + 1;
      if (from == 0 || to == 0 || range.length > 2) return null;
      for (var d = from;; d = d % 7 + 1) {
        days.add(d);
        if (d == to) break;
      }
    }
    return ((days.toList()..sort()), holidays);
  }

  // -----------------------------------------------------------------------
  // Japanese wording of the official lists
  // -----------------------------------------------------------------------

  static const _jaDays = {
    '月': 1, '火': 2, '水': 3, '木': 4, '金': 5, '土': 6, '日': 7, //
  };

  /// Parses the common Japanese wordings; null when any part is not
  /// understood (the original text is shown then).
  static OpeningHours? parseJapanese(String raw) {
    var s = _normalise(raw);
    if (s.isEmpty || s.contains('\n')) return null;

    var newYear = false;
    var holidaysOff = false;
    final closedDays = <int>{};

    // Closures in brackets or after (注): "（土曜日・日曜日・祝日を除く）".
    final notes = RegExp(r'\(注\)(.*)$|\(([^()]*)\)');
    for (final m in notes.allMatches(s).toList()) {
      final text = (m[1] ?? m[2] ?? '').trim();
      final res = _closures(text);
      if (res == null) return null;
      newYear |= res.newYear;
      holidaysOff |= res.holidays;
      closedDays.addAll(res.days);
    }
    s = s.replaceAll(notes, '').trim();
    // Trailing remarks without brackets.
    for (final tail in ['年末年始利用不可', '年末年始閉鎖', '年末年始は休業']) {
      if (s.endsWith(tail)) {
        newYear = true;
        s = s.substring(0, s.length - tail.length).trim();
      }
    }
    s = s.replaceAll(RegExp(r'[、,]$'), '');

    // Around the clock.
    const always = [
      '終日', '終日利用可能', '24時間', '24時間利用可能', '年中利用可', //
      '0:00~23:59', '00:00~23:59', '00:00:00~23:59:00', '0時~23時59分',
      '00:00~00:0024時間利用可能', '00:00~24:00', '0:00~24:00',
    ];
    var days = List<int>.of(_allDays);
    final dayPrefix =
        RegExp(r'^((?:.曜日[、・,]?)*.曜日(?:から.曜日)?|平日)の?');
    final dm = dayPrefix.firstMatch(s);
    if (dm != null) {
      final parsed = _jaDayList(dm[1]!);
      if (parsed == null) return null;
      days = parsed;
      s = s.substring(dm.end);
    }
    if (always.contains(s)) {
      if (days.length == 7 && closedDays.isEmpty && !holidaysOff) {
        return OpeningHours(always: true, closedNewYear: newYear);
      }
      s = '0:00~24:00';
    }

    final span = _jaSpan(s);
    if (span == null) return null;
    days = [for (final d in days) if (!closedDays.contains(d)) d];
    if (days.isEmpty) return null;
    return OpeningHours(
      rules: [
        HoursRule(days: days, spans: [span]),
        if (holidaysOff) const HoursRule(days: [], holidays: true, off: true),
      ],
      closedNewYear: newYear,
    );
  }

  static String _normalise(String s) {
    final b = StringBuffer();
    for (final r in s.trim().runes) {
      // Full-width ASCII (０-９, ：, （ …) to half-width.
      if (r >= 0xFF01 && r <= 0xFF5E) {
        b.writeCharCode(r - 0xFEE0);
      } else if (r == 0x3000) {
        // ideographic space: dropped
      } else if (r == 0x301C) {
        b.write('~'); // 〜 wave dash
      } else {
        b.writeCharCode(r);
      }
    }
    return b
        .toString()
        .replaceAll(' ', '')
        .replaceAll('－', '-')
        .replaceAll('（', '(')
        .replaceAll('）', ')');
  }

  /// Closing days in Japanese ("土日祝日、年末年始は休業"); null when a part
  /// is not understood (お盆, Golden Week, "every 3rd Wednesday" …).
  static Closures? parseClosures(String text) => _closures(_normalise(text));

  static Closures? _closures(String text) {
    final t = text
        .replaceAll(RegExp(r'^休み:'), '')
        .replaceAll(RegExp(r'(を除く|は休業|休業|除く)$'), '');
    if (t == '祝日含む' || t == '原則無休') return const Closures();
    if (t == '祝日除く') return const Closures(holidays: true);
    if (t == '年末年始閉鎖' || t == '年末年始利用不可') {
      return const Closures(newYear: true);
    }
    var newYear = false;
    var holidays = false;
    final days = <int>{};
    for (final item in t.split(RegExp(r'[・、,]'))) {
      final i = item.trim();
      if (i.isEmpty) continue;
      if (i == '年末年始') {
        newYear = true;
      } else if (i == '祝日' || i == '休日') {
        holidays = true;
      } else if (i == '土日祝日' || i == '土日祝') {
        days.addAll([6, 7]);
        holidays = true;
      } else if (i == '土日') {
        days.addAll([6, 7]);
      } else if (RegExp(r'^.曜日$').hasMatch(i) && _jaDays.containsKey(i[0])) {
        days.add(_jaDays[i[0]]!);
      } else {
        return null;
      }
    }
    if (!newYear && !holidays && days.isEmpty) return null;
    return Closures(
        newYear: newYear, holidays: holidays, days: days.toList()..sort());
  }

  static List<int>? _jaDayList(String text) {
    if (text == '平日') return [1, 2, 3, 4, 5];
    final range = RegExp(r'^(.)曜日から(.)曜日$').firstMatch(text);
    if (range != null) {
      final from = _jaDays[range[1]];
      final to = _jaDays[range[2]];
      if (from == null || to == null || to < from) return null;
      return [for (var d = from; d <= to; d++) d];
    }
    final out = <int>[];
    for (final item in text.split(RegExp(r'[、・,]'))) {
      final m = RegExp(r'^(.)曜日$').firstMatch(item.trim());
      final d = m == null ? null : _jaDays[m[1]];
      if (d == null) return null;
      out.add(d);
    }
    return out..sort();
  }

  static final _jaTime = RegExp(
      r'(翌)?(午前|午後)?(\d{1,2})(?::(\d{2})(?::00)?|時(?:(\d{1,2})分)?)');

  static (int, int)? _jaSpan(String s) {
    final m = RegExp('^(.+?)(?:~|から)(.+?)(?:まで)?\$').firstMatch(s);
    if (m == null) return null;
    final from = _jaMinutes(m[1]!);
    var to = _jaMinutes(m[2]!);
    if (from == null || to == null) return null;
    if (to <= from) to += 24 * 60;
    return (from, to);
  }

  static int? _jaMinutes(String s) {
    final m = _jaTime.firstMatch(s);
    if (m == null || m.start != 0 || m.end != s.length) return null;
    var h = int.parse(m[3]!);
    final min = int.parse(m[4] ?? m[5] ?? '0');
    if (min > 59) return null;
    if (m[2] == '午前' && h == 12) h = 0;
    if (m[2] == '午後' && h < 12) h += 12;
    if (m[1] == '翌') h += 24;
    if (h > 48) return null;
    return h * 60 + min;
  }
}

/// Days a place is closed on.
class Closures {
  const Closures({this.newYear = false, this.holidays = false, this.days = const []});

  /// 年末年始 (Dec 29 – Jan 3).
  final bool newYear;
  final bool holidays;

  /// Weekdays 1 (Mo) … 7 (Su).
  final List<int> days;
}
