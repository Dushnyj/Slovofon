import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../audio/audio_state.dart';

abstract interface class DownloadClient {
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  });
}

class DownloadClientResponse {
  const DownloadClientResponse({
    required this.bytes,
    required this.totalBytes,
    required this.contentLength,
    required this.supportsResume,
    required this.shouldAppend,
    required this.fileExtension,
  });

  final Stream<List<int>> bytes;
  final int? totalBytes;
  final int? contentLength;
  final bool supportsResume;
  final bool shouldAppend;
  final String fileExtension;
}

class DownloadCancellationToken {
  bool _isCanceled = false;
  final _listeners = <void Function()>{};

  bool get isCanceled => _isCanceled;

  void cancel() {
    if (_isCanceled) {
      return;
    }
    _isCanceled = true;
    for (final listener in _listeners.toList()) {
      listener();
    }
    _listeners.clear();
  }

  void Function() addListener(void Function() listener) {
    if (_isCanceled) {
      listener();
    } else {
      _listeners.add(listener);
    }
    return () => _listeners.remove(listener);
  }

  /// Stops waiting immediately, even when a client cannot cancel its own open.
  /// Late values are still disposed and late errors are consumed.
  Future<T> waitFor<T>(
    Future<T> future, {
    void Function(T value)? onCanceledValue,
  }) {
    final result = Completer<T>();
    final removeListener = addListener(() {
      if (!result.isCompleted) {
        result.completeError(const DownloadCanceledException());
      }
    });
    future.then(
      (value) {
        removeListener();
        if (result.isCompleted) {
          onCanceledValue?.call(value);
        } else {
          result.complete(value);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        removeListener();
        if (!result.isCompleted) {
          result.completeError(error, stackTrace);
        }
      },
    );
    return result.future;
  }

  /// Cancellation must not wait for the next byte, or for a stalled async*
  /// producer's cancel future. The detached subscription cannot emit to users.
  Stream<T> bindStream<T>(
    Stream<T> source, {
    Duration? idleTimeout,
    void Function()? onRelease,
  }) {
    StreamSubscription<T>? subscription;
    Timer? timer;
    void Function()? removeListener;
    var finished = false;
    late final StreamController<T> controller;

    void finish({Object? error, StackTrace? stackTrace}) {
      if (finished) {
        return;
      }
      finished = true;
      timer?.cancel();
      removeListener?.call();
      if (error != null) {
        controller.addError(error, stackTrace);
      }
      unawaited(controller.close());
      final activeSubscription = subscription;
      if (activeSubscription != null) {
        unawaited(activeSubscription.cancel().catchError((Object _) {}));
      }
      onRelease?.call();
    }

    void resetTimer() {
      timer?.cancel();
      if (!finished && idleTimeout != null) {
        timer = Timer(idleTimeout, () {
          finish(error: const DownloadClientException('Media read timed out.'));
        });
      }
    }

    controller = StreamController<T>(
      onListen: () {
        removeListener = addListener(finish);
        if (finished) {
          return;
        }
        subscription = source.listen(
          (value) {
            if (!finished) {
              resetTimer();
              controller.add(value);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (isCanceled) {
              finish();
            } else {
              finish(error: error, stackTrace: stackTrace);
            }
          },
          onDone: finish,
        );
        resetTimer();
      },
      onPause: () {
        timer?.cancel();
        subscription?.pause();
      },
      onResume: () {
        subscription?.resume();
        resetTimer();
      },
      onCancel: finish,
    );
    return controller.stream;
  }
}

class DownloadCanceledException extends DownloadClientException {
  const DownloadCanceledException() : super('Download canceled.');
}

class DownloadClientException implements Exception {
  const DownloadClientException(this.message, {this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() {
    final code = statusCode == null ? '' : ' status=$statusCode';
    final reason = cause == null ? '' : ' cause=$cause';
    return 'DownloadClientException:$code $message$reason';
  }
}

class DefaultDownloadClient implements DownloadClient {
  DefaultDownloadClient({
    HttpClient? httpClient,
    this.connectionTimeout = const Duration(seconds: 30),
    this.readTimeout = const Duration(seconds: 30),
  }) : _httpClient = httpClient;

  final HttpClient? _httpClient;
  final Duration connectionTimeout;
  final Duration readTimeout;
  final _activeClients = <HttpClient>{};
  bool _closed = false;

  void close() {
    _closed = true;
    for (final client in _activeClients.toList()) {
      client.close(force: true);
    }
    _activeClients.clear();
  }

  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async {
    if (_closed) {
      throw const DownloadClientException('Download client is closed.');
    }
    if (cancellationToken.isCanceled) {
      return _canceledResponse(source, startByte);
    }

    switch (source.type) {
      case AudioMediaSourceType.url:
        return _openUrl(
          source,
          startByte: startByte,
          cancellationToken: cancellationToken,
        );
      case AudioMediaSourceType.file:
        return _openFile(source, startByte: startByte);
      case AudioMediaSourceType.asset:
        return _openAsset(source, startByte: startByte);
    }
  }

  Future<DownloadClientResponse> _openUrl(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async {
    // Each production request owns its client so cancellation also interrupts
    // DNS/connect/TLS, before getUrl has produced an abortable request.
    final client = _httpClient ?? HttpClient();
    client.connectionTimeout = connectionTimeout;
    if (_httpClient == null) {
      _activeClients.add(client);
    }
    HttpClientRequest? request;
    var released = false;
    void Function()? removeListener;
    void release() {
      if (released) {
        return;
      }
      released = true;
      removeListener?.call();
      request?.abort(const DownloadCanceledException());
      if (_httpClient == null) {
        _activeClients.remove(client);
        client.close(force: true);
      }
    }

    removeListener = cancellationToken.addListener(release);

    try {
      final activeRequest = await cancellationToken.waitFor<HttpClientRequest>(
        client.getUrl(source.uri).timeout(connectionTimeout),
        onCanceledValue: (lateRequest) => lateRequest.abort(),
      );
      request = activeRequest;
      source.headers.forEach(activeRequest.headers.add);
      // Byte offsets must refer to the actual bytes written to the part file.
      activeRequest.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      if (startByte > 0) {
        activeRequest.headers.set(HttpHeaders.rangeHeader, 'bytes=$startByte-');
      }

      final response = await cancellationToken.waitFor(
        activeRequest.close().timeout(connectionTimeout),
      );
      final isPartial = response.statusCode == HttpStatus.partialContent;
      if (response.statusCode != HttpStatus.ok && !isPartial) {
        throw DownloadClientException(
          'Media request failed.',
          statusCode: response.statusCode,
        );
      }
      final shouldAppend = startByte > 0 && isPartial;
      if (isPartial) {
        final range = response.headers.value(HttpHeaders.contentRangeHeader);
        final match = range == null
            ? null
            : RegExp(r'^bytes (\d+)-(\d+)/(\d+|\*)$').firstMatch(range);
        if (match == null || int.parse(match.group(1)!) != startByte) {
          throw const DownloadClientException('Invalid media byte range.');
        }
      }

      return DownloadClientResponse(
        bytes: cancellationToken.bindStream(
          response,
          idleTimeout: readTimeout,
          onRelease: release,
        ),
        totalBytes: _totalBytes(
          response,
          startByte: shouldAppend ? startByte : 0,
        ),
        contentLength: response.contentLength < 0
            ? null
            : response.contentLength,
        supportsResume: _supportsResume(response),
        shouldAppend: shouldAppend,
        fileExtension: _extensionFromPath(source.uri.path),
      );
    } on TimeoutException {
      release();
      throw const DownloadClientException('Media connection timed out.');
    } on Object {
      release();
      rethrow;
    }
  }

  Future<DownloadClientResponse> _openFile(
    AudioMediaSource source, {
    required int startByte,
  }) async {
    final file = File(source.filePath);
    final totalBytes = await file.length();
    final normalizedStart = startByte.clamp(0, totalBytes);

    return DownloadClientResponse(
      bytes: file.openRead(normalizedStart),
      totalBytes: totalBytes,
      contentLength: totalBytes - normalizedStart,
      supportsResume: true,
      shouldAppend: normalizedStart > 0,
      fileExtension: _extensionFromPath(file.path),
    );
  }

  Future<DownloadClientResponse> _openAsset(
    AudioMediaSource source, {
    required int startByte,
  }) async {
    final data = await rootBundle.load(source.assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final normalizedStart = startByte.clamp(0, bytes.length);
    final remaining = Uint8List.sublistView(bytes, normalizedStart);

    return DownloadClientResponse(
      bytes: Stream<List<int>>.fromIterable([remaining]),
      totalBytes: bytes.length,
      contentLength: remaining.length,
      supportsResume: true,
      shouldAppend: normalizedStart > 0,
      fileExtension: _extensionFromPath(source.assetPath),
    );
  }

  DownloadClientResponse _canceledResponse(
    AudioMediaSource source,
    int startByte,
  ) {
    return DownloadClientResponse(
      bytes: const Stream.empty(),
      totalBytes: startByte,
      contentLength: 0,
      supportsResume: true,
      shouldAppend: startByte > 0,
      fileExtension: _extensionFromPath(source.uri.path),
    );
  }

  int? _totalBytes(HttpClientResponse response, {required int startByte}) {
    final contentRange = response.headers.value(HttpHeaders.contentRangeHeader);
    if (contentRange != null) {
      final match = RegExp(r'/(\d+)$').firstMatch(contentRange);
      if (match != null) {
        return int.parse(match.group(1)!);
      }
    }

    if (response.contentLength >= 0) {
      return startByte + response.contentLength;
    }

    return null;
  }

  bool _supportsResume(HttpClientResponse response) {
    final acceptRanges = response.headers.value(HttpHeaders.acceptRangesHeader);
    return response.statusCode == HttpStatus.partialContent ||
        acceptRanges?.toLowerCase().contains('bytes') == true;
  }

  String _extensionFromPath(String value) {
    final extension = p.extension(value).replaceFirst('.', '').toLowerCase();
    return extension.isEmpty ? 'bin' : extension;
  }
}
