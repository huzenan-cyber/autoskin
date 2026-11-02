---@meta

--- Auto-generated from Graphics/GraphicsDefs

---@alias PrimitiveType
---| integer # PrimitiveType enum values

---@type PrimitiveType
TRIANGLE_LIST = 0
---@type PrimitiveType
LINE_LIST = LINE_LIST
---@type PrimitiveType
POINT_LIST = POINT_LIST
---@type PrimitiveType
TRIANGLE_STRIP = TRIANGLE_STRIP
---@type PrimitiveType
LINE_STRIP = LINE_STRIP
---@type PrimitiveType
TRIANGLE_FAN = TRIANGLE_FAN

---@alias GeometryType
---| integer # GeometryType enum values

---@type GeometryType
GEOM_STATIC = 0
---@type GeometryType
GEOM_SKINNED = 1
---@type GeometryType
GEOM_INSTANCED = 2
---@type GeometryType
GEOM_BILLBOARD = 3
---@type GeometryType
GEOM_STATIC_NOINSTANCING = 11
---@type GeometryType
MAX_GEOMETRYTYPES = 10

---@alias BlendMode
---| integer # BlendMode enum values

---@type BlendMode
BLEND_REPLACE = 0
---@type BlendMode
BLEND_ADD = BLEND_ADD
---@type BlendMode
BLEND_MULTIPLY = BLEND_MULTIPLY
---@type BlendMode
BLEND_ALPHA = BLEND_ALPHA
---@type BlendMode
BLEND_ADDALPHA = BLEND_ADDALPHA
---@type BlendMode
BLEND_PREMULALPHA = BLEND_PREMULALPHA
---@type BlendMode
BLEND_INVDESTALPHA = BLEND_INVDESTALPHA
---@type BlendMode
BLEND_SUBTRACT = BLEND_SUBTRACT
---@type BlendMode
BLEND_SUBTRACTALPHA = BLEND_SUBTRACTALPHA
---@type BlendMode
MAX_BLENDMODES = MAX_BLENDMODES

---@alias CompareMode
---| integer # CompareMode enum values

---@type CompareMode
CMP_ALWAYS = 0
---@type CompareMode
CMP_EQUAL = CMP_EQUAL
---@type CompareMode
CMP_NOTEQUAL = CMP_NOTEQUAL
---@type CompareMode
CMP_LESS = CMP_LESS
---@type CompareMode
CMP_LESSEQUAL = CMP_LESSEQUAL
---@type CompareMode
CMP_GREATER = CMP_GREATER
---@type CompareMode
CMP_GREATEREQUAL = CMP_GREATEREQUAL
---@type CompareMode
MAX_COMPAREMODES = MAX_COMPAREMODES

---@alias CullMode
---| integer # CullMode enum values

---@type CullMode
CULL_NONE = 0
---@type CullMode
CULL_CCW = CULL_CCW
---@type CullMode
CULL_CW = CULL_CW
---@type CullMode
MAX_CULLMODES = MAX_CULLMODES

---@alias FillMode
---| integer # FillMode enum values

---@type FillMode
FILL_SOLID = 0
---@type FillMode
FILL_WIREFRAME = FILL_WIREFRAME
---@type FillMode
FILL_POINT = FILL_POINT

---@alias StencilOp
---| integer # StencilOp enum values

---@type StencilOp
OP_KEEP = 0
---@type StencilOp
OP_ZERO = OP_ZERO
---@type StencilOp
OP_REF = OP_REF
---@type StencilOp
OP_INCR = OP_INCR
---@type StencilOp
OP_DECR = OP_DECR

---@alias LockState
---| integer # LockState enum values

---@type LockState
LOCK_NONE = 0
---@type LockState
LOCK_HARDWARE = LOCK_HARDWARE
---@type LockState
LOCK_SHADOW = LOCK_SHADOW
---@type LockState
LOCK_SCRATCH = LOCK_SCRATCH

---@alias LegacyVertexElement
---| integer # LegacyVertexElement enum values

