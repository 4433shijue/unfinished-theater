import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';
import 'package:web/web.dart' as web;

extension _LocalStorageKeys on web.Storage {
  List<String> get keys => <String>[
        for (var index = 0; index < length; index++)
          if (key(index) case final value?) value,
      ];
}

const String _stableKeyPrefix = 'wwjc.flutter.';
const String _legacyKeyPrefix = 'flutter.';
const String _legacyBackupStorageKey = 'wwjc.shared_preferences.backup.v1';
const String _databaseName = 'wwjc-durable-storage';
const int _databaseVersion = 2;
const String _preferencesStoreName = 'preferences';
const String _registryKey = '__wwjc_preference_keys__';

Future<void> initializeDurableWebPreferences() async {
  SharedPreferencesStorePlatform.instance =
      await DurableWebPreferencesStore.open();
}

class DurableWebPreferencesStore extends SharedPreferencesStorePlatform {
  DurableWebPreferencesStore._({
    required web.IDBDatabase? database,
    required Map<String, String> encodedValues,
  })  : _database = database,
        _encodedValues = encodedValues;

  final web.IDBDatabase? _database;
  final Map<String, String> _encodedValues;

  static Future<DurableWebPreferencesStore> open() async {
    web.IDBDatabase? database;
    try {
      database = await _openDatabase();
      final store = DurableWebPreferencesStore._(
        database: database,
        encodedValues: <String, String>{},
      );
      await store._loadIndexedValues();
      await store._migrateLocalStorageIntoIndexedDb();
      return store;
    } catch (_) {
      database?.close();
      return DurableWebPreferencesStore._(
        database: null,
        encodedValues: _readLocalStorageValues(),
      );
    }
  }

  @override
  Future<bool> clear() async {
    return clearWithPrefix(_stableKeyPrefix);
  }

