# Editor Script examples

Copy any of these into a game project's `Editor/` folder (or any `**/Editor/`
directory). Reopen the project or use **Tools → Reload Editor Scripts**.

These are desktop editor tools, not gameplay. Do not treat them as the game
entry, and do not put them in the gameplay `examples/` tree.

| File | What it does |
|---|---|
| [HelloMenu.lua](HelloMenu.lua) | Tools menu item that logs |
| [BatchRename.lua](BatchRename.lua) | Prefix selected node names (undoable) |
| [BatchRenameWindow.lua](BatchRenameWindow.lua) | Same action in an `Editor.Window` |
| [UndoSmoke.lua](UndoSmoke.lua) | Create / dim Light / delete, then Ctrl+Z |
| [HandlesSmoke.lua](HandlesSmoke.lua) | Scene-view Position / Rotation / Scale handles on the selected node |
| [AssetFieldWindow.lua](AssetFieldWindow.lua) | ObjectField / Image / AssetDatabase copy / Serialize |
| [EditorGUILayoutGallery.lua](EditorGUILayoutGallery.lua) | Complete `EditorGUILayout` field gallery + `EditorGUI` scopes |
| [GUILayoutGallery.lua](GUILayoutGallery.lua) | Layout containers, toolbar, images, image buttons, and Window lifecycle |
| [UtilityWindow.lua](UtilityWindow.lua) | Unity-style `ShowUtility`, focus control, and focus lifecycle |
| [AssetDatabaseWorkflow.lua](AssetDatabaseWorkflow.lua) | Load → clone → create → dirty → save/import asset workflow |
| [AssetPreviewGallery.lua](AssetPreviewGallery.lua) | Async full previews, mini thumbnails, and type-icon fallbacks |
| [InteractiveAssetPreview.lua](InteractiveAssetPreview.lua) | `Editor.CreateEditor` material/model/texture/Prefab preview |
| [CustomCameraInspector.lua](CustomCameraInspector.lua) | Attribute-driven `PropertyField` Inspector + type-specific `OnSceneGUI` |
| [SceneViewOverlay.lua](SceneViewOverlay.lua) | Multiple Scene GUI listeners, mouse raycast, focus, and listener removal |
| [InspectorLight.lua](InspectorLight.lua) | `CustomEditor` Light Inspector + Hierarchy / project context menu |
| [AtmosphereTool.lua](AtmosphereTool.lua) | Directional light + Zone fog (existing types) |
| [TerrainHeightNudge.lua](TerrainHeightNudge.lua) | Clone heightmap, raise one column, Apply |
| [SplinePathHandles.lua](SplinePathHandles.lua) | SplinePath control-point Handles + curve in front of the camera |
| [AnimationClipTool.lua](AnimationClipTool.lua) | Inspect / sample / extract / merge `.ani` (`Editor.Animation`) |
| [MaterialBakeTool.lua](MaterialBakeTool.lua) | Bake selected model materials on the GPU, preview images, export PNGs |

## API coverage map

Use the smallest example that matches the task. The gallery files are useful as a lookup table;
the task-oriented files show recommended end-to-end workflows.

| API area | Primary examples |
|---|---|
| `EditorGUILayout` fields and `EditorGUI` scopes | [EditorGUILayoutGallery.lua](EditorGUILayoutGallery.lua) |
| `GUILayout`, Image / ImageButton, and Window lifecycle | [GUILayoutGallery.lua](GUILayoutGallery.lua) |
| `EditorWindow.ShowUtility`, Focus / HasFocus, focus lifecycle | [UtilityWindow.lua](UtilityWindow.lua) |
| Resource / Node `ObjectField` and Window state restore | [AssetFieldWindow.lua](AssetFieldWindow.lua) |
| `AssetDatabase`, `EditorUtility.SetDirty`, `Object.Instantiate` | [AssetDatabaseWorkflow.lua](AssetDatabaseWorkflow.lua) |
| `Editor.MaterialBaking`, UV mapping, image export | [MaterialBakeTool.lua](MaterialBakeTool.lua) |
| `AssetPreview` full / mini / type thumbnails | [AssetPreviewGallery.lua](AssetPreviewGallery.lua) |
| `Editor.CreateEditor`, Preview Settings, interactive preview | [InteractiveAssetPreview.lua](InteractiveAssetPreview.lua) |
| `CustomEditor.OnInspectorGUI`, `PropertyField`, multi-selection | [CustomCameraInspector.lua](CustomCameraInspector.lua) |
| `CustomEditor.OnSceneGUI` and non-interactive Handles | [CustomCameraInspector.lua](CustomCameraInspector.lua) |
| `SceneView.duringSceneGui`, MouseRay / Raycast / Focus | [SceneViewOverlay.lua](SceneViewOverlay.lua) |
| Position / Rotation / Scale handles and Undo | [HandlesSmoke.lua](HandlesSmoke.lua) |
| Polyline control points and component editing | [SplinePathHandles.lua](SplinePathHandles.lua) |
| Menu items, context menus, Selection, Scene, Dialog, and Undo | [HelloMenu.lua](HelloMenu.lua), [InspectorLight.lua](InspectorLight.lua), [UndoSmoke.lua](UndoSmoke.lua) |