---@type LegacyVertexElement
ELEMENT_POSITION = 0
---@type LegacyVertexElement
ELEMENT_NORMAL = ELEMENT_NORMAL
---@type LegacyVertexElement
ELEMENT_COLOR = ELEMENT_COLOR
---@type LegacyVertexElement
ELEMENT_TEXCOORD1 = ELEMENT_TEXCOORD1
---@type LegacyVertexElement
ELEMENT_TEXCOORD2 = ELEMENT_TEXCOORD2
---@type LegacyVertexElement
ELEMENT_CUBETEXCOORD1 = ELEMENT_CUBETEXCOORD1
---@type LegacyVertexElement
ELEMENT_CUBETEXCOORD2 = ELEMENT_CUBETEXCOORD2
---@type LegacyVertexElement
ELEMENT_TANGENT = ELEMENT_TANGENT
---@type LegacyVertexElement
ELEMENT_BLENDWEIGHTS = ELEMENT_BLENDWEIGHTS
---@type LegacyVertexElement
ELEMENT_BLENDINDICES = ELEMENT_BLENDINDICES
---@type LegacyVertexElement
ELEMENT_INSTANCEMATRIX1 = ELEMENT_INSTANCEMATRIX1
---@type LegacyVertexElement
ELEMENT_INSTANCEMATRIX2 = ELEMENT_INSTANCEMATRIX2
---@type LegacyVertexElement
ELEMENT_INSTANCEMATRIX3 = ELEMENT_INSTANCEMATRIX3
---@type LegacyVertexElement
ELEMENT_OBJECTINDEX = ELEMENT_OBJECTINDEX
---@type LegacyVertexElement
MAX_LEGACY_VERTEX_ELEMENTS = MAX_LEGACY_VERTEX_ELEMENTS

---@alias VertexElementType
---| integer # VertexElementType enum values

---@type VertexElementType
TYPE_INT = 0
---@type VertexElementType
TYPE_FLOAT = TYPE_FLOAT
---@type VertexElementType
TYPE_VECTOR2 = TYPE_VECTOR2
---@type VertexElementType
TYPE_VECTOR3 = TYPE_VECTOR3
---@type VertexElementType
TYPE_VECTOR4 = TYPE_VECTOR4
---@type VertexElementType
TYPE_UBYTE4 = TYPE_UBYTE4
---@type VertexElementType
TYPE_UBYTE4_NORM = TYPE_UBYTE4_NORM
---@type VertexElementType
MAX_VERTEX_ELEMENT_TYPES = MAX_VERTEX_ELEMENT_TYPES

---@alias VertexElementSemantic
---| integer # VertexElementSemantic enum values

---@type VertexElementSemantic
SEM_POSITION = 0
---@type VertexElementSemantic
SEM_NORMAL = SEM_NORMAL
---@type VertexElementSemantic
SEM_BINORMAL = SEM_BINORMAL
---@type VertexElementSemantic
SEM_TANGENT = SEM_TANGENT
---@type VertexElementSemantic
SEM_TEXCOORD = SEM_TEXCOORD
---@type VertexElementSemantic
SEM_COLOR = SEM_COLOR
---@type VertexElementSemantic
SEM_BLENDWEIGHTS = SEM_BLENDWEIGHTS
---@type VertexElementSemantic
SEM_BLENDINDICES = SEM_BLENDINDICES
---@type VertexElementSemantic
SEM_OBJECTINDEX = SEM_OBJECTINDEX
---@type VertexElementSemantic
MAX_VERTEX_ELEMENT_SEMANTICS = MAX_VERTEX_ELEMENT_SEMANTICS

---@alias TextureFilterMode
---| integer # TextureFilterMode enum values

---@type TextureFilterMode
FILTER_NEAREST = 0
---@type TextureFilterMode
FILTER_BILINEAR = FILTER_BILINEAR
---@type TextureFilterMode
FILTER_TRILINEAR = FILTER_TRILINEAR
---@type TextureFilterMode
FILTER_ANISOTROPIC = FILTER_ANISOTROPIC
---@type TextureFilterMode
FILTER_NEAREST_ANISOTROPIC = FILTER_NEAREST_ANISOTROPIC
---@type TextureFilterMode
FILTER_DEFAULT = FILTER_DEFAULT
---@type TextureFilterMode
MAX_FILTERMODES = MAX_FILTERMODES

---@alias TextureAddressMode
---| integer # TextureAddressMode enum values

