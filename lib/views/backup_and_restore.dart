import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/dav_client.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/widgets/config_item.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BackupAndRestore extends ConsumerStatefulWidget {
  const BackupAndRestore({super.key});

  @override
  ConsumerState<BackupAndRestore> createState() => _BackupAndRestoreState();
}

class _BackupAndRestoreState extends ConsumerState<BackupAndRestore>
    with UniqueKeyStateMixin {
  final _davConnection = DAVConnectionController();

  @override
  void initState() {
    super.initState();
    ref.listenManual(davSettingProvider, (_, _) {
      _updateDAVClient();
    }, fireImmediately: true);
  }

  void _updateDAVClient() {
    unawaited(_davConnection.update(ref.read(davSettingProvider)));
  }

  @override
  void dispose() {
    _davConnection.dispose();
    super.dispose();
  }

  Future<void> _showAddWebDAV(DAVProps? dav) async {
    await showFormSheet<void>(
      context: context,
      builder: (_) => WebDAVForm(dav: dav?.copyWith()),
    );
  }

  Future<void> _run({
    required String title,
    required String successMessage,
    required Future<bool> Function() task,
  }) async {
    final res = await globalState.loadingRun<bool>(
      task,
      tag: LoadingTag.backup_restore,
      title: title,
    );
    if (res != true) return;
    unawaited(
      dialogs.showMessage(
        title: title,
        message: TextSpan(text: successMessage),
      ),
    );
  }

  Future<void> _backup(BackupDelivery deliver) {
    final appLocalizations = context.appLocalizations;
    return _run(
      title: appLocalizations.backup,
      successMessage: appLocalizations.backupSuccess,
      task: () => ref.read(backupActionProvider.notifier).backup(deliver),
    );
  }

  Future<void> _restore(RestoreOption option, BackupFetch fetch) {
    final appLocalizations = context.appLocalizations;
    return _run(
      title: appLocalizations.restore,
      successMessage: appLocalizations.restoreSuccess,
      task: () =>
          ref.read(backupActionProvider.notifier).restore(option, fetch),
    );
  }

  Future<RestoreOption?> _pickRestoreOption() {
    return dialogs.showCommonDialog<RestoreOption>(
      child: const RestoreOptionsDialog(),
    );
  }

  Future<void> _backupOnWebDAV() async {
    final client = _davConnection.client;
    final dav = ref.read(davSettingProvider);
    if (client == null || dav == null) return;
    final l = context.appLocalizations;
    await _backup((archivePath) async {
      final now = DateTime.now();
      if (BackupFileName.validate(
            dav.fileName,
            version: globalState.packageInfo.version,
            platform: Platform.operatingSystem,
            now: now,
          ) !=
          null) {
        throw MessageException(l.invalidBackupFileName);
      }
      final name = BackupFileName.render(
        dav.fileName,
        version: globalState.packageInfo.version,
        platform: Platform.operatingSystem,
        now: now,
      );
      await client.upload(archivePath, name: name);
      return true;
    });
  }

  Future<void> _restoreOnWebDAV() async {
    final client = _davConnection.client;
    if (client == null) return;
    final files = await globalState.loadingRun<List<DAVFile>>(
      client.listBackups,
      title: context.appLocalizations.restore,
      tag: LoadingTag.backup_restore,
    );
    if (files == null || !mounted) return;
    final name = await dialogs.showCommonDialog<String>(
      child: RemoteBackupsDialog(files: files, onDelete: client.deleteBackup),
    );
    if (name == null || !mounted) return;
    final option = await _pickRestoreOption();
    if (option == null || !mounted) return;
    await _restore(option, (downloadPath) async {
      await client.download(downloadPath, name: name);
      return downloadPath;
    });
  }

  Future<void> _backupOnLocal() {
    return _backup((archivePath) async {
      final savedPath = await picker.saveFileWithPath(
        getBackupFileName(),
        archivePath,
      );
      return savedPath != null;
    });
  }

  Future<void> _restoreOnLocal() async {
    final option = await _pickRestoreOption();
    if (option == null || !mounted) return;
    final file = await picker.pickerFile();
    final path = file?.path;
    if (path == null || !mounted) return;
    await _restore(option, (_) async => path);
  }

  Future<void> _editFileName(DAVProps dav) async {
    final value = await dialogs.showCommonDialog<String>(
      child: BackupFileNameDialog(
        value: dav.fileName,
        version: globalState.packageInfo.version,
        platform: Platform.operatingSystem,
      ),
    );
    if (value == null || !mounted) return;
    if (ref.read(davSettingProvider) != dav) return;
    ref
        .read(davSettingProvider.notifier)
        .update((state) => state?.copyWith(fileName: value));
  }

  Future<void> _editDirectory(DAVProps dav) async {
    final appLocalizations = context.appLocalizations;
    final value = await dialogs.showCommonDialog<String>(
      child: InputDialog(
        title: appLocalizations.davDirectory,
        value: dav.directory,
        labelText: appLocalizations.davDirectory,
        maxLength: TextInputLimits.uri,
        keyboardType: TextInputType.text,
        validator: (value) => DAVDirectory.isValid(value ?? '')
            ? null
            : appLocalizations.invalidDavDirectory,
        actionsBuilder: (controller, submit) => [
          _DAVDirectoryActions(
            controller: controller,
            loadDirectories: DAVClient(dav).listDirectories,
            submit: submit,
          ),
        ],
      ),
    );
    if (value == null || !mounted) return;
    if (ref.read(davSettingProvider) != dav) return;
    ref
        .read(davSettingProvider.notifier)
        .update(
          (state) => state?.copyWith(directory: DAVDirectory.normalize(value)),
        );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final dav = ref.watch(davSettingProvider);
    final isLoading = ref.watch(loadingProvider(LoadingTag.backup_restore));
    return CommonScaffold(
      isLoading: isLoading,
      title: appLocalizations.backupAndRestore,
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ).copyWith(top: context.appBarInset, bottom: 16),
        children: [
          generateSection(
            title: appLocalizations.remote,
            items: [
              if (dav == null)
                ListItem(
                  leading: const GlyphIcon(AppGlyphs.account),
                  title: Text(appLocalizations.noInfo),
                  subtitle: Text(appLocalizations.pleaseBindWebDAV),
                  trailing: TonalButton(
                    label: appLocalizations.bind,
                    onPressed: () {
                      _showAddWebDAV(dav);
                    },
                  ),
                )
              else ...[
                ListItem(
                  leading: const GlyphIcon(AppGlyphs.account),
                  title: TooltipText(
                    text: Text(
                      dav.user,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(appLocalizations.connectivity),
                        _DavConnectionIndicator(connection: _davConnection),
                      ],
                    ),
                  ),
                  trailing: TonalButton(
                    label: appLocalizations.edit,
                    onPressed: () {
                      _showAddWebDAV(dav);
                    },
                  ),
                ),
                ListItem(
                  title: Text(appLocalizations.file),
                  subtitle: Text(dav.fileName),
                  onTap: () => _editFileName(dav),
                ),
                ListItem(
                  title: Text(appLocalizations.davDirectory),
                  subtitle: Text(DAVDirectory.normalize(dav.directory)),
                  onTap: () => _editDirectory(dav),
                ),
                ListItem(
                  onTap: () {
                    _backupOnWebDAV();
                  },
                  title: Text(appLocalizations.backup),
                ),
                ListItem(
                  onTap: () {
                    _restoreOnWebDAV();
                  },
                  title: Text(appLocalizations.restore),
                ),
              ],
            ],
          ),
          generateSection(
            title: appLocalizations.local,
            items: [
              ListItem(
                onTap: () {
                  _backupOnLocal();
                },
                title: Text(appLocalizations.backup),
              ),
              ListItem(
                onTap: () {
                  _restoreOnLocal();
                },
                title: Text(appLocalizations.restore),
              ),
            ],
          ),
          generateSection(
            title: appLocalizations.options,
            items: [
              ConfigOptionsItem<RestoreStrategy>(
                title: (l) => l.restoreStrategy,
                options: RestoreStrategy.values,
                textBuilder: (strategy) => strategy.label,
                selector: appSettingProvider.select(
                  (state) => state.restoreStrategy,
                ),
                onChanged: (ref, value) => ref
                    .read(appSettingProvider.notifier)
                    .update((state) => state.copyWith(restoreStrategy: value)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DavConnectionIndicator extends StatelessWidget {
  const _DavConnectionIndicator({required this.connection});

  final ValueNotifier<bool?> connection;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: connection,
      builder: (context, isConnected, _) {
        return Center(
          child: FadeThroughBox(
            child: isConnected == null
                ? const CommonCircleLoading(size: 12)
                : Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: !isConnected
                          ? context.colorScheme.error
                          : context.colorScheme.success,
                    ),
                    width: 12,
                    height: 12,
                  ),
          ),
        );
      },
    );
  }
}

class RestoreOptionsDialog extends StatefulWidget {
  const RestoreOptionsDialog({super.key});

  @override
  State<RestoreOptionsDialog> createState() => _RestoreOptionsDialogState();
}

class _RestoreOptionsDialogState extends State<RestoreOptionsDialog> {
  void _handleOnTab(RestoreOption? option) {
    if (option == null) return;
    Navigator.of(context).pop(option);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.restore,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Wrap(
        children: [
          ListItem(
            onTap: () {
              _handleOnTab(RestoreOption.onlyProfiles);
            },
            title: Text(appLocalizations.restoreOnlyConfig),
          ),
          ListItem(
            onTap: () {
              _handleOnTab(RestoreOption.all);
            },
            title: Text(appLocalizations.restoreAllData),
          ),
        ],
      ),
    );
  }
}

enum _DavField { uri, user, password }

class WebDAVForm extends ConsumerStatefulWidget {
  final DAVProps? dav;

  const WebDAVForm({super.key, this.dav});

  @override
  ConsumerState<WebDAVForm> createState() => _WebDAVFormState();
}

class _WebDAVFormState extends ConsumerState<WebDAVForm> {
  late final TextEditingController _uriController;
  late final TextEditingController _userController;
  late final TextEditingController _passwordController;
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    _uriController = TextEditingController(text: widget.dav?.uri);
    _userController = TextEditingController(text: widget.dav?.user);
    _passwordController = TextEditingController(text: widget.dav?.password);
  }

  @override
  void dispose() {
    _uriController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  ({_DavField field, String message})? _issue(
    AppLocalizations appLocalizations,
  ) {
    final uri = _uriController.text;
    if (uri.isEmpty || !uri.isUrl) {
      return (field: _DavField.uri, message: appLocalizations.addressTip);
    }
    if (_userController.text.isEmpty) {
      return (
        field: _DavField.user,
        message: appLocalizations.emptyTip(appLocalizations.account),
      );
    }
    if (_passwordController.text.isEmpty) {
      return (
        field: _DavField.password,
        message: appLocalizations.emptyTip(appLocalizations.password),
      );
    }
    return null;
  }

  void _handleChanged(String _) {
    if (_attempted) {
      setState(() {});
    }
  }

  void _submit() {
    if (_issue(context.appLocalizations) != null) {
      setState(() {
        _attempted = true;
      });
      return;
    }
    ref
        .read(davSettingProvider.notifier)
        .update(
          (_) => DAVProps(
            uri: _uriController.text,
            user: _userController.text,
            password: _passwordController.text,
            fileName: widget.dav?.fileName ?? defaultDavFileName,
            directory:
                widget.dav?.directory ??
                (const DAVProps(uri: '', user: '')).directory,
          ),
        );
    Navigator.pop(context);
  }

  void _delete() {
    ref.read(davSettingProvider.notifier).update((_) => null);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final issue = _attempted ? _issue(appLocalizations) : null;
    return FormPage(
      title: appLocalizations.webDAVConfiguration,
      onSave: _submit,
      error: issue?.message,
      children: [
        generateSection(
          footer: appLocalizations.addressHelp,
          items: [
            FormRow(
              title: appLocalizations.address,
              invalid: issue?.field == _DavField.uri,
              trailing: FormRowTextField(
                controller: _uriController,
                hintText: appLocalizations.required,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                inputFormatters: TextInputLimits.limit(TextInputLimits.uri),
                onChanged: _handleChanged,
              ),
            ),
            FormRow(
              title: appLocalizations.account,
              invalid: issue?.field == _DavField.user,
              trailing: FormRowTextField(
                controller: _userController,
                hintText: appLocalizations.required,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                inputFormatters: TextInputLimits.limit(
                  TextInputLimits.userName,
                ),
                onChanged: _handleChanged,
              ),
            ),
            FormRow(
              title: appLocalizations.password,
              invalid: issue?.field == _DavField.password,
              trailing: FormRowSecretTextField(
                controller: _passwordController,
                hintText: appLocalizations.required,
                textInputAction: TextInputAction.done,
                inputFormatters: TextInputLimits.limit(
                  TextInputLimits.password,
                ),
                onChanged: _handleChanged,
                onFieldSubmitted: (_) => _submit(),
              ),
            ),
          ],
        ),
        if (widget.dav != null)
          generateSection(
            items: [
              FormRow(
                title: appLocalizations.delete,
                titleStyle: TextStyle(color: context.colorScheme.error),
                onPressed: _delete,
              ),
            ],
          ),
      ],
    );
  }
}

class BackupFileNameDialog extends StatefulWidget {
  final String value;
  final String version;
  final String platform;

  const BackupFileNameDialog({
    super.key,
    required this.value,
    required this.version,
    required this.platform,
  });

  @override
  State<BackupFileNameDialog> createState() => _BackupFileNameDialogState();
}

class _BackupFileNameDialogState extends State<BackupFileNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  late final DateTime _previewTime;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _previewTime = DateTime.now();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _render(String value) => BackupFileName.render(
    value,
    version: widget.version,
    platform: widget.platform,
    now: _previewTime,
  );

  String? _validate(String? value) {
    final appLocalizations = context.appLocalizations;
    final error = BackupFileName.validate(
      value ?? '',
      version: widget.version,
      platform: widget.platform,
      now: _previewTime,
    );
    return switch (error) {
      null => null,
      BackupFileNameError.empty => appLocalizations.emptyTip(
        appLocalizations.fileName,
      ),
      BackupFileNameError.unknownVariable =>
        appLocalizations.unknownBackupVariable,
      _ => appLocalizations.invalidBackupFileName,
    };
  }

  void _insert(String variable) {
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : _controller.text.length;
    final end = selection.isValid ? selection.end : start;
    final token = '{$variable}';
    _controller.value = TextEditingValue(
      text: _controller.text.replaceRange(start, end, token),
      selection: TextSelection.collapsed(offset: start + token.length),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    final value = _controller.text;
    Navigator.of(context).pop(BackupFileName.ensureZipExtension(value));
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final replacements = {
      'version': appLocalizations.backupVersionDescription,
      'date': appLocalizations.backupDateDescription,
      'time': appLocalizations.backupTimeDescription,
      'platform': appLocalizations.backupPlatformDescription,
    };
    return CommonDialog(
      title: appLocalizations.fileName,
      maxWidth: 420,
      actions: [
        TextButton(
          onPressed: () => _controller.text = defaultDavFileName,
          child: Text(appLocalizations.reset),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(appLocalizations.save)),
      ],
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            TextFormField(
              controller: _controller,
              maxLength: TextInputLimits.fileName,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: appLocalizations.fileName,
                hintText: defaultDavFileName,
              ),
              validator: _validate,
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Text(appLocalizations.textReplacement),
                for (final entry in replacements.entries)
                  Row(
                    spacing: 12,
                    children: [
                      TonalChip(
                        label: '{${entry.key}}',
                        color: context.colorScheme.secondaryContainer,
                        foregroundColor:
                            context.colorScheme.onSecondaryContainer,
                        onPressed: () => _insert(entry.key),
                      ),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: AppTextStyle.footnote
                              .of(context)
                              .copyWith(
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${appLocalizations.preview}: '),
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: _controller,
                    builder: (_, value, _) => Text(
                      _render(value.text),
                      style: AppTextStyle.body
                          .of(context)
                          .copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DAVDirectoryActions extends StatefulWidget {
  final TextEditingController controller;
  final Future<List<String>> Function(String path) loadDirectories;
  final VoidCallback submit;

  const _DAVDirectoryActions({
    required this.controller,
    required this.loadDirectories,
    required this.submit,
  });

  @override
  State<_DAVDirectoryActions> createState() => _DAVDirectoryActionsState();
}

class _DAVDirectoryActionsState extends State<_DAVDirectoryActions> {
  bool _browsing = false;

  Future<void> _browse() async {
    if (_browsing) return;
    setState(() => _browsing = true);
    try {
      final value = await dialogs.showCommonDialog<String>(
        context: context,
        child: DAVDirectoryBrowserDialog(
          directory: DAVDirectory.isValid(widget.controller.text)
              ? DAVDirectory.normalize(widget.controller.text)
              : '/',
          loadDirectories: widget.loadDirectories,
        ),
      );
      if (mounted && value != null) widget.controller.text = value;
    } finally {
      if (mounted) setState(() => _browsing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _browsing ? null : _browse,
          child: Text(appLocalizations.browse),
        ),
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: _browsing
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pop((const DAVProps(uri: '', user: '')).directory),
                child: Text(appLocalizations.reset),
              ),
              TextButton(
                onPressed: _browsing ? null : widget.submit,
                child: Text(appLocalizations.submit),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DAVDirectoryBrowserDialog extends StatefulWidget {
  final String directory;
  final Future<List<String>> Function(String path) loadDirectories;

  const DAVDirectoryBrowserDialog({
    super.key,
    required this.directory,
    required this.loadDirectories,
  });

  @override
  State<DAVDirectoryBrowserDialog> createState() =>
      _DAVDirectoryBrowserDialogState();
}

class _DAVDirectoryBrowserDialogState extends State<DAVDirectoryBrowserDialog> {
  late String _directory;
  List<String> _directories = [];
  bool _loading = true;
  Object? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _directory = DAVDirectory.normalize(widget.directory);
    unawaited(_load(_directory));
  }

  Future<void> _load(String path) async {
    final requestId = ++_requestId;
    setState(() {
      _directory = DAVDirectory.normalize(path);
      _directories = [];
      _error = null;
      _loading = true;
    });
    try {
      final directories = await widget.loadDirectories(_directory);
      if (mounted && requestId == _requestId) {
        setState(() => _directories = directories);
      }
    } catch (error) {
      if (mounted && requestId == _requestId) setState(() => _error = error);
    } finally {
      if (mounted && requestId == _requestId) setState(() => _loading = false);
    }
  }

  void _parent() {
    final segments = _directory
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();
    if (segments.isEmpty) return;
    segments.removeLast();
    unawaited(_load('/${segments.join('/')}'));
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.browse,
      maxWidth: 360,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.cancel),
        ),
        TextButton(
          onPressed: _loading || _error != null
              ? null
              : () => Navigator.of(context).pop(_directory),
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _directory,
              style: AppTextStyle.body
                  .of(context)
                  .copyWith(color: context.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 8),
          if (_directory != '/')
            ListItem(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const GlyphIcon(AppGlyphs.arrowUp),
              title: Text(appLocalizations.parentDirectory),
              onTap: _parent,
            ),
          if (_loading)
            const Center(child: CommonCircleLoading(size: 24))
          else if (_error != null) ...[
            Text(userFacingErrorMessage(_error!, appLocalizations)),
            TextButton(
              onPressed: () => _load(_directory),
              child: Text(appLocalizations.retry),
            ),
          ] else if (_directories.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  appLocalizations.noDirectories,
                  style: AppTextStyle.body
                      .of(context)
                      .copyWith(color: context.colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            for (final directory in _directories)
              ListItem(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                leading: const GlyphIcon(AppGlyphs.profiles),
                title: Text(directory),
                onTap: () =>
                    _load(DAVDirectory.normalize('$_directory/$directory')),
              ),
        ],
      ),
    );
  }
}

class RemoteBackupsDialog extends StatefulWidget {
  final List<DAVFile> files;
  final Future<void> Function(String name)? onDelete;

  const RemoteBackupsDialog({super.key, required this.files, this.onDelete});

  @override
  State<RemoteBackupsDialog> createState() => _RemoteBackupsDialogState();
}

class _RemoteBackupsDialogState extends State<RemoteBackupsDialog> {
  late List<DAVFile> _files;
  String? _selected;
  bool _deleting = false;

  bool get _canDelete =>
      widget.onDelete != null &&
      _files.where((file) => file.name == _selected).firstOrNull?.type ==
          DAVResourceType.file;

  @override
  void initState() {
    super.initState();
    _files = [...widget.files];
    _selected = _files.firstOrNull?.name;
  }

  Future<void> _delete() async {
    final name = _selected;
    final onDelete = widget.onDelete;
    if (_deleting || name == null || onDelete == null || !_canDelete) return;
    final appLocalizations = context.appLocalizations;
    setState(() => _deleting = true);
    try {
      final confirmed = await dialogs.showMessage(
        context: context,
        title: appLocalizations.delete,
        message: TextSpan(text: appLocalizations.deleteTip(name)),
      );
      if (confirmed != true || !mounted) return;
      final deleted = await globalState.safeRun<bool>(
        () async {
          await onDelete(name);
          return true;
        },
        title: appLocalizations.delete,
        silence: false,
      );
      if (deleted != true || !mounted) return;
      setState(() {
        _files.removeWhere((file) => file.name == name);
        _selected = _files.firstOrNull?.name;
      });
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return PopScope(
      canPop: !_deleting,
      child: CommonDialog(
        title: appLocalizations.selectRemoteBackup,
        maxWidth: 420,
        actions: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (widget.onDelete != null)
                TextButton(
                  onPressed: _deleting || !_canDelete ? null : _delete,
                  style: TextButton.styleFrom(
                    foregroundColor: context.colorScheme.error,
                  ),
                  child: Text(appLocalizations.delete),
                ),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _deleting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(appLocalizations.cancel),
                    ),
                    TextButton(
                      onPressed: _deleting || _selected == null
                          ? null
                          : () => Navigator.of(context).pop(_selected),
                      child: Text(appLocalizations.confirm),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        child: _files.isEmpty
            ? Text(appLocalizations.noRemoteBackups)
            : RadioGroup<String>(
                groupValue: _selected,
                onChanged: (value) {
                  if (_deleting || value == null) return;
                  setState(() => _selected = value);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final file in _files)
                      ListItem(
                        trailing: _selected == file.name
                            ? const SelectionCheck()
                            : const SizedBox.square(
                                dimension: SelectionCheck.size,
                              ),
                        padding: EdgeInsets.zero,
                        title: Text(
                          file.name,
                          style: AppTextStyle.body.of(context),
                        ),
                        subtitle: file.modified == null
                            ? null
                            : Text(
                                file.modified!.toLocal().show,
                                style: AppTextStyle.footnote
                                    .of(context)
                                    .copyWith(
                                      color:
                                          context.colorScheme.onSurfaceVariant,
                                    ),
                              ),
                        onTap: _deleting
                            ? null
                            : () => setState(() => _selected = file.name),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
