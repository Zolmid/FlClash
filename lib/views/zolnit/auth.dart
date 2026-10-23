import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'brand.dart';
import 'kit.dart';
import 'skin.dart';

class ZolnitLoginPage extends StatefulWidget {
  const ZolnitLoginPage({
    super.key,
    required this.session,
    required this.onSignedIn,
    required this.openWebsite,
    this.openRegistration,
    this.openRecovery,
  });

  final ZolnitSessionController session;
  final Future<void> Function() onSignedIn;
  final VoidCallback openWebsite;
  final VoidCallback? openRegistration;
  final VoidCallback? openRecovery;

  @override
  State<ZolnitLoginPage> createState() => _ZolnitLoginPageState();
}

class _ZolnitLoginPageState extends State<ZolnitLoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.clear();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_submitting || widget.session.busy) return;
    if (_form.currentState?.validate() != true) return;
    setState(() => _submitting = true);
    try {
      final login = widget.session.login(_email.text.trim(), _password.text);
      final generation = widget.session.accountGeneration;
      await login;
      if (mounted) _password.clear();
      if (mounted &&
          widget.session.authenticated &&
          widget.session.accountGeneration == generation) {
        await widget.onSignedIn();
      }
    } finally {
      if (mounted) {
        _password.clear();
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _restore() async {
    if (_submitting || widget.session.busy) return;
    setState(() => _submitting = true);
    try {
      await widget.session.restore();
      if (mounted && widget.session.authenticated) {
        await widget.onSignedIn();
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final session = widget.session;
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    final busy = _submitting || session.busy;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Row(
          children: [
            if (wide)
              const Expanded(
                key: ValueKey('zolnit-brand-panel'),
                child: ZolnitBrandRegion(),
              ),
            Expanded(
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: skin.desktop ? 28 : 16,
                      vertical: skin.desktop ? 24 : 16,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: ZolnitCard(
                        padding: EdgeInsets.all(skin.desktop ? 30 : 20),
                        child: AutofillGroup(
                          onDisposeAction: AutofillContextAction.cancel,
                          child: Form(
                            key: _form,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!wide) ...[
                                  Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: ZolnitBrand(
                                      width: skin.desktop ? 227 : 180,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                ],
                                Text(
                                  text.zolnitLoginEyebrow.toUpperCase(),
                                  style: AppTextStyle.caption2
                                      .of(context, emphasized: true)
                                      .copyWith(
                                        color: colors.accent,
                                        letterSpacing: 1.4,
                                      ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  text.zolnitWelcome,
                                  style:
                                      (skin.desktop
                                              ? AppTextStyle.title1
                                              : AppTextStyle.largeTitle)
                                          .of(context, emphasized: true),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  text.zolnitLoginSubtitle,
                                  style: AppTextStyle.footnote
                                      .of(context)
                                      .copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 28),
                                TextFormField(
                                  key: const ValueKey('zolnit-email'),
                                  controller: _email,
                                  enabled: !busy,
                                  autocorrect: false,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.username],
                                  onFieldSubmitted: (_) =>
                                      _passwordFocus.requestFocus(),
                                  decoration: InputDecoration(
                                    labelText: text.zolnitEmail,
                                  ),
                                  validator: (value) =>
                                      value?.trim().contains('@') == true
                                      ? null
                                      : text.zolnitCredentialsInvalid,
                                ),
                                const SizedBox(height: 16),
                                SecretTextFormField(
                                  key: const ValueKey('zolnit-password'),
                                  controller: _password,
                                  focusNode: _passwordFocus,
                                  enabled: !busy,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  decoration: InputDecoration(
                                    labelText: text.password,
                                  ),
                                  validator: (value) =>
                                      (value?.length ?? 0) >= 8
                                      ? null
                                      : text.zolnitCredentialsInvalid,
                                  onFieldSubmitted: (_) => _login(),
                                ),
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: TextButton(
                                    onPressed:
                                        widget.openRecovery ??
                                        widget.openWebsite,
                                    child: Text(text.zolnitForgotPassword),
                                  ),
                                ),
                                ZolnitFailureMessage(
                                  code:
                                      session.failure == 'unauthenticated' &&
                                          session.restoreState !=
                                              ZolnitRestoreState.expired
                                      ? 'invalid_credentials'
                                      : session.failure,
                                  serverMessage: session.failureMessage,
                                ),
                                if (session.restoreState ==
                                    ZolnitRestoreState.offline)
                                  Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: TextButton(
                                      onPressed: busy ? null : _restore,
                                      child: Text(text.retry),
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  key: const ValueKey('zolnit-sign-in'),
                                  onPressed: busy ? null : _login,
                                  child: busy
                                      ? const SizedBox.square(
                                          dimension: 20,
                                          child: CommonCircleLoading(size: 20),
                                        )
                                      : Text(text.zolnitSignIn),
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: TextButton(
                                    onPressed:
                                        widget.openRegistration ??
                                        widget.openWebsite,
                                    child: Text(text.zolnitRegister),
                                  ),
                                ),
                                Text(
                                  text.zolnitRegistrationWebsiteHint,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyle.caption1
                                      .of(context)
                                      .copyWith(color: colors.muted),
                                ),
                                TextButton(
                                  onPressed: widget.openWebsite,
                                  child: Text(text.zolnitWebsite),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
