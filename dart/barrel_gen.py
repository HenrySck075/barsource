# cwd is the folder where this script lives
import os

workdir = os.path.dirname(os.path.abspath(__file__))

# nuke off all existing files in the first level of the lib dir first
# we can assume they're barrel files
libdir = os.path.join(workdir, 'lib')
for file in os.listdir(libdir):
    if os.path.isfile(os.path.join(libdir, file)):
        os.remove(os.path.join(libdir, file))

everything_barrel = open(os.path.join(libdir, "tennoji.dart"), "w")
everything_barrel.write("// AUTO-GENERATED BARREL FILE. DO NOT EDIT BY HAND\n")
# scan lib/src/ for folders
srcdir = os.path.join(workdir, 'lib', 'src')
# for each folders:
for folder in os.listdir(srcdir):
    if os.path.isdir(os.path.join(srcdir, folder)):
        # create a barrel file in the lib dir named after the folder
        barrel_file = os.path.join(libdir, f'{folder}.dart')
        with open(barrel_file, 'w') as f:
            if folder != 'dart_ui':
                everything_barrel.write(f"export '{folder}.dart';\n")
            f.write("// AUTO-GENERATED BARREL FILE. DO NOT EDIT BY HAND\n")
            # if its dart_ui, we will just reexport a file with the same name in that folder out, since other files was defined as "part" of dart_ui.dart
            if folder == 'dart_ui':
                f.write(f"export 'src/{folder}/{folder}.dart';\n")
                continue
            # scan the folder for .dart files
            for file in os.listdir(os.path.join(srcdir, folder)):
                if file.endswith('.dart'):
                    # add an export statement for each .dart file
                    f.write(f"export 'src/{folder}/{file}';\n")

