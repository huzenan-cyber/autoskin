---@meta

--- Auto-generated from UI/NanoVGEnums

---@alias NVGwinding
---| integer # NVGwinding enum values

---@type NVGwinding
NVG_CCW = 1
---@type NVGwinding
NVG_CW = 2

---@alias NVGsolidity
---| integer # NVGsolidity enum values

---@type NVGsolidity
NVG_SOLID = 1
---@type NVGsolidity
NVG_HOLE = 2

---@alias NVGlineCap
---| integer # NVGlineCap enum values

---@type NVGlineCap
NVG_BUTT = NVG_BUTT
---@type NVGlineCap
NVG_ROUND = NVG_ROUND
---@type NVGlineCap
NVG_SQUARE = NVG_SQUARE
---@type NVGlineCap
NVG_BEVEL = NVG_BEVEL
---@type NVGlineCap
NVG_MITER = NVG_MITER

---@alias NVGalign
---| integer # NVGalign enum values

---@type NVGalign
NVG_ALIGN_LEFT = 1<<0
---@type NVGalign
NVG_ALIGN_CENTER = 1<<1
---@type NVGalign
NVG_ALIGN_RIGHT = 1<<2
---@type NVGalign
NVG_ALIGN_CENTER_VISUAL = 1<<7
---@type NVGalign
NVG_ALIGN_TOP = 1<<3
---@type NVGalign
NVG_ALIGN_MIDDLE = 1<<4
---@type NVGalign
NVG_ALIGN_BOTTOM = 1<<5
---@type NVGalign
NVG_ALIGN_BASELINE = 1<<6

---@alias NVGblendFactor
---| integer # NVGblendFactor enum values

---@type NVGblendFactor
NVG_ZERO = 1<<0
---@type NVGblendFactor
NVG_ONE = 1<<1
---@type NVGblendFactor
NVG_SRC_COLOR = 1<<2
---@type NVGblendFactor
NVG_ONE_MINUS_SRC_COLOR = 1<<3
---@type NVGblendFactor
NVG_DST_COLOR = 1<<4
---@type NVGblendFactor
NVG_ONE_MINUS_DST_COLOR = 1<<5
---@type NVGblendFactor
NVG_SRC_ALPHA = 1<<6
---@type NVGblendFactor
NVG_ONE_MINUS_SRC_ALPHA = 1<<7
---@type NVGblendFactor
NVG_DST_ALPHA = 1<<8
---@type NVGblendFactor
NVG_ONE_MINUS_DST_ALPHA = 1<<9
---@type NVGblendFactor
NVG_SRC_ALPHA_SATURATE = 1<<10

---@alias NVGcompositeOperation
---| integer # NVGcompositeOperation enum values

---@type NVGcompositeOperation
NVG_SOURCE_OVER = NVG_SOURCE_OVER
---@type NVGcompositeOperation
NVG_SOURCE_IN = NVG_SOURCE_IN
---@type NVGcompositeOperation
NVG_SOURCE_OUT = NVG_SOURCE_OUT
---@type NVGcompositeOperation
NVG_ATOP = NVG_ATOP
---@type NVGcompositeOperation
NVG_DESTINATION_OVER = NVG_DESTINATION_OVER
---@type NVGcompositeOperation
NVG_DESTINATION_IN = NVG_DESTINATION_IN
---@type NVGcompositeOperation
NVG_DESTINATION_OUT = NVG_DESTINATION_OUT
---@type NVGcompositeOperation
NVG_DESTINATION_ATOP = NVG_DESTINATION_ATOP
---@type NVGcompositeOperation
NVG_LIGHTER = NVG_LIGHTER
---@type NVGcompositeOperation
NVG_COPY = NVG_COPY
---@type NVGcompositeOperation
NVG_XOR = NVG_XOR

---@alias NVGimageFlags
---| integer # NVGimageFlags enum values

---@type NVGimageFlags
NVG_IMAGE_GENERATE_MIPMAPS = 1<<0
---@type NVGimageFlags
NVG_IMAGE_REPEATX = 1<<1
---@type NVGimageFlags
NVG_IMAGE_REPEATY = 1<<2
---@type NVGimageFlags
NVG_IMAGE_FLIPY = 1<<3
---@type NVGimageFlags
NVG_IMAGE_PREMULTIPLIED = 1<<4
---@type NVGimageFlags
NVG_IMAGE_NEAREST = 1<<5

---@alias NVGColorSpace
---| integer # NVGColorSpace enum values

---@type NVGColorSpace
NVG_COLOR_GAMMA = 0
---@type NVGColorSpace
NVG_COLOR_LINEAR = NVG_COLOR_LINEAR