---@type TextureAddressMode
ADDRESS_WRAP = 0
---@type TextureAddressMode
ADDRESS_MIRROR = ADDRESS_MIRROR
---@type TextureAddressMode
ADDRESS_CLAMP = ADDRESS_CLAMP
---@type TextureAddressMode
ADDRESS_BORDER = ADDRESS_BORDER
---@type TextureAddressMode
MAX_ADDRESSMODES = MAX_ADDRESSMODES

---@alias TextureCoordinate
---| integer # TextureCoordinate enum values

---@type TextureCoordinate
COORD_U = 0
---@type TextureCoordinate
COORD_V = COORD_V
---@type TextureCoordinate
COORD_W = COORD_W
---@type TextureCoordinate
MAX_COORDS = MAX_COORDS

---@alias TextureUsage
---| integer # TextureUsage enum values

---@type TextureUsage
TEXTURE_STATIC = 0
---@type TextureUsage
TEXTURE_DYNAMIC = TEXTURE_DYNAMIC
---@type TextureUsage
TEXTURE_RENDERTARGET = TEXTURE_RENDERTARGET
---@type TextureUsage
TEXTURE_DEPTHSTENCIL = TEXTURE_DEPTHSTENCIL

---@alias CubeMapFace
---| integer # CubeMapFace enum values

---@type CubeMapFace
FACE_POSITIVE_X = 0
---@type CubeMapFace
FACE_NEGATIVE_X = FACE_NEGATIVE_X
---@type CubeMapFace
FACE_POSITIVE_Y = FACE_POSITIVE_Y
---@type CubeMapFace
FACE_NEGATIVE_Y = FACE_NEGATIVE_Y
---@type CubeMapFace
FACE_POSITIVE_Z = FACE_POSITIVE_Z
---@type CubeMapFace
FACE_NEGATIVE_Z = FACE_NEGATIVE_Z
---@type CubeMapFace
MAX_CUBEMAP_FACES = MAX_CUBEMAP_FACES

---@alias RenderSurfaceUpdateMode
---| integer # RenderSurfaceUpdateMode enum values

---@type RenderSurfaceUpdateMode
SURFACE_MANUALUPDATE = 0
---@type RenderSurfaceUpdateMode
SURFACE_UPDATEVISIBLE = SURFACE_UPDATEVISIBLE
---@type RenderSurfaceUpdateMode
SURFACE_UPDATEALWAYS = SURFACE_UPDATEALWAYS

---@alias ShaderType
---| integer # ShaderType enum values

---@type ShaderType
VS = 0
---@type ShaderType
PS = PS

---@alias BuiltinTexture
---| integer # BuiltinTexture enum values

---@type BuiltinTexture
BUILTIN_TEXTURE_NONE = 0
---@type BuiltinTexture
BUILTIN_TEXTURE_ENVIRONMENT_BRDF = BUILTIN_TEXTURE_ENVIRONMENT_BRDF

---@alias TextureUnit
---| integer # TextureUnit enum values

---@type TextureUnit
TU_DIFFUSE = 0
---@type TextureUnit
TU_ALBEDOBUFFER = 0
---@type TextureUnit
TU_NORMAL = 1
---@type TextureUnit
TU_NORMALBUFFER = 1
---@type TextureUnit
TU_SPECULAR = 2
---@type TextureUnit
TU_EMISSIVE = 3
---@type TextureUnit
TU_ENVIRONMENT = 4

---@alias FaceCameraMode
---| integer # FaceCameraMode enum values

---@type FaceCameraMode
FC_NONE = 0
---@type FaceCameraMode
FC_ROTATE_XYZ = FC_ROTATE_XYZ
---@type FaceCameraMode
FC_ROTATE_Y = FC_ROTATE_Y
---@type FaceCameraMode
FC_LOOKAT_XYZ = FC_LOOKAT_XYZ
---@type FaceCameraMode
FC_LOOKAT_Y = FC_LOOKAT_Y
---@type FaceCameraMode
FC_LOOKAT_MIXED = FC_LOOKAT_MIXED
---@type FaceCameraMode
FC_DIRECTION = FC_DIRECTION

