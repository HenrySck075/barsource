import 'dart:io';
import 'package:native_assets_cli/code_assets.dart';
import 'package:native_assets_cli/native_assets_cli.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final targetOS = input.config.code.targetOS;
    // 1. Determine the library filename based on the target OS
    final libName = targetOS == OS.windows ? 'tennoji.dll' : 
                    targetOS == OS.macOS   ? 'libtennoji.dylib' : 
                                             'libtennoji.so';

    // 2. Locate your prebuilt file
    final libFile = File('blob/$libName');

    // 3. Register it as an asset
    output.assets.code.add(
      CodeAsset(
        // This ID is what @Native() looks for (defaulting to package name)
        package: 'tennoji', 
        name: "rina",
        linkMode: DynamicLoadingBundled(), 
        file: libFile.uri,
      ),
    );
  });
}