# UrhoX 编辑器文档

给在 UrhoXEditor 旁工作的人和 Coding Agent。覆盖两件事：

1. **写编辑器脚本**：工程内 `Editor/**/*.lua`，扩展菜单 / 窗口 / 批处理
2. **操作正在运行的编辑器**：按需用本机 HTTP/Python 调 MCP（不把 60+ 工具 schema 常驻进 Agent）

这不是玩法 `engine-docs`，也不是 Maker Web 插件。

编辑器脚本跑在独立 Lua state（`GetLuaEnvironment() == 4`），不进 Runtime / 发布包。

---

## 首先阅读

写脚本：

1. [架构](architecture.md)
2. [脚本指南](scripting-guide.md)
3. [API 索引](api/index.md)

按任务再读：

- 菜单 / 窗口 / 日志：[Editor API](api/editor.md)
- 编辑字段、图片和 UI Scope：[Editor UI](api/editor-gui.md)
- Project / Package 资产：[AssetDatabase](api/asset.md)
- 资产缩略图与交互预览：[Asset Preview](api/asset-preview.md)
- 动画资源裁剪 / 合并：[Animation](api/animation.md)
- GPU 材质 UV 烘焙：[MaterialBaking](api/material-baking.md)
- Inspector / 右键：[Custom Inspector](api/inspector.md)
- 当前选择：[Selection](api/selection.md)
- 改场景：[Undo](api/undo.md)
- 视口拖点 / 辅助线：[Handles](api/handles.md)
- 示例脚本：[examples/](examples/)（复制到工程 `Editor/`，含动画裁剪 `AnimationClipTool.lua`）
- 示例说明：[批量重命名](recipes/batch-rename.md)、[窗口](recipes/editor-window.md)、[资产预览](recipes/asset-preview.md)、[现有类型](recipes/existing-types.md)
- 陷阱：[gotchas](gotchas/index.md)

操作正在运行的编辑器（不要把 MCP 常驻进 Agent）：

- [按需 CLI](cli.md)
- [换皮网格拟合到已有骨架](cli.md#换皮网格拟合到已有骨架)：通过 `bind_mesh_to_skeleton` 检查、保存并取得输出资源引用。

玩法 Lua API 仍看 [engine-docs](../engine-docs/index.md)。不要整包加载玩法文档。

## 文档结构

```text
editor-docs/
├─ index.md
├─ architecture.md
├─ scripting-guide.md
├─ api/
│  ├─ index.md
│  ├─ editor.md
│  ├─ editor-gui.md
│  ├─ selection.md
│  ├─ undo.md
│  ├─ handles.md
│  ├─ asset.md
│  ├─ asset-preview.md
│  ├─ material-baking.md
│  └─ inspector.md
├─ recipes/
│  ├─ batch-rename.md
│  ├─ editor-window.md
│  ├─ asset-preview.md
│  └─ existing-types.md
├─ examples/          # 随 kit 分发的 Editor Script，复制到工程 Editor/
├─ cli.md
└─ gotchas/
   └─ index.md
```
