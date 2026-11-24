import 'dart:io';
import 'package:fl_clash/common/task_pool.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'compares delay limits with a simultaneous page request on loopback',
    () async {
      for (final n in [2, 12, 50]) {
        for (final concurrency in [32, 4, 8, 16]) {
          final totals = <int>[];
          final pages = <int>[];
          for (var repeat = 0; repeat < 5; repeat++) {
            final server = await HttpServer.bind(
              InternetAddress.loopbackIPv4,
              0,
            );
            final link = TaskPool(8);
            server.listen((request) async {
              await link.run(() async {
                await Future<void>.delayed(
                  Duration(milliseconds: request.uri.path == '/page' ? 5 : 20),
                );
                request.response.write('ok');
                await request.response.close();
              });
            });
            final client = HttpClient()..maxConnectionsPerHost = 64;
            Future<void> get(String path) async {
              final request = await client.getUrl(
                Uri.parse('http://127.0.0.1:${server.port}$path'),
              );
              await (await request.close()).drain<void>();
            }

            await get('/page');
            final pool = TaskPool(concurrency);
            var completed = 0;
            final total = Stopwatch()..start();
            final probes = Future.wait([
              for (var i = 0; i < n; i++)
                pool.run(() async {
                  await get('/probe');
                  completed++;
                }),
            ]);
            final page = Future<void>.delayed(
              const Duration(milliseconds: 5),
              () async {
                final watch = Stopwatch()..start();
                await get('/page');
                pages.add(watch.elapsedMicroseconds);
              },
            );
            await probes;
            totals.add(total.elapsedMicroseconds);
            expect(completed, n);
            expect(pool.activeCount, 0);
            expect(pool.pendingCount, 0);
            await page;
            client.close(force: true);
            await server.close(force: true);
          }
          totals.sort();
          pages.sort();
          debugPrint(
            'nodes=$n limit=$concurrency total_ms=${totals[2] / 1000} page_ms=${pages[2] / 1000}',
          );
        }
      }
    },
  );
}
