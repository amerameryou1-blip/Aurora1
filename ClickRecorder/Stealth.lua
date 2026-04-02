-- Aurora Click Recorder v6.0 - Stealth Module
-- Clean anti-detection · environment isolation · connection safety

local Stealth = { _VERSION = "6.0" }

-- ─── Executor Detection ──────────────────────────────
local exec = { name = "unknown", isDelta = false, features = {} }
pcall(function()
    exec.name = identifyexecutor()
    exec.isDelta = exec.name:lower():find("delta") ~= nil
end)
exec.features = {
    gethui            = gethui ~= nil,
    sethiddenproperty = sethiddenproperty ~= nil,
    hookmetamethod    = hookmetamethod ~= nil,
    newcclosure       = newcclosure ~= nil,
    checkcaller       = checkcaller ~= nil,
}
Stealth.executor = exec

-- ─── System Name Generator ───────────────────────────
local SYS = {
    "CoreScript","PlayerModule","CameraScript","ControlModule",
    "ChatService","BubbleChat","TouchController","GamepadMenu",
    "PerformanceStats","BackpackScript","HealthScript","TopBarApp",
    "EmotesMenu","ScreenshotHud","VoiceChatUI","SettingsHub",
}
function Stealth.sysName()
    return SYS[math.random(#SYS)] .. "_" .. string.format("%04X", math.random(0, 0xFFFF))
end

-- ─── Environment Isolation ───────────────────────────
-- Every key stored in getgenv is randomised so scanning
-- scripts can not find our globals by name.
local Env = {}
local _keyMap, _fallback = {}, {}

local function mapped(k)
    if not _keyMap[k] then
        _keyMap[k] = "rx_" .. string.format("%08x", math.random(0, 0x7FFFFFFF))
    end
    return _keyMap[k]
end

function Env.set(k, v)
    local mk = mapped(k)
    if getgenv then getgenv()[mk] = v else _fallback[mk] = v end
end
function Env.get(k)
    local mk = mapped(k)
    if getgenv then return getgenv()[mk] end
    return _fallback[mk]
end
function Env.del(k)
    local mk = mapped(k)
    if getgenv then getgenv()[mk] = nil end
    _fallback[mk] = nil
end
function Env.flush()
    for _, mk in pairs(_keyMap) do
        if getgenv then getgenv()[mk] = nil end
        _fallback[mk] = nil
    end
    _keyMap = {}
end
Stealth.Env = Env

-- ─── GUI Protection ──────────────────────────────────
local GuiShield = {}

function GuiShield.parent(gui)
    if not gui then return false end
    -- Best: hidden container (invisible to game scripts)
    if gethui then
        local ok = pcall(function() gui.Parent = gethui() end)
        if ok and gui.Parent then return true end
    end
    -- Fallback: CoreGui
    pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if gui.Parent then return true end
    -- Last resort: PlayerGui
    pcall(function()
        gui.Parent = game:GetService("Players").LocalPlayer
            :WaitForChild("PlayerGui", 5)
    end)
    return gui.Parent ~= nil
end

function GuiShield.configure(gui)
    if not gui then return end
    gui.Name = Stealth.sysName()
    gui.ResetOnSpawn = false
    if sethiddenproperty then
        pcall(function() sethiddenproperty(gui, "OnTopOfCoreBlur", true) end)
    end
end

function GuiShield.destroyPrevious()
    local prev = Env.get("gui_ref")
    if prev and typeof(prev) == "Instance" then
        pcall(function() prev:Destroy() end)
    end
    Env.del("gui_ref")
end

Stealth.GuiShield = GuiShield

-- ─── Connection Pool ─────────────────────────────────
-- Tracks every RBXScriptConnection so we can mass-disconnect
-- on reload or destroy without leaking listeners.
local Pool = {}
local _conns = {}

function Pool.add(label, conn)
    if _conns[label] then pcall(function() _conns[label]:Disconnect() end) end
    _conns[label] = conn
    return conn
end
function Pool.remove(label)
    if _conns[label] then
        pcall(function() _conns[label]:Disconnect() end)
        _conns[label] = nil
    end
end
function Pool.clear()
    for _, c in pairs(_conns) do pcall(function() c:Disconnect() end) end
    _conns = {}
end
function Pool.count()
    local n = 0
    for _ in pairs(_conns) do n = n + 1 end
    return n
end
Stealth.Pool = Pool

-- ─── Lifecycle ───────────────────────────────────────
function Stealth.init()
    Pool.clear()
    GuiShield.destroyPrevious()
    return exec
end

function Stealth.destroy()
    Pool.clear()
    GuiShield.destroyPrevious()
    Env.flush()
end

return Stealth
