-- Aurora Click Recorder v6.0 - Logic Module
-- Flat event log · state machine · loop & speed · safe cancel
-- Fixes: path timing, finger tracking, cleanup, no duplicate code

-- ─── Duplicate Guard ─────────────────────────────────
if getgenv and getgenv()._AURORA_LOGIC_LOADED then
    return getgenv()._AURORA_LOGIC_API
end
if getgenv then getgenv()._AURORA_LOGIC_LOADED = true end

-- ─── Services ────────────────────────────────────────
local UIS         = game:GetService("UserInputService")
local GS          = game:GetService("GuiService")
local VIM         = game:GetService("VirtualInputManager")
local RunService  = game:GetService("RunService")
local Players     = game:GetService("Players")

local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
local isDelta  = false
pcall(function() isDelta = identifyexecutor():lower():find("delta") ~= nil end)

-- ─── Coordinate Calibration ─────────────────────────
local correction = Vector2.new(0, 0)
do
    task.wait(0.3)
    local inset = GS:GetGuiInset()

    if inset.Y < 1 and isMobile then
        local waited = 0
        while inset.Y < 1 and waited < 2 do
            task.wait(0.1)
            waited = waited + 0.1
            inset = GS:GetGuiInset()
        end
        if inset.Y < 1 then
            inset = Vector2.new(0, 54)
        end
    end

    correction = inset
end

local function corrected(x, y)
    return x + correction.X, y + correction.Y
end

-- ─── State ───────────────────────────────────────────
-- IDLE | RECORDING | REPLAYING
local _state       = "IDLE"
local _gui         = nil
local _stealth     = nil

-- Event log: flat chronological list
-- { {type="down"|"move"|"up"|"cam", t=number, x=number, y=number, finger=number, cf=table?}, ... }
local eventLog     = {}

-- Recording internals
local _conns       = {}         -- active signal connections
local _fingerMap   = {}         -- InputObject -> fingerId (for touch)
local _mouseState  = nil        -- { down=bool, finger=number } (for mouse)
local _fingerNext  = 0
local _lastPos     = {}         -- fingerId -> { x, y } for distance gating
local _lastCamCF   = nil
local _lastCamTime = 0
local _recStart    = 0

-- Replay internals
local _replayActive = false     -- flag checked by replay loop
local _replayFingers = {}       -- fingerId -> true (for cleanup)

-- ─── Virtual Input Wrappers ──────────────────────────
local function mDown(x, y)    pcall(function() VIM:SendMouseButtonEvent(x, y, 0, true, game, 1) end) end
local function mUp(x, y)      pcall(function() VIM:SendMouseButtonEvent(x, y, 0, false, game, 1) end) end
local function mMove(x, y)    pcall(function() VIM:SendMouseMoveEvent(x, y, game) end) end
local function tDown(x, y, f) pcall(function() VIM:SendTouchEvent(f, 0, x, y) end) end
local function tMove(x, y, f) pcall(function() VIM:SendTouchEvent(f, 2, x, y) end) end
local function tUp(x, y, f)   pcall(function() VIM:SendTouchEvent(f, 1, x, y) end) end

-- ─── Helpers ─────────────────────────────────────────
local function nextFinger()
    _fingerNext = _fingerNext + 1
    return _fingerNext
end

local function addEvent(typ, x, y, fid)
    -- Distance gate for move events (3px minimum)
    if typ == "move" and _lastPos[fid] then
        local lp = _lastPos[fid]
        local dx, dy = x - lp.x, y - lp.y
        if dx * dx + dy * dy < 9 then return end
    end

    _lastPos[fid] = (typ ~= "up") and { x = x, y = y } or nil

    table.insert(eventLog, {
        type   = typ,
        t      = tick(),
        x      = x,
        y      = y,
        finger = fid,
    })
end

local function addCamEvent()
    local cam = workspace.CurrentCamera
    if not cam then return end

    local now = tick()
    if now - _lastCamTime < 0.033 then return end  -- ~30 fps cap

    local cf = cam.CFrame
    if _lastCamCF then
        local dp = (cf.Position - _lastCamCF.Position).Magnitude
        if dp < 0.01 then return end
    end

    _lastCamCF   = cf
    _lastCamTime = now

    table.insert(eventLog, {
        type = "cam",
        t    = now,
        cf   = {
            px = cf.Position.X, py = cf.Position.Y, pz = cf.Position.Z,
            lx = cf.LookVector.X, ly = cf.LookVector.Y, lz = cf.LookVector.Z,
        },
    })
end

