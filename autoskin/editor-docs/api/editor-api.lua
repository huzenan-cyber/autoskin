---@meta

---Canonical UrhoX Editor Script declarations.
---These APIs exist only in the Editor Script VM.

---@class GUILayoutOptions
---@field width? number
---@field height? number
---@field expandWidth? boolean
---@field expandHeight? boolean
---@field tooltip? string

---@class EditorWindowOptions
---@field width? number Initial width in logical pixels.
---@field height? number Initial height in logical pixels.

---@class GUILayoutImageOptions: GUILayoutOptions
---@field scaleMode? 'Stretch'|'ScaleToFit'|'ScaleAndCrop'
---@field tint? Color
---@field uv0? Vector2
---@field uv1? Vector2
---@field selected? boolean

---@class AssetCreateOptions
---@field overwrite? boolean

---@class ScaleHandleOptions
---@field allowNegative? boolean
---@field uniform? boolean

---@class EditorMenuOptions
---@field description? string
---@field validate? fun(): boolean
---@field shortcut? string
---@field mcp? boolean
---@field id? string

---@class EditorContextMenuOptions
---@field description? string
---@field validate? fun(): boolean
---@field mcp? boolean
---@field id? string

---@class CustomEditorContext
---@field target Component
---@field targets Component[]

---@class CustomEditorDescriptor
---@field OnInspectorGUI? fun(self: CustomEditorContext)
---@field OnSceneGUI? fun(self: CustomEditorContext)

---@class EditorWindow
---@field OnGUI? fun(self: EditorWindow)
---@field OnEnable? fun(self: EditorWindow)
---@field OnDisable? fun(self: EditorWindow)
---@field OnFocus? fun(self: EditorWindow)
---@field OnLostFocus? fun(self: EditorWindow)
local EditorWindow = {}
function EditorWindow:Show() end
function EditorWindow:ShowUtility() end
---@return boolean focused
function EditorWindow:Focus() end
function EditorWindow:Close() end
---@return boolean
function EditorWindow:IsOpen() end
---@return boolean
function EditorWindow:HasFocus() end

---@class SceneRaycastHit
---@field node Node
---@field position Vector3
---@field normal Vector3

---@class SceneGuiEvent
local SceneGuiEvent = {}
---@param listener fun(sceneView: EditorSceneView)
function SceneGuiEvent:AddListener(listener) end
---@param listener fun(sceneView: EditorSceneView)
---@return boolean removed
function SceneGuiEvent:RemoveListener(listener) end

---@class EditorGUILayout
EditorGUILayout = {}

