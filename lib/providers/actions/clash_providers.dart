part of '../action.dart';

@Riverpod(keepAlive: true)
class ClashProvidersAction extends _$ClashProvidersAction {
  @override
  void build() {}

  CoreController get _core => ref.read(coreHandlerProvider);

  @visibleForTesting
  Future<void> Function(int step)? syncPublishHook;

  Future<ClashProvider> putProvider(
    ClashProvider provider, {
    ClashProvider? previous,
    List<int>? content,
    bool refresh = false,
  }) async {
    final before = await _stored(provider.id);
    final download =
        provider.isRemote &&
        (refresh || provider.fileName != previous?.fileName);
    final compiled = switch (content) {
      final content? => await _compileContent(provider, content),
      null when download => await _compile(provider, download: true),
      null => provider,
    };
    final latest = before == null ? null : await _stored(provider.id);
    if (before != null &&
        (latest == null || latest.fileName != before.fileName)) {
      if (latest?.fileName != compiled.fileName) {
        await _clearCache(compiled);
      }
      return latest ?? compiled;
    }
    final next = switch ((before, latest)) {
      (final before?, final latest?) => latest.copyWith(
        label: compiled.label == before.label ? latest.label : compiled.label,
        url: compiled.url,
        behavior: compiled.behavior,
        format: compiled.format,
      ),
      _ => compiled,
    };
    ref.read(clashProvidersProvider.notifier).put(next);
    if (previous != null && previous.fileName != next.fileName) {
      unawaited(_clearCache(previous));
    }
    unawaited(
      applyIfReferenced(ProviderKind.rule, {
        next.label,
        ?previous?.label,
      }, force: content != null || download),
    );
    return next;
  }

  /// Downloads outlast edits, so a result lands on the set as it is by then.
  Future<ClashProvider?> _stored(int id) async {
    final rows =
        ref.read(clashProvidersProvider).value ??
        await database.clashProvidersDao.query().get();
    return rows.where((item) => item.id == id).firstOrNull;
  }

  Future<ClashProvider> _compile(
    ClashProvider provider, {
    bool download = false,
  }) async {
    // Made here, or a Core running as root would create it as its own.
    await File(await provider.path).parent.create(recursive: true);
    final info = await _core.compileRuleSet(
      provider.fileName,
      url: download ? provider.url : '',
    );
    final next = provider.withInfo(info);
    if (!next.isCompiled) {
      await File(await next.compiledPath).safeDelete();
    }
    return next;
  }

  Future<ClashProvider> _compileContent(
    ClashProvider provider,
    List<int> content,
  ) async {
    final stagedName = '${provider.fileName}.new';
    final staged = await appPath.getProviderCachePath(stagedName);
    try {
      await File(staged).safeWriteAsBytes(content);
      final next = provider.withInfo(await _core.compileRuleSet(stagedName));
      if (next.isCompiled) {
        await File('$staged.mrs').rename(await next.compiledPath);
      } else {
        await File(await next.compiledPath).safeDelete();
      }
      await File(staged).rename(await next.path);
      return next;
    } finally {
      await File(staged).safeDelete();
      await File('$staged.mrs').safeDelete();
    }
  }

  /// A subscription's set can share the name, so match by path.
  Future<ClashProvider?> remoteProviderOf(ExternalProvider external) async {
    final path = external.path;
    if (external.type != 'Rule' ||
        external.vehicleType != 'File' ||
        path == null) {
      return null;
    }
    for (final provider in await database.clashProvidersDao.query().get()) {
      if (provider.isRemote && await provider.corePath == path) {
        return provider;
      }
    }
    return null;
  }

