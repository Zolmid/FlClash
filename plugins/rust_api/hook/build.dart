import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';

import 'cargo_environment.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.userDefines['build_assets'] == false) {
      stdout.writeln('Skipping the Rust build: user-define build_assets=false');
      return;
    }
    await FlutterRustBridgeNativeAssetsBuilder(
      cratePath: 'rust',
      extraCargoEnvironmentVariables: input.config.buildCodeAssets
          ? cargoEnvironment(input.config.code)
          : const {},
    ).run(input: input, output: output);
  });
}
