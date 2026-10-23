import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'data.dart';

class ZolnitPasswordForm extends StatefulWidget {
  const ZolnitPasswordForm({super.key, required this.session});

  final ZolnitSessionController session;

  @override
  State<ZolnitPasswordForm> createState() => _ZolnitPasswordFormState();
}

class _ZolnitPasswordFormState extends State<ZolnitPasswordForm> {
  final _old = TextEditingController();
  final _fresh = TextEditingController();
  late final int _generation = widget.session.api.generation;
  bool _saving = false;
  bool _closing = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_accountChanged);
  }

  void _accountChanged() {
    if (widget.session.api.generation != _generation) {
      _old.clear();
      _fresh.clear();
      if (mounted && !_closing) {
        _closing = true;
        Navigator.of(context).maybePop();
      }
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_accountChanged);
    _old.dispose();
    _fresh.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || widget.session.api.generation != _generation) return;
    final text = context.appLocalizations;
    if (_old.text.isEmpty ||
        _fresh.text.runes.length < 8 ||
        _old.text == _fresh.text) {
      setState(() => _failure = text.zolnitPasswordInvalid);
      return;
    }
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ZolnitAccountClient(
        widget.session.api,
      ).changePassword(oldPassword: _old.text, newPassword: _fresh.text);
      if (mounted && widget.session.api.generation == _generation) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted && widget.session.api.generation == _generation) {
        setState(() {
          _failure = zolnitFailureText(
            context,
            error is ClientFailure ? error.code : null,
            error is ClientFailure ? error.serverMessage : null,
          );
        });
      }
    } finally {
      if (mounted) {
        _old.clear();
        _fresh.clear();
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    return FormPage(
      title: text.zolnitChangePassword,
      onSave: _submit,
      saving: _saving,
      error: _failure,
      children: [
        AbsorbPointer(
          absorbing: _saving,
          child: generateSection(
            items: [
              FormRow(
                title: text.zolnitOldPassword,
                trailing: FormRowSecretTextField(
                  key: const ValueKey('zolnit-old-password'),
                  controller: _old,
                  textInputAction: TextInputAction.next,
                ),
              ),
              FormRow(
                title: text.zolnitNewPassword,
                trailing: FormRowSecretTextField(
                  key: const ValueKey('zolnit-new-password'),
                  controller: _fresh,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
