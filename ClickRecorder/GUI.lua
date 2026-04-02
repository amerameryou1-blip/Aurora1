-- Aurora Click Recorder v6.0 - GUI Module
-- Premium dark UI · Aurora gradient · Loop / Speed / Clear
-- Custom drag · mobile-safe · fully animated

-- ─── Duplicate Guard ─────────────────────────────────
do
    if getgenv and getgenv()._AURORA_GUI_LOADED then
        local cached = getgenv()._AURORA_GUI_API
        if cached then return cached end
    end
end
if getgenv then getgenv()._AURORA_GUI_LOADED = true end

-- Destroy leftover GUI from previous execution
if getgenv and getgenv()._AURORA_GUI_REF then
    pcall(function() getgenv()._AURORA_GUI_REF:Destroy() end)
    getgenv()._AURORA_GUI_REF = nil
end

-- ─── Services ────────────────────────────────────────
local Players     = game:GetService("Players")
local TS          = game:GetService("TweenService")
local RS          = game:GetService("RunService")
local UIS         = game:GetService("UserInputService")
local player      = Players.LocalPlayer
local isMobile    = UIS.TouchEnabled and not UIS.KeyboardEnabled

-- ─── Theme ───────────────────────────────────────────
local C = {
    bg         = Color3.fromRGB(13, 17, 23),
    bgLight    = Color3.fromRGB(22, 27, 34),
    surface    = Color3.fromRGB(30, 35, 44),
    surfHover  = Color3.fromRGB(42, 48, 58),
    red        = Color3.fromRGB(239, 68, 68),
    redDim     = Color3.fromRGB(180, 45, 45),
    green      = Color3.fromRGB(34, 197, 94),
    greenDim   = Color3.fromRGB(22, 150, 70),
    purple     = Color3.fromRGB(139, 92, 246),
    purpleDim  = Color3.fromRGB(109, 62, 216),
    blue       = Color3.fromRGB(59, 130, 246),
    amber      = Color3.fromRGB(245, 158, 11),
    text       = Color3.fromRGB(230, 237, 243),
    textSub    = Color3.fromRGB(125, 133, 144),
    textMuted  = Color3.fromRGB(72, 80, 92),
    border     = Color3.fromRGB(48, 54, 61),
}

