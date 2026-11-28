part of '../action.dart';

typedef BackupDelivery = Future<bool> Function(String archivePath);

/// Returns the archive to restore, or null when the user backed out. A source
/// that downloads writes to [downloadPath], which is removed afterwards.
typedef BackupFetch = Future<String?> Function(String downloadPath);

@Riverpod(keepAlive: true)
class BackupAction extends _$BackupAction {
  @override
  void build() {}

  @visibleForTesting
  Future<void> Function()? afterSnapshotForTesting;
  @visibleForTesting
  Future<void> Function()? afterStagingForTesting;

  Future<bool> backup(BackupDelivery deliver) {
    return _withWorkDir((workDir) async {
      return deliver(await _createArchive(workDir));
    });
  }

  Future<bool> restore(RestoreOption option, BackupFetch fetch) {
    return _withWorkDir((workDir) async {
      final archivePath = await fetch(join(workDir, 'download.zip'));
      if (archivePath == null) {
        return false;
      }
      final stagingDirPath = join(workDir, 'staging');
      final MigrationData data;
      try {
        data = await restoreTask((
          archivePath: archivePath,
          stagingDirPath: stagingDirPath,
        ));
      } on BackupException catch (e) {
        throw MessageException(switch (e.failure) {
          BackupFailure.invalid => currentAppLocalizations.invalidBackupFile,
          BackupFailure.newerVersion =>
            currentAppLocalizations.backupFromNewerVersion,
        });
      }
      await applyRestore(data, option, stagingDirPath: stagingDirPath);
      return true;
    });
  }

  Future<bool> _withWorkDir(Future<bool> Function(String workDir) run) async {
    final workDir = Directory(join(await appPath.tempPath, 'backup$uniqueId'));
    await workDir.create(recursive: true);
    try {
      return await run(workDir.path);
    } finally {
      await workDir.safeDelete(recursive: true);
      await _discardLegacyStaging();
    }
  }

  /// Earlier versions staged restores in the home directory and never removed
  /// the downloaded archive.
  Future<void> _discardLegacyStaging() async {
    final homeDirPath = await appPath.homeDirPath;
    await File(join(homeDirPath, 'backup.zip')).safeDelete();
    await Directory(join(homeDirPath, 'restore')).safeDelete(recursive: true);
  }

  Future<String> _createArchive(String workDir) async {
    final homeDirPath = await appPath.homeDirPath;
    final (profiles, scripts, providers) = await (
      database.profilesDao.query().get(),
      database.scriptsDao.query().get(),
      database.clashProvidersDao.query().get(),
    ).wait;
    final original = backupManifest(profiles, scripts, providers);
    final initialStats = <String, FileStat>{};
    for (final entry in original.entries) {
      final source = File(BackupEntries.resolve(homeDirPath, entry));
      final stat = await source.stat();
      if (stat.type != FileSystemEntityType.file &&
          original.requiredEntries.contains(entry)) {
        throw FileSystemException(
          'Required backup file is missing',
          source.path,
        );
      }
      initialStats[entry] = stat;
    }
    final databaseSnapshotPath = join(workDir, backupDatabaseName);
    await database.customStatement('VACUUM INTO ?', [databaseSnapshotPath]);
    final snapshot = await backupSnapshotEntries(databaseSnapshotPath);
    await afterSnapshotForTesting?.call();
    if (snapshot.entries.length != original.entries.length ||
        !original.entries.containsAll(snapshot.entries) ||
        snapshot.requiredEntries.length != original.requiredEntries.length ||
        !original.requiredEntries.containsAll(snapshot.requiredEntries)) {
      throw const FileSystemException(
        'Backup references changed during snapshot',
      );
    }
    final entries = snapshot.entries
        .where(
          (entry) => initialStats[entry]!.type == FileSystemEntityType.file,
        )
        .toList();
    final stagedPath = join(workDir, 'files');
    for (final entry in entries) {
      final source = File(BackupEntries.resolve(homeDirPath, entry));
      final target = File(BackupEntries.resolve(stagedPath, entry));
      await target.parent.create(recursive: true);
      await source.copy(target.path);
    }
    await afterStagingForTesting?.call();
    for (final entry in entries) {
      final source = File(BackupEntries.resolve(homeDirPath, entry));
      final before = initialStats[entry]!;
      final after = await source.stat();
      if (after.type != FileSystemEntityType.file ||
          before.size != after.size ||
          before.modified != after.modified ||
          before.changed != after.changed) {
        throw FileSystemException(
          'Backup file changed while copying',
          source.path,
        );
      }
    }
    final configMap = ref.read(configProvider).toJson();
    configMap['version'] = await preferences.getVersion();
    final archivePath = join(workDir, 'backup.zip');
    await backupTask((
      archivePath: archivePath,
      configMap: configMap,
      databaseSnapshotPath: databaseSnapshotPath,
      homeDirPath: stagedPath,
      entries: entries,
    ));
    return archivePath;
  }

