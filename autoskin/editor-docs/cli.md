# 按需调用正在运行的编辑器

不要把 UrhoXEditor MCP 配进日常写玩法的 Agent。60+ 工具 schema 每轮都会进上下文。

编辑器必须已经打开并加载了工程。本 CLI 只做本机 HTTP，不启动编辑器。

## 命令

在有 `tools/editor_mcp.py` 的工作区（ai-dev-kit 或引擎仓 `python tools/dev/editor_mcp.py`）：

```text
python tools/editor_mcp.py status
python tools/editor_mcp.py tools
python tools/editor_mcp.py tools --name editor_script
python tools/editor_mcp.py tools --schema get_editor_state
python tools/editor_mcp.py call get_editor_state
python tools/editor_mcp.py call rename_node '{"...": "..."}'
python tools/editor_mcp.py wait op_01J...
```

stdout 永远是 JSON。失败时 exit 1；多实例未指定 `--instance` 时 exit 2。

| 命令 | 作用 |
|---|---|
| `status` | `/health` + `get_editor_state`（含 `editor_scripts`） |
| `tools` | **只**打印 name + description，不要默认要 schema |
| `tools --schema NAME` | 需要参数时再拉这一个工具的 inputSchema |
| `call NAME [JSON]` | `tools/call`；JSON 必须是对象；`-` 表示从 stdin 读 |
| `wait OP_ID` | 轮询 `get_operation` 直到结束 |

长任务：`call` 若返回里带 `operation_id`（`open_scene` / import / build 等）会自动接着 `wait`。不要当同步 `opened=true` 用。  
成功结果在 `data.result`（`open_scene` 的 `scene_generation` / `path`）。只要启动、自己轮询时加 `--no-wait`。

给节点挂脚本：先 `find_nodes`（`name` 或 `path`），再用返回的 `ref` 调 `attach_lua_script`。不要把节点名直接传给挂脚本。

找组件（例如所有点光）：`find_components`，`type` + 可选 `attributes`，再用 component ref 写属性。

## 换皮网格拟合到已有骨架

`bind_mesh_to_skeleton` 对应编辑器 **Bind Mesh to Skeleton...**，共用拟合与保存实现。
通过本 CLI 调用正在运行的编辑器；独立的 `UrhoXCLI bind-mesh` 则直接处理磁盘文件。

先按需查看参数：

```text
python tools/editor_mcp.py tools --schema bind_mesh_to_skeleton
```

PowerShell 示例（假设资源位于项目的 `assets/Models/`）：

```powershell
@'
{"source":{"path":"Models/skin.mdl"},"target":{"path":"Models/character.mdl"},"check_only":true}
'@ | python tools/editor_mcp.py call bind_mesh_to_skeleton -

@'
{"source":{"path":"Models/skin.mdl"},"target":{"path":"Models/character.mdl"},"output_path":"assets/Models/skin_Bound.mdl"}
'@ | python tools/editor_mcp.py call bind_mesh_to_skeleton -
```

- `source` / `target` 使用已注册的 ResourceRef：`{"path":"..."}` 或 `{"uuid":"..."}`。路径相对于资源目录，UUID 使用 `get_resource_uuid` 返回的值。
- `output_path` 相对于**项目根目录**，必须位于已挂载的可写资源目录。项目直接以根目录作为资源目录时写 `Models/skin_Bound.mdl`；以 `assets/` 为资源目录时写 `assets/Models/skin_Bound.mdl`。
- `check_only: true` 执行完整拟合检查，不保存文件，允许省略 `output_path`。保存时必须显式给出输出路径。
- `fold_auxiliary_bones` 默认 `true`，将符合条件的 `_S` 辅助骨权重折叠到对应主骨。
- `overwrite` 默认 `false`；设为 `true` 才允许覆盖输出模型及其侧文件。目标骨架模型始终禁止覆盖，只读 Package 内禁止输出。
- 本工具同步完成，结果直接位于 `data`，不返回 `operation_id`。`data.report` 包含骨名映射及顶点/LOD 统计；保存后 `data.saved` 为 `true`，`data.resource` 是输出的路径/UUID 引用。失败时退出码为 `1`，拟合诊断在 `error.details.report`（若已执行到拟合阶段）。
- 保存会刷新编辑器资源与缩略图；不会自动替换场景组件，也不会生成动画。继续使用换皮模型的材质和目标角色的动画/FSM/挂点配置。Play 模式中不能调用此工具。

This CLI forwards `bind_mesh_to_skeleton` over the editor MCP protocol. Inputs use registered resource
paths/UUIDs; the output is project-relative. Check first, then save and use `data.resource` to assign the model.

## 多实例

本机开了多个编辑器时必须：

```text
python tools/editor_mcp.py --instance ed_... status
```

`status` 失败并列出 id 时，不要猜「最近一个」。

也可用环境变量 `EDITOR_MCP_ENDPOINT` / `EDITOR_MCP_TOKEN`，或 `--endpoint` / `--token`。

## 编辑器中途重启

**不要问用户「是不是重启了」。** 每条命令都会重新发现实例。

返回 JSON 带 `_cli`：

| 字段 | 含义 |
|---|---|
| `editor_instance_id` | 当前编辑器 |
| `editor_restarted` | 相对上次 CLI 调用，实例 id 变了 |
| `healed_scene_refs` | 已把参数里的 `scene_generation` / `expected_scene_revision` 改成当前值 |
| `rediscovered` | 连接失败后重新发现并重试成功 |

`editor_restarted` 为 true 时：节点 id 可能对不上，再 `call list_scene_tree` / `get_selection` 后继续，不要让用户确认。

## Agent 用法

1. 先 `status`。没有 live editor 就停，让人打开 UrhoXEditor。
2. 需要某个写工具时再 `tools --schema <name>`，不要把全部 schema 读进对话。
3. 写操作可带 `scene_generation` / `expected_scene_revision`；过期时 CLI 会改成当前值。
4. 验收编辑器脚本：`tools --name editor_script` → `call editor_script....` → `call undo`。

不要在玩法任务里调用本 CLI。
