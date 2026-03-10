-- DRJ_Prefs.lua (Build 42.12.3, SP)
-- Purpose: INI read/write + ReportWindow state helpers (extracted from DRJ.lua)
-- Safe Alternative — This is a clean extraction that mirrors the prior inline helpers.
-- No behavior change expected in SP.

local M = {}

local INI_DIR  = "TransmogDE" -- folder in Zomboid/mods save area
local INI_FILE = "settings.ini"
local INI_PATH = INI_DIR .. "/" .. INI_FILE
local KEEP     = ".keep"

local function getWinKey(win)
    winType = win.Type or "DefaultWin"
    return winType .. "."
end

local function createFolder(dir)
    local file = dir .. "/" .. KEEP
    local w = getFileWriter(file, true, false); if not w then return end
    w:close()
end

local function _ensureDir()
    createFolder(INI_DIR)
end

local function _readAll()
    _ensureDir()
    local r = getFileReader(INI_PATH, true); if not r then return {} end
    local t = {}
    while true do
        local line = r:readLine(); if not line then break end
        line = line:gsub("%s*#.*$", "") -- strip comments
        local k, v = line:match("^%s*([^=]+)%s*=%s*(.-)%s*$")
        if k then t[k] = v end
    end
    r:close(); return t
end

local function _writeAll(tbl)
    _ensureDir()
    local w = getFileWriter(INI_PATH, true, false); if not w then return end
    for k, v in pairs(tbl) do
        w:write(("%s=%s\n"):format(tostring(k), tostring(v)))
    end
    w:close()
end

function M.get(key, default)
    local t = _readAll(); local v = t[key]
    if v == nil then return default end
    if v == "true" or v == "false" then return v == "true" end
    local n = tonumber(v); return n or v
end

function M.set(key, value)
    local t = _readAll()
    if type(value) == "boolean" then
        t[key] = value and "true" or "false"
    else
        t[key] = tostring(value)
    end
    _writeAll(t)
end

function M.clampToScreen(x, y, w, h)
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    return math.max(0, math.min(x, sw - w)), math.max(0, math.min(y, sh - h))
end

-- Window state helpers
function M.saveWindowState(win)
    local winKey = getWinKey(win)
    M.set(winKey.."winX",   math.floor(win:getX()))
    M.set(winKey.."winY",   math.floor(win:getY()))
end

function M.restoreWindowStateOrCenter(win)
    local winKey = getWinKey(win)
    local w, h = win:getWidth(), win:getHeight()
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()

    local x = tonumber(M.get(winKey.."winX", nil))
    local y = tonumber(M.get(winKey.."winY", nil))
    if x and y then
        x, y = M.clampToScreen(x, y, w, h)
    else
        x = sw/4 - w/2; y = sh/2 - h/2
    end
    win:setX(x); win:setY(y)
end

return M