  @visibleForTesting
  Future<void> applyRestore(
    MigrationData data,
    RestoreOption option, {
    String? stagingDirPath,
  }) async {
    final configMap = data.configMap;
    final config = option == RestoreOption.onlyProfiles || configMap == null
        ? null
        : Config.fromJson(configMap);
    final isOverride =
        ref.read(appSettingProvider).restoreStrategy ==
        RestoreStrategy.override;
    final previousProviders = await database.clashProvidersDao.query().get();
    final putBack = stagingDirPath == null
        ? null
        : await _copyStagedFiles(data, stagingDirPath);
    try {
      await database.restore(
        data.profiles,
        data.scripts,
        data.rules,
        data.disabledRules,
        data.proxyGroups,
        clashProviders: data.clashProviders,
        customProxies: data.customProxies,
        proxyDialers: data.proxyDialers,
        isOverride: isOverride,
      );
    } catch (_) {
      await putBack?.call();
      rethrow;
    }
    await _clearReplacedProviderCaches(previousProviders);
    await _clearOutdatedCompiledRuleSets(data.clashProviders);
    if (config == null) {
      return;
    }
    // A desktop backup carries no package lists; the apps picked here stay.
    final accessControlProps = config.vpnProps.accessControlProps.hasPackages
        ? config.vpnProps.accessControlProps
        : ref.read(vpnSettingProvider).accessControlProps;
    writeConfig(
      ref,
      config.copyWith(
        davProps: config.davProps ?? ref.read(davSettingProvider),
        vpnProps: config.vpnProps.copyWith(
          accessControlProps: accessControlProps,
        ),
      ),
    );
  }

  /// The files go in before the rows that name them, so the returned callback
  /// is how a restore whose rows fail takes them back out.
  Future<Future<void> Function()> _copyStagedFiles(
    MigrationData data,
    String stagingDirPath,
  ) async {
    final homeDirPath = await appPath.homeDirPath;
    final replacedDirPath = join(stagingDirPath, 'replaced');
    final copied = <String, bool>{};
    Future<void> putBack() async {
      for (final MapEntry(key: entry, value: replaced) in copied.entries) {
        final target = BackupEntries.resolve(homeDirPath, entry);
        if (replaced) {
          await File(
            BackupEntries.resolve(replacedDirPath, entry),
          ).safeCopy(target);
        } else {
          await File(target).safeDelete();
        }
      }
    }

    try {
      for (final entry in BackupEntries.ofData(data)) {
        final staged = File(BackupEntries.resolve(stagingDirPath, entry));
        if (!await staged.exists()) {
          continue;
        }
        final target = File(BackupEntries.resolve(homeDirPath, entry));
        final replaced = await target.exists();
        if (replaced) {
          await target.safeCopy(BackupEntries.resolve(replacedDirPath, entry));
        }
        copied[entry] = replaced;
        await staged.safeCopy(target.path);
      }
    } catch (_) {
      await putBack();
      rethrow;
    }
    return putBack;
  }

  Future<void> _clearReplacedProviderCaches(
    List<ClashProvider> previousProviders,
  ) async {
    final kept = (await database.clashProvidersDao.fileNames().get()).toSet();
    for (final provider in previousProviders) {
      if (kept.contains(provider.fileName)) {
        continue;
      }
      await File(await provider.path).safeDelete();
      await File(await provider.compiledPath).safeDelete();
    }
  }

  /// A restored source outdates the mrs compiled from the one it replaced.
  Future<void> _clearOutdatedCompiledRuleSets(
    List<ClashProvider> restored,
  ) async {
    for (final provider in restored) {
      if (!provider.isRemote) {
        await File(await provider.compiledPath).safeDelete();
      }
    }
  }
}
