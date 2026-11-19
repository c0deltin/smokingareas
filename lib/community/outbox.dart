import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';

/// Thrown after a contribution was kept on the device because there was no
/// connection; it is shown right away and sent later ([Outbox]).
class SavedOffline implements Exception {
  const SavedOffline();
  @override
  String toString() => 'Saved on this device – will be sent when online.';
}

/// Whether [e] means "no connection" (as opposed to a refusal by the
/// server, e.g. a rate limit or a missing permission).
bool isOfflineError(Object e) {
  if (e is SocketException || e is TimeoutException || e is HttpException) {
    return true;
  }
  final text = e.toString();
  return text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('TimeoutException') ||
      text.contains('Failed host lookup') ||
      text.contains('Network is unreachable') ||
      text.contains('Connection closed') ||
      text.contains('Connection refused') ||
      text.contains('Connection reset');
}

/// Kinds of contributions that can wait for a connection.
enum OutboxKind { spot, vote, featureVote, closure, review }

/// One contribution waiting to be sent.
class OutboxEntry {
  const OutboxEntry(this.kind, this.data);

  OutboxEntry.spot(CommunitySpot s) : this(OutboxKind.spot, s.toJson());
  OutboxEntry.vote(ExistenceVote v) : this(OutboxKind.vote, v.toJson());
  OutboxEntry.featureVote(FeatureVote v)
      : this(OutboxKind.featureVote, v.toJson());
  OutboxEntry.closure(ClosureReport r) : this(OutboxKind.closure, r.toJson());
  OutboxEntry.review(SpotReview r) : this(OutboxKind.review, r.toJson());

  final OutboxKind kind;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {'kind': kind.name, 'data': data};

  static OutboxEntry? fromJson(Map<String, dynamic> j) {
    for (final k in OutboxKind.values) {
      if (k.name == j['kind']) {
        return OutboxEntry(k, (j['data'] as Map).cast<String, dynamic>());
      }
    }
    return null;
  }
}

/// Contributions made without a connection, in the order they were made,
/// kept in `<dir>/community/outbox.json` until they are sent.
class Outbox {
  Outbox(this._directory);

  final Future<Directory> Function() _directory;
  List<OutboxEntry>? _entries;

  Future<File> _file() async {
    final dir = Directory('${(await _directory()).path}/community');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/outbox.json');
  }

  Future<List<OutboxEntry>> _load() async {
    final loaded = _entries;
    if (loaded != null) return loaded;
    var entries = <OutboxEntry>[];
    try {
      final f = await _file();
      if (await f.exists()) {
        entries = [
          for (final e in jsonDecode(await f.readAsString()) as List)
            ?OutboxEntry.fromJson((e as Map).cast<String, dynamic>()),
        ];
      }
    } catch (_) {
      entries = [];
    }
    return _entries = entries;
  }

  Future<void> _save() async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(
        jsonEncode([for (final e in _entries ?? const []) e.toJson()]));
    await tmp.rename(f.path);
  }

  /// Entries waiting to be sent, oldest first.
  Future<List<OutboxEntry>> entries() async => List.of(await _load());

  Future<void> add(OutboxEntry entry) async {
    (await _load()).add(entry);
    await _save();
  }

  Future<void> removeFirst() async {
    final list = await _load();
    if (list.isEmpty) return;
    list.removeAt(0);
    await _save();
  }
}
