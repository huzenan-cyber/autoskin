# autoskin

Character rigging and skinning project for Blender and UrhoX.

The UrhoX project is in `autoskin/`. It includes character assets, rigging
workflow documentation, editor integration tools, and engine reference files.

## Contents

- `autoskin/docs/rigging/`: rigging, skinning, animation, and attachment workflow.
- `autoskin/source-assets/`: reference skeleton source files.
- `autoskin/artifacts/`: character models, textures, previews, and reports.
- `autoskin/scripts/`: Lua runtime entry point.
- `autoskin/.project/`: UrhoX project and resource configuration.
- `autoskin/tools/`: editor integration and development utilities.

## Open the project

Open the `autoskin/` directory in UrhoXEditor and restore the packages configured
in `.project/`. Use Blender to inspect or edit the included `.blend` and `.fbx`
assets. Read `autoskin/docs/rigging/` for the character preparation workflow.

Downloaded engine packages, local tool installations, build output, and SVN
metadata are excluded from Git. The engine and external packages are required
separately; this repository does not contain a standalone engine executable.