-- ─── Helpers ─────────────────────────────────────────
local function rn()
    local p = {"Core","Sys","Net","Ui","Render","Frame","View","Touch","Event","Signal"}
    local s = {"Ctrl","Mgr","Svc","Bridge","Adapter","Proxy","Cache","Pool","Buffer","Queue"}
    return p[math.random(#p)] .. s[math.random(#s)] .. "_" .. string.format("%04x", math.random(0, 0xFFFF))
end

local function tw(obj, props, dur, style)
    return TS:Create(obj, TweenInfo.new(dur or 0.25, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
end

local hitboxes = {}
local function reg(obj) table.insert(hitboxes, obj); return obj end

-- ─── Root ScreenGui ──────────────────────────────────
local root = Instance.new("ScreenGui")
root.Name            = rn()
root.ResetOnSpawn    = false
root.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
root.DisplayOrder    = 999
root.IgnoreGuiInset  = false

if gethui then pcall(function() root.Parent = gethui() end) end
if not root.Parent then pcall(function() root.Parent = game:GetService("CoreGui") end) end
if not root.Parent then root.Parent = player:WaitForChild("PlayerGui") end
if getgenv then getgenv()._AURORA_GUI_REF = root end

-- ─── Constants ───────────────────────────────────────
local W, H = 310, 198
local minimized = false

-- ─── Main Frame ──────────────────────────────────────
local main = Instance.new("Frame")
main.Name               = rn()
main.Size               = UDim2.new(0, W, 0, H)
main.Position           = UDim2.new(0.5, -W / 2, 0, 80)
main.BackgroundColor3   = C.bg
main.BorderSizePixel    = 0
main.ClipsDescendants   = true
main.Parent             = root
reg(main)
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
local mainStroke = Instance.new("UIStroke", main)
mainStroke.Color        = C.border
mainStroke.Thickness    = 1
mainStroke.Transparency = 0.3

-- Drop shadow (layered behind)
local shadow = Instance.new("Frame")
shadow.Name               = rn()
shadow.Size               = UDim2.new(1, 12, 1, 12)
shadow.Position           = UDim2.new(0, -6, 0, -4)
shadow.BackgroundColor3   = Color3.fromRGB(0, 0, 0)
shadow.BackgroundTransparency = 0.82
shadow.BorderSizePixel    = 0
shadow.ZIndex             = -1
shadow.Parent             = main
Instance.new("UICorner", shadow).CornerRadius = UDim.new(0, 16)

-- ─── Aurora Accent Bar (top 2px gradient) ────────────
local accent = Instance.new("Frame")
accent.Name             = rn()
accent.Size             = UDim2.new(1, 0, 0, 2)
accent.BackgroundColor3 = Color3.new(1, 1, 1)
accent.BorderSizePixel  = 0
accent.ZIndex           = 5
accent.Parent           = main
local ag = Instance.new("UIGradient", accent)
ag.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, C.purple),
    ColorSequenceKeypoint.new(0.5, C.blue),
    ColorSequenceKeypoint.new(1, C.green),
})

-- ─── Title Bar ───────────────────────────────────────
local titleBar = Instance.new("Frame")
titleBar.Name             = rn()
titleBar.Size             = UDim2.new(1, 0, 0, 36)
titleBar.Position         = UDim2.new(0, 0, 0, 2)
titleBar.BackgroundColor3 = C.bgLight
titleBar.BorderSizePixel  = 0
titleBar.ZIndex           = 2
titleBar.Parent           = main
reg(titleBar)

local titleText = Instance.new("TextLabel")
titleText.Size               = UDim2.new(1, -70, 1, 0)
titleText.Position           = UDim2.new(0, 14, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text               = "Aurora"
titleText.TextColor3         = C.text
titleText.TextSize           = 14
titleText.Font               = Enum.Font.GothamBold
titleText.TextXAlignment     = Enum.TextXAlignment.Left
titleText.ZIndex             = 3
titleText.Parent             = titleBar

-- Status dot (in title bar)
local dot = Instance.new("Frame")
dot.Size             = UDim2.new(0, 7, 0, 7)
dot.Position         = UDim2.new(1, -56, 0.5, -3)
dot.BackgroundColor3 = C.textMuted
dot.BorderSizePixel  = 0
dot.ZIndex           = 3
dot.Parent           = titleBar
Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

-- Minimize button
local minBtn = Instance.new("TextButton")
minBtn.Size               = UDim2.new(0, 30, 0, 30)
minBtn.Position           = UDim2.new(1, -38, 0.5, -15)
minBtn.BackgroundTransparency = 1
minBtn.Text               = "─"
minBtn.TextColor3         = C.textSub
minBtn.TextSize           = 14
minBtn.Font               = Enum.Font.GothamBold
minBtn.BorderSizePixel    = 0
minBtn.ZIndex             = 4
minBtn.Parent             = titleBar

-- Divider
local div = Instance.new("Frame")
div.Size             = UDim2.new(1, 0, 0, 1)
div.Position         = UDim2.new(0, 0, 1, -1)
div.BackgroundColor3 = C.border
div.BackgroundTransparency = 0.5
div.BorderSizePixel  = 0
div.ZIndex           = 3
div.Parent           = titleBar

-- ─── Custom Drag ─────────────────────────────────────
local dragging, dragStart, frameStart = false, nil, nil

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging   = true
        dragStart  = input.Position
        frameStart = main.Position
    end
end)

UIS.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
    and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local d = input.Position - dragStart
    main.Position = UDim2.new(
        frameStart.X.Scale, frameStart.X.Offset + d.X,
        frameStart.Y.Scale, frameStart.Y.Offset + d.Y
    )
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- ─── Minimize Toggle ─────────────────────────────────
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        tw(main, { Size = UDim2.new(0, W, 0, 40) }, 0.3):Play()
        minBtn.Text = "+"
    else
        tw(main, { Size = UDim2.new(0, W, 0, H) }, 0.3):Play()
        minBtn.Text = "─"
    end
end)