  @override
  Future<bool> clearWithPrefix(String prefix) async {
    return clearWithParameters(
      ClearParameters(filter: PreferencesFilter(prefix: prefix)),
    );
  }

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) async {
    final filter = parameters.filter;
    final keys = _prefixedKeys(filter.prefix, allowList: filter.allowList)
        .toList(growable: false);
    if (keys.isEmpty) {
      return true;
    }
    final previous = Map<String, String>.of(_encodedValues);
    for (final key in keys) {
      _encodedValues.remove(key);
    }
    try {
      final database = _database;
      if (database == null) {
        for (final key in keys) {
          web.window.localStorage.removeItem(key);
        }
      } else {
        await _writeIndexedMutation((objectStore) {
          for (final key in keys) {
            objectStore.delete(key.toJS);
          }
          _writeRegistry(objectStore);
        });
      }
      return true;
    } catch (_) {
      _encodedValues
        ..clear()
        ..addAll(previous);
      return false;
    }
  }

  @override
  Future<Map<String, Object>> getAll() async {
    return getAllWithPrefix(_legacyKeyPrefix);
  }

  @override
  Future<Map<String, Object>> getAllWithPrefix(String prefix) async {
    return getAllWithParameters(
      GetAllParameters(filter: PreferencesFilter(prefix: prefix)),
    );
  }

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) async {
    final filter = parameters.filter;
    final result = <String, Object>{};
    for (final key
        in _prefixedKeys(filter.prefix, allowList: filter.allowList)) {
      final raw = _encodedValues[key];
      if (raw == null) {
        continue;
      }
      final decoded = _decodeValue(raw);
      if (decoded != null) {
        result[_externalKey(key, filter.prefix)] = decoded;
      }
    }
    return result;
  }

  @override
  Future<bool> remove(String key) async {
    final normalized = _normalizeKey(key);
    final previous = _encodedValues.remove(normalized);
    if (previous == null) {
      return true;
    }
    try {
      final database = _database;
      if (database == null) {
        web.window.localStorage.removeItem(normalized);
      } else {
        await _writeIndexedMutation((objectStore) {
          objectStore.delete(normalized.toJS);
          _writeRegistry(objectStore);
        });
      }
      return true;
    } catch (_) {
      _encodedValues[normalized] = previous;
      return false;
    }
  }

  @override
  Future<bool> setValue(String valueType, String key, Object? value) async {
    final normalized = _normalizeKey(key);
    final encoded = jsonEncode(value);
    final previous = _encodedValues[normalized];
    _encodedValues[normalized] = encoded;
    try {
      final database = _database;
      if (database == null) {
        web.window.localStorage.setItem(normalized, encoded);
      } else {
        await _writeIndexedMutation((objectStore) {
          objectStore.put(encoded.toJS, normalized.toJS);
          _writeRegistry(objectStore);
        });
      }
      return true;
    } catch (_) {
      if (previous == null) {
        _encodedValues.remove(normalized);
      } else {
        _encodedValues[normalized] = previous;
      }
      return false;
    }
  }

  Future<void> _loadIndexedValues() async {
    final registryRaw = await _readIndexedRecord(_registryKey);
    for (final key in _decodeRegistry(registryRaw)) {
      final value = await _readIndexedRecord(key);
      if (value != null) {
        _encodedValues[key] = value;
      }
    }
  }

  Future<void> _migrateLocalStorageIntoIndexedDb() async {
    final localValues = _readLocalStorageValues();
    if (localValues.isEmpty) {
      return;
    }
    for (final entry in localValues.entries) {
      _encodedValues.putIfAbsent(entry.key, () => entry.value);
    }
    await _replaceAllIndexedValues();
    _removeMigratedLocalStorageValues();
  }

  Future<String?> _readIndexedRecord(String key) async {
    final database = _database;
    if (database == null) {
      return null;
    }
    final transaction = database.transaction(_preferencesStoreName.toJS);
    final request =
        transaction.objectStore(_preferencesStoreName).get(key.toJS);
    final result = await _waitForRequest(request);
    final value = result?.dartify();
    return value is String ? value : null;
  }

  Future<void> _replaceAllIndexedValues() async {
    await _writeIndexedMutation((objectStore) {
      objectStore.clear();
      for (final entry in _encodedValues.entries) {
        objectStore.put(entry.value.toJS, entry.key.toJS);
      }
      _writeRegistry(objectStore);
    });
  }

  Future<void> _writeIndexedMutation(
    void Function(web.IDBObjectStore objectStore) mutation,
  ) async {
    final database = _database;
    if (database == null) {
      return;
    }
    final transaction = database.transaction(
      _preferencesStoreName.toJS,
      'readwrite',
    );
    final completion = _waitForTransaction(transaction);
    mutation(transaction.objectStore(_preferencesStoreName));
    await completion;
  }

  void _writeRegistry(web.IDBObjectStore objectStore) {
    final keys = _encodedValues.keys.toList(growable: false)..sort();
    objectStore.put(jsonEncode(keys).toJS, _registryKey.toJS);
  }

  Iterable<String> _prefixedKeys(String prefix, {Set<String>? allowList}) {
    final normalizedPrefix = _normalizePrefix(prefix);
    return _encodedValues.keys.where((key) {
      if (!key.startsWith(normalizedPrefix)) {
        return false;
      }
      if (allowList == null) {
        return true;
      }
      return allowList.contains(key) ||
          allowList.contains(_legacyKeyForStableKey(key));
    });
  }

  static Future<web.IDBDatabase> _openDatabase() {
    final completer = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(_databaseName, _databaseVersion);
    request.onupgradeneeded = ((web.Event _) {
      final database = request.result as web.IDBDatabase;
      if (!database.objectStoreNames.contains(_preferencesStoreName)) {
        database.createObjectStore(_preferencesStoreName);
      }
    }).toJS;
    request.onsuccess = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.complete(request.result as web.IDBDatabase);
      }
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('IndexedDB 打开失败：${request.error}'),
        );
      }
    }).toJS;
    request.onblocked = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('IndexedDB 被另一个旧版本页面占用。'));
      }
    }).toJS;
    return completer.future.timeout(const Duration(seconds: 8));
  }

  static Future<JSAny?> _waitForRequest(web.IDBRequest request) {
    final completer = Completer<JSAny?>();
    request.onsuccess = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.complete(request.result);
      }
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('IndexedDB 读取失败：${request.error}'),
        );
      }
    }).toJS;
    return completer.future;
  }

  static Future<void> _waitForTransaction(web.IDBTransaction transaction) {
    final completer = Completer<void>();
    void fail() {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('IndexedDB 写入失败：${transaction.error}'),
        );
      }
    }

    transaction.oncomplete = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }).toJS;
    transaction.onerror = ((web.Event _) => fail()).toJS;
    transaction.onabort = ((web.Event _) => fail()).toJS;
    return completer.future;
  }

  static Map<String, String> _readLocalStorageValues() {
    final result = <String, String>{};
    try {
      final rawBackup =
          web.window.localStorage.getItem(_legacyBackupStorageKey);
      if (rawBackup != null && rawBackup.isNotEmpty) {
        final decoded = jsonDecode(rawBackup);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final key = entry.key.toString();
            final value = entry.value?.toString();
            if (key.startsWith(_stableKeyPrefix) && value != null) {
              result[key] = value;
            }
          }
        }
      }
    } catch (_) {
      // A damaged legacy backup must not hide valid per-key values.
    }
    try {
      for (final key in web.window.localStorage.keys) {
        final value = web.window.localStorage.getItem(key);
        if (value == null) {
          continue;
        }
        if (key.startsWith(_stableKeyPrefix)) {
          result[key] = value;
        } else if (key.startsWith(_legacyKeyPrefix)) {
          final stableKey =
              '$_stableKeyPrefix${key.substring(_legacyKeyPrefix.length)}';
          result.putIfAbsent(stableKey, () => value);
        }
      }
    } catch (_) {
      // Browsers can deny localStorage while still allowing IndexedDB.
    }
    return result;
  }

  static void _removeMigratedLocalStorageValues() {
    try {
      for (final key in web.window.localStorage.keys.toList(growable: false)) {
        if (key.startsWith(_stableKeyPrefix) ||
            key.startsWith(_legacyKeyPrefix) ||
            key == _legacyBackupStorageKey) {
          web.window.localStorage.removeItem(key);
        }
      }
    } catch (_) {
      // Migration already committed; leftover legacy keys are harmless.
    }
  }

  static List<String> _decodeRegistry(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const <String>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((item) => item.toString())
            .where((item) => item.startsWith(_stableKeyPrefix))
            .toSet()
            .toList(growable: false);
      }
    } catch (_) {
      return const <String>[];
    }
    return const <String>[];
  }

  static String _normalizePrefix(String prefix) {
    if (prefix == _legacyKeyPrefix) {
      return _stableKeyPrefix;
    }
    return prefix;
  }

  static String _normalizeKey(String key) {
    if (key.startsWith(_legacyKeyPrefix)) {
      return '$_stableKeyPrefix${key.substring(_legacyKeyPrefix.length)}';
    }
    return key;
  }

  static String _legacyKeyForStableKey(String key) {
    if (!key.startsWith(_stableKeyPrefix)) {
      return key;
    }
    return '$_legacyKeyPrefix${key.substring(_stableKeyPrefix.length)}';
  }

  static String _externalKey(String key, String requestedPrefix) {
    if (requestedPrefix == _legacyKeyPrefix) {
      return _legacyKeyForStableKey(key);
    }
    return key;
  }

  static Object? _decodeValue(String encodedValue) {
    try {
      final decoded = jsonDecode(encodedValue);
      if (decoded is List) {
        return decoded.cast<String>();
      }
      return decoded;
    } catch (_) {
      return null;
    }
  }
}
