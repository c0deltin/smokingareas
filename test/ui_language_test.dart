import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app UI is English. Guards against German strings slipping back in
/// (string literals with umlauts/ß or typical German words; comments and
/// Japanese text are fine).
void main() {
  test('no German UI strings in lib/', () {
    final literal = RegExp(r"""(?<![A-Za-z_\]])'((?:[^'\\]|\\.)*)'""");
    final german = RegExp(
        r'[äöüÄÖÜß]|\b(der|die|das|und|nicht|mit|für|Raucher\w*|Toilette\w*|'
        r'Abbrechen|Speichern|Melden|Nutzer|Einstellungen|Benachrichtig\w*)\b');
    final offenders = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
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
}