---@param label string
---@param value? string
function EditorGUILayout.LabelField(label, value) end
---@param label string
---@param value? string
function EditorGUILayout.SelectableLabel(label, value) end
---@param label string
---@param value string
---@return string
function EditorGUILayout.TextField(label, value) end
---@param label string
---@param value string
---@return string
function EditorGUILayout.TextArea(label, value) end
---@param label string
---@param value string
---@return string
function EditorGUILayout.PasswordField(label, value) end
---@param label string
---@param value string
---@return string
function EditorGUILayout.DelayedTextField(label, value) end
---@param label string
---@param value integer
---@return integer
function EditorGUILayout.DelayedIntField(label, value) end
---@param label string
---@param value number
---@return number
function EditorGUILayout.DelayedFloatField(label, value) end
---@param label string
---@param value integer
---@return integer
function EditorGUILayout.IntField(label, value) end
---@param label string
---@param value number
---@return number
function EditorGUILayout.FloatField(label, value) end
---@param label string
---@param value number
---@param min number
---@param max number
---@return number
function EditorGUILayout.Slider(label, value, min, max) end
---@param label string
---@param value integer
---@param min integer
---@param max integer
---@return integer
function EditorGUILayout.IntSlider(label, value, min, max) end
---@param label string
---@param minValue number
---@param maxValue number
---@param minLimit number
---@param maxLimit number
---@return number minValue
---@return number maxValue
function EditorGUILayout.MinMaxSlider(label, minValue, maxValue, minLimit, maxLimit) end
---@param label string
---@param value boolean
---@return boolean
function EditorGUILayout.Toggle(label, value) end
---@param label string
---@param value boolean
---@return boolean
function EditorGUILayout.ToggleLeft(label, value) end
---@param label string
---@param selected integer One-based index.
---@param values string[]
---@return integer selected
function EditorGUILayout.Popup(label, selected, values) end
---@param label string
---@param selected integer One-based index.
---@param values string[]
---@return integer selected
function EditorGUILayout.EnumPopup(label, selected, values) end
---@param label string
---@param mask integer
---@param values string[]
---@return integer mask
function EditorGUILayout.MaskField(label, mask, values) end
---@param label string
---@param value Vector2
---@return Vector2
function EditorGUILayout.Vector2Field(label, value) end
---@param label string
---@param value Vector3
---@return Vector3
function EditorGUILayout.Vector3Field(label, value) end
---@param label string
---@param value Vector4
---@return Vector4
function EditorGUILayout.Vector4Field(label, value) end
---@param label string
---@param value Rect
---@return Rect
function EditorGUILayout.RectField(label, value) end
---@param label string
---@param value BoundingBox
---@return BoundingBox
function EditorGUILayout.BoundsField(label, value) end
---@param label string
---@param value Color
---@return Color
function EditorGUILayout.ColorField(label, value) end
---@param label string
---@param value string|Node|nil
---@param typeName string Resource type name, or `Node`.
---@return string|Node|nil
function EditorGUILayout.ObjectField(label, value, typeName) end
---@param target Node|Component
---@param attributeName string
---@return boolean changed
function EditorGUILayout.PropertyField(target, attributeName) end
---@param label string
---@param open boolean
---@return boolean open
function EditorGUILayout.Foldout(label, open) end
---@param message string
---@param messageType? integer Use `EditorGUI.MessageType`.
function EditorGUILayout.HelpBox(message, messageType) end
---@param pixels? number
function EditorGUILayout.Space(pixels) end

---@class GUILayout
GUILayout = {}

---@param text string
function GUILayout.Label(text) end
---@param text string
---@param options? GUILayoutOptions
---@return boolean clicked
function GUILayout.Button(text, options) end
---@param text? string
---@param options? GUILayoutOptions
function GUILayout.Box(text, options) end
---@param text string
---@param selected boolean
---@param options? GUILayoutOptions
---@return boolean clicked
function GUILayout.Selectable(text, selected, options) end
---@param textureOrPath Texture2D|string|nil
---@param options? GUILayoutImageOptions
function GUILayout.Image(textureOrPath, options) end
---@param id string Stable control id.
---@param textureOrPath Texture2D|string|nil
---@param options? GUILayoutImageOptions
---@return boolean clicked
function GUILayout.ImageButton(id, textureOrPath, options) end
---@param pixels? number
function GUILayout.Space(pixels) end
function GUILayout.FlexibleSpace() end
function GUILayout.Separator() end
function GUILayout.BeginHorizontal() end
function GUILayout.EndHorizontal() end
function GUILayout.BeginVertical() end
function GUILayout.EndVertical() end
function GUILayout.BeginGroup() end
function GUILayout.EndGroup() end
---@param id string Stable child id.
---@param options? GUILayoutOptions
function GUILayout.BeginScrollView(id, options) end
function GUILayout.EndScrollView() end
---@param selected integer One-based index.
---@param values string[]
---@return integer selected
function GUILayout.Toolbar(selected, values) end

---@class EditorGUI
---@field MessageType table<string, integer>
EditorGUI = {}

function EditorGUI.BeginChangeCheck() end
---@return boolean changed
function EditorGUI.EndChangeCheck() end
---@param disabled boolean
function EditorGUI.BeginDisabledGroup(disabled) end
function EditorGUI.EndDisabledGroup() end
---@param amount? number
function EditorGUI.PushIndent(amount) end
function EditorGUI.PopIndent() end
---@param width number
function EditorGUI.PushLabelWidth(width) end
function EditorGUI.PopLabelWidth() end
---@param mixed boolean
function EditorGUI.PushMixedValue(mixed) end
function EditorGUI.PopMixedValue() end

---@class AssetDatabase
AssetDatabase = {}

