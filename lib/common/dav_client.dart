import 'dart:async';
import 'dart:io' as io;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart';

typedef DAVClientFactory = DAVClient Function(DAVProps props);

abstract final class DAVDirectory {
  static final _invalid = RegExp(r'[\\<>:"|?*\x00-\x1f\x7f]');

  static String normalize(String value) {
    final segments = value.trim().split('/').where((part) => part.isNotEmpty);
    return '/${segments.join('/')}';
  }

  static bool isValid(String value) =>
      !_invalid.hasMatch(value) &&
      !value.trim().split('/').any((part) => part == '.' || part == '..');
}

class DAVClient {
  DAVClient(DAVProps dav)
    : _transport = DAVTransport(
        uri: dav.uri,
        user: dav.user,
        password: dav.password,
      ),
      fileName = dav.fileName,
      directory = DAVDirectory.normalize(dav.directory) {
    if (!DAVDirectory.isValid(dav.directory)) {
      throw ArgumentError.value(
        directory,
        'directory',
        'Invalid WebDAV directory',
      );
    }
  }

  final DAVTransport _transport;
  final String fileName;
  final String directory;

  Future<bool> ping() async {
    try {
      await _transport.options('/');
      return true;
    } catch (e) {
      commonPrint.log(
        'dav ping error ${e.toString()}',
        logLevel: LogLevel.warning,
      );
      return false;
    }
  }

  String get root => directory;

  String get backupFile => '$root/$fileName';

  String _backupPath(String name) {
    if (name.isEmpty ||
        name == '.' ||
        name == '..' ||
        name.contains('/') ||
        name.contains('\\') ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) {
      throw ArgumentError.value(name, 'name', 'Expected a backup file name');
    }
    return '$root/$name';
  }

  Future<void> upload(String localPath, {String? name}) async {
    final backupPath = _backupPath(name ?? fileName);
    if (!DAVDirectory.isValid(directory)) {
      throw ArgumentError.value(
        directory,
        'directory',
        'Invalid WebDAV directory',
      );
    }
    var path = '';
    for (final segment
        in directory.split('/').where((part) => part.isNotEmpty)) {
      path = '$path/$segment';
      await _transport.mkcol(path);
    }
    await _rejectCollection(backupPath);
    await _transport.put(backupPath, await io.File(localPath).readAsBytes());
  }

  Future<void> download(String localPath, {String? name}) async {
    final path = _backupPath(name ?? fileName);
    await _rejectCollection(path);
    final bytes = await _transport.get(path);
    await io.File(localPath).safeWriteAsBytes(bytes);
  }

  Future<List<DAVFile>> listBackups() async {
    _backupPath(fileName);
    try {
      final files = await _transport.list(root);
      return files
          .where(
            (file) =>
                file.name.toLowerCase().endsWith('.zip') ||
                file.name == fileName,
          )
          .toList();
    } on DAVException catch (error) {
      if ((error.statusCode == 405 || error.statusCode == 501) &&
          !BackupFileName.hasVariables(fileName)) {
        return [DAVFile(name: fileName)];
      }
      rethrow;
    }
  }

  Future<List<String>> listDirectories(String path) async {
    if (!DAVDirectory.isValid(path)) {
      throw ArgumentError.value(path, 'path', 'Invalid WebDAV directory');
    }
    final directories = await _transport.list(
      DAVDirectory.normalize(path),
      directoriesOnly: true,
    );
    return directories
        .map((directory) => directory.name)
        .where(DAVDirectory.isValid)
        .toList();
  }

  Future<void> deleteBackup(String name) =>
      _transport.delete(_backupPath(name));

  Future<void> _rejectCollection(String path) async {
    try {
      if (await _transport.resourceType(path) == DAVResourceType.collection) {
        throw StateError('A WebDAV backup must be a file');
      }
    } on DAVException catch (error) {
      if (error.statusCode != 405 && error.statusCode != 501) rethrow;
    }
  }
}

class DAVConnectionController extends ValueNotifier<bool?> {
  DAVConnectionController({DAVClientFactory? createClient})
    : _createClient = createClient ?? DAVClient.new,
      super(null);

  final DAVClientFactory _createClient;

  DAVProps? _lastProps;
  bool _hasUpdated = false;
  int _requestId = 0;
  bool _disposed = false;

  DAVClient? client;

  Future<void> update(DAVProps? props) async {
    final nextClient = props == null ? null : _createClient(props);
    client = nextClient;

    final rawProps = props?.copyWith(fileName: '', directory: '');
    final rawLastProps = _lastProps?.copyWith(fileName: '', directory: '');
    final isSameCredentials = _hasUpdated && rawProps == rawLastProps;
    _lastProps = props;
    _hasUpdated = true;
    if (isSameCredentials) {
      return;
    }

    final requestId = ++_requestId;
    value = null;
    final result = await nextClient?.ping() ?? false;
    if (!_disposed && requestId == _requestId) {
      value = result;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _requestId++;
    super.dispose();
  }
}
