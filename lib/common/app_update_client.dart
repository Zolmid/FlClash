import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'app_update.dart';
import 'constant.dart';
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

  void attach(ProviderReader read) => _read = read;

  void close() => _dio.close(force: true);

  Future<ReleaseManifest?> checkForUpdate({
    required String currentVersion,
  }) async {
    final release = await latestRelease();
    return release != null && compareVersions(release.tag, currentVersion) > 0
        ? release
        : null;
  }

  Future<ReleaseManifest?> latestRelease() async {
    try {
      final response = await _dio.get<Object?>(
        'https://api.github.com/repos/$repository/releases/latest',
        options: Options(responseType: ResponseType.json),
      );
      return ReleaseManifest.fromGitHubRelease(response.data);
    } on DioException {
      // Release downloads remain available when GitHub's API quota is exhausted.
    } on FormatException {
      // An invalid API response has no usable asset metadata.
    }
    try {
      final response = await _dio.get<String>(
        'https://github.com/$repository/releases/latest/download/version.json',
        options: Options(responseType: ResponseType.plain),
      );
      return ReleaseManifest.fromJson(jsonDecode(response.data ?? ''));
    } on DioException {
      // Older releases may not publish the optional manifest.
    } on FormatException {
      // Never install an asset from an unreadable manifest.
    }
    final response = await _dio.get<void>(
      'https://github.com/$repository/releases/latest',
      options: Options(
        followRedirects: false,
        validateStatus: (status) =>
            status == HttpStatus.notFound || (status != null && status < 400),
      ),
    );
    if (response.statusCode == HttpStatus.notFound) return null;
    final location = response.headers.value(HttpHeaders.locationHeader);
    final uri = Uri.parse('https://github.com').resolve(location ?? '');
    final prefix = [...repository.split('/'), 'releases', 'tag'];
    final segments = uri.pathSegments;
    if (uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        segments.length != prefix.length + 1 ||
        prefix.indexed.any((part) => segments[part.$1] != part.$2)) {
      throw FormatException('No release tag in the redirect', location);
    }
    return ReleaseManifest(tag: segments.last, notes: '');
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
