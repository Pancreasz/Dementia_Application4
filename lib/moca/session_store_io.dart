import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'session_record.dart';

/// Session persistence on desktop and mobile: one JSON file per session under
/// the app's documents directory.
///
/// One file per session rather than one file holding all of them. A save
/// happens after every subtest, and rewriting a single growing file each time
/// means a crash mid-write can take out every past session as well as the
/// current one.
class SessionStore {
  /// Injectable so tests can point at a temp directory instead of the real
  /// documents directory, which `flutter test` cannot resolve.
  final Future<Directory> Function() _directory;

  SessionStore({Future<Directory> Function()? directory})
      : _directory = directory ?? _defaultDirectory;

  static Future<Directory> _defaultDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/moca_sessions');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _fileFor(String id) async =>
      File('${(await _directory()).path}/$id.json');

  /// Writes the record, replacing any previous copy of the same session.
  ///
  /// Writes to a temporary file and renames it over the target. A rename is
  /// atomic on every platform this ships to, so a crash or a battery death
  /// mid-write leaves either the previous complete record or the new complete
  /// one — never a half-written file that loads as a partial assessment.
  Future<void> save(SessionRecord record) async {
    final target = await _fileFor(record.id);
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(jsonEncode(record.toJson()), flush: true);
    await temp.rename(target.path);
  }

  Future<SessionRecord?> load(String id) async {
    final file = await _fileFor(id);
    if (!await file.exists()) return null;
    return _decode(await file.readAsString());
  }

  /// Every stored session, newest first.
  Future<List<SessionRecord>> loadAll() async {
    final dir = await _directory();
    if (!await dir.exists()) return const [];

    final records = <SessionRecord>[];
    await for (final entity in dir.list()) {
      // .tmp files are half-written by definition; skip rather than parse.
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final record = _decode(await entity.readAsString());
      // An unreadable file is skipped, not fatal: one corrupt record must not
      // make every other stored session unreachable.
      if (record != null) records.add(record);
    }
    records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return records;
  }

  /// The most recently updated unfinished session, if there is one.
  ///
  /// What "resume after a tab close" actually asks for. A completed session is
  /// never offered: reopening the app after finishing should not drop the
  /// clinician back into an assessment that is already done.
  Future<SessionRecord?> loadResumable() async {
    for (final record in await loadAll()) {
      if (!record.completed) return record;
    }
    return null;
  }

  Future<void> delete(String id) async {
    final file = await _fileFor(id);
    if (await file.exists()) await file.delete();
  }

  static SessionRecord? _decode(String contents) {
    try {
      final json = jsonDecode(contents);
      if (json is! Map) return null;
      return SessionRecord.fromJson(json.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }
}