-- ─── Content Area ────────────────────────────────────
local content = Instance.new("Frame")
content.Name               = rn()
content.Size               = UDim2.new(1, -20, 0, 140)
content.Position           = UDim2.new(0, 10, 0, 42)
content.BackgroundTransparency = 1
content.ZIndex             = 2
content.Parent             = main

-- Status label
local statusLabel = Instance.new("TextLabel")
statusLabel.Name               = rn()
statusLabel.Size               = UDim2.new(1, 0, 0, 18)
statusLabel.Position           = UDim2.new(0, 0, 0, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text               = "Ready"
statusLabel.TextColor3         = C.textSub
statusLabel.TextSize           = 11
statusLabel.Font               = Enum.Font.Gotham
statusLabel.TextXAlignment     = Enum.TextXAlignment.Left
statusLabel.ZIndex             = 3
statusLabel.Parent             = content

-- ─── Main Button Factory ─────────────────────────────
local function makeMainBtn(parent, label, icon, x, y, w, h, col, colDim)
    local frame = Instance.new("Frame")
    frame.Name             = rn()
    frame.Size             = UDim2.new(0, w, 0, h)
    frame.Position         = UDim2.new(0, x, 0, y)
    frame.BackgroundColor3 = col
    frame.BorderSizePixel  = 0
    frame.ZIndex           = 3
    frame.Parent           = parent
    reg(frame)
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    -- Subtle top-highlight gradient
    local g = Instance.new("UIGradient", frame)
    g.Color = ColorSequence.new(Color3.new(1,1,1), Color3.new(1,1,1))
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.82),
        NumberSequenceKeypoint.new(0.5, 0.92),
        NumberSequenceKeypoint.new(1, 0.95),
    })
    g.Rotation = 180

    local btn = Instance.new("TextButton")
    btn.Name               = rn()
    btn.Size               = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text               = ""
    btn.BorderSizePixel    = 0
    btn.ZIndex             = 4
    btn.Parent             = frame

    local ic = Instance.new("TextLabel")
    ic.Size               = UDim2.new(0, 20, 1, 0)
    ic.Position           = UDim2.new(0, 14, 0, 0)
    ic.BackgroundTransparency = 1
    ic.Text               = icon
    ic.TextColor3         = C.text
    ic.TextSize           = 11
    ic.Font               = Enum.Font.GothamBold
    ic.TextXAlignment     = Enum.TextXAlignment.Center
    ic.ZIndex             = 5
    ic.Parent             = btn

    local lb = Instance.new("TextLabel")
    lb.Size               = UDim2.new(1, -38, 1, 0)
    lb.Position           = UDim2.new(0, 36, 0, 0)
    lb.BackgroundTransparency = 1
    lb.Text               = label
    lb.TextColor3         = C.text
    lb.TextSize           = 14
    lb.Font               = Enum.Font.GothamBold
    lb.TextXAlignment     = Enum.TextXAlignment.Left
    lb.ZIndex             = 5
    lb.Parent             = btn

    btn.MouseEnter:Connect(function() tw(frame, { BackgroundColor3 = colDim }, 0.12):Play() end)
    btn.MouseLeave:Connect(function() tw(frame, { BackgroundColor3 = col }, 0.12):Play() end)
    btn.MouseButton1Down:Connect(function() tw(frame, { Size = UDim2.new(0, w - 2, 0, h - 2), Position = UDim2.new(0, x + 1, 0, y + 1) }, 0.06):Play() end)
    btn.MouseButton1Up:Connect(function()   tw(frame, { Size = UDim2.new(0, w, 0, h), Position = UDim2.new(0, x, 0, y) }, 0.12):Play() end)

    return { frame = frame, btn = btn, icon = ic, label = lb, baseCol = col, dimCol = colDim }
end

-- Main button row
local bW = math.floor((290 - 8) / 2)   -- 141
local bH = 42
local bY = 24

