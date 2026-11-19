import 'package:intl/intl.dart';

import '../i18n.dart';
import '../models/opening_hours.dart';

/// Whether [text] contains Japanese script (kana or kanji).
bool isJapanese(String text) =>
    RegExp(r'[぀-ヿ㐀-鿿]').hasMatch(text);

/// Opening hours for the UI language: OSM values and the common Japanese
/// wordings are shown in [lang]; a Japanese UI keeps Japanese source text
/// as it is; anything else stays the original text.
String hoursText(String raw, AppLocalizations l, String lang) {
  if (lang == 'ja' && isJapanese(raw)) return raw;
  final parsed = OpeningHours.parseOsm(raw) ?? OpeningHours.parseJapanese(raw);
  return parsed == null ? raw : formatHours(parsed, l, lang);
}

String formatHours(OpeningHours h, AppLocalizations l, String lang) {
  final lines = <String>[
    if (h.always) l.hoursAlways,
    for (final r in h.rules)
      if (!r.off)
        [
          if (r.days.length < 7 || r.holidays) _selector(r, l, lang),
          r.spans.map((s) => _span(s, l)).join(', '),
        ].join(' '),
  ];
  final closed = [
    for (final r in h.rules)
      if (r.off) _selector(r, l, lang),
    if (h.closedNewYear) l.hoursNewYear,
  ];
  if (closed.isNotEmpty) {
    lines.add(l.hoursClosedOn(closed.join(lang == 'ja' ? '・' : ', ')));
  }
  return lines.join('\n');
}

String _selector(HoursRule r, AppLocalizations l, String lang) {
  final parts = <String>[];
  final days = r.days;
  var i = 0;
  while (i < days.length) {
    var j = i;
    while (j + 1 < days.length && days[j + 1] == days[j] + 1) {
      j++;
    }
    if (j - i >= 2) {
      parts.add('${_day(days[i], lang)}–${_day(days[j], lang)}');
    } else {
      for (var k = i; k <= j; k++) {
        parts.add(_day(days[k], lang));
      }
    }
    i = j + 1;
  }
  if (r.holidays) parts.add(l.hoursHolidays);
  return parts.join(lang == 'ja' ? '・' : ', ');
}

/// Short weekday name, 1 = Monday (January 1st, 2024 was a Monday).
String _day(int d, String lang) {
  final date = DateTime(2024, 1, d);
  try {
    return DateFormat.E(lang).format(date);
  } catch (_) {
    return DateFormat.E('en').format(date);
  }
}

String _span((int, int) s, AppLocalizations l) {
  final (from, to) = s;
  final end = to == 24 * 60 ? '24:00' : _time(to % (24 * 60));
  return '${_time(from)}–${to > 24 * 60 ? l.hoursNextDay(end) : end}';
}

String _time(int m) =>
    '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}';

/// Frequent notes of the official lists in the UI language; null when the
/// note is not known (it is shown as it is, with a translate button).
String? noteText(String raw, AppLocalizations l, String lang) {
  if (lang == 'ja' || !isJapanese(raw)) return null;
  final out = <String>[];
  for (final part in raw.split(RegExp(r'\n|;'))) {
    final p = part.trim().replaceFirst(RegExp(r'^※'), '');
    if (p.isEmpty) continue;
    final known = switch (p) {
      'ベビーチェア・ベビーシート' => l.noteBabyChairTable,
      'ベビーシート' => l.noteChangingTable,
      '男女共用' => l.noteUnisex,
      '男性専用' => l.noteMenOnly,
      '女性専用' => l.noteWomenOnly,
      '加熱式たばこ専用' || '加熱式専用' => l.noteHeatedOnly,
      '女子トイレ 誰でもトイレ兼用' => l.noteWomenAccessible,
      '工事中のため、休止中' => l.noteConstruction,
      _ => _closedNote(p, l, lang),
    };
    if (known == null) return null;
    out.add(known);
  }
  return out.isEmpty ? null : out.join('\n');
}

/// "土日祝日、年末年始は休業" → "Closed: Sat, Sun, public holidays, …".
String? _closedNote(String text, AppLocalizations l, String lang) {
  if (!text.endsWith('は休業')) return null;
  final c = OpeningHours.parseClosures(text);
  if (c == null) return null;
  return formatHours(
      OpeningHours(rules: [
        if (c.days.isNotEmpty) HoursRule(days: c.days, off: true),
        if (c.holidays) const HoursRule(days: [], holidays: true, off: true),
      ], closedNewYear: c.newYear),
      l,
      lang);
}

/// Google Translate for text the app cannot translate itself.
Uri translateUri(String text, String lang) =>
    Uri.https('translate.google.com', '/', {
      'sl': 'ja',
      'tl': lang,
      'text': text,
      'op': 'translate',
    });