  /// Returns false when the set changed shape, which only a reapply loads.
  Future<bool> syncRemote(ClashProvider provider) async {
    final stagedName = '${provider.fileName}.$uniqueId.sync';
    final staged = File(await appPath.getProviderCachePath(stagedName));
    final stagedCompiled = File('${staged.path}.mrs');
    try {
      await staged.parent.create(recursive: true);
      final info = await _core.compileRuleSet(stagedName, url: provider.url);
      final next = provider.withInfo(info);
      if (!staged.existsSync() ||
          (next.isCompiled && !stagedCompiled.existsSync())) {
        throw FileSystemException(
          'Compiled rule set is incomplete',
          staged.path,
        );
      }
      final destination = await provider.path;
      final compiledDestination = await provider.compiledPath;
      String? reapplyLabel;
      _RuleSetPublication? publication;
      final bool unchanged;
      try {
        unchanged = await database.transaction(() async {
          final latest = await database.clashProviders
              .readable(
                (row) => row.toClashProvider(),
                where: (row) => row.id.equals(provider.id),
              )
              .getSingleOrNull();
          if (latest == null ||
              latest.url != provider.url ||
              latest.behavior != provider.behavior ||
              latest.format != provider.format) {
            return true;
          }
          publication = await _RuleSetPublication.prepare([
            (staged: staged, target: File(destination)),
            (
              staged: next.isCompiled ? stagedCompiled : null,
              target: File(compiledDestination),
            ),
          ]);
          await publication!.publish(syncPublishHook);
          if (next.behavior == latest.behavior &&
              next.format == latest.format) {
            return true;
          }
          await (database.update(
            database.clashProviders,
          )..where((row) => row.id.equals(provider.id))).write(
            ClashProvidersCompanion(
              behavior: Value(next.behavior),
              format: Value(next.format),
            ),
          );
          await syncPublishHook?.call(2);
          reapplyLabel = latest.label;
          return false;
        });
      } catch (_) {
        await publication?.rollback();
        rethrow;
      }
      await publication?.discardBackups();
      if (reapplyLabel case final label?) {
        unawaited(applyIfReferenced(ProviderKind.rule, {label}, force: true));
      }
      return unchanged;
    } finally {
      await staged.safeDelete();
      await stagedCompiled.safeDelete();
    }
  }

  /// Backups leave remote sets out and older sets have no mrs yet.
  Future<ClashProvider> prepare(ClashProvider provider) async {
    if (await File(await provider.corePath).exists()) {
      return provider;
    }
    try {
      final next = await _compile(
        provider,
        download:
            provider.isRemote && !await File(await provider.path).exists(),
      );
      if (next != provider) {
        await database.clashProviders.put(next.toCompanion());
      }
      return next;
    } catch (e) {
      commonPrint.log(
        'prepare rule set ${provider.label}: $e',
        logLevel: LogLevel.warning,
      );
      return provider;
    }
  }

  void delProvider(ClashProvider provider) {
    ref.read(clashProvidersProvider.notifier).del(provider.id);
    unawaited(_clearCache(provider));
  }

  Future<List<Profile>> profilesUsing(ClashProvider provider) {
    return profilesReferencing(ProviderKind.rule, provider.label);
  }

  Future<List<Profile>> profilesReferencing(
    ProviderKind kind,
    String name,
  ) async {
    final ids = switch (kind) {
      ProviderKind.proxy => await database.proxyGroupsDao.profileIdsUsing(name),
      ProviderKind.rule => await database.rulesDao.profileIdsUsingRuleProvider(
        name,
      ),
    };
    return [
      for (final profile in ref.read(profilesProvider))
        if (ids.contains(profile.id) ||
            kind == ProviderKind.rule &&
                profile.type == ProfileType.custom &&
                profile.overrides.ruleSets.contains(name))
          profile,
    ];
  }

  Future<void> _clearCache(ClashProvider provider) async {
    await File(await provider.path).safeDelete();
    await File(await provider.compiledPath).safeDelete();
  }

