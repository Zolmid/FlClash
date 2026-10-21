import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'brand.dart';

class ZolnitLoginPage extends StatefulWidget {
  const ZolnitLoginPage({
    super.key,
    required this.session,
    required this.onSignedIn,
    required this.openWebsite,
  });

  final ZolnitSessionController session;
  final Future<void> Function() onSignedIn;
  final VoidCallback openWebsite;

  @override
  State<ZolnitLoginPage> createState() => _ZolnitLoginPageState();
}

class _ZolnitLoginPageState extends State<ZolnitLoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_form.currentState?.validate() != true || widget.session.busy) return;
    await widget.session.login(_email.text.trim(), _password.text);
    if (!mounted) return;
    _password.clear();
    if (widget.session.authenticated) await widget.onSignedIn();
  }

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final session = widget.session;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Row(
          children: [
            if (wide)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const ZolnitBrand(width: 210),
                      const SizedBox(height: 48),
                      Text(
                        text.zolnitTagline,
                        style: AppTextStyle.largeTitle.of(context),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        text.zolnitProfileSource,
                        style: AppTextStyle.body.of(context),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: ZolnitPanel(
                      child: Form(
                        key: _form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!wide) ...[
                              const ZolnitBrand(),
                              const SizedBox(height: 32),
                            ],
                            Text(
                              text.zolnitWelcome,
                              style: AppTextStyle.title1.of(context),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              key: const ValueKey('zolnit-email'),
                              controller: _email,
                              enabled: !session.busy,
                              autocorrect: false,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.username],
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
                              decoration: InputDecoration(
                                labelText: text.password,
                              ),
                              validator: (value) => (value?.length ?? 0) >= 8
                                  ? null
                                  : text.zolnitCredentialsInvalid,
                              onFieldSubmitted: (_) => _login(),
                            ),
                            ZolnitFailureMessage(
                              visible: session.failure != null,
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              key: const ValueKey('zolnit-sign-in'),
                              onPressed: session.busy ? null : _login,
                              child: session.busy
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CommonCircleLoading(size: 20),
                                    )
                                  : Text(text.zolnitSignIn),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              text.zolnitSessionOnly,
                              style: AppTextStyle.footnote.of(context),
                            ),
                            TextButton(
                              onPressed: widget.openWebsite,
                              child: Text(text.zolnitLoginWebsite),
                            ),
                          ],
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