---@param typeName string
---@param path string Project-relative resource path.
---@return Resource|nil asset
---@return string|nil error
function AssetDatabase.LoadAssetAtPath(typeName, path) end
---@param path string
---@return boolean
function AssetDatabase.AssetPathExists(path) end
---@param asset Resource
---@param path string Project-relative destination in any project directory.
---@param options? AssetCreateOptions
---@return Resource|nil created
---@return string|nil error
function AssetDatabase.CreateAsset(asset, path, options) end
---@param sourcePath string Project or mounted Package resource path.
---@param destinationPath string Project-relative destination.
---@param options? AssetCreateOptions
---@return boolean ok
---@return string|nil error
function AssetDatabase.CopyAsset(sourcePath, destinationPath, options) end
---@param asset Resource
---@return boolean ok
---@return string|nil error
function AssetDatabase.SaveAssetIfDirty(asset) end
---@param path string
---@return boolean ok
---@return string|nil error
function AssetDatabase.ImportAsset(path) end
function AssetDatabase.Refresh() end

---@class AssetPreview
AssetPreview = {}
---@param asset Resource
---@return Texture2D|nil preview Returns nil while an asynchronous preview is pending or when unsupported.
function AssetPreview.GetAssetPreview(asset) end
---@param asset Resource
---@return Texture2D|nil preview Returns nil while an asynchronous preview is pending or when unsupported.
function AssetPreview.GetMiniThumbnail(asset) end
---@param typeName string
---@return Texture2D|nil icon
function AssetPreview.GetMiniTypeThumbnail(typeName) end
---@param asset Resource
---@return boolean
function AssetPreview.IsLoadingAssetPreview(asset) end
---@return boolean
function AssetPreview.IsLoadingAssetPreviews() end

---@class AssetEditor
local AssetEditor = {}
---@return boolean
function AssetEditor:HasPreviewGUI() end
---@return string
function AssetEditor:GetPreviewTitle() end
function AssetEditor:OnPreviewSettings() end
---@param options? GUILayoutOptions
function AssetEditor:OnPreviewGUI(options) end
---@param options? GUILayoutOptions
function AssetEditor:OnInteractivePreviewGUI(options) end
---@return boolean
function AssetEditor:RequiresConstantRepaint() end

---@class EditorUtility
EditorUtility = {}
---@param asset Resource
function EditorUtility.SetDirty(asset) end

---@param asset Resource
---@return Resource|nil clone
---@return string|nil error
function Object.Instantiate(asset) end

---@class EditorSelection
local EditorSelection = {}
---@return Node[]
function EditorSelection.GetNodes() end
---@return Node|nil
function EditorSelection.GetActiveNode() end
---@return Component|nil
function EditorSelection.GetComponent() end
---@param nodes Node[]
function EditorSelection.SetNodes(nodes) end
---@param node Node|nil
function EditorSelection.SetActiveNode(node) end

---@class EditorScene
local EditorScene = {}
---@return Scene|nil
function EditorScene.Get() end
---@return string
function EditorScene.GetGeneration() end
---@return integer
function EditorScene.GetRevision() end
---@param id integer
---@return Node|nil
function EditorScene.FindNode(id) end
---@param name string
---@return Node|nil
function EditorScene.FindNodeByName(name) end

---@class EditorUndo
local EditorUndo = {}
---@param label? string
function EditorUndo.Begin(label) end
---@param target Node|Component
function EditorUndo.Record(target) end
function EditorUndo.End() end
function EditorUndo.Cancel() end
---@return boolean
function EditorUndo.CanUndo() end
---@return boolean
function EditorUndo.CanRedo() end

---@class EditorDialog
local EditorDialog = {}
---@param title string
---@param message string
function EditorDialog.Info(title, message) end
---@param title string
---@param message string
---@return boolean
function EditorDialog.Confirm(title, message) end

---@class EditorSceneView
---@field duringSceneGui SceneGuiEvent
local EditorSceneView = {}
---@return Ray
function EditorSceneView.MouseRay() end
---@return boolean
function EditorSceneView.IsHovered() end
---@param ray Ray
---@param viewMask? integer
---@return SceneRaycastHit|nil
function EditorSceneView.Raycast(ray, viewMask) end
---@param node Node
---@return boolean
function EditorSceneView.Focus(node) end

