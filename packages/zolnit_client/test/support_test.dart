import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zolnit_client/zolnit_client.dart';

void main() {
  final requests = <http.Request>[];
  late ZolnitSupportClient support;
  late XboardClient api;

  void serve(int status, Object body) {
    requests.clear();
    api = XboardClient(
      origin: Uri.parse('https://panel.example'),
      client: MockClient((request) async {
        requests.add(request);
        return http.Response.bytes(utf8.encode(jsonEncode(body)), status);
      }),
    )..setAuthorization('Bearer sessionA');
    support = ZolnitSupportClient(api);
  }

  tearDown(() => api.close());

  Future<void> expectFailure(Future<void> Function() run, String code) =>
      expectLater(
        run(),
        throwsA(isA<ClientFailure>().having((e) => e.code, 'code', code)),
      );

  test('lists tickets as served and skips unusable entries', () async {
    serve(200, {
      'data': [
        {
          'id': 7,
          'level': 2,
          'reply_status': 1,
          'status': 0,
          'subject': 'Slow node',
          'message': null,
          'created_at': 1760000100,
          'updated_at': 1760000200,
        },
        {'id': '3', 'level': '9', 'status': '1', 'subject': null},
        {'subject': 'no id'},
        'junk',
      ],
    });
    final list = await support.tickets();
    expect(requests.single.url.path, '/api/v1/user/ticket/fetch');
    expect(requests.single.method, 'GET');
    expect(list.map((t) => t.id), [7, 3]);
    expect(list[0].level, ZolnitTicketLevel.high);
    expect(list[0].canReply, isTrue);
    expect(list[0].staffReplied, isTrue);
    expect(list[0].createdAt, DateTime.utc(2025, 10, 9, 8, 55));
    expect(list[1].level, ZolnitTicketLevel.medium);
    expect(list[1].closed, isTrue);
    expect(list[1].canReply, isFalse);
    expect(list[1].replyStatus, isNull);
    expect(list[1].staffReplied, isNull);
  });

  test('thread sorts messages ascending and sends the id query', () async {
    serve(200, {
      'data': {
        'id': 7,
        'level': 0,
        'reply_status': 0,
        'status': 0,
        'subject': 'Slow node',
        'message': [
          {'id': 12, 'is_me': false, 'message': 'Try again', 'created_at': 200},
          {'id': 11, 'is_me': true, 'message': 'Help', 'created_at': 100},
          {'id': 10, 'is_me': 1, 'message': 'Hello', 'created_at': 100},
          {'id': 13, 'is_me': true, 'message': '  '},
          5,
        ],
      },
    });
    final thread = await support.thread(7);
    expect(requests.single.url.queryParameters, {'id': '7'});
    expect(thread.ticket.subject, 'Slow node');
    expect(thread.messages.map((m) => m.text), ['Hello', 'Help', 'Try again']);
    expect(thread.messages.map((m) => m.fromUser), [true, true, false]);
  });

  test('invalid shapes are rejected', () async {
    serve(200, {
      'data': {'id': 1},
    });
    await expectLater(support.tickets(), throwsA(isA<ClientFailure>()));
    await expectLater(support.thread(1), throwsA(isA<ClientFailure>()));
    serve(200, {'data': []});
    await expectLater(support.thread(1), throwsA(isA<ClientFailure>()));
  });

  test('writes send trimmed bodies and require literal true', () async {
    serve(200, {'data': true});
    await support.create(
      subject: '  Billing ',
      message: ' Hi ',
      level: ZolnitTicketLevel.high,
    );
    expect(requests.last.url.path, '/api/v1/user/ticket/save');
    expect(jsonDecode(requests.last.body), {
      'subject': 'Billing',
      'message': 'Hi',
      'level': 2,
    });
    await support.reply(4, ' more ');
    expect(requests.last.url.path, '/api/v1/user/ticket/reply');
    expect(jsonDecode(requests.last.body), {'id': 4, 'message': 'more'});
    await support.close(4);
    expect(requests.last.url.path, '/api/v1/user/ticket/close');
    expect(jsonDecode(requests.last.body), {'id': 4});

    serve(200, {'data': 1});
    await expectFailure(() => support.close(4), 'ticket_failed');
    await expectFailure(
      () => support.create(subject: 's', message: 'm'),
      'ticket_failed',
    );
  });

  test('invalid input is rejected before any request', () async {
    serve(200, {'data': true});
    await expectFailure(
      () => support.create(subject: '  ', message: 'm'),
      'invalid_ticket',
    );
    await expectFailure(
      () => support.create(subject: 's', message: ''),
      'invalid_ticket',
    );
    await expectFailure(() => support.reply(1, ' '), 'invalid_ticket');
    await expectFailure(() => support.reply(0, 'x'), 'invalid_ticket');
    await expectFailure(() => support.close(-1), 'invalid_ticket');
    await expectFailure(() => support.thread(0), 'invalid_ticket');
    expect(requests, isEmpty);
  });

  test('server refusals keep their message', () async {
    serve(400, {'message': 'The ticket is closed and cannot be replied'});
    await expectLater(
      support.reply(2, 'x'),
      throwsA(
        isA<ClientFailure>()
            .having((e) => e.code, 'code', 'api_error')
            .having(
              (e) => e.serverMessage,
              'message',
              'The ticket is closed and cannot be replied',
            ),
      ),
    );
  });
}
