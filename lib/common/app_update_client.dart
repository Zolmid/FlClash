import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart' show visibleForTesting, compute;

import 'app_update.dart';
import 'constant.dart' show browserUa;
import 'http.dart';
import 'package.dart';
import 'provider_reader.dart';

class AppUpdateClient {
  AppUpdateClient({Dio? dio, ProviderReader? read})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
              headers: {'User-Agent': browserUa},
            ),
          ),
      _read = read {
    if (dio == null) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () =>
            _StrictHttpOverrides().createHttpClient(null)
              ..findProxy = (uri) {
                final read = _read;
                return read == null
                    ? 'DIRECT'
                    : FlClashHttpOverrides.findProxyForReader(read, uri);
              },
      );
    }
  }

  final Dio _dio;
  ProviderReader? _read;
  bool _downloading = false;

  @visibleForTesting
  Dio get dio => _dio;

  void attach(ProviderReader read) => _read = read;

  void close() => _dio.close(force: true);

  Future<ReleaseManifest?> checkForUpdate({
    required String currentVersion,
    UpdateTarget? target,
  }) async {
    final release = await latestRelease(
      currentVersion: currentVersion,
      target: target,
    );
    if (release == null) return null;
    try {
      return compareVersions(release.tag, currentVersion) > 0 ? release : null;
    } on FormatException {
      return null;
    }
  }

  Future<ReleaseManifest?> latestRelease({
    String? currentVersion,
    UpdateTarget? target,
  }) async {
    try {
      final cancel = CancelToken();
      final response = await _dio.get<String>(
        websiteReleaseManifestUrl,
        cancelToken: cancel,
        onReceiveProgress: (received, total) {
          if (received > maxWebsiteManifestBytes ||
              total > maxWebsiteManifestBytes) {
            cancel.cancel('Website metadata is too large');
          }
        },
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: false,
          headers: {'User-Agent': 'ZolNit/${currentVersion ?? '0'}'},
          validateStatus: (status) => status == HttpStatus.ok,
        ),
      );
      final releases = await compute(
        decodeWebsiteReleases,
        response.data ?? '',
      );
      if (releases == null) return null;
      releases.sort((a, b) => compareVersions(b.tag, a.tag));
      for (var index = 1; index < releases.length; index++) {
        if (compareVersions(releases[index - 1].tag, releases[index].tag) ==
            0) {
          return null;
        }
      }
      return target == null
          ? releases.first
          : releases
                .where((release) => planAppUpdate(release, target) != null)
                .firstOrNull;
    } on DioException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<void> downloadFile(
    String url,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    int? expectedSize,
    int retries = 3,
    Duration Function(int attempt) retryDelay = _retryDelay,
    Future<void> Function(File part)? verify,
  }) async {
    if (expectedSize != null &&
        (expectedSize <= 0 || expectedSize > maxUpdatePackageBytes)) {
      throw ArgumentError.value(expectedSize, 'expectedSize');
    }
    if (_downloading) throw StateError('An app update is already downloading');
    _downloading = true;
    try {
      await _downloadFile(
        url,
        savePath,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
        expectedSize: expectedSize,
        retries: retries,
        retryDelay: retryDelay,
        verify: verify,
      );
    } finally {
      _downloading = false;
    }
  }

  Future<void> _downloadFile(
    String url,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    int? expectedSize,
    required int retries,
    required Duration Function(int attempt) retryDelay,
    Future<void> Function(File part)? verify,
  }) async {
    final part = File('$savePath.part');
    for (var attempt = 0; ; attempt++) {
      _throwIfCancelled(cancelToken);
      try {
        await _downloadRange(
          url,
          part,
          onReceiveProgress,
          cancelToken,
          expectedSize,
        );
        break;
      } catch (error) {
        if (error is UpdatePackageSizeException && await part.exists()) {
          await part.delete();
        }
        if (attempt >= retries || !_isTransient(error)) rethrow;
        await _waitRetry(retryDelay(attempt + 1), cancelToken);
      }
    }
    _throwIfCancelled(cancelToken);
    if (expectedSize != null && await part.length() != expectedSize) {
      await part.delete();
      throw const UpdatePackageSizeException();
    }
    await verify?.call(part);
    _throwIfCancelled(cancelToken);
    await part.rename(savePath);
  }

  Future<void> _downloadRange(
    String url,
    File part,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    int? expectedSize,
  ) async {
    var offset = await part.exists() ? await part.length() : 0;
    if (expectedSize != null && offset > expectedSize) {
      await part.delete();
      offset = 0;
    }
    final response = await _dio.get<ResponseBody>(
      url,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: false,
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          HttpHeaders.acceptEncodingHeader: 'identity',
          if (offset > 0) HttpHeaders.rangeHeader: 'bytes=$offset-',
        },
        validateStatus: (status) =>
            status == HttpStatus.ok ||
            status == HttpStatus.partialContent ||
            status == HttpStatus.requestedRangeNotSatisfiable,
      ),
    );
    final body = response.data!;
    final range = response.headers.value(HttpHeaders.contentRangeHeader) ?? '';
    if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
      await body.stream.listen(null).cancel();
      final total = RegExp(r'^bytes \*/(\d+)$').firstMatch(range);
      if (offset > 0 && total != null && int.parse(total[1]!) == offset) return;
      if (await part.exists()) await part.delete();
      throw const HttpException('The partial file overruns the download');
    }
    final resumed = response.statusCode == HttpStatus.partialContent;
    final parsedRange = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$').firstMatch(range);
    final length = body.contentLength;
    if (expectedSize != null &&
        ((resumed &&
                parsedRange != null &&
                int.parse(parsedRange[3]!) != expectedSize) ||
            (length >= 0 &&
                (resumed
                    ? offset + length > expectedSize
                    : length != expectedSize)))) {
      await body.stream.listen(null).cancel();
      throw const UpdatePackageSizeException();
    }
    if (resumed &&
        (parsedRange == null ||
            int.parse(parsedRange[1]!) != offset ||
            int.parse(parsedRange[2]!) < offset ||
            int.parse(parsedRange[3]!) <= int.parse(parsedRange[2]!) ||
            (length >= 0 &&
                int.parse(parsedRange[2]!) - offset + 1 != length))) {
      await body.stream.listen(null).cancel();
      if (await part.exists()) await part.delete();
      throw const HttpException('Content-Range does not match the request');
    }
    var received = resumed ? offset : 0;
    final total = resumed ? int.parse(parsedRange![3]!) : length;
    final sink = part.openWrite(
      mode: resumed ? FileMode.append : FileMode.write,
    );
    try {
      await for (final chunk in body.stream) {
        _throwIfCancelled(cancelToken);
        if (expectedSize != null && received + chunk.length > expectedSize) {
          throw const UpdatePackageSizeException();
        }
        sink.add(chunk);
        received += chunk.length;
        onReceiveProgress?.call(received, total);
      }
    } finally {
      await sink.close();
    }
    if (total >= 0 && received != total) {
      throw const HttpException('Connection closed before the body ended');
    }
    if (expectedSize != null && received < expectedSize) {
      throw const HttpException('Connection closed before the package ended');
    }
  }

  bool _isTransient(Object error) => switch (error) {
    UpdatePackageSizeException() => false,
    DioException(error: TlsException()) => false,
    DioException(:final type, :final response) => switch (type) {
      DioExceptionType.badResponse =>
        (response?.statusCode ?? 0) >= HttpStatus.internalServerError,
      DioExceptionType.badCertificate || DioExceptionType.cancel => false,
      _ => true,
    },
    SocketException() || HttpException() || TimeoutException() => true,
    _ => false,
  };
}

class UpdatePackageSizeException implements Exception {
  const UpdatePackageSizeException();

  @override
  String toString() => 'The update does not match its declared size';
}

Duration _retryDelay(int attempt) => Duration(seconds: 2 * attempt);

void _throwIfCancelled(CancelToken? token) {
  final error = token?.cancelError;
  if (error != null) throw error;
}

Future<void> _waitRetry(Duration duration, CancelToken? token) async {
  _throwIfCancelled(token);
  final done = Completer<void>();
  final timer = Timer(duration, done.complete);
  if (token != null) {
    unawaited(
      token.whenCancel.then((_) {
        if (!done.isCompleted) done.complete();
      }),
    );
  }
  try {
    await done.future;
  } finally {
    timer.cancel();
  }
  _throwIfCancelled(token);
}

final appUpdateClient = AppUpdateClient();

class _StrictHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..badCertificateCallback = (certificate, host, port) => false;
}
