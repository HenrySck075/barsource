import 'dart:io';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    // 1. Determine the library filename based on the target OS
    final targetOS = input.config.code.targetOS;
    final libName = targetOS == OS.windows ? 'tennoji.dll' : 
                    targetOS == OS.macOS   ? 'libtennoji.dylib' : 
                                             'libtennoji.so';

    // 2. Locate your prebuilt file
    final libFile = input.packageRoot.resolve('blob/$libName');

    // 3. Register it as an asset
    output.assets.code.add(
      CodeAsset(
        // This ID is what @Native() looks for (defaulting to package name)
        package: input.packageName, 
        name: "rina",
        linkMode: DynamicLoadingBundled(), 
        file: libFile,
      ),
    );
  });
}