  Future<bool> _isReferenced(
    int profileId,
    ProviderKind kind,
    Set<String> labels,
  ) async {
    return switch (kind) {
      ProviderKind.proxy =>
        (await database.proxyGroupsDao.query(profileId).get()).any(
          (group) => group.use?.any(labels.contains) ?? false,
        ),
      ProviderKind.rule =>
        (ref
                    .read(profilesProvider)
                    .getProfile(profileId)
                    ?.overrides
                    .ruleSets
                    .any(labels.contains) ??
                false) ||
            (await database.rulesDao.queryProfileRules(profileId).get()).any(
              (rule) => rule.ruleSets.any(labels.contains),
            ),
    };
  }

  /// [force] reapplies a provider whose content changed under the same path,
  /// which leaves the generated config unchanged.
  Future<void> applyIfReferenced(
    ProviderKind kind,
    Set<String> labels, {
    bool force = false,
  }) => _applyIf(
    (profileId) => _isReferenced(profileId, kind, labels),
    force: force,
  );

  Future<void> applyIfProxiesNamed(Set<String> names) => _applyIf(
    (profileId) async => (await database.proxyGroupsDao.query(profileId).get())
        .any((group) => group.proxies?.any(names.contains) ?? false),
  );

  Future<void> _applyIf(
    Future<bool> Function(int profileId) isReferenced, {
    bool force = false,
  }) async {
    final profile = ref.read(currentProfileProvider);
    if (profile == null ||
        profile.type != ProfileType.custom ||
        !await isReferenced(profile.id)) {
      return;
    }
    ref
        .read(setupActionProvider.notifier)
        .applyProfileDebounce(silence: true, force: force);
  }
}

class _RuleSetPublication {
  _RuleSetPublication(this.entries, this.backupDirectory);

  final List<({File? staged, File target, File? backup})> entries;
  final Directory backupDirectory;
  int _published = 0;

  static Future<_RuleSetPublication> prepare(
    List<({File? staged, File target})> files,
  ) async {
    final entries = <({File? staged, File target, File? backup})>[];
    final backupDirectory = await files.first.target.parent.createTemp(
      '.rules-backup-',
    );
    try {
      for (final file in files) {
        File? backup;
        if (await file.target.exists()) {
          backup = File(join(backupDirectory.path, basename(file.target.path)));
        }
        entries.add((staged: file.staged, target: file.target, backup: backup));
        if (backup != null) {
          await file.target.copy(backup.path);
        }
      }
      return _RuleSetPublication(entries, backupDirectory);
    } catch (_) {
      for (final entry in entries) {
        await entry.backup?.safeDelete();
      }
      await backupDirectory.safeDelete();
      rethrow;
    }
  }

  Future<void> publish(Future<void> Function(int)? hook) async {
    for (final entry in entries) {
      _published++;
      if (entry.staged case final staged?) {
        await _renameRuleSetFile(staged, entry.target);
      } else if (await entry.target.exists()) {
        await entry.target.delete();
      }
      await hook?.call(_published - 1);
    }
  }

  Future<void> rollback() async {
    for (final entry in entries.take(_published).toList().reversed) {
      if (entry.backup case final backup?) {
        await _renameRuleSetFile(backup, entry.target);
      } else if (await entry.target.exists()) {
        await entry.target.delete();
      }
    }
    await discardBackups();
  }

  Future<void> discardBackups() async {
    for (final entry in entries) {
      await entry.backup?.safeDelete();
    }
    await backupDirectory.safeDelete();
  }
}

Future<void> _renameRuleSetFile(File source, File target) async {
  try {
    await source.rename(target.path);
  } on FileSystemException catch (error) {
    if (!Platform.isWindows ||
        !{80, 183}.contains(error.osError?.errorCode) ||
        !await target.exists()) {
      rethrow;
    }
    final displaced = File('${target.path}.$uniqueId.displaced');
    await target.rename(displaced.path);
    try {
      await source.rename(target.path);
    } catch (_) {
      await displaced.rename(target.path);
      rethrow;
    }
    await displaced.safeDelete();
  }
}