local function setCam(data)
    local cam = workspace.CurrentCamera
    if not cam or not data then return end
    local pos  = Vector3.new(data.px, data.py, data.pz)
    local look = Vector3.new(data.lx, data.ly, data.lz)
    cam.CFrame = CFrame.new(pos, pos + look)
end

-- ─── Connection Manager ──────────────────────────────
local function clearConns()
    for label, conn in pairs(_conns) do
        pcall(function() conn:Disconnect() end)
    end
    _conns = {}
end

local function addConn(label, conn)
    if _conns[label] then pcall(function() _conns[label]:Disconnect() end) end
    _conns[label] = conn
end

-- ─── Recording ───────────────────────────────────────
local function startRecording()
    if _state ~= "IDLE" then return end
    _state = "RECORDING"

    eventLog     = {}
    _fingerMap   = {}
    _mouseState  = nil
    _fingerNext  = 0
    _lastPos     = {}
    _lastCamCF   = nil
    _lastCamTime = 0
    _recStart    = tick()

    if _gui then
        _gui.setRecordState(true)
        _gui.setStatus("Recording...", Color3.fromRGB(239, 68, 68))
    end

    -- Input began
    addConn("rec_began", UIS.InputBegan:Connect(function(input, gp)
        if _state ~= "RECORDING" then return end

        local isM = input.UserInputType == Enum.UserInputType.MouseButton1
        local isT = input.UserInputType == Enum.UserInputType.Touch
        if not isM and not isT then return end

        local cx, cy = corrected(input.Position.X, input.Position.Y)

        -- Ignore clicks on our GUI
        if _gui and _gui.isOverGui(cx, cy) then return end

        local fid = nextFinger()
        if isT then
            _fingerMap[input] = fid
        else
            _mouseState = { down = true, finger = fid }
        end

        addEvent("down", cx, cy, fid)
    end))

    -- Input moved
    addConn("rec_changed", UIS.InputChanged:Connect(function(input, gp)
        if _state ~= "RECORDING" then return end

        local fid = nil
        if input.UserInputType == Enum.UserInputType.Touch then
            fid = _fingerMap[input]
        elseif input.UserInputType == Enum.UserInputType.MouseMovement then
            if _mouseState and _mouseState.down then
                fid = _mouseState.finger
            end
        end
        if not fid then return end

        local cx, cy = corrected(input.Position.X, input.Position.Y)
        if _gui and _gui.isOverGui(cx, cy) then return end

        addEvent("move", cx, cy, fid)
    end))

    -- Input ended
    addConn("rec_ended", UIS.InputEnded:Connect(function(input, gp)
        if _state ~= "RECORDING" then return end

        local fid = nil
        local isM = input.UserInputType == Enum.UserInputType.MouseButton1
        local isT = input.UserInputType == Enum.UserInputType.Touch
        if not isM and not isT then return end

        if isT then
            fid = _fingerMap[input]
            _fingerMap[input] = nil
        elseif _mouseState and _mouseState.down then
            fid = _mouseState.finger
            _mouseState.down = false
        end
        if not fid then return end

        local cx, cy = corrected(input.Position.X, input.Position.Y)
        addEvent("up", cx, cy, fid)
    end))

    -- Camera tracking
    addConn("rec_cam", RunService.RenderStepped:Connect(function()
        if _state ~= "RECORDING" then return end
        addCamEvent()
    end))

    -- Live counter
    addConn("rec_hud", RunService.Heartbeat:Connect(function()
        if _state ~= "RECORDING" or not _gui then return end
        local elapsed = tick() - _recStart
        local m = math.floor(elapsed / 60)
        local s = elapsed % 60
        _gui.setStatus(
            string.format("Recording %d:%04.1f  ·  %d events", m, s, #eventLog),
            Color3.fromRGB(239, 68, 68)
        )
    end))
end

local function stopRecording()
    if _state ~= "RECORDING" then return end
    _state = "IDLE"
    clearConns()
    _fingerMap = {}
    _mouseState = nil
    _lastPos = {}

    if _gui then
        _gui.setRecordState(false)
        _gui.setStatus(#eventLog .. " events saved", Color3.fromRGB(245, 158, 11))
    end
end

-- ─── Replay ──────────────────────────────────────────
local function startReplay()
    if _state ~= "IDLE" then return end
    if #eventLog == 0 then
        if _gui then _gui.setStatus("Nothing to replay", Color3.fromRGB(245, 158, 11)) end
        return
    end

    _state = "REPLAYING"
    _replayActive  = true
    _replayFingers = {}

    if _gui then
        _gui.setReplayState(true)
        _gui.setStatus("Replaying...", Color3.fromRGB(34, 197, 94))
    end

    task.spawn(function()
        local log = eventLog
        local total = #log

        repeat
            local speed = (_gui and _gui.getSettings().speed) or 1

            for i, ev in ipairs(log) do
                if not _replayActive then break end

                -- Wait for time delta from previous event
                if i > 1 then
                    local dt = (ev.t - log[i - 1].t) / speed
                    if dt > 0 then
                        local waitStart = tick()
                        while tick() - waitStart < dt do
                            if not _replayActive then break end
                            RunService.Heartbeat:Wait()
                        end
                    end
                end

                if not _replayActive then break end

                -- Dispatch event
                if ev.type == "cam" then
                    setCam(ev.cf)
                elseif ev.type == "down" then
                    _replayFingers[ev.finger] = true
                    if isMobile then tDown(ev.x, ev.y, ev.finger)
                    else mDown(ev.x, ev.y) end
                elseif ev.type == "move" then
                    if isMobile then tMove(ev.x, ev.y, ev.finger)
                    else mMove(ev.x, ev.y) end
                elseif ev.type == "up" then
                    _replayFingers[ev.finger] = nil
                    if isMobile then tUp(ev.x, ev.y, ev.finger)
                    else mUp(ev.x, ev.y) end
                end

                -- Update HUD
                if _gui and i % 3 == 0 then
                    _gui.setStatus(
                        "Replay " .. i .. " / " .. total,
                        Color3.fromRGB(34, 197, 94)
                    )
                end
            end

            -- Check loop
            if _replayActive and _gui then
                local settings = _gui.getSettings()
                if settings.loop then
                    _gui.setStatus("Loop restart...", Color3.fromRGB(139, 92, 246))
                    task.wait(0.4)
                else
                    break
                end
            else
                break
            end
        until not _replayActive

        -- ─── Cleanup ─────────────────────────────
        -- Release any fingers/mouse still held
        for fid in pairs(_replayFingers) do
            if isMobile then tUp(0, 0, fid) else mUp(0, 0) end
        end
        _replayFingers = {}

        _replayActive = false
        _state = "IDLE"

        if _gui then
            _gui.setReplayState(false)
            _gui.setStatus("Done  ·  " .. total .. " events", Color3.fromRGB(125, 133, 144))
        end
    end)
end

local function stopReplay()
    if _state ~= "REPLAYING" then return end
    _replayActive = false
    -- The replay coroutine will detect the flag, clean up, and set state to IDLE
end

-- ─── Public API ──────────────────────────────────────
local API = {}

function API.init(gui, stealth)
    if not gui then return false end
    _gui     = gui
    _stealth = stealth

    -- Apply stealth to GUI
    if stealth and stealth.GuiShield then
        stealth.GuiShield.configure(gui.root)
    end

    -- Wire callbacks
    gui.setCallbacks({
        onRecord = function()
            if _state == "REPLAYING" then return end
            if _state == "RECORDING" then stopRecording() else startRecording() end
        end,
        onReplay = function()
            if _state == "RECORDING" then return end
            if _state == "REPLAYING" then stopReplay() else startReplay() end
        end,
        onClear = function()
            if _state ~= "IDLE" then return end
            eventLog = {}
            gui.setStatus("Cleared", Color3.fromRGB(125, 133, 144))
        end,
    })

    -- Show loaded count if re-init
    if #eventLog > 0 then
        gui.setStatus(#eventLog .. " events loaded", Color3.fromRGB(125, 133, 144))
    end

    return true
end

API.isRecording  = function() return _state == "RECORDING" end
API.isReplaying  = function() return _state == "REPLAYING" end
API.getState     = function() return _state end
API.getEventCount= function() return #eventLog end
API.getEventLog  = function() return eventLog end
API.getCorrection= function() return correction end
API.isMobile     = function() return isMobile end
API.isDelta      = function() return isDelta end

API.record       = startRecording
API.stopRecord   = stopRecording
API.replay       = startReplay
API.stopReplay   = stopReplay

function API.clearLog()
    if _state ~= "IDLE" then return end
    eventLog = {}
    if _gui then _gui.setStatus("Cleared", Color3.fromRGB(125, 133, 144)) end
end

function API.destroy()
    stopRecording()
    _replayActive = false
    task.wait(0.1)
    clearConns()
    eventLog = {}
    if getgenv then
        getgenv()._AURORA_LOGIC_API = nil
        getgenv()._AURORA_LOGIC_LOADED = nil
    end
end

if getgenv then getgenv()._AURORA_LOGIC_API = API end
return API
