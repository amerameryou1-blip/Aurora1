-- Aurora Click Recorder v6.0 - Loader
-- Run this in your executor. It fetches all modules from GitHub.

local BASE = "https://raw.githubusercontent.com/amerameryou1-blip/Aurora1/main/ClickRecorder/"

local function fetch(name)
    local url = BASE .. name
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if not ok then
        warn("[Aurora] Failed to load " .. name .. ": " .. tostring(result))
        return nil
    end
    return result
end

-- Load in order: Stealth first, then GUI, then Logic
local Stealth = fetch("Stealth.lua")
if Stealth then
    Stealth.init()
end

local GUI = fetch("GUI.lua")
if not GUI then
    warn("[Aurora] GUI failed to load. Aborting.")
    return
end

local Logic = fetch("Logic.lua")
if not Logic then
    warn("[Aurora] Logic failed to load. Aborting.")
    return
end

local ok = Logic.init(GUI, Stealth)
if ok then
    print("[Aurora] Click Recorder v6.0 loaded successfully.")
else
    warn("[Aurora] Logic init failed.")
end