local recBtn = makeMainBtn(content, "Record", "●", 0,       bY, bW, bH, C.red,   C.redDim)
local repBtn = makeMainBtn(content, "Replay", "▶", bW + 8, bY, bW, bH, C.green, C.greenDim)

-- ─── Control Row ─────────────────────────────────────
local cY  = bY + bH + 8      -- 74
local cH  = 28
local cGap = 8
local sGap = 4

-- Small button factory
local function makeSmallBtn(parent, label, x, y, w, h, defaultCol, activeCol)
    local frame = Instance.new("Frame")
    frame.Name             = rn()
    frame.Size             = UDim2.new(0, w, 0, h)
    frame.Position         = UDim2.new(0, x, 0, y)
    frame.BackgroundColor3 = defaultCol or C.surface
    frame.BorderSizePixel  = 0
    frame.ZIndex           = 3
    frame.Parent           = parent
    reg(frame)
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local btn = Instance.new("TextButton")
    btn.Name               = rn()
    btn.Size               = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text               = label
    btn.TextColor3         = C.textSub
    btn.TextSize           = 11
    btn.Font               = Enum.Font.GothamMedium
    btn.BorderSizePixel    = 0
    btn.ZIndex             = 4
    btn.Parent             = frame

    btn.MouseEnter:Connect(function() tw(frame, { BackgroundColor3 = C.surfHover }, 0.1):Play() end)
    btn.MouseLeave:Connect(function()
        -- Restore correct color (might be active)
        tw(frame, { BackgroundColor3 = frame:GetAttribute("_active") and (activeCol or C.purple) or (defaultCol or C.surface) }, 0.1):Play()
    end)

    return { frame = frame, btn = btn, activeCol = activeCol }
end

-- Clear
local clearCtrl = makeSmallBtn(content, "Clear", 0, cY, 56, cH)
-- Loop
local loopCtrl  = makeSmallBtn(content, "Loop", 56 + cGap, cY, 56, cH, C.surface, C.purple)
-- Speed buttons
local speedX    = 56 + cGap + 56 + cGap   -- 128
local spW       = math.floor((290 - speedX - sGap * 2) / 3) -- 50
local speedCtrls = {}
for i, spd in ipairs({1, 2, 4}) do
    local sx = speedX + (i - 1) * (spW + sGap)
    local sc = makeSmallBtn(content, spd .. "x", sx, cY, spW, cH, C.surface, C.purple)
    speedCtrls[spd] = sc
end

-- ─── State ───────────────────────────────────────────
local loopEnabled   = false
local currentSpeed  = 1
local callbacks     = {}

-- Initialise speed highlight (1x active)
speedCtrls[1].frame.BackgroundColor3 = C.purple
speedCtrls[1].frame:SetAttribute("_active", true)
speedCtrls[1].btn.TextColor3 = C.text

-- Loop toggle
loopCtrl.btn.MouseButton1Click:Connect(function()
    loopEnabled = not loopEnabled
    if loopEnabled then
        loopCtrl.frame.BackgroundColor3 = C.purple
        loopCtrl.frame:SetAttribute("_active", true)
        loopCtrl.btn.TextColor3 = C.text
    else
        loopCtrl.frame.BackgroundColor3 = C.surface
        loopCtrl.frame:SetAttribute("_active", false)
        loopCtrl.btn.TextColor3 = C.textSub
    end
end)

-- Speed toggle
for spd, ctrl in pairs(speedCtrls) do
    ctrl.btn.MouseButton1Click:Connect(function()
        currentSpeed = spd
        for s, sc in pairs(speedCtrls) do
            local active = (s == spd)
            sc.frame.BackgroundColor3 = active and C.purple or C.surface
            sc.frame:SetAttribute("_active", active)
            sc.btn.TextColor3 = active and C.text or C.textSub
        end
    end)
end

-- Clear click
clearCtrl.btn.MouseButton1Click:Connect(function()
    if callbacks.onClear then callbacks.onClear() end
end)

