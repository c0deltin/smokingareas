import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// UI texts live in `lib/l10n/app_<lang>.arb` (English is the template and
/// the fallback). Guards against hard-coded German strings in the code and
/// against missing translations.
void main() {
  Map<String, dynamic> arb(String lang) =>
      jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
          as Map<String, dynamic>;

  Set<String> keys(Map<String, dynamic> m) =>
      m.keys.where((k) => !k.startsWith('@')).toSet();

  test('no German UI strings in the code (outside the translations)', () {
    final literal = RegExp(r"""(?<![A-Za-z_\]])'((?:[^'\\]|\\.)*)'""");
    final german = RegExp(
        r'[äöüÄÖÜß]|\b(der|die|das|und|nicht|mit|für|Raucher\w*|Toilette\w*|'
        r'Abbrechen|Speichern|Melden|Nutzer|Einstellungen|Benachrichtig\w*)\b');
    final offenders = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) =>
            f.path.endsWith('.dart') &&
            !f.path.replaceAll(r'\', '/').contains('lib/l10n/'))) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//')) continue;
        for (final m in literal.allMatches(lines[i])) {
          if (german.hasMatch(m.group(1)!)) {
            offenders.add('${f.path}:${i + 1}: ${m.group(1)}');
          }
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('English is complete and English; German and Japanese translate '
      'every text', () {
    final en = arb('en');
    final german = RegExp(r'[äöüÄÖÜß]');
    for (final k in keys(en)) {
      expect(en[k] as String, isNot(matches(german)), reason: k);
    }
    for (final lang in ['de', 'ja']) {
      final other = arb(lang);
      expect(keys(other), keys(en), reason: lang);
      for (final k in keys(en)) {
        // Placeholders must survive the translation.
        final meta = en['@$k'] as Map<String, dynamic>?;
        final names = (meta?['placeholders'] as Map<String, dynamic>?)?.keys;
        for (final name in names ?? const <String>[]) {
          expect(other[k] as String, contains('{$name'), reason: '$lang.$k');
        }
      }
    }
  });

  test('iOS permission texts are English, with German and Japanese', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final texts = RegExp(r'UsageDescription</key>\s*<string>([^<]*)</string>')
        .allMatches(plist)
        .map((m) => m.group(1)!)
        .toList();
    expect(texts, isNotEmpty);
    for (final t in texts) {
      expect(t, isNot(matches(RegExp(r'[äöüÄÖÜß]|\b(und|der|die|dein)\b'))),
          reason: t);
    }
    final keys = RegExp(r'<key>(NS\w+UsageDescription)</key>')
        .allMatches(plist)
        .map((m) => m.group(1)!)
        .toSet();
    for (final lang in ['de', 'ja']) {
      final strings =
          File('ios/Runner/$lang.lproj/InfoPlist.strings').readAsStringSync();
      for (final k in keys) {
        expect(strings, contains('"$k"'), reason: '$lang: $k');
      }
    }
  });
}
