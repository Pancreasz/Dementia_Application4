import 'dart:convert';

import 'package:web/web.dart' as web;

import 'session_record.dart';

/// Session persistence on the web: one localStorage entry per session.
///
/// localStorage rather than IndexedDB. It is synchronous, which means a save
/// completes inside the same event-loop turn as the call — and the case this
/// exists for is a tab being closed, where an async write may simply never run
/// its continuation. The cost is a storage quota measured in single-digit
/// megabytes, which a session of scores and tap offsets is nowhere near.
///
/// The API is `Future`-returning anyway so it matches the io implementation:
/// callers must not have to know which platform they are on.
class SessionStore {
  /// Namespaced so the backend-URL entry written by
  /// `backend_url_resolver_web.dart` shares localStorage without collision.
  static const String _prefix = 'moca_session_';

  Future<void> save(SessionRecord record) async {
    try {
      web.window.localStorage
          .setItem('$_prefix${record.id}', jsonEncode(record.toJson()));
    } catch (_) {
      // localStorage throws under a blocked/private-mode storage policy, and
      // on quota exhaustion. Swallowed deliberately: failing to persist must
      // not take down a session in progress, which still holds everything in
      // memory. The session is no worse off than before this file existed.
    }
  }

  Future<SessionRecord?> load(String id) async {
    try {
      final raw = web.window.localStorage.getItem('$_prefix$id');
      return raw == null ? null : _decode(raw);
    } catch (_) {
      return null;
    }
  }

  /// Every stored session, newest first.
  Future<List<SessionRecord>> loadAll() async {
    final records = <SessionRecord>[];
    try {
      final storage = web.window.localStorage;
      for (var i = 0; i < storage.length; i++) {
        final key = storage.key(i);
        if (key == null || !key.startsWith(_prefix)) continue;
        final raw = storage.getItem(key);
        if (raw == null) continue;
        final record = _decode(raw);
        // One corrupt entry must not make every other stored session
        // unreachable.
        if (record != null) records.add(record);
      }
    } catch (_) {
      return records;
    }
    records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return records;
  }

  /// The most recently updated unfinished session, if there is one.
  ///
  /// This is the whole point of the web implementation: a closed tab is the
  /// failure mode the README names, and on the published GitHub Pages build it
  /// is the likeliest one.
  Future<SessionRecord?> loadResumable() async {
    for (final record in await loadAll()) {
      if (!record.completed) return record;
    }
    return null;
  }

  Future<void> delete(String id) async {
    try {
      web.window.localStorage.removeItem('$_prefix$id');
    } catch (_) {}
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