-- Main button clicks
recBtn.btn.MouseButton1Click:Connect(function()
    if callbacks.onRecord then callbacks.onRecord() end
end)
repBtn.btn.MouseButton1Click:Connect(function()
    if callbacks.onReplay then callbacks.onReplay() end
end)

-- ─── Footer ──────────────────────────────────────────
local footer = Instance.new("TextLabel")
footer.Name               = rn()
footer.Size               = UDim2.new(1, -20, 0, 18)
footer.Position           = UDim2.new(0, 10, 1, -22)
footer.BackgroundTransparency = 1
footer.Text               = "v6.0 · Aurora"
footer.TextColor3         = C.textMuted
footer.TextSize           = 9
footer.Font               = Enum.Font.Gotham
footer.TextXAlignment     = Enum.TextXAlignment.Center
footer.ZIndex             = 2
footer.Parent             = main

-- ─── Pulse Animation ─────────────────────────────────
local pulseInfo = TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local pulseAnim = nil

local function stopPulse()
    if pulseAnim then pulseAnim:Cancel(); pulseAnim = nil end
    dot.Size = UDim2.new(0, 7, 0, 7)
    dot.BackgroundTransparency = 0
end

local function startPulse(color)
    stopPulse()
    dot.BackgroundColor3 = color
    pulseAnim = TS:Create(dot, pulseInfo, {
        BackgroundTransparency = 0.4,
        Size = UDim2.new(0, 9, 0, 9),
    })
    pulseAnim:Play()
end

local function setDot(color)
    stopPulse()
    tw(dot, { BackgroundColor3 = color }, 0.2):Play()
end

-- ─── Public API ──────────────────────────────────────
local API = {}
API.root = root

function API.setStatus(text, color)
    statusLabel.Text       = text or "Ready"
    statusLabel.TextColor3 = color or C.textSub
    if color then setDot(color) end
end

function API.setRecordState(recording)
    if recording then
        recBtn.label.Text = "Stop"
        recBtn.icon.Text  = "■"
        tw(recBtn.frame, { BackgroundColor3 = C.redDim }, 0.15):Play()
        startPulse(C.red)
    else
        recBtn.label.Text = "Record"
        recBtn.icon.Text  = "●"
        tw(recBtn.frame, { BackgroundColor3 = C.red }, 0.15):Play()
        setDot(C.textMuted)
    end
end

function API.setReplayState(replaying)
    if replaying then
        repBtn.label.Text = "Stop"
        tw(repBtn.frame, { BackgroundColor3 = C.greenDim }, 0.15):Play()
        startPulse(C.green)
    else
        repBtn.label.Text = "Replay"
        tw(repBtn.frame, { BackgroundColor3 = C.green }, 0.15):Play()
        setDot(C.textMuted)
    end
end

function API.setCallbacks(cbs)
    if type(cbs) ~= "table" then return end
    callbacks = cbs
end

function API.getSettings()
    return { loop = loopEnabled, speed = currentSpeed }
end

function API.isOverGui(x, y)
    for _, obj in ipairs(hitboxes) do
        if obj and obj.Parent then
            local p = obj.AbsolutePosition
            local s = obj.AbsoluteSize
            if x >= p.X and x <= p.X + s.X and y >= p.Y and y <= p.Y + s.Y then
                return true
            end
        end
    end
    return false
end

function API.destroy()
    pcall(function() root:Destroy() end)
    if getgenv then
        getgenv()._AURORA_GUI_REF = nil
        getgenv()._AURORA_GUI_API = nil
        getgenv()._AURORA_GUI_LOADED = nil
    end
end

-- ─── Intro Animation ─────────────────────────────────
do
    main.BackgroundTransparency = 1
    mainStroke.Transparency     = 1
    main.Size                   = UDim2.new(0, W, 0, 0)

    task.spawn(function()
        task.wait(0.05)
        tw(main, { Size = UDim2.new(0, W, 0, H), BackgroundTransparency = 0 }, 0.45):Play()
        task.wait(0.15)
        tw(mainStroke, { Transparency = 0.3 }, 0.3):Play()
    end)
end

if getgenv then getgenv()._AURORA_GUI_API = API end
return API
