# Surface Shader 编写教程（抢先体验版）
**当前为预览版本，尚未覆盖所有平台，发布需谨慎**

## 心智模型

Surface Shader 是给 Lua 游戏脚本使用的自定义材质脚本。你写一个 `.shader` 文件描述材质颜色、贴图、粗糙度、金属度、透明度或顶点形变，再通过材质资源或 Lua 把它绑定到 `Material` 上。

你只需要关心三类文件：

| 文件 | 作用 |
|------|------|
| `assets/Shaders/BLGL/*.shader` | 写 Godot-style 的材质逻辑 |
| `assets/Materials/*.xml` | 材质资源：绑定 shader、贴图和参数（固定搭配的材质首选） |
| `scripts/*.lua` | 加载材质、挂到模型上，按需在运行时改参数 |

固定搭配的材质写成 `.xml`，Lua 只 `cache:GetResource("Material", ...)`；只有运行时才能确定的
shader 或贴图才用 `SetSurfaceShader()` / `SetSurfaceTexture()`。格式见
[材质文件配置（Material XML）](#材质文件配置material-xml)。

不要使用生成后的 shader 名、纹理槽位名或底层 Technique。Lua 层只使用 `.shader` 文件路径和 shader 源码里的 sampler 名。

SurfaceShader 与普通 Technique 是互斥的材质来源，不混用普通 Technique LOD。
`SetSurfaceShader()` 成功后替换整个 Technique 列表，只保留生成项；调用 `SetTechnique()`
切回普通材质，并清除生成项。材质参数和贴图覆盖继续保留；FillMode 的调用顺序语义见下方说明。
XML/JSON 存档只写当前来源；旧存档同时包含两种来源时，优先读取 `surfaceshader`，忽略
`technique`/`techniques`。SurfaceShader 加载失败会返回失败，不改用存档中的普通 Technique。

---

## UrhoX 引擎扩展

引擎扩展独立存放于 `surface-shader-addons/`。按当前任务选择对应文档，无需通读所有 addon：

| 需求 | 按需阅读 |
|------|----------|
| 延迟光照前统一修改粗糙度、法线等表面属性 | [GBuffer Postprocess](surface-shader-addons/gbuffer-postprocess.md)：`gbuffer_postprocess` shader 与 Zone 接入 |
| GPU 生成纹理、处理 buffer、异步读回数组 | [Compute](surface-shader-addons/compute.md)：`shader_type compute` 与 `ComputeDispatch`，支持一至三维调度，不通过 Material 调用 |
| 前向/延迟水面、折射、入水效果、引擎波浪与浮力、三帧 FFT | [Water](surface-shader-addons/water.md)：`shading_model_water`、引擎波浪、相机查询、水线、回退与完整独立样例 |
| 自定义体积云的形状、颜色、自发光、散射 | [Cloud](surface-shader-addons/cloud.md)：`shader_type cloud` 与 `VolumetricCloud.material`，含最小云场景与默认云的完整写法 |

---

## 最小例子：纯色无光照材质

资源路径：

```text
assets/
└── Shaders/
    └── BLGL/
        └── GlowBlue.shader
```

`assets/Shaders/BLGL/GlowBlue.shader`：

```glsl
shader_type spatial;
render_mode shading_model_unlit, cull_disabled;

void fragment() {
    ALBEDO = vec3(0.0, 0.75, 1.0);
}
```

Lua 中使用：

```lua
local material = Material:new()
if not material:SetSurfaceShader("Shaders/BLGL/GlowBlue.shader") then
    print("failed to load surface shader")
    return
end

local model = node:CreateComponent("StaticModel")
model.model = cache:GetResource("Model", "Models/Box.mdl")
model:SetMaterial(material)
```

---

`unshaded` 是 `shading_model_unlit` 的同义写法；两者都输出无光照颜色。不能与其他
`shading_model_*` 或 custom `light()` 混用。每次设置或热重载 SurfaceShader 都直接写入材质
FillMode：有 `wireframe` 时为 `FILL_WIREFRAME`，没有时为 `FILL_SOLID`。随后设置
`material.fillMode` 可以覆盖；再次设置或热重载 Shader 会重新应用它的模式。
XML/JSON 保存当前 FillMode，加载时在 Shader 状态之后恢复存档值；Clone/DeepClone 复制当前值。
不跟踪继承来源，普通 `SetTechnique()` 沿用原有行为，不额外重置 FillMode。

## 材质文件配置（Material XML）

Lua 里 `Material:new()` + `SetSurfaceShader()` 适合运行时临时生成的材质。**固定搭配的材质应该写成 `.xml`
资源文件**：shader、贴图和参数都在文件里声明，Lua 只负责加载。

资源路径：

```text
assets/
├── Shaders/
│   └── BLGL/
│       └── StoneWall.shader
├── Materials/
│   └── StoneWall.xml
└── Textures/
    ├── stone_albedo.png
    ├── stone_normal.png
    └── stone_orm.png
```

`assets/Materials/StoneWall.xml`：

```xml
<material>
    <surfaceshader name="Shaders/BLGL/StoneWall.shader" />
    <surfacetexture name="albedo_map" texture="Textures/stone_albedo.png" />
    <surfacetexture name="normal_map" texture="Textures/stone_normal.png" />
    <surfacetexture name="orm_map" texture="Textures/stone_orm.png" />
    <parameter name="tint" value="1 0.95 0.9 1" />
    <parameter name="uv_scale" value="2.0" />
</material>
```

Lua 里只加载，不再设置 shader 和贴图：

```lua
local material = cache:GetResource("Material", "Materials/StoneWall.xml")

local model = node:CreateComponent("StaticModel")
model.model = cache:GetResource("Model", "Models/Box.mdl")
model:SetMaterial(material)
```

### 元素

| 元素 | 属性 | 说明 |
|------|------|------|
| `<surfaceshader>` | `name` | `.shader` 资源路径，取代普通材质的 `<technique>` |
| `<surfacetexture>` | `name` / `texture` / `type` | `name` 是 shader 源码里的 sampler 名，`texture` 是贴图资源路径；`type` 省略即 `Texture2D`，立方体/数组/3D 贴图要显式写 `TextureCube` / `Texture2DArray` / `Texture3D` |
| `<parameter>` | `name` / `value` / `type` | uniform 覆盖值，等价于 `SetShaderParameter()` |
| `<cull>` / `<shadowcull>` | `value` | `none` / `ccw` / `cw`，覆盖 shader `render_mode` 的 cull |
| `<fill>` | `value` | `solid` / `wireframe` / `point`，覆盖 `wireframe` render_mode |
| `<renderorder>` | `value` | 0–255，Stencil 先写后读这类顺序需求用它 |
| `<depthbias>` | `constant` / `slopescaled` | 深度偏移 |
| `<alphatocoverage>` | `enable` | 材质侧开关 A2C |

`<parameter>` 不写 `type` 时按空格分隔的数字个数解析：1 个是 float，2/3/4 是 Vector2/3/4，9 和 16 是
Matrix3/Matrix4；首字符是字母按 bool 解析（`true` / `false`）。`bvec` 写 `0`/`1` 分量（`value="1 0 1"`），
整数标量直接写数字。数组 uniform 在 XML 里按字节解析，不要手写，改用 Lua `SetShaderParameter()` 传 VectorBuffer。

### 规则

- **贴图只能用 XML 绑定**：JSON 材质只有 `surfaceshader` 和 `shaderParameters`，没有按 sampler 名绑定贴图的字段。
  SurfaceShader 材质统一写 `.xml`。
- `<surfacetexture>` 必须和 `<surfaceshader>` 在同一个文件里，否则整段被忽略；不能只写贴图再等 Lua 设置 shader。
- `<surfaceshader>` 加载失败时整个材质加载失败，`cache:GetResource()` 返回 `nil`，不会退回 `<technique>`。
- `name` 必须与 shader 里的 `uniform sampler2D <name>` 完全一致（大小写敏感）。**写错不报错**，贴图静默不生效。
- `<parameter>` 是显式覆盖，和 `SetShaderParameter()` 一样不再跟随 shader 默认值热重载；想回到默认值就删掉该条。
- 引擎 `material:Save(path)` 导出的 XML 会额外带一串 `<texture unit="..." name="..." />` 槽位快照，那是生成结果；
  手写材质只写 `<surfacetexture>`，不要碰槽位名。

---

## 透明材质

写 `ALPHA` 不会自动变透明。需要显式加 `blend_mix`。

如果材质本来就是不透明，直接省略 `ALPHA` 即可。`ALPHA = 1.0`（包括编译期可折叠为
`1.0` 的表达式）会继续使用不透明 pass，也不会产生透明模式警告；动态值或可能小于 `1.0`
的表达式在缺少 `blend_*` 时会报警，提醒你显式选择透明模式，但不会替你切换渲染队列。

```glsl
shader_type spatial;
render_mode shading_model_unlit, blend_mix, cull_disabled, depth_draw_never;

uniform vec4 tint_color = vec4(0.0, 0.75, 1.0, 0.35);

void fragment() {
    ALBEDO = tint_color.rgb;
    ALPHA = tint_color.a;
}
```

常用规则：

| 需求 | render_mode |
|------|-------------|
| 普通透明 | `blend_mix` |
| 预乘 Alpha 混合 | `blend_premul_alpha` |
| 双面透明 | `blend_mix, cull_disabled` |
| 不写深度的透明特效 | `blend_mix, depth_draw_never` |

---

使用 `blend_premul_alpha` 时，`PREMUL_ALPHA_FACTOR` 乘最终 RGB，不改变 Alpha，默认 1。
未预乘的颜色配 `PREMUL_ALPHA_FACTOR = ALPHA`，已预乘的保留 1。没有该 blend 模式时赋值被忽略。

## 随机镂空与 MSAA 覆盖

写 `ALPHA_HASH_SCALE` 启用对象空间 Alpha Hash，材质仍算不透明。`ALPHA` 决定平均可见比例，
scale 决定哈希网格尺度，默认 1；它不是透明强度。阴影里的图案不要求与颜色逐像素一致。

```glsl
shader_type spatial;
render_mode unshaded, cull_back;
uniform float opacity = 0.5;
void fragment() {
    ALBEDO = vec3(0.3, 0.8, 0.2);
    ALPHA = opacity;
    ALPHA_HASH_SCALE = 1.0;
}
```

`render_mode alpha_to_coverage` 把 Alpha 交给 MSAA 样本覆盖。实际 attachment 必须启用 MSAA；
单采样 color/depth/velocity 不自动补透明度裁剪，需要镂空时显式使用 Alpha Scissor 或 Alpha Hash。
阴影及材质烘焙 pass 保留独立的 `Alpha < 0.5` 裁剪规则。普通 A2C 保留输出 Alpha，不自动写 1。
无需为以上镂空模式添加 `blend_mix`。

A2C 的可选 fragment 输出：

| 字段 | 类型 / 默认值 | 作用 |
|------|---------------|------|
| `ALPHA_ANTIALIASING_EDGE` | `float` / 0 | 显式写入时启用导数边缘平滑；和 scissor 同用时加到 scissor 阈值上 |
| `ALPHA_TEXTURE_COORDINATE` | `vec2` / `(0, 0)` | 以 texel 为单位的纹理坐标，例如 `UV * vec2(textureSize(tex, 0))`，用于 mip 估算和 Alpha 补偿 |


## Stencil 屏幕标记

`stencil_mode` 只影响材质颜色 pass，可以在共享深度/Stencil attachment 上先写标记、再按标记筛选像素。
必须给出 0–255 的 reference。例如写入者使用 `stencil_mode write, 200;`，读取者使用
`stencil_mode read, compare_equal, 200;`。用材质 `renderOrder` 安排先写后读。

| 模式 | 作用 |
|------|------|
| `read` | 读取完整 8-bit Stencil 并按 compare 比较 |
| `write` | Stencil 与深度测试通过时写入 reference |
| `write_depth_fail` | Stencil 测试通过、深度测试失败时写入 reference |
| `compare_less/equal/less_or_equal/greater/not_equal/greater_or_equal/always` | 比较 reference 与缓冲中的值；默认 always |

未指定的写操作保持原值。可以组合 read/write/write_depth_fail；没有 read 时比较 mask 为零。
shadow、pre-Z 与 velocity 不继承材质 Stencil，Stencil 功能不会替代这些 pass 的深度策略。

材质侧可以覆盖或关闭 shader 里声明的 Stencil 设置。

## PBR 材质

PBR 适合受灯光、IBL、阴影影响的实体材质。

```glsl
shader_type spatial;
render_mode shading_model_pbr, cull_back;

uniform vec4 base_color : source_color = vec4(0.85, 0.35, 0.16, 1.0);
uniform float roughness_value : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform float metallic_value : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0, 0.01) = 0.5;

void fragment() {
    ALBEDO = base_color.rgb;
    ALPHA = base_color.a;
    ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
    ROUGHNESS = roughness_value;
    METALLIC = metallic_value;
    AO = 1.0;
    EMISSION = vec3(0.0);
}
```

PBR 常用输出：

| 字段 | 类型 | 说明 |
|------|------|------|
| `ALBEDO` | `vec3` | 基础颜色 |
| `ALPHA` | `float` | 透明度，需配合 `blend_*` 才会透明 |
| `ALPHA_SCISSOR_THRESHOLD` | `float` | 镂空阈值；Alpha 低于该值的像素不渲染 |
| `ROUGHNESS` | `float` | 粗糙度，0 光滑，1 粗糙 |
| `METALLIC` | `float` | 金属度，0 非金属，1 金属 |
| `SPECULAR` | `float` | 非金属镜面反射强度 |
| `AO` | `float` | 环境遮蔽 |
| `AO_LIGHT_AFFECT` | `float` | fragment 输出，默认 0；直接光乘 `mix(1, AO, AO_LIGHT_AFFECT)`，1 表示完全使用材质 AO 遮蔽直接光 |
| `EMISSION` | `vec3` | 自发光 |
| `NORMAL_MAP` | `vec3` | 切线空间法线贴图，RGB 从 0–1 解码到 −1–1；通常写 `texture(normal_map, UV).rgb` |
| `LIGHT_VERTEX` | `vec3` | fragment 的独立 view-space 光照位置；默认 `VIEW_MATRIX * vec4(VERTEX, 1)` 的 xyz，不移动几何 |
| `DEPTH` | `float` | 当前引擎 0～1 硬件深度，近 0、远 1；默认当前光栅深度，仅写入时启用自定义深度路径 |
| `NORMAL_MAP_DEPTH` | `float` | 法线扰动强度，默认 1，0 退回写入 `NORMAL` 后的原始法线；不是屏幕或世界空间深度 |
| `PREMUL_ALPHA_FACTOR` | `float` | 预乘混合的最终 RGB 权重，默认 1 |
| `CLEARCOAT` | `float` | 清漆强度；普通 PBR 使用时自动启用 Clearcoat |
| `CLEARCOAT_ROUGHNESS` | `float` | 顶层清漆粗糙度；普通 PBR 使用时自动启用 Clearcoat |

---

`NORMAL_MAP` 使用 UrhoX 的 RGB 解码和原生 TBN。强度默认 1，保持旧 Surface 的 packed
varying 乘法；0 返回扰动前归一化法线，其余值混合基础法线与完整扰动方向后归一化。
fragment 显式写入 `NORMAL/TANGENT/BINORMAL` 时，仅对应轴参与覆盖；未写轴使用原始插值值。
`BINORMAL` 统一为 UrhoX packed B 的方向；曾依赖旧 Surface 反号 B 的手写计算需调整。

**与 Godot 的差异**：蓝通道就是切线空间 Z，按 OpenGL 与 Unity 约定使用，不像 Godot 那样从 XY 重建。
常规法线贴图本来就满足。若贴图只在 R、G 存法线，要自己重建 Z 再编码：
`NORMAL_MAP = vec3(rg, sqrt(max(1.0 - dot(rg*2.0-1.0, rg*2.0-1.0), 0.0)) * 0.5 + 0.5)`。

`DEPTH` 与 `FRAGCOORD.z`、屏幕深度纹理使用同一窗口深度约定；不是线性距离，也不是 Godot
Reverse-Z。从原生 clip 位置计算时，DX 为 `clip.z / clip.w`，GL 还需乘 0.5 加 0.5。
既有 `CLIP_SPACE_FAR` 逻辑常量不适合作为此输出的远端值。条件分支未赋值时保留当前光栅深度。
透明材质与读屏材质要写 `depth_draw_always` 才会更新深度缓冲。
写 `DEPTH` 只改深度值，不改变光照位置、投影轮廓或阴影命中点。

声明 `hint_depth_texture` 即可用 `SCREEN_UV` 采样场景深度。同一材质不要既采样深度又写 `DEPTH`。

`LIGHT_VERTEX` 保留原生 view-space 输入，和现有 world-space fragment `VERTEX` 有区别。例如：

```glsl
void fragment() {
    vec3 stepped_world = floor(VERTEX * 4.0) / 4.0;
    LIGHT_VERTEX = (VIEW_MATRIX * vec4(stepped_world, 1.0)).xyz;
    ALBEDO = vec3(0.6);
}
```

该输出只改变光照位置，含反射视线、灯光衰减和阴影接收，不改变深度、投影、雾或阴影投射。
fragment 中的 VIEW 仍是原始几何视线，后续 BRDF/light() 使用新的视线。Unlit 可读写该值但不进行受光。
偏移不会扩大该物体的灯光收录范围与阴影覆盖，所以大幅偏移可能采不到本应照到它的灯。

材质级静态开关可与上述光照材质或 custom `light()` 一起使用：

| render_mode | 作用 |
|-------------|------|
| `shadows_disabled` | 关闭材质的 shadow map 接收，保留投射阴影及灯光距离/锥角衰减 |
| `fog_disabled` | 跳过距离雾、高度雾与材质雾混合 |
| `ambient_light_disabled` | 关闭环境漫反射、IBL 和 lightmap，保留直接光和自发光 |
| `specular_occlusion_disabled` | 仅关闭间接高光的 AO 遮蔽，包括 Clearcoat 顶层反射；漫反射 AO 保留 |

`AO_LIGHT_AFFECT` 是每片元输出，不用声明成 uniform，它作用于材质 `AO`。
`fog_disabled` 只关材质雾，不取消全屏或体积雾。这些开关都只作用于当前材质。

## 清漆材质

清漆材质适合车漆、上釉陶瓷、亮面塑料等有额外表层高光的材质。

```glsl
shader_type spatial;
render_mode shading_model_clearcoat, cull_back;

uniform vec4 base_color : source_color = vec4(0.6, 0.05, 0.02, 1.0);
uniform float coat_strength : hint_range(0.0, 1.0, 0.01) = 0.8;
uniform float coat_roughness : hint_range(0.0, 1.0, 0.01) = 0.15;

void fragment() {
    ALBEDO = base_color.rgb;
    ALPHA = base_color.a;
    METALLIC = 0.0;
    SPECULAR = 0.5;
    ROUGHNESS = 0.35;
    AO = 1.0;
    CLEARCOAT = coat_strength;
    CLEARCOAT_ROUGHNESS = coat_roughness;
}
```

---

## 卡通材质（Toon）（仅 Web 预览版）

UrhoX Toon 是基于 Metallic PBR 材质参数的赛璐璐卡通渲染。采用预设卡通光照，提供主光明暗分段、暗部调色、皮肤与脸部处理、边缘光、深度效果和光照描边。

以下示例展示 Toon 材质的基础用法；`mix_map` 是自定义混合贴图，可按项目需要调整通道。

```glsl
shader_type spatial;
render_mode shading_model_toon, outline, cull_back;

uniform sampler2D albedo_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mix_map : filter_linear_mipmap, repeat_enable;
uniform sampler2D ramp_map : filter_nearest, repeat_disable;         // 明暗色带贴图，`filter_nearest` 产生硬色带；需要产生平滑过渡时改用 `filter_linear`

uniform float dither_opacity : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float area_type : hint_range(0.0, 3.0, 1.0) = 0.0;

// 以下为 Toon 内置材质参数（仅前向生效；未声明则用 Zone 级配置）。
uniform vec3 toon_shadow_hsv = vec3(0.0, 0.5, 0.7);                  // x=暗部-色相偏移，y=暗部-饱和度增强，z=暗部-明度倍率。
uniform vec4 toon_skin_shadow_tint = vec4(1.0, 0.3392, 0.3787, 1.0); // rgb=皮肤暗部颜色，a=皮肤暗部颜色混合强度（覆盖HSV）。
uniform vec4 toon_rim_color = vec4(1.0, 1.0, 1.0, 6.0);              // rgb=边缘光颜色，a=边缘光强度。

void fragment() {
    vec3 albedo = texture(albedo_map, UV).rgb;
    vec4 mix_value = texture(mix_map, UV);
    float ndotl = dot(NORMAL, MAIN_LIGHT_DIRECTION);

    ALBEDO = albedo;

    // 衣服和装饰需要 PBR 质感时使用。
    METALLIC = mix_value.r;
    ROUGHNESS = mix_value.g;
    SPECULAR = mix_value.b;

    // 自定义明暗色带
    TOON_RAMP = texture(ramp_map, vec2(clamp(ndotl * 0.5 + 0.5, 0.0, 1.0), 0.5)).r;
    // TOON_RAMP 的缺省计算为：TOON_RAMP = smoothstep(-0.025, 0.025, ndotl);

    // 标记部件区域
    TOON_AREA_TYPE = area_type;            // 0=衣服/配件，1=头发，2=皮肤，3=脸部
    // TOON_AREA_TYPE = mix_value.a * 3.0; // 或指定贴图通道作为部件区域。

    DITHER_OPACITY = dither_opacity;
}
```

### 效果

- **预设光照**：`shading_model_toon` 使用引擎内置 Toon 光照，统一处理主光、附加光、阴影、环境光和 Toon 专属效果。
- **明暗分段**：可自定义主光明暗分段/色带。
- **暗部调色**：可调节暗部色相、饱和度和明度。
- **部件区域**：可指定衣服/配件、头发、皮肤、脸部四种部件区域，并对不同部位应用对应的特化处理。
- **脸部平坦光照**：弱化模型法线产生的立体明暗，使脸部受光更平整。
- **皮肤暗部**：支持为皮肤和脸部设置独立暗部颜色与混合强度，以覆盖HSV。
- **PBR 材质**：同时支持 GGX 高光、金属度、镜面反射、粗糙度、法线贴图、IBL、AO 和自发光。
- **多光源**：支持多光源，弱化附加光计算。
- **边缘光与深度效果**：支持边缘光（Rim）；高画质延迟渲染额外支持深度边缘光（Depth Rim）和深度阴影（Depth Shadow）。
- **光照描边**：高画质下，Toon 描边颜色可受到光照与阴影影响。
- **抖动镂空**：通过不透明像素的疏密实现模型的淡入淡出。

### Toon 专用输出

| 输出 | 类型 | 作用 |
|------|------|------|
| `TOON_RAMP` | `float` | 明暗色带；`0.0` 使用暗部颜色，`1.0` 使用 `ALBEDO`，中间值在两者之间混合 |
| `TOON_AREA_TYPE` | `float` | 部件区域：`0` 衣服/配件、`1` 头发、`2` 皮肤、`3` 脸部 |
| `DITHER_OPACITY` | `float` | 专用抖动镂空效果，栅格化半透过渡 |

### 要点

- `ALPHA_SCISSOR_THRESHOLD` 是通用 Spatial 镂空输出；`DITHER_OPACITY` 是内置 Toon Lighting 路径专用的抖动镂空输出。
- `TOON_RAMP` 只描述明暗色带，不要乘入主光颜色、阴影或衰减；内置 Toon 光照会继续处理这些数据
- `toon_shadow_hsv`、`toon_skin_shadow_tint`、`toon_rim_color` 可按需声明。未声明时使用 Zone 配置；声明后以源码默认值作为 Technique 值，Material 可继续覆盖。
- 前向与延迟共用核心 Toon 光照效果；延迟渲染的 `toon_*` 参数始终使用 Zone 配置，材质 AO 也仅在前向渲染生效。
- 写了 `light()` 后走自定义光照，不再使用内置 Toon 光照。普通描边仍可用。
- **所有输出和 uniform 都按需使用。** 上面的基础示例是能力一览；材质只写实际用到的项，其余走缺省值。

#### Zone 级 ToonShading 参数

| 参数 | 效果 |
|------|------|
| `shadowHSV`、`skinShadowTint`、`rimTint`、`rimIntensity` | 对应材质参数 `toon_shadow_hsv`、`toon_skin_shadow_tint`、`toon_rim_color`；未声明材质参数时使用这些 Zone 配置。 |
| `mainLightMaxContribution`、`mainLightMultiplier` | 限制主光最大贡献，并对主光结果进行倍率调节。 |
| `depthEffectsSimpleOffset` | 控制高画质延迟渲染的深度效果。非 `0` 时启用 Depth Rim 和 Depth Shadow，并控制采样偏移；设为 `0` 时关闭深度效果，边缘光回退为 NdotV Rim。 |

使用 `ToonShadingParams` 整体读取和写回：

```lua
local toon = zone:GetToonShadingParams()
toon.shadowHSV = Vector3(0.0, 0.5, 0.7)
toon.skinShadowTint = Color(1.0, 0.61, 0.64, 1.0)
toon.rimTint = Color(1.0, 1.0, 1.0, 1.0)
toon.rimIntensity = 6.0
toon.mainLightMaxContribution = Color(1.0, 1.0, 1.0, 1.0)
toon.mainLightMultiplier = Color(1.0, 1.0, 1.0, 1.0)
toon.depthEffectsSimpleOffset = 1.0
zone:SetToonShadingParams(toon)
```

---

## 描边（Outline）（仅Web预览版）

通用法线外拓描边。为 Surface Shader 添加 `render_mode outline` 后，可在 `StaticModel` 或 `AnimatedModel` 实例上直接启用和调节，无需单独创建描边材质。

**平滑法线**：优先使用 `.mdl` 导入时生成的平滑法线。

```lua
model:SetOutlineEnabled(true)
model:SetOutlineThickness(0.0025)
model:SetOutlineColor(Color(0.0, 0.0, 0.0, 0.8))
model:SetOutlineZBias(0.01)
```

| 接口 | 说明 |
|------|------|
| `SetOutlineEnabled()` | 开启或关闭当前模型实例的描边。 |
| `SetOutlineThickness()` | 描边宽度（米），`0` 不外扩。离相机 `60 / fov` 米内屏幕粗细不变，更远时按这个米数越远越细。 |
| `SetOutlineColor()` | RGB 为描边颜色，支持大于 `1` 的 HDR 颜色；Alpha 为颜色使用比例，`0` 使用材质 `ALBEDO`，`1` 完全使用指定颜色。 |
| `SetOutlineZBias()` | 描边深度往远处推多少米，默认 `0.01`。比这更近的重叠（如刘海下的眉毛）不显示描边。 |

旧项目中的 `SetOutlineBrightness()` 已废弃。

和旧版的差别：宽度在近处变细；深度偏移改成按米算，默认 `0.01`。交叠处多出描边时，把它调大到 `0.05`～`0.2`。

描边只支持不透明。和 `blend_mix` 或 `hint_screen_texture` 一起写时，描边会被忽略，材质仍可加载。

---

## 自定义光照 `light()`

需要自己决定每盏实时灯如何影响材质时，可以像 Godot spatial shader 一样编写 `light()`。`fragment()` 仍然负责写 `ALBEDO`、`ROUGHNESS`、`METALLIC`、`AO`、`NORMAL_MAP`、`BACKLIGHT` 等材质属性；`light()` 负责根据当前灯光写 `DIFFUSE_LIGHT`、`SPECULAR_LIGHT`、`ALPHA`。

```glsl
shader_type spatial;
render_mode cull_back;

uniform vec4 base_color : source_color = vec4(0.8, 0.45, 0.25, 1.0);
uniform float shadow_steps : hint_range(1.0, 6.0, 1.0) = 3.0;

void fragment() {
    ALBEDO = base_color.rgb;
    ALPHA = base_color.a;
    BACKLIGHT = base_color.rgb * 0.25;
    ROUGHNESS = 0.7;
    METALLIC = 0.0;
    AO = 1.0;
}

void light() {
    float ndotl = max(dot(NORMAL, LIGHT), 0.0);
    float steps = max(shadow_steps, 1.0);
    float band = ceil(ndotl * steps) / steps;
    vec3 lit = ALBEDO * LIGHT_COLOR * ATTENUATION * band;
    vec3 back = BACKLIGHT * LIGHT_COLOR * ATTENUATION * (1.0 - ndotl);

    DIFFUSE_LIGHT += lit;
    DIFFUSE_LIGHT += back;
}
```

要点：

- `light()` 使用 Godot-style 的光照阶段语义，常用输入包括 `NORMAL`、`LIGHT`、`LIGHT_COLOR`、`ATTENUATION`、`VIEW`、`ALBEDO`、`ROUGHNESS`。
- 写了 `light()` 后，实时灯的直接光照由 `light()` 决定；如果还需要高光或透明度影响，在 `light()` 中显式写 `SPECULAR_LIGHT`、`ALPHA`；不需要高光时可以不写 `SPECULAR_LIGHT`。
- `BACKLIGHT` 在 `light()` 中是只读输入；需要背光参数时，在 `fragment()` 中写 `BACKLIGHT`，再在 `light()` 中读取它。
- 不需要自定义光照时，不写 `light()`，直接使用 PBR、Toon 或 Unlit 模型即可。
- `light()` 可以和普通描边一起用；描边壳不跑 `light()`。

---

## 贴图采样

需要保留数据纹理的采样精度时，可以声明 `uniform highp sampler2D displacement_map;`。
`highp`、`mediump`、`lowp` 适用于材质的 `sampler2D`、`sampler2DArray`、`sampler3D`、
`samplerCube`，compute 的 `sampler2D` 也支持。未写精度的 sampler 仍生成原来的
`SAMPLER2D` 等宏，保留各后端原有行为；只有显式声明精度才使用带精度参数的宏。

- runtime Metal：显式 `highp` 使用 `texture2d<float>` 等类型；`mediump`／`lowp`
  使用原有 half 采样策略。已有高精度数据纹理集合仍优先保证 float，不被较低精度声明降级。
- runtime GLES：显式 `highp` 生成高精度 GLSL sampler，`mediump`／`lowp` 在编译链路中
  可能统一为 `mediump`。原有低精度 sampler 同样可能限制采样结果精度，因此数据纹理应按需
  声明 `highp`；不能只根据 RGBA32F 存储格式判断采样精度。
- WebGPU：浮点纹理的 WGSL 采样类型是 `f32`，没有 `texture_2d<f16>`，不能直接套用 Metal
  的 half 纹理采样结论。坐标、插值和后续运算仍可能经过低精度转换，需要分别检查生成代码。
  参见 [WGSL sampled texture types](https://www.w3.org/TR/WGSL/#sampled-texture-type)。

sampler 精度不改变纹理存储格式、UV／varying 的精度或硬件过滤能力；`highp` 也不会让不支持
线性过滤的格式自动支持 `filter_linear`。这些需要分别选择和验证。

在 shader 中声明 sampler：

```glsl
shader_type spatial;
render_mode shading_model_pbr, cull_back;

uniform sampler2D albedo_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear, repeat_enable;
uniform sampler2D orm_map : hint_default_white, filter_linear, repeat_enable;

void fragment() {
    vec4 base = texture(albedo_map, UV);
    vec3 normal_sample = texture(normal_map, UV).rgb;
    vec4 orm = texture(orm_map, UV);

    ALBEDO = base.rgb;
    ALPHA = base.a;
    AO = orm.r;
    ROUGHNESS = orm.g;
    METALLIC = orm.b;
    NORMAL_MAP = normal_sample;
}
```

Lua 中按 shader 源码里的 sampler 名设置贴图：

```lua
local material = Material:new()
if not material:SetSurfaceShader("Shaders/BLGL/MyPBR.shader") then
    print("failed to load surface shader")
    return
end

material:SetSurfaceTexture("albedo_map", cache:GetResource("Texture2D", "Textures/stone_albedo.png"))
material:SetSurfaceTexture("normal_map", cache:GetResource("Texture2D", "Textures/stone_normal.png"))
material:SetSurfaceTexture("orm_map", cache:GetResource("Texture2D", "Textures/stone_orm.png"))
```

也可以不写这段 Lua，直接在材质 XML 里用 `<surfacetexture name="albedo_map" texture="..." />` 绑定，
见 [材质文件配置（Material XML）](#材质文件配置material-xml)。

关键规则：

- `SetSurfaceTexture()` 的第一个参数为 shader 里声明的 sampler 名。
- 普通材质贴图的 `filter_*` 与 `repeat_*` 生效；screen 与 depth 这类外部资源不接受逐材质覆盖。
- 同一张 ORM 贴图只采样一次，再拆通道：`R=AO`、`G=Roughness`、`B=Metallic`。
- v1 建议最多使用 6 张自定义贴图。

---

## 顶点动画

默认 `VERTEX` 是 object space，适合局部形变，会跟随物体自身变换。

```glsl
shader_type spatial;
render_mode shading_model_unlit, cull_disabled;

void vertex() {
    VERTEX.y += sin(TIME + VERTEX.x * 6.0) * 0.15;
}

void fragment() {
    ALBEDO = vec3(0.15, 0.8, 0.35);
}
```

如果需要世界空间偏移，使用 `world_vertex_coords`：

```glsl
shader_type spatial;
render_mode shading_model_unlit, world_vertex_coords, cull_disabled;

void vertex() {
    VERTEX.y += sin(TIME + VERTEX.x * 4.0) * 0.05;
}

void fragment() {
    ALBEDO = vec3(0.2, 0.7, 1.0);
}
```

选择建议：

| 需求 | 做法 |
|------|------|
| 物体局部鼓动、草叶摆动 | 默认 `VERTEX` |
| 世界坐标波浪、全局扫描线 | `world_vertex_coords` |
| 只改颜色、不改形状 | 不写 `vertex()` |

`StaticModel` 和 `CustomGeometry` 都会先应用节点的平移、旋转与缩放，再把世界坐标交给
`world_vertex_coords` 的 `vertex()`。`CustomGeometry` 如果需要读取 `NORMAL`，必须为顶点调用
`DefineNormal()`；没有法线输入时，不要依赖 `NORMAL`、`TANGENT` 或 `BINORMAL` 的数值。

写 `vertex()` 后，深度、阴影与运动矢量都会使用同一份形变结果，所以纯 `TIME` 驱动的
程序动画也会产生正确的运动矢量。

`skip_vertex_transform` 让 vertex() 返回 **view-space** 的位置和 N/T/B，随后仍执行投影。
同时指定 `world_vertex_coords` 时，skip 优先；fragment 的 VERTEX/NORMAL 仍转回 world-space。
`POSITION` 是独立的最终裁剪位置，与 `PROJECTION_MATRIX` 使用当前后端原生 clip 约定；写入它
不会重定义 fragment VERTEX。条件分支未赋值时为 vec4(1)，请为所有需要显示的分支赋值。
`Z_CLIP_SCALE` 默认 1，0 把深度收拢到近面，保持 XY 和光照位置；投射阴影时跳过。
顶点位移不改变物体的剔除范围，位移过大时物体可能被提前剔除。

---

## vertex 到 fragment 传值

使用 `varying` 把顶点阶段的计算结果传给片元阶段。

```glsl
shader_type spatial;
render_mode shading_model_unlit, cull_disabled;

varying vec3 debug_color;

void vertex() {
    debug_color = vec3(UV, 1.0);
}

void fragment() {
    ALBEDO = debug_color;
}
```

v1 只建议少量使用 `varying`。如果只是片元阶段能直接算出来的值，不要绕一圈 varying。

---

## GPU 实例化数据

### Per-instance color

Lua 中，可在 `StaticModel` 和 `AnimatedModel` 上设置：

```lua
model.instanceColor = Color(0.25, 0.8, 1.0, 1.0)

-- 赋值会自动启用。手动关闭后保留已有颜色，但不消费。
model.useInstanceColor = false
```

启用 `InstanceColor` 后，Shader 中 COLOR 会初始化为 `COLOR = VERTEX_COLOR * INSTANCE_COLOR`，也可直接通过 INSTANCE_COLOR 读取实例颜色。

```shader
void fragment() {
    ALBEDO = COLOR.rgb; // VERTEX_COLOR * INSTANCE_COLOR
}
```

```shader
void vertex() {
    COLOR = INSTANCE_COLOR;
}

void fragment() {
    ALBEDO = COLOR.rgb;
}
```

`VERTEX_COLOR` 和 `INSTANCE_COLOR` 可以在 `vertex()` 中独立读取使用。如果 `fragment()` 需要将两者分开消费，请在 `vertex()` 中将它们写入不同的自定义 `varying`。

### Per-instance custom data

Lua 中，可以为 `StaticModel` 基类设置：

```lua
model.instanceCustomData = Vector4(0.2, 0.4, 0.8, 1.0)

-- 赋值会自动启用。关闭后 Shader 中会读取到 ZERO。
model.useInstanceCustomData = false
```

Shader 中，`INSTANCE_CUSTOM` 是由四个自定义分量 `vec4` 组成，只能在 `vertex()` 中直接读取。传到片元阶段时使用 `varying`：

```shader
varying vec4 instance_data;

void vertex() {
    instance_data = INSTANCE_CUSTOM;
}

void fragment() {
    ALBEDO = instance_data.rgb;
}
```

未明确支持 `INSTANCE_CUSTOM` 的实例类型，读取结果未定义，不保证为 `ZERO`。

**满足合批条件时，多实例绘制会自动启用 GPU Instancing；单实例绘制会回退到等价的 uniform 路径，两者结果一致。**

### Per-instance uniforms

相比内置的 `InstanceColor` 和 `InstanceCustomData`，`instance uniform` 可自定义多个具名的标量或向量字段，更灵活地组织每个实例的数据。

`assets/Shaders/BLGL/InstanceTint.shader`：

```glsl
shader_type spatial;
render_mode unshaded;

instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float damage = 0.0;

void fragment() {
    ALBEDO = mix(tint.rgb, vec3(1.0, 0.0, 0.0), damage);
}
```

```lua
local material = Material:new()
material:SetSurfaceShader("Shaders/BLGL/InstanceTint.shader")
model:SetMaterial(material)
model:SetInstanceShaderParameters({ tint = Color(0.2, 0.8, 1.0, 1.0), damage = 0.0 })
model:SetInstanceShaderParameter("damage", 0.8)
model:ClearInstanceShaderParameter("damage") -- Restore the shader default.
```

未设置或清除的参数使用 Shader 默认值。`Color` 自动转为线性颜色；已是线性值时用 `Vector3/4`。字段支持 `bool/int/uint/float` 和 `vec/ivec/uvec2..4`，不支持纹理、矩阵和数组。

---

## 常用输入变量

| 变量 | 阶段 | 说明 |
|------|------|------|
| `UV` | vertex / fragment | 主 UV |
| `UV2` | vertex 可读写 / fragment 只读 | 第二套原始 UV；模型需提供该顶点流，vertex 改动传至 fragment，不改变 lightmap atlas UV |
| `COLOR` | vertex / fragment | `vertex()` 阶段可读写，默认为顶点色 `VERTEX_COLOR`；实例启用 `InstanceColor` 时初始化为 `VERTEX_COLOR * INSTANCE_COLOR`；`COLOR` 同时作为内置 varying，可在 `fragment()` 中读取。 |
| `VERTEX_COLOR` | vertex | 顶点色，只读；模型缺少顶点色时读取结果未定义 |
| `INSTANCE_COLOR` | vertex | 每实例颜色`vec4`，只读；实例未启用时读取结果为白色 |
| `INSTANCE_CUSTOM` | vertex | 每实例自定义`vec4`；未明确支持的实例类型上读取结果未定义 |
| `VERTEX` | vertex / fragment | vertex 中默认是 object space，`world_vertex_coords` 时是 world space；fragment 中是插值后的 world space 位置 |
| `NORMAL` | vertex / fragment | vertex 中与 `VERTEX` 使用相同空间；fragment 中是插值并归一化后的 world space 网格法线，Unlit/PBR/Toon 均可用。fragment 写入也是 world space：与 Godot 的视空间约定不同，移植 Godot 代码时去掉 `VIEW_MATRIX` 变换 |
| `TANGENT` | vertex / fragment | vertex 中与 `NORMAL` 使用相同空间；fragment 中是归一化后的 world space 切线，仅在实际读取时增加 tangent 输入与 varying |
| `BINORMAL` | fragment 可读写 | UrhoX 原生副切线方向；写入不修改公共 TBN |
| `TIME` | vertex / fragment | 当前场景时间，适合动画；velocity 的历史求值读取上一帧时间 |
| `VERTEX_ID` | vertex | 当前 draw 的顶点编号；索引 draw 读取实际索引值 |
| `INSTANCE_ID` | vertex | draw-local 实例编号，普通 draw 为 0；只用于外观计算，与几何/coverage/outline 组合暂时拒绝 |
| `BONE_INDICES` / `BONE_WEIGHTS` | vertex | 原始骨骼流，非蒙皮为零 |
| `FRONT_FACING` | fragment | 光栅正反面标记，按 UrhoX cull_back 正面约定统一后端 |
| `POSITION` | vertex 可读写 | 独立 clip-space 位置，写入时覆盖默认裁剪位置 |
| `Z_CLIP_SCALE` | vertex 可读写 | 默认 1，向当前后端近裁剪面缩放深度，阴影 pass 跳过 |
| `CAMERA_POSITION_WORLD` | vertex / fragment | 世界空间相机位置 |
| `MAIN_LIGHT_DIRECTION` | vertex / fragment | 从表面指向主平行光的归一化世界空间方向；可直接与世界空间 `NORMAL` 点积 |
| `MAIN_LIGHT_COLOR` | vertex / fragment | 主平行光的有效 RGB 颜色；不包含阴影或逐对象衰减 |
| `MODEL_MATRIX` | vertex / fragment | Godot 列向量约定的 object-to-world 矩阵；用 `MODEL_MATRIX * vec4(position, 1.0)` |
| `MODEL_NORMAL_MATRIX` | vertex / fragment | 模型矩阵的逆转置 3×3 法线矩阵，支持非均匀缩放；fragment 读取 VS 传递的三个轴 |
| `MODELVIEW_MATRIX` / `MODELVIEW_NORMAL_MATRIX` | vertex 只读 | object-to-view 矩阵与逆转置法线矩阵 |
| `IN_SHADOW_PASS` | vertex / fragment / light | 当前是否为投射阴影 pass；普通颜色 pass 为 false，和是否接收阴影无关 |
| `VIEW_MATRIX` / `INV_VIEW_MATRIX` | vertex / fragment | Godot 列向量约定的 world/view 变换矩阵 |
| `PROJECTION_MATRIX` | vertex / fragment | Godot 列向量约定的投影矩阵 |
| `SCREEN_UV` | fragment | 屏幕采样 UV，需要配合 `hint_screen_texture` 或 `hint_depth_texture` |
| `VIEWPORT_SIZE` | vertex / fragment | 当前绘制视口的像素尺寸，包含 render texture / 分辨率缩放 |
| `INV_PROJECTION_MATRIX` | vertex / fragment | Godot-compatible 反投影矩阵；vertex 支持齐次反投影，包含透视与正交 |

矩阵乘法沿用 Godot 写法，矩阵放在左侧：

> **旧项目迁移**：早期 UrhoX 兼容层曾要求把内建矩阵写在右侧，例如
> `vec4(position, 1.0) * VIEW_MATRIX`。矩阵语义修正后必须改为
> `VIEW_MATRIX * vec4(position, 1.0)`；旧写法可能继续编译，但计算结果不再代表同一个变换。

```glsl
varying vec3 debug_world_normal;

void vertex() {
    vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    debug_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
    VERTEX += debug_world_normal * 0.05;
}
```

生成器会把矩阵乘法转成各后端安全的 `mul` 调用，并适配 UrhoX 与 Godot 的行/列向量约定。
法线矩阵在 vertex 求逆转置；零尺度等退化矩阵回退单位矩阵，避免 NaN。fragment 的三个矩阵轴
经过插值，不等于恢复原始逐顶点蒙皮矩阵。fragment `MODEL_MATRIX` 仍有 draw-level 绑定边界；
需要实例/蒙皮后的最终方向时优先使用 `VERTEX/NORMAL` 或明确的 vertex varying。
向量 `equal/notEqual/lessThan/lessThanEqual/greaterThan/greaterThanEqual` 保留分量类型，
`ivec/uvec` 比较不会转换成 float；`all/any/not` 支持 `bvec2/3/4`。`==/!=` 对向量返回一个 bool，
`equal/notEqual` 返回逐分量的 bvec，可再用 `all/any` 规约。

2D/Array/3D/Cube 的 `texture`、`textureLod`、`textureGrad` 与 `textureProj*` 都可用，
Array 的 Grad 只传 XY 导数。vertex 里无 bias 的采样使用 LOD 0。

纹理尺寸查询：

| 函数 | 功能与输入 |
|------|------------|
| `textureSize(tex, lod)` | 查询指定有效 mip 的尺寸；支持 2D/Array/3D/Cube，Array 第三分量为层数 |

同一个 sampler helper 可以混合接收带 `source_color` 的颜色纹理和普通数据纹理；用途按每次
调用传递，嵌套/重载也保留，不会因为另一个调用传入颜色纹理就把数据纹理一起解码。

整数纹理 `isampler2D/usampler2D`、`isampler2DArray/usampler2DArray` 和
普通 `int/uint` 材质参数和整数运算不受影响。

屏幕导数不能从 vertex 调用，包括间接调用 helper 的情况。

`dFdx/dFdy/fwidth` 接受 float/vec2/3/4，仅用于 fragment；`fwidth` 为对应 x/y 导数绝对值之和。
避免在非一致控制流内求导，不依赖高阶导数。

常用函数：

```glsl
sin(x)
atan(x)
atan(y, x) // Full quadrant angle.
cos(x)
mix(a, b, t)
clamp(x, minValue, maxValue)
smoothstep(edge0, edge1, x)
texture(my_sampler, UV)
normalize(v)
dot(a, b)
```

---

## 宏与公共 include

SurfaceShader 在解析前处理 Godot 风格的 `#define/#undef`、`#if/#elif/#else/#endif`、
`#ifdef/#ifndef`、`#include` 和 `#error`。可把公共函数写入 `.shaderinc`（公共片段后缀，与主文件 `.shader` 配对）：

```glsl
shader_type spatial;
render_mode unshaded;
#include "lib/Color.shaderinc"
#define COLOR_GAIN 0.8
void fragment() {
    ALBEDO = make_color(UV) * COLOR_GAIN;
}
```

相对 include 从当前文件目录解析；`res://Shaders/BLGL/lib/Color.shaderinc` 从资源根目录解析。
嵌套 include 的更新会触发引用 shader 热重载；重复 include 沿用 Godot 去重行为。
错误保留原文件与行号。

内置宏沿用 Godot 的定义，`CURRENT_RENDERER` 为 `RENDERER_FORWARD_PLUS`。

`#if` 使用 Godot 的数值/布尔常量规则与运算优先级，支持基本数学函数；`&&/||` 两侧都会求值，
不要用 `0 && (1 / 0)` 规避除零。字符串、容器、对象/方法表达式未接入。

## Uniform 参数

普通 uniform 可以直接在 shader 里给默认值：

```glsl
uniform vec4 tint_color : source_color = vec4(1.0, 0.5, 0.2, 1.0);
uniform float pulse_speed : hint_range(0.0, 10.0, 0.1) = 2.0;
```

未显式覆盖的参数随 shader 热重载更新；一旦 `SetShaderParameter` 赋过值就固定下来，
`RemoveShaderParameter("name")` 解除覆盖、回到 shader 当前默认值。克隆材质保留这层关系。

支持 `bool/int/uint/float`、`bvec/ivec/uvec/vec2..4`、`mat2..4` 与固定长度数组。
未写默认值时数值为 0、布尔为 false、矩阵为单位矩阵。uniform 数组不能写初始化表达式，值由材质提供。

使用引擎现有材质参数类型：特殊向量用 Vector2/3/4，布尔分量为 0/1；mat2 用按行排列的
Vector4，mat3/4 用 Matrix3/4；数组使用包含连续 float 的 VectorBuffer。

```glsl
uniform uint ids[2];
uniform bvec3 enabled_axes;
uniform mat2 basis;
```

```lua
assert(material:SetSurfaceShader("Shaders/BLGL/Example.shader"))
local ids = VectorBuffer()
ids:WriteFloat(7)
ids:WriteFloat(19)
material:SetShaderParameter("ids", ids)
material:SetShaderParameter("enabled_axes", Vector3(1, 0, 1))
material:SetShaderParameter("basis", Vector4(1, 3, 2, 4)) -- Rows; shader columns are (1,2), (3,4).
```

所有值保存在 Material 的普通参数容器中，Getter 返回引擎参数表示；没有单独的 SurfaceShader
打包缓存或 Lua table 转换规则。普通参数可在选择 shader 前后设置。数组每元素紧密排列：
标量 1、向量 N、mat2/3/4 为 4/9/16 个 float，矩阵按行排列，不补齐 vec4。
类型和 Buffer 长度由调用方保证。整数数组写 float 数值，不能使用 WriteInt 写入位模式。

整数 uniform 沿用引擎的浮点传输，连续整数精确范围为 [-16777216,16777216]，uint 为非负部分；
超出范围可能舍入，不保证完整 32-bit 精度。shader 内的整数常量和运算仍保持整数类型。
无固定 64 vec4 声明预算；活动参数仍受真实后端容量约束。CPU 数组默认值分配会检查字节长度溢出。

`ClearShaderParameters()` 清除覆盖并恢复默认值；`ClearUnusedShaderParameters()` 保留已声明参数。
`Save(path)` 保存 XML，`SaveJSON(path)` 保存 JSON；也支持 JSONValue 接口。
保存恢复沿用原生 Variant/Buffer 表示与显式覆盖关系。

多数 gameplay 脚本只需要使用默认值。固定不变的覆盖值写在材质 XML 的 `<parameter>` 里；只有运行时才变化的
参数才用 Lua，直接使用 shader 源码里的 uniform 名：

```lua
material:SetShaderParameter("pulse_speed", Variant(4.0))
material:SetShaderParameter("tint_color", Variant(Color(1.0, 0.2, 0.1, 1.0)))
```

贴图不要用 `SetShaderParameter()`，贴图统一使用：

```lua
material:SetSurfaceTexture("albedo_map", texture)
-- Remove the override and use the shader's current fallback texture.
material:SetSurfaceTexture("albedo_map", nil)
```

基础读屏沿用引擎现有路径：

```glsl
shader_type spatial;
render_mode unshaded;
uniform sampler2D screen_color : hint_screen_texture;
void fragment() {
    ALBEDO = texture(screen_color, SCREEN_UV).rgb;
}
```

屏幕颜色没有 mip 链，`textureLod(screen_color, SCREEN_UV, 3.0)` 拿不到模糊结果。
对屏幕与深度纹理声明 filter 或 repeat hint 无效。

普通材质自有贴图的采样过滤通过原有 TextureSettings 机制控制，多个材质可使用不同设置：

| Hint | mip 内过滤 | mip 选择 |
|------|------------|----------|
| `filter_nearest` | 最近点 | 固定 0，显式 textureLod 也受限制 |
| `filter_linear` | 双线性 | 固定 0 |
| `filter_nearest_mipmap` | 最近点 | 相邻 mip 线性混合 |
| `filter_linear_mipmap` | 双线性 | 相邻 mip 线性混合（三线性） |

`repeat_enable` 循环 UV，`repeat_disable` 钳制边界；省略 hint 继承纹理设置。
还支持 `filter_linear_mipmap_anisotropic`，级别取纹理自身的 `SetAnisotropy`，0 表示用默认级别。
这项过滤与 BRDF 的 `ANISOTROPY` 无关。

未绑定的普通 float sampler 默认采白纹理；`hint_default_black` 为黑色、不透明，
`hint_default_transparent` 为透明黑。2D `hint_normal`/`hint_roughness_normal` 默认采
RGBA8 `(128,128,255,255)`，`hint_anisotropy` 默认采 `(255,128,255,255)`。
这些默认资源保持线性。

默认资源支持 `sampler2D`、`samplerCube`、`sampler3D`、`sampler2DArray`。
热重载改变 sampler 顺序时，显式纹理按名称保留。
普通材质贴图的 `SetTextureSetting()` 显式设置优先于 shader hint，重新应用、热重载和克隆均保留；
未覆盖的 sampler 设置随 shader 更新。
`ClearTextures()` 清理贴图和 sampler 覆盖并恢复默认值，
保留 Technique、剔除状态、FillMode 和材质参数。
未绑定 sampler 使用引擎共享的默认纹理，不会写入材质存档。
`GetSurfaceTexture()` 返回材质覆盖或 Technique 默认纹理；传入空纹理解除覆盖。
通用 `GetTexture()` 仍只查询材质自身的贴图，未显式设置时可以为空。

---

## 推荐模板

### 不透明 PBR 贴图材质

```glsl
shader_type spatial;
render_mode shading_model_pbr, cull_back;

uniform sampler2D albedo_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear, repeat_enable;
uniform sampler2D orm_map : hint_default_white, filter_linear, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
    vec4 base = texture(albedo_map, UV) * tint;
    vec3 normal_sample = texture(normal_map, UV).rgb;
    vec4 orm = texture(orm_map, UV);

    ALBEDO = base.rgb;
    AO = orm.r;
    ROUGHNESS = orm.g;
    METALLIC = orm.b;
    NORMAL_MAP = normal_sample;
}
```

### 无光照特效材质

```glsl
shader_type spatial;
render_mode shading_model_unlit, blend_mix, cull_disabled, depth_draw_never;

uniform sampler2D mask_map : hint_default_white, filter_linear, repeat_enable;
uniform vec4 color_a : source_color = vec4(0.0, 0.6, 1.0, 0.2);
uniform vec4 color_b : source_color = vec4(1.0, 1.0, 1.0, 0.8);

void fragment() {
    float mask = texture(mask_map, UV).r;
    vec4 color = mix(color_a, color_b, mask);
    ALBEDO = color.rgb;
    ALPHA = color.a;
}
```

---

## 当前不要使用

这些能力不是 gameplay Lua 层当前应使用的 Surface Shader v1 范围：

| 不要使用 | 替代做法 |
|----------|----------|
| `shader_type canvas_item` / `particles` / `sky` / `fog` | 只用 `shader_type spatial` |
| normal-roughness texture | 暂不作为 v1 gameplay shader 输入 |
| 手写底层 sampler 槽位名 | 用源码 sampler 名 + `<surfacetexture>` 或 `SetSurfaceTexture()` |
| 材质 XML 里手写 `<texture unit="...">` 绑 SurfaceShader 贴图 | 用 `<surfacetexture name="<sampler名>">` |
| 依赖生成后的 `.glsl` 文件路径 | 只引用自己的 `.shader` 文件 |

---

## 调试清单

1. `SetSurfaceShader()` 返回 `false`：检查 `.shader` 路径是否是 `Shaders/BLGL/xxx.shader`，以及文件是否在项目 `assets/` 资源目录下。
2. 贴图没生效：检查 `<surfacetexture name="...">` 或 `SetSurfaceTexture("name", texture)` 里的 `"name"` 是否和
   shader 中 `uniform sampler2D name` 完全一致；sampler 名写错不会报错。
3. 写了 `ALPHA` 但不透明：检查 `render_mode` 是否包含 `blend_mix`。
4. PBR 看起来太黑：确认场景有 LightGroup 或灯光/Zone；无光照效果请用 `shading_model_unlit`。
5. shader 编译失败：先简化到最小 `ALBEDO` 输出，再逐步加回贴图、uniform 和顶点动画。
6. `cache:GetResource("Material", ...)` 返回 `nil`：材质 XML 里的 `<surfaceshader name="...">` 没加载成功，
   日志会给出失败的 `.shader` 路径；SurfaceShader 失败不会退回 `<technique>`。
7. 材质 XML 里的贴图整段没生效：确认文件里有 `<surfaceshader>`，缺它时所有 `<surfacetexture>` 都被忽略。

### 背光、轮廓光与 Clearcoat

`BACKLIGHT` 默认 `vec3(0)`，只影响直接光，受灯色、衰减、阴影与 `AO_LIGHT_AFFECT` 影响。
`RIM` 与 `RIM_TINT` 默认 0，轮廓宽度由 ROUGHNESS 决定，只走直接光，不是 IBL。
写了 `light()` 后这两项由你自己求值。

桌面延迟的普通 PBR 已支持 `BACKLIGHT`，可与 `cull_disabled`、Alpha Scissor 和材质 `AO`
组合，用于叶片、草、纸或布。它沿用前向的逐灯透光公式，不是 TwoSidedFoliage 模型；
不会在无灯时自行发光，也不会增加金属部分的透光。使用非负 RGB，允许强度大于 1；
延迟存储有量化误差，负分量按 0 处理。
移动延迟，以及与 ClearCoat、Toon、`AO_LIGHT_AFFECT`、自定义 `light()` 等尚不兼容的组合，
仍会给出不支持延迟的诊断，没有自动前向兜底。前向用法保持不变。

Toon 的 RIM 继承 Zone 设置：写 `RIM=0.5` 是设定强度，`RIM *= 0.5` 是把继承值减半，
不写则保留继承值。这与 Godot 不同，Godot 没有 Zone 这一层。

PBR 下写 `CLEARCOAT` / `CLEARCOAT_ROUGHNESS` 会自动启用清漆，无需显式 `shading_model_clearcoat`。
`NORMAL_MAP` 只扰动底层法线，直接写 `NORMAL` 会同时影响顶层。

### 独立 Toon 光照项

`diffuse_toon` 与 `specular_toon` 可以各自单独使用，也可以合用得到完整 Toon 效果；
`shading_model_toon` 是等价的完整入口。Toon 只支持不透明。

`specular_disabled` 只关闭直接光高光，环境反射仍消费 `SPECULAR`。

### 各向异性输出

`ANISOTROPY` 默认 0，范围 −1～1；`ANISOTROPY_FLOW` 默认 `(1,0)`，零向量回退默认方向。
**与 Godot 的差异**：正负强度都会应用 flow。强度为 0 时仍是普通 GGX；flow 只改高光方向，
不旋转法线贴图。流向贴图要自己把 RG 从 0～1 解码到 −1～1。

### 材质雾

`FOG` 是可写 vec4，RGB 为线性雾颜色，A 为不透明度。写入它会替代材质的距离/高度雾：
`color = color * (1 - FOG.a) + FOG.rgb * FOG.a`；默认 vec4(0)，`fog_disabled` 跳过合成。
它在 PREMUL_ALPHA_FACTOR 之前执行，附加灯只乘透射率，不重复叠加雾色。
全屏雾与体积雾不受 `FOG` 影响。

`blend_mix` 写入目标 Alpha 采用 source-over，透明度 0.5 的两层累计 Alpha 为 0.75。

### 材质环境输入

`RADIANCE` 和 `IRRADIANCE` 均为可写 vec4：RGB 是线性环境输入，A 是替换权重；默认 0 继承，
1 替换。分别在环境镜面/漫反射采样后混合，然后执行 AO 与材质 BRDF。`ambient_light_disabled`
关闭两者，`specular_occlusion_disabled` 仅跳过镜面 AO。它们不属于直接光，也不是 EMISSION。

没有环境贴图时也可以只靠这两个输入提供环境光。需要平坦 Zone 环境色时设置
`zone:SetAmbientSource(AMBIENT_COLOR)`，默认 SH/IBL 模式不把 `zone.ambientColor` 当平坦颜色用。

#### 纹理槽位与可组合数量

材质 sampler 上限是桌面 8、移动与 Web 6。用了 screen 或 depth hint 会占掉 0/1 两个槽位，
上限相应降到 6/4。环境反射与蒙皮也各占槽位，声明过多 sampler 会编译失败。

#### 纹理用途 hint 的导入边界

`hint_normal`、`hint_anisotropy`、`hint_roughness_*` 只决定未绑定时的兜底纹理。

#### 局部矩阵与结构体构造

`mat2/3/4` 与矩阵 uniform 保持相同的列约定：用列向量构造，单标量构造对角矩阵，跨尺寸转换保留
左上部分并用单位矩阵补齐。矩阵直接赋值为拷贝，访问顺序为 `m[column][row]`。
列、分量和 swizzle 支持赋值及合法的复合操作；带副作用的索引只计算一次。

```glsl
mat3 basis = mat3(vec3(1.0, 2.0, 0.0), vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0));
basis[1].xz = vec2(3.0, 4.0);
mat4 transform = mat4(basis);
vec3 restored = inverse(basis) * (basis * vec3(0.5, 0.25, 1.0));
```

保留 Godot 前端的构造限制：矩阵用列向量构造；同尺寸复制使用 `mat3 copy = basis`。
矩阵元素作为 out 实参被前端拒绝时，先用普通局部变量接收，再写回该元素。
