import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'ios_setup_handoff.dart';
import 'zolnit_bundle.dart';

import 'app.dart';
import 'config.dart';
import 'core.dart';
import 'database.dart';

part 'generated/state.g.dart';
part 'state/proxies.dart';
part 'state/navigation.dart';
part 'state/system.dart';
part 'state/theme.dart';
part 'state/profile.dart';
part 'state/custom.dart';
part 'state/custom_import.dart';

final desktopListenersReadyProvider =
    NotifierProvider<DesktopListenersReady, bool>(DesktopListenersReady.new);

class DesktopListenersReady extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(coreStatusProvider, (_, _) => state = false);
    return false;
  }

  void setReady(bool ready) => state = ready;
}