---@alias ShadowQuality
---| integer # ShadowQuality enum values

---@type ShadowQuality
SHADOWQUALITY_SIMPLE_16BIT = 0
---@type ShadowQuality
SHADOWQUALITY_SIMPLE_24BIT = SHADOWQUALITY_SIMPLE_24BIT
---@type ShadowQuality
SHADOWQUALITY_PCF_16BIT = SHADOWQUALITY_PCF_16BIT
---@type ShadowQuality
SHADOWQUALITY_PCF_24BIT = SHADOWQUALITY_PCF_24BIT
---@type ShadowQuality
SHADOWQUALITY_VSM = SHADOWQUALITY_VSM
---@type ShadowQuality
SHADOWQUALITY_BLUR_VSM = SHADOWQUALITY_BLUR_VSM

---@alias VolumetricFogQuality
---| integer # VolumetricFogQuality enum values

---@type VolumetricFogQuality
VOLUMETRIC_FOG_QUALITY_LOW = 0
---@type VolumetricFogQuality
VOLUMETRIC_FOG_QUALITY_HIGH = VOLUMETRIC_FOG_QUALITY_HIGH
---@type VolumetricFogQuality
VOLUMETRIC_FOG_QUALITY_ULTRA = VOLUMETRIC_FOG_QUALITY_ULTRA

---@alias MaterialQuality
---| integer # MaterialQuality enum values

---@type MaterialQuality
QUALITY_LOW = QUALITY_LOW
---@type MaterialQuality
QUALITY_MEDIUM = QUALITY_MEDIUM
---@type MaterialQuality
QUALITY_HIGH = QUALITY_HIGH
---@type MaterialQuality
QUALITY_MAX = QUALITY_MAX

---@alias ClearTarget
---| integer # ClearTarget enum values

---@type ClearTarget
CLEAR_COLOR = CLEAR_COLOR
---@type ClearTarget
CLEAR_DEPTH = CLEAR_DEPTH
---@type ClearTarget
CLEAR_STENCIL = CLEAR_STENCIL

---@alias VertexMask
---| integer # VertexMask enum values

---@type VertexMask
MASK_NONE = MASK_NONE
---@type VertexMask
MASK_POSITION = MASK_POSITION
---@type VertexMask
MASK_NORMAL = MASK_NORMAL
---@type VertexMask
MASK_COLOR = MASK_COLOR
---@type VertexMask
MASK_TEXCOORD1 = MASK_TEXCOORD1
---@type VertexMask
MASK_TEXCOORD2 = MASK_TEXCOORD2
---@type VertexMask
MASK_CUBETEXCOORD1 = MASK_CUBETEXCOORD1
---@type VertexMask
MASK_CUBETEXCOORD2 = MASK_CUBETEXCOORD2
---@type VertexMask
MASK_TANGENT = MASK_TANGENT
---@type VertexMask
MASK_BLENDWEIGHTS = MASK_BLENDWEIGHTS
---@type VertexMask
MASK_BLENDINDICES = MASK_BLENDINDICES
---@type VertexMask
MASK_INSTANCEMATRIX1 = MASK_INSTANCEMATRIX1
---@type VertexMask
MASK_INSTANCEMATRIX2 = MASK_INSTANCEMATRIX2
---@type VertexMask
MASK_INSTANCEMATRIX3 = MASK_INSTANCEMATRIX3
---@type VertexMask
MASK_OBJECTINDEX = MASK_OBJECTINDEX

---@class VertexElement
---@overload fun(type: VertexElementType, semantic: VertexElementSemantic, index?: number, perInstance?: boolean): VertexElement
---@overload fun(): VertexElement
---@field type VertexElementType
---@field semantic VertexElementSemantic
---@field index number -- unsigned char
---@field perInstance boolean
---@field offset integer
VertexElement = {}

---@overload fun(self: VertexElement, type: VertexElementType, semantic: VertexElementSemantic, index?: number, perInstance?: boolean): VertexElement
---@overload fun(type: VertexElementType, semantic: VertexElementSemantic, index?: number, perInstance?: boolean): VertexElement
---@return VertexElement
function VertexElement.new() end


-- Global variables
---@type integer
MAX_MATERIAL_TEXTURE_UNITS = nil