---@class EditorHandles
local EditorHandles = {}
---@param start Vector3
---@param finish Vector3
---@param color? Color
function EditorHandles.DrawLine(start, finish, color) end
---@param center Vector3
---@param radius? number
---@param color? Color
function EditorHandles.DrawSphere(center, radius, color) end
---@param points Vector3[]
---@param color? Color
function EditorHandles.DrawPolyline(points, color) end
---@param id string
---@param position Vector3
---@param rotation? Quaternion
---@return Vector3 value
---@return boolean changed
function EditorHandles.PositionHandle(id, position, rotation) end
---@param id string
---@param rotation Quaternion
---@param position Vector3
---@return Quaternion value
---@return boolean changed
function EditorHandles.RotationHandle(id, rotation, position) end
---@param id string
---@param scale Vector3
---@param position Vector3
---@param rotation Quaternion
---@param options? ScaleHandleOptions
---@return Vector3 value
---@return boolean changed
function EditorHandles.ScaleHandle(id, scale, position, rotation, options) end
---@param id string
---@param position Vector3
---@param size? number
---@return boolean clicked
function EditorHandles.Button(id, position, size) end

---@class Editor
---@field Selection EditorSelection
---@field Scene EditorScene
---@field Undo EditorUndo
---@field Dialog EditorDialog
---@field SceneView EditorSceneView
---@field Handles EditorHandles
---@field MaterialBaking EditorMaterialBaking
Editor = Editor or {}

---@param path string
---@param callback fun()
---@param options? EditorMenuOptions
function Editor.MenuItem(path, callback, options) end
---@param title? string
---@param idOrOptions? string|EditorWindowOptions
---@param options? EditorWindowOptions
---@return EditorWindow
function Editor.Window(title, idOrOptions, options) end
---@param asset Resource
---@return AssetEditor
function Editor.CreateEditor(asset) end
---@param typeName string
---@param descriptor CustomEditorDescriptor
function Editor.CustomEditor(typeName, descriptor) end
---@param scope 'hierarchy'|'project'
---@param path string
---@param callback fun(items: Node[]|string[])
---@param options? EditorContextMenuOptions
function Editor.ContextMenu(scope, path, callback, options) end
---@param message any
function Editor.Log(message) end
---@param message any
function Editor.Warn(message) end
---@param message any
function Editor.Error(message) end

---@class MaterialBakeOptions
---@field resolution? integer Square image edge, 1..2048; default 256.
---@field allowFallback? boolean Default false: require the material shader's bake contract.

---@class MaterialBakeGeometry
---@field geometryIndex integer Engine LOD0 geometry index, starting at 0.
---@field layout 'Material'|'FixedPBR'
---@field colorEncoding 'sRGB'|'source'
---@field normalEncoding? string EncodeNormal in shader/model space; not a tangent-space normal map.
---@field uvRect Vector4 Image UV = (sourceUV - uvRect.xy) * uvRect.zw.
---@field albedo Image Alpha is dilated coverage, not material opacity.
---@field rme Image R=roughness, G=metallic, B=occlusion.
---@field normal? Image Absent for FixedPBR.
---@field emissive Image
---@field opacity? Image Red is undilated material opacity; absent for FixedPBR.
---@field coverage Image Alpha is original UV geometry coverage, before material discard.
---@field rawTargets Image[] Unmodified MRT readbacks, starting at Lua index 1.

---@class MaterialBakeResult
---@field version integer Editor result schema, currently 1; independent of the CLI manifest version.
---@field resolution integer
---@field format 'RGBA8'
---@field geometries MaterialBakeGeometry[] Lua index 1 corresponds to geometryIndex 0.

---@class EditorMaterialBaking
local EditorMaterialBaking = {}
---@return boolean supported Requires an initialized real renderer.
function EditorMaterialBaking.IsSupported() end
---Queue a GPU bake; at most one request executes per editor Update, before scene/UI rendering.
---The callback runs later, outside OnGUI. Reload/unload cancels queued callbacks.
---Images are retained by Lua and may outlive the callback. Save via AssetDatabase.CreateAsset.
---@param model Model
---@param materials Material[] Lua index 1 maps to geometry 0. Missing slots require allowFallback.
---@param options MaterialBakeOptions|nil
---@param onComplete fun(result: MaterialBakeResult|nil, err: string|nil)
---@return boolean accepted
---@return string|nil err Rejection does not call onComplete.
function EditorMaterialBaking.Bake(model, materials, options, onComplete) end
