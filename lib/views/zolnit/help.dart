import 'dart:async';

import 'package:fl_clash/common/context.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'data.dart';
import 'kit.dart';
import 'skin.dart';

List<Json> _prepareHelpArticles(List<Json> articles) => [
  for (final article in articles)
    {
      ...article,
      'plain_body': plainLines(
        (article['body'] as String? ?? '').replaceAll(
          RegExp(
            r'<(script|style)\b[^>]*>.*?</\1\s*>',
            caseSensitive: false,
            dotAll: true,
          ),
          '',
        ),
        maxLines: 10000,
        maxLength: 100000,
      ).join('\n\n'),
    },
];

class ZolnitHelpPage extends StatefulWidget {
  const ZolnitHelpPage({super.key, required this.session});
  final ZolnitSessionController session;

  @override
  State<ZolnitHelpPage> createState() => _ZolnitHelpPageState();
}

class _ZolnitHelpPageState extends State<ZolnitHelpPage>
    with WidgetsBindingObserver {
  late final int _generation = widget.session.api.generation;
  List<Json> _articles = const [];
  List<ZolnitTicket> _tickets = const [];
  bool _loading = false;
  bool _started = false;
  String? _error;

  bool get _current =>
      mounted &&
      widget.session.authenticated &&
      widget.session.api.generation == _generation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      unawaited(_load());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    if (!_current || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final language = Localizations.localeOf(context).toLanguageTag();
      var articles = _articles;
      var tickets = _tickets;
      String? failure;
      void failed(Object error) {
        failure = error is ClientFailure ? error.code : 'network';
      }

      await Future.wait([
        () async {
          try {
            final source = await widget.session.api.knowledge(
              language: language,
            );
            articles = await compute(_prepareHelpArticles, source);
          } catch (error) {
            failed(error);
          }
        }(),
        () async {
          try {
            tickets = await ZolnitSupportClient(widget.session.api).tickets();
          } catch (error) {
            failed(error);
          }
        }(),
      ]);
      if (failure == 'unauthenticated' && _current) {
        await widget.session.refresh();
      }
      if (_current) {
        setState(() {
          _articles = articles;
          _tickets = tickets;
          _error = failure;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _compose([int? ticketId]) async {
    if (!_current) return;
    await showFormSheet<void>(
      context: context,
      builder: (_) => _TicketComposer(
        session: widget.session,
        ticketId: ticketId,
        generation: _generation,
      ),
    );
    if (_current) await _load();
  }

  Future<void> _thread(ZolnitTicket ticket) async {
    await openZolnitPage<void>(
      context,
      _TicketThread(
        session: widget.session,
        ticket: ticket,
        generation: _generation,
      ),
    );
    if (_current) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final colors = ZolnitColors.of(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: colors.paper,
        surfaceTintColor: colors.paper,
        leading: IconButton(
          tooltip: text.back,
          onPressed: () => unawaited(Navigator.maybePop(context)),
          icon: GlyphIcon(AppGlyphs.arrowBack, color: colors.ink),
        ),
        title: Text(
          text.zolnitHelpSupport,
          style: AppTextStyle.headline.of(context, emphasized: true),
        ),
      ),
      body: ListenableBuilder(
        listenable: widget.session,
        builder: (context, _) {
          if (!_current) return Center(child: Text(text.zolnitSessionExpired));
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null && !_loading)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            zolnitFailureText(
                              context,
                              _error,
                              null,
                              fallback: text.zolnitHelpLoadFailed,
                            ),
                            style: zolnitText(context, 13, color: colors.ink),
                          ),
                        ),
                        TextButton(
                          onPressed: () => unawaited(_load()),
                          child: Text(text.retry),
                        ),
                      ],
                    )
                  else if (!_loading && _articles.isEmpty)
                    Text(text.zolnitHelpNoArticles),
                  for (final article in _articles)
                    ExpansionTile(
                      trailing: const GlyphIcon(
                        AppGlyphs.chevronDown,
                        size: 16,
                      ),
                      title: Text(article['title'] as String? ?? ''),
                      childrenPadding: const EdgeInsets.all(12),
                      children: [
                        SelectionArea(
                          child: Text(
                            article['plain_body'] as String? ?? '',
                            style: zolnitText(context, 14, leading: 22),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 18),
                  ZolnitSectionHeading(
                    title: text.zolnitSupportTickets,
                    actionLabel: text.zolnitNewTicket,
                    onAction: () => _compose(),
                  ),
                  for (final ticket in _tickets)
                    ListTile(
                      title: Text(ticket.subject),
                      subtitle: Text(
                        ticket.closed
                            ? text.zolnitRenewalEnded
                            : text.zolnitRenewalPending,
                      ),
                      trailing: const GlyphIcon(
                        AppGlyphs.chevronForward,
                        size: 16,
                      ),
                      onTap: () => _thread(ticket),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TicketComposer extends StatefulWidget {
  const _TicketComposer({
    required this.session,
    required this.generation,
    this.ticketId,
  });
  final ZolnitSessionController session;
  final int? ticketId;
  final int generation;
  @override
  State<_TicketComposer> createState() => _TicketComposerState();
}

class _TicketComposerState extends State<_TicketComposer> {
  final _message = TextEditingController();
  int get _generation => widget.generation;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _message.text.trim();
    if (message.isEmpty) {
      setState(() => _error = 'empty_ticket');
      return;
    }
    if (_busy ||
        !widget.session.authenticated ||
        widget.session.api.generation != _generation) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ZolnitSupportClient(widget.session.api);
      if (widget.ticketId case final id?) {
        await api.reply(id, message);
      } else {
        await api.create(
          subject: message.split('\n').first.characters.take(80).string,
          message: message,
        );
      }
      if (mounted && widget.session.api.generation == _generation) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted && widget.session.api.generation == _generation) {
        setState(
          () => _error = error is ClientFailure ? error.code : 'network',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    return ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) {
        final valid =
            widget.session.authenticated &&
            widget.session.api.generation == _generation;
        if (!valid) {
          return FormPage(
            title: text.zolnitSupportTickets,
            onSave: () => Navigator.pop(context),
            saveLabel: text.cancel,
            error: text.zolnitSessionExpired,
            children: const [],
          );
        }
        return PopScope(
          canPop: !_busy,
          child: FormPage(
            title: text.zolnitSupportTickets,
            onSave: _send,
            saving: _busy,
            saveLabel: text.zolnitSendRequest,
            error: _error == null
                ? null
                : zolnitFailureText(context, _error, null),
            children: [
              FormRow(title: text.zolnitTicketMessage),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _message,
                  maxLines: null,
                  minLines: 4,
                  maxLength: 4000,
                  enabled: !_busy,
                  decoration: InputDecoration(
                    hintText: text.zolnitTicketMessage,
                  ),
                ),
              ),
              if (_busy) const LinearProgressIndicator(),
            ],
          ),
        );
      },
    );
  }
}

class _TicketThread extends StatefulWidget {
  const _TicketThread({
    required this.session,
    required this.ticket,
    required this.generation,
  });
  final ZolnitSessionController session;
  final ZolnitTicket ticket;
  final int generation;
  @override
  State<_TicketThread> createState() => _TicketThreadState();
}

class _TicketThreadState extends State<_TicketThread> {
  int get _generation => widget.generation;
  late Future<ZolnitTicketThread> _thread = _load();
  Future<ZolnitTicketThread> _load() =>
      ZolnitSupportClient(widget.session.api).thread(widget.ticket.id);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.appLocalizations.zolnitSupportTickets)),
    body: ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) {
        if (!widget.session.authenticated ||
            widget.session.api.generation != _generation) {
          return Center(
            child: Text(context.appLocalizations.zolnitSessionExpired),
          );
        }
        return FutureBuilder<ZolnitTicketThread>(
          future: _thread,
          builder: (context, snapshot) {
            final thread = snapshot.data;
            if (snapshot.hasError) {
              return Center(
                child: Text(context.appLocalizations.zolnitFailure),
              );
            }
            if (thread == null) {
              return const Center(child: CommonCircleLoading());
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final message in thread.messages)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ZolnitCard(child: SelectableText(message.text)),
                  ),
                if (thread.ticket.canReply)
                  TextButton(
                    onPressed: () async {
                      await showFormSheet<void>(
                        context: context,
                        builder: (_) => _TicketComposer(
                          session: widget.session,
                          ticketId: widget.ticket.id,
                          generation: _generation,
                        ),
                      );
                      if (mounted &&
                          widget.session.api.generation == _generation) {
                        setState(() => _thread = _load());
                      }
                    },
                    child: Text(context.appLocalizations.zolnitTicketReply),
                  ),
              ],
            );
          },
        );
      },
    ),
  );
}
