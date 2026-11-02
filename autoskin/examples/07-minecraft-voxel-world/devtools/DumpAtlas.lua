-- ====================================================================
-- devtools/DumpAtlas.lua
-- 图集导出工具 - 把材质包生成的图集存成 PNG，方便肉眼/AI 检查每个 tile
--
-- 用法（headless 即可，不需要 GPU）：
--   UrhoXRuntime.exe devtools/DumpAtlas.lua -tapcode_dir=<Minecraft 目录> \
--       -skip_login -graphicsheadless
--
-- 产物（引擎沙盒目录，日志里会打印绝对路径）：
--   atlas_classic.png / atlas_hd_diffuse.png / atlas_hd_normal.png / atlas_hd_specular.png
-- ====================================================================

local ClassicPack = require("rendering.texturepacks.ClassicPack")
local HDPack = require("rendering.texturepacks.HDPack")
local Atlas = require("rendering.texturepacks.AtlasLayout")

---把 Image 存成 PNG（沙盒可写目录）
---@param image Image
---@param name string 文件名
local function save(image, name)
    local dir = fileSystem:GetAppPreferencesDir("urhox", "atlas")
    if not fileSystem:DirExists(dir) then
        fileSystem:CreateDir(dir)
    end
    local path = dir .. name
    if image:SavePNG(path) then
        print("[DumpAtlas] saved " .. path)
    else
        print("[DumpAtlas] FAILED to save " .. path)
    end
end

function Start()
    print(string.format("[DumpAtlas] layout: %d tiles", Atlas.count()))

    -- Classic：单张 diffuse
    save(ClassicPack:createImage(), "atlas_classic.png")

    -- HD：diffuse + normal + specular 三张
    local hdImages = HDPack.createImages and HDPack:createImages() or nil
    if hdImages then
        save(hdImages.diffuse, "atlas_hd_diffuse.png")
        save(hdImages.normal, "atlas_hd_normal.png")
        save(hdImages.specular, "atlas_hd_specular.png")
    else
        print("[DumpAtlas] HDPack:createImages() unavailable, skipped HD dump")
    end

    print("[DumpAtlas] done")
    engine:Exit()
end

function Stop()
end
