-- ============================================================
-- LINEAGE UI LIBRARY  —  Glass/Frost Edition
-- Drop-in replacement for the original Library.lua
-- All original API preserved: Toggles, Options, Window, Tabs,
-- Groupboxes, Tabboxes, Addons — identical call signatures.
-- ============================================================

local InputService  = game:GetService('UserInputService')
local TextService   = game:GetService('TextService')
local CoreGui       = game:GetService('CoreGui')
local Teams         = game:GetService('Teams')
local Players       = game:GetService('Players')
local RunService    = game:GetService('RunService')
local TweenService  = game:GetService('TweenService')
local RenderStepped = RunService.RenderStepped

local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer:GetMouse()

local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end)

local ScreenGui = Instance.new('ScreenGui')
ProtectGui(ScreenGui)
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.Parent = CoreGui

local Toggles = {}
local Options = {}
getgenv().Toggles = Toggles
getgenv().Options = Options

-- ── TWEEN HELPERS ────────────────────────────────────────────
local function tween(inst, t, props, style, dir)
    style = style or Enum.EasingStyle.Quart
    dir   = dir   or Enum.EasingDirection.Out
    TweenService:Create(inst, TweenInfo.new(t, style, dir), props):Play()
end

local function tweenSpring(inst, t, props)
    tween(inst, t, props, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

local function tweenBounce(inst, t, props)
    tween(inst, t, props, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
end

-- ── GLASS PALETTE ────────────────────────────────────────────
-- All "colors" are transparency values layered over a dark base.
-- Real glass look: everything is semi-transparent, borders are
-- bright-white at low opacity, highlights are accent-colored glows.

local Glass = {
    -- Base surfaces
    WindowBG        = Color3.fromRGB(12, 12, 16),       -- near-black base
    PanelBG         = Color3.fromRGB(18, 18, 24),
    GroupBG         = Color3.fromRGB(22, 22, 30),
    ElementBG       = Color3.fromRGB(28, 28, 38),
    HoverBG         = Color3.fromRGB(38, 38, 52),

    -- Borders (bright-white glass edge)
    BorderBright    = Color3.fromRGB(255, 255, 255),     -- at ~0.82 transparency = glass edge
    BorderDim       = Color3.fromRGB(255, 255, 255),     -- at ~0.90 = subtle inner edge

    -- Accent: electric blue
    Accent          = Color3.fromRGB(0, 110, 255),
    AccentGlow      = Color3.fromRGB(0, 150, 255),
    AccentDark      = Color3.fromRGB(0, 60, 180),
    AccentText      = Color3.fromRGB(80, 170, 255),

    -- Text
    TextPrimary     = Color3.fromRGB(240, 240, 255),
    TextSecondary   = Color3.fromRGB(160, 160, 190),
    TextDim         = Color3.fromRGB(100, 100, 130),

    -- Risk
    Risk            = Color3.fromRGB(255, 60, 80),

    Black           = Color3.new(0, 0, 0),
}

-- Transparency constants
local T = {
    WindowBG    = 0.15,   -- window is semi-transparent
    PanelBG     = 0.20,
    GroupBG     = 0.30,
    ElementBG   = 0.40,
    BorderGlass = 0.82,   -- bright-white glass-edge border
    BorderInner = 0.90,
    Hidden      = 1,
    Opaque      = 0,
}

-- ── LIBRARY TABLE ─────────────────────────────────────────────
local Library = {
    Registry    = {};
    RegistryMap = {};
    HudRegistry = {};

    -- expose palette for registry compatibility
    FontColor       = Glass.TextPrimary;
    MainColor       = Glass.ElementBG;
    BackgroundColor = Glass.GroupBG;
    AccentColor     = Glass.Accent;
    AccentColorDark = Glass.AccentDark;
    OutlineColor    = Glass.BorderBright;
    RiskColor       = Glass.Risk;
    Black           = Glass.Black;

    Font = Enum.Font.GothamMedium;   -- upgrade from Code → cleaner on glass

    OpenedFrames    = {};
    DependencyBoxes = {};
    Signals         = {};
    ScreenGui       = ScreenGui;
}

-- ── RAINBOW ───────────────────────────────────────────────────
local RainbowStep, Hue = 0, 0
table.insert(Library.Signals, RenderStepped:Connect(function(dt)
    RainbowStep += dt
    if RainbowStep >= (1/60) then
        RainbowStep = 0
        Hue = (Hue + 1/400) % 1
        Library.CurrentRainbowHue   = Hue
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1)
    end
end))

-- ── UTILITY ───────────────────────────────────────────────────
local function GetPlayersString()
    local t = Players:GetPlayers()
    for i = 1, #t do t[i] = t[i].Name end
    table.sort(t, function(a,b) return a < b end)
    return t
end

local function GetTeamsString()
    local t = Teams:GetTeams()
    for i = 1, #t do t[i] = t[i].Name end
    table.sort(t, function(a,b) return a < b end)
    return t
end

function Library:SafeCallback(f, ...)
    if not f then return end
    if not Library.NotifyOnError then return f(...) end
    local ok, err = pcall(f, ...)
    if not ok then
        local _, i = err:find(':%d+: ')
        Library:Notify(i and err:sub(i+1) or err, 3)
    end
end

function Library:AttemptSave()
    if Library.SaveManager then Library.SaveManager:Save() end
end

function Library:Create(Class, Properties)
    local inst = type(Class) == 'string' and Instance.new(Class) or Class
    for k, v in next, Properties do inst[k] = v end
    return inst
end

-- ── GLASS FRAME CONSTRUCTOR ───────────────────────────────────
-- Builds the standard two-layer glass panel:
--   Outer: solid dark base at T.WindowBG transparency
--   Border: bright-white UIStroke at low opacity (glass edge)
--   Inner gradient: subtle top-to-bottom light bleed
function Library:CreateGlassFrame(props, withGlow)
    local frame = Library:Create('Frame', {
        BackgroundColor3 = props.Color or Glass.GroupBG,
        BackgroundTransparency = props.Transparency or T.GroupBG,
        BorderSizePixel = 0,
        Size   = props.Size   or UDim2.new(1, 0, 0, 30),
        Position = props.Position or UDim2.new(0, 0, 0, 0),
        ZIndex = props.ZIndex or 1,
        Parent = props.Parent,
    })

    -- Glass edge stroke
    local stroke = Library:Create('UIStroke', {
        Color       = Glass.BorderBright,
        Thickness   = 1,
        Transparency = T.BorderGlass,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = frame,
    })

    -- Corner rounding — glass looks best with slight radius
    Library:Create('UICorner', {
        CornerRadius = UDim.new(0, props.Radius or 4),
        Parent = frame,
    })

    -- Inner top-light gradient (glass sheen)
    if not props.NoGradient then
        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(0.4, Color3.fromRGB(200, 200, 220)),
                ColorSequenceKeypoint.new(1,   Color3.fromRGB(160, 160, 190)),
            }),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0,   0.88),
                NumberSequenceKeypoint.new(0.5, 0.95),
                NumberSequenceKeypoint.new(1,   0.98),
            }),
            Rotation = 90,
            Parent = frame,
        })
    end

    -- Optional accent glow line at top
    if withGlow then
        local glow = Library:Create('Frame', {
            BackgroundColor3 = Glass.Accent,
            BackgroundTransparency = 0.3,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 2),
            ZIndex = (props.ZIndex or 1) + 1,
            Parent = frame,
        })
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 2), Parent = glow })
        Library:AddToRegistry(glow, { BackgroundColor3 = 'AccentColor' })

        -- Animate glow width in on creation
        glow.Size = UDim2.new(0, 0, 0, 2)
        tween(glow, 0.5, { Size = UDim2.new(1, 0, 0, 2) }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    end

    Library:AddToRegistry(frame, {
        BackgroundColor3 = type(props.RegistryKey) == 'string' and props.RegistryKey or nil,
    })

    return frame, stroke
end

-- ── TEXT / LABEL ──────────────────────────────────────────────
function Library:ApplyTextStroke(inst)
    inst.TextStrokeTransparency = 1
    Library:Create('UIStroke', {
        Color = Color3.new(0,0,0),
        Thickness = 1.2,
        LineJoinMode = Enum.LineJoinMode.Miter,
        Parent = inst,
    })
end

function Library:CreateLabel(Properties, IsHud)
    local label = Library:Create('TextLabel', {
        BackgroundTransparency = 1,
        Font      = Library.Font,
        TextColor3 = Library.FontColor,
        TextSize  = 14,
        TextStrokeTransparency = 1,
    })
    Library:ApplyTextStroke(label)
    Library:AddToRegistry(label, { TextColor3 = 'FontColor' }, IsHud)
    return Library:Create(label, Properties)
end

-- ── DRAG ──────────────────────────────────────────────────────
function Library:MakeDraggable(Instance, Cutoff)
    Instance.Active = true
    Instance.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            local off = Vector2.new(
                Mouse.X - Instance.AbsolutePosition.X,
                Mouse.Y - Instance.AbsolutePosition.Y
            )
            if off.Y > (Cutoff or 40) then return end
            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                Instance.Position = UDim2.new(
                    0, Mouse.X - off.X + (Instance.Size.X.Offset * Instance.AnchorPoint.X),
                    0, Mouse.Y - off.Y + (Instance.Size.Y.Offset * Instance.AnchorPoint.Y)
                )
                RenderStepped:Wait()
            end
        end
    end)
end

-- ── TOOLTIP ───────────────────────────────────────────────────
function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 13)
    local tip = Library:CreateGlassFrame({
        Color = Glass.PanelBG,
        Transparency = T.PanelBG,
        Size = UDim2.fromOffset(X + 12, Y + 8),
        ZIndex = 200,
        Parent = Library.ScreenGui,
        NoGradient = false,
        Radius = 6,
    })
    tip.Visible = false
    tip.BackgroundTransparency = 1

    local lbl = Library:CreateLabel({
        Position = UDim2.fromOffset(6, 3),
        Size     = UDim2.fromOffset(X, Y),
        TextSize = 13,
        Text     = InfoStr,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex   = 201,
        Parent   = tip,
    })

    local hovering = false
    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then return end
        hovering = true
        tip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        tip.BackgroundTransparency = T.PanelBG
        tip.Visible = true
        tween(tip, 0.15, { BackgroundTransparency = T.PanelBG })
        while hovering do
            RunService.Heartbeat:Wait()
            tip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        end
    end)
    HoverInstance.MouseLeave:Connect(function()
        hovering = false
        tween(tip, 0.1, { BackgroundTransparency = 1 })
        task.delay(0.12, function() if not hovering then tip.Visible = false end end)
    end)
end

-- ── HOVER HELPER ─────────────────────────────────────────────
function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
    HighlightInstance.MouseEnter:Connect(function()
        local Reg = Library.RegistryMap[Instance]
        for Prop, ColorIdx in next, Properties do
            Instance[Prop] = Library[ColorIdx] or ColorIdx
            if Reg and Reg.Properties[Prop] then Reg.Properties[Prop] = ColorIdx end
        end
    end)
    HighlightInstance.MouseLeave:Connect(function()
        local Reg = Library.RegistryMap[Instance]
        for Prop, ColorIdx in next, PropertiesDefault do
            Instance[Prop] = Library[ColorIdx] or ColorIdx
            if Reg and Reg.Properties[Prop] then Reg.Properties[Prop] = ColorIdx end
        end
    end)
end

-- ── MOUSE HELPERS ─────────────────────────────────────────────
function Library:MouseIsOverOpenedFrame()
    for Frame in next, Library.OpenedFrames do
        local p, s = Frame.AbsolutePosition, Frame.AbsoluteSize
        if Mouse.X >= p.X and Mouse.X <= p.X + s.X
        and Mouse.Y >= p.Y and Mouse.Y <= p.Y + s.Y then
            return true
        end
    end
end

function Library:IsMouseOverFrame(Frame)
    local p, s = Frame.AbsolutePosition, Frame.AbsoluteSize
    return Mouse.X >= p.X and Mouse.X <= p.X + s.X
       and Mouse.Y >= p.Y and Mouse.Y <= p.Y + s.Y
end

function Library:UpdateDependencyBoxes()
    for _, db in next, Library.DependencyBoxes do db:Update() end
end

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
    return (1 - ((Value - MinA)/(MaxA - MinA))) * MinB + ((Value - MinA)/(MaxA - MinA)) * MaxB
end

function Library:GetTextBounds(Text, Font, Size, Resolution)
    local b = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920,1080))
    return b.X, b.Y
end

function Library:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color)
    return Color3.fromHSV(H, S, V/1.5)
end
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor)

-- ── REGISTRY ──────────────────────────────────────────────────
function Library:AddToRegistry(Instance, Properties, IsHud)
    if not Instance then return end
    -- filter nil-keyed props
    local clean = {}
    for k, v in next, Properties or {} do
        if k then clean[k] = v end
    end
    local idx  = #Library.Registry + 1
    local data = { Instance = Instance; Properties = clean; Idx = idx }
    table.insert(Library.Registry, data)
    Library.RegistryMap[Instance] = data
    if IsHud then table.insert(Library.HudRegistry, data) end
end

function Library:RemoveFromRegistry(Instance)
    local data = Library.RegistryMap[Instance]
    if not data then return end
    for i = #Library.Registry, 1, -1 do
        if Library.Registry[i] == data then table.remove(Library.Registry, i) end
    end
    for i = #Library.HudRegistry, 1, -1 do
        if Library.HudRegistry[i] == data then table.remove(Library.HudRegistry, i) end
    end
    Library.RegistryMap[Instance] = nil
end

function Library:UpdateColorsUsingRegistry()
    for _, obj in next, Library.Registry do
        for Prop, ColorIdx in next, obj.Properties do
            if type(ColorIdx) == 'string' then
                obj.Instance[Prop] = Library[ColorIdx]
            elseif type(ColorIdx) == 'function' then
                obj.Instance[Prop] = ColorIdx()
            end
        end
    end
end

function Library:GiveSignal(Signal)
    table.insert(Library.Signals, Signal)
end

function Library:Unload()
    for i = #Library.Signals, 1, -1 do
        table.remove(Library.Signals, i):Disconnect()
    end
    if Library.OnUnload then Library.OnUnload() end
    ScreenGui:Destroy()
end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(inst)
    if Library.RegistryMap[inst] then Library:RemoveFromRegistry(inst) end
end))

-- ═══════════════════════════════════════════════════════════════
-- ADDONS  (ColorPicker + KeyPicker — full implementations)
-- ═══════════════════════════════════════════════════════════════
local BaseAddons = {}

do
    local Funcs = {}

    -- ── COLOR PICKER ─────────────────────────────────────────
    function Funcs:AddColorPicker(Idx, Info)
        local ToggleLabel = self.TextLabel
        assert(Info.Default, 'AddColorPicker: Missing default value.')

        local ColorPicker = {
            Value        = Info.Default;
            Transparency = Info.Transparency or 0;
            Type         = 'ColorPicker';
            Title        = type(Info.Title) == 'string' and Info.Title or 'Color';
            Callback     = Info.Callback or function() end;
        }

        function ColorPicker:SetHSVFromRGB(c)
            local h,s,v = Color3.toHSV(c)
            self.Hue, self.Sat, self.Vib = h, s, v
        end
        ColorPicker:SetHSVFromRGB(ColorPicker.Value)

        -- Swatch
        local SwatchOuter = Library:Create('Frame', {
            BackgroundColor3 = Glass.Black,
            Size = UDim2.new(0, 28, 0, 14),
            ZIndex = 6,
            Parent = ToggleLabel,
        })
        Library:Create('UICorner', { CornerRadius = UDim.new(0,3), Parent = SwatchOuter })

        local SwatchInner = Library:Create('Frame', {
            BackgroundColor3 = ColorPicker.Value,
            Size = UDim2.new(1,0,1,0),
            ZIndex = 7,
            Parent = SwatchOuter,
        })
        Library:Create('UICorner', { CornerRadius = UDim.new(0,3), Parent = SwatchInner })

        -- Picker frame
        local PickerFrame, _ = Library:CreateGlassFrame({
            Color = Glass.PanelBG,
            Transparency = T.PanelBG,
            Size = UDim2.fromOffset(230, Info.Transparency and 271 or 253),
            ZIndex = 15,
            Radius = 8,
            Parent = ScreenGui,
        }, true)
        PickerFrame.Name = 'Color'
        PickerFrame.Visible = false
        PickerFrame.Position = UDim2.fromOffset(
            SwatchOuter.AbsolutePosition.X,
            SwatchOuter.AbsolutePosition.Y + 20
        )

        SwatchOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            PickerFrame.Position = UDim2.fromOffset(
                SwatchOuter.AbsolutePosition.X,
                SwatchOuter.AbsolutePosition.Y + 20
            )
        end)

        -- Title label
        Library:CreateLabel({
            Position = UDim2.fromOffset(5,5),
            Size = UDim2.new(1,0,0,14),
            TextSize = 13,
            Text = ColorPicker.Title,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 16,
            Parent = PickerFrame,
        })

        -- SatVib map
        local SatVibOuter = Library:Create('Frame', {
            BackgroundColor3 = Glass.Black,
            BorderSizePixel = 0,
            Position = UDim2.new(0,4,0,25),
            Size = UDim2.new(0,200,0,200),
            ZIndex = 17,
            Parent = PickerFrame,
        })
        Library:Create('UICorner', { CornerRadius = UDim.new(0,4), Parent = SatVibOuter })

        local SatVibMap = Library:Create('ImageLabel', {
            BackgroundColor3 = Color3.new(1,1,1),
            BorderSizePixel = 0,
            Size = UDim2.new(1,0,1,0),
            ZIndex = 18,
            Image = 'rbxassetid://4155801252',
            Parent = SatVibOuter,
        })
        Library:Create('UICorner', { CornerRadius = UDim.new(0,4), Parent = SatVibMap })

        local CursorOuter = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0.5,0.5),
            Size = UDim2.new(0,8,0,8),
            BackgroundTransparency = 1,
            Image = 'http://www.roblox.com/asset/?id=9619665977',
            ImageColor3 = Color3.new(0,0,0),
            ZIndex = 19,
            Parent = SatVibMap,
        })
        Library:Create('ImageLabel', {
            Size = UDim2.new(0,6,0,6),
            Position = UDim2.new(0,1,0,1),
            BackgroundTransparency = 1,
            Image = 'http://www.roblox.com/asset/?id=9619665977',
            ZIndex = 20,
            Parent = CursorOuter,
        })

        -- Hue strip
        local HueOuter = Library:Create('Frame', {
            BackgroundColor3 = Glass.Black,
            BorderSizePixel = 0,
            Position = UDim2.new(0,208,0,25),
            Size = UDim2.new(0,15,0,200),
            ZIndex = 17,
            Parent = PickerFrame,
        })
        Library:Create('UICorner', { CornerRadius = UDim.new(0,4), Parent = HueOuter })

        local HueInner = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1,1,1),
            BorderSizePixel = 0,
            Size = UDim2.new(1,0,1,0),
            ZIndex = 18,
            Parent = HueOuter,
        })
        Library:Create('UICorner', { CornerRadius = UDim.new(0,4), Parent = HueInner })

        local HueCursor = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1,1,1),
            AnchorPoint = Vector2.new(0,0.5),
            BorderSizePixel = 0,
            Size = UDim2.new(1,0,0,2),
            ZIndex = 19,
            Parent = HueInner,
        })

        local seqT = {}
        for h = 0, 1, 0.1 do
            table.insert(seqT, ColorSequenceKeypoint.new(h, Color3.fromHSV(h,1,1)))
        end
        Library:Create('UIGradient', {
            Color = ColorSequence.new(seqT),
            Rotation = 90,
            Parent = HueInner,
        })

        -- Hex/RGB boxes
        local function makeInputBox(pos, placeholder, default)
            local outer = Library:Create('Frame', {
                BackgroundColor3 = Glass.ElementBG,
                BorderSizePixel = 0,
                Position = pos,
                Size = UDim2.new(0.5,-6,0,20),
                ZIndex = 18,
                Parent = PickerFrame,
            })
            Library:Create('UICorner', { CornerRadius = UDim.new(0,4), Parent = outer })
            local box = Library:Create('TextBox', {
                BackgroundTransparency = 1,
                Position = UDim2.new(0,5,0,0),
                Size = UDim2.new(1,-5,1,0),
                Font = Library.Font,
                PlaceholderColor3 = Glass.TextDim,
                PlaceholderText = placeholder,
                Text = default,
                TextColor3 = Glass.TextPrimary,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 20,
                Parent = outer,
            })
            return outer, box
        end

        local _, HueBox = makeInputBox(UDim2.fromOffset(4,228), 'Hex', '#FFFFFF')
        local _, RgbBox = makeInputBox(UDim2.new(0.5,2,0,228), 'RGB', '255, 255, 255')

        -- Transparency strip (optional)
        local TransInner, TransCursor
        if Info.Transparency then
            local transOuter = Library:Create('Frame', {
                BackgroundColor3 = Glass.ElementBG,
                BorderSizePixel = 0,
                Position = UDim2.fromOffset(4,251),
                Size = UDim2.new(1,-8,0,15),
                ZIndex = 19,
                Parent = PickerFrame,
            })
            Library:Create('UICorner', { CornerRadius = UDim.new(0,4), Parent = transOuter })

            TransInner = Library:Create('Frame', {
                BackgroundColor3 = ColorPicker.Value,
                BorderSizePixel = 0,
                Size = UDim2.new(1,0,1,0),
                ZIndex = 19,
                Parent = transOuter,
            })
            Library:Create('UICorner', { CornerRadius = UDim.new(0,4), Parent = TransInner })

            Library:Create('ImageLabel', {
                BackgroundTransparency = 1,
                Size = UDim2.new(1,0,1,0),
                Image = 'http://www.roblox.com/asset/?id=12978095818',
                ZIndex = 20,
                Parent = TransInner,
            })

            TransCursor = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(1,1,1),
                AnchorPoint = Vector2.new(0.5,0),
                BorderSizePixel = 0,
                Size = UDim2.new(0,2,1,0),
                ZIndex = 21,
                Parent = TransInner,
            })
        end

        function ColorPicker:Display()
            self.Value = Color3.fromHSV(self.Hue, self.Sat, self.Vib)
            SatVibMap.BackgroundColor3 = Color3.fromHSV(self.Hue,1,1)

            tween(SwatchInner, 0.12, { BackgroundColor3 = self.Value })

            CursorOuter.Position = UDim2.new(self.Sat,0,1-self.Vib,0)
            HueCursor.Position   = UDim2.new(0,0,self.Hue,0)

            HueBox.Text = '#' .. self.Value:ToHex()
            RgbBox.Text = table.concat({
                math.floor(self.Value.R*255),
                math.floor(self.Value.G*255),
                math.floor(self.Value.B*255),
            }, ', ')

            if TransInner then
                TransInner.BackgroundColor3 = self.Value
                TransCursor.Position = UDim2.new(1-self.Transparency,0,0,0)
            end

            Library:SafeCallback(self.Callback, self.Value)
            Library:SafeCallback(self.Changed, self.Value)
        end

        function ColorPicker:Show()
            for f in next, Library.OpenedFrames do
                if f.Name == 'Color' then
                    tween(f, 0.15, { BackgroundTransparency = 1 })
                    task.delay(0.15, function() f.Visible = false end)
                    Library.OpenedFrames[f] = nil
                end
            end
            PickerFrame.BackgroundTransparency = 1
            PickerFrame.Visible = true
            tween(PickerFrame, 0.2, { BackgroundTransparency = T.PanelBG })
            Library.OpenedFrames[PickerFrame] = true
        end

        function ColorPicker:Hide()
            tween(PickerFrame, 0.15, { BackgroundTransparency = 1 })
            task.delay(0.15, function() PickerFrame.Visible = false end)
            Library.OpenedFrames[PickerFrame] = nil
        end

        function ColorPicker:SetValue(HSV, Tr)
            self.Transparency = Tr or 0
            self:SetHSVFromRGB(Color3.fromHSV(HSV[1],HSV[2],HSV[3]))
            self:Display()
        end

        function ColorPicker:SetValueRGB(c, Tr)
            self.Transparency = Tr or 0
            self:SetHSVFromRGB(c)
            self:Display()
        end

        function ColorPicker:OnChanged(f) self.Changed = f; f(self.Value) end

        HueBox.FocusLost:Connect(function(enter)
            if enter then
                local ok, c = pcall(Color3.fromHex, HueBox.Text)
                if ok then self.Hue, self.Sat, self.Vib = Color3.toHSV(c) end
            end
            ColorPicker:Display()
        end)

        RgbBox.FocusLost:Connect(function(enter)
            if enter then
                local r,g,b = RgbBox.Text:match('(%d+),%s*(%d+),%s*(%d+)')
                if r then self.Hue, self.Sat, self.Vib = Color3.toHSV(Color3.fromRGB(r,g,b)) end
            end
            ColorPicker:Display()
        end)

        SatVibMap.InputBegan:Connect(function(inp)
            if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                local minX, maxX = SatVibMap.AbsolutePosition.X, SatVibMap.AbsolutePosition.X + SatVibMap.AbsoluteSize.X
                local minY, maxY = SatVibMap.AbsolutePosition.Y, SatVibMap.AbsolutePosition.Y + SatVibMap.AbsoluteSize.Y
                ColorPicker.Sat = (math.clamp(Mouse.X, minX, maxX) - minX) / (maxX - minX)
                ColorPicker.Vib = 1 - (math.clamp(Mouse.Y, minY, maxY) - minY) / (maxY - minY)
                ColorPicker:Display()
                RenderStepped:Wait()
            end
            Library:AttemptSave()
        end)

        HueInner.InputBegan:Connect(function(inp)
            if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                local minY, maxY = HueInner.AbsolutePosition.Y, HueInner.AbsolutePosition.Y + HueInner.AbsoluteSize.Y
                ColorPicker.Hue = (math.clamp(Mouse.Y, minY, maxY) - minY) / (maxY - minY)
                ColorPicker:Display()
                RenderStepped:Wait()
            end
            Library:AttemptSave()
        end)

        if TransInner then
            TransInner.InputBegan:Connect(function(inp)
                if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local minX, maxX = TransInner.AbsolutePosition.X, TransInner.AbsolutePosition.X + TransInner.AbsoluteSize.X
                    ColorPicker.Transparency = 1 - (math.clamp(Mouse.X,minX,maxX)-minX)/(maxX-minX)
                    ColorPicker:Display()
                    RenderStepped:Wait()
                end
                Library:AttemptSave()
            end)
        end

        SwatchOuter.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if PickerFrame.Visible then ColorPicker:Hide() else ColorPicker:Show() end
            end
        end)

        Library:GiveSignal(InputService.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                local p, s = PickerFrame.AbsolutePosition, PickerFrame.AbsoluteSize
                if Mouse.X < p.X or Mouse.X > p.X+s.X or Mouse.Y < (p.Y-21) or Mouse.Y > p.Y+s.Y then
                    ColorPicker:Hide()
                end
            end
        end))

        ColorPicker:Display()
        ColorPicker.DisplayFrame = SwatchOuter
        Options[Idx] = ColorPicker
        return self
    end

    -- ── KEY PICKER ───────────────────────────────────────────
    function Funcs:AddKeyPicker(Idx, Info)
        local ParentObj   = self
        local ToggleLabel = self.TextLabel
        assert(Info.Default, 'AddKeyPicker: Missing default value.')

        local KeyPicker = {
            Value        = Info.Default;
            Toggled      = false;
            Mode         = Info.Mode or 'Toggle';
            Type         = 'KeyPicker';
            Callback     = Info.Callback or function() end;
            ChangedCallback = Info.ChangedCallback or function() end;
            SyncToggleState = Info.SyncToggleState or false;
        }

        if KeyPicker.SyncToggleState then
            Info.Modes = { 'Toggle' }
            Info.Mode  = 'Toggle'
        end

        local PickOuter = Library:Create('Frame', {
            BackgroundColor3 = Glass.ElementBG,
            BorderSizePixel = 0,
            Size = UDim2.new(0,30,0,16),
            ZIndex = 6,
            Parent = ToggleLabel,
        })
        Library:Create('UICorner', { CornerRadius = UDim.new(0,4), Parent = PickOuter })
        Library:Create('UIStroke', {
            Color = Glass.BorderBright,
            Transparency = T.BorderGlass,
            Thickness = 1,
            Parent = PickOuter,
        })

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1,0,1,0),
            TextSize = 12,
            Text = Info.Default,
            ZIndex = 7,
            Parent = PickOuter,
        })

        -- Mode selector
        local ModeOuter = Library:Create('Frame', {
            BackgroundColor3 = Glass.PanelBG,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(
                ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4,
                ToggleLabel.AbsolutePosition.Y + 1
            ),
            Size = UDim2.new(0,65,0, (#(Info.Modes or {'Always','Toggle','Hold'}) * 16) + 4),
            Visible = false,
            ZIndex = 14,
            Parent = ScreenGui,
        })
        Library:Create('UICorner', { CornerRadius = UDim.new(0,6), Parent = ModeOuter })
        Library:Create('UIStroke', {
            Color = Glass.BorderBright,
            Transparency = T.BorderGlass,
            Thickness = 1,
            Parent = ModeOuter,
        })

        ToggleLabel:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            ModeOuter.Position = UDim2.fromOffset(
                ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4,
                ToggleLabel.AbsolutePosition.Y + 1
            )
        end)

        Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = ModeOuter,
        })

        local ContainerLabel = Library:CreateLabel({
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1,0,0,18),
            TextSize = 13,
            Visible = false,
            ZIndex = 110,
            Parent = Library.KeybindContainer,
        }, true)

        local Modes      = Info.Modes or { 'Always', 'Toggle', 'Hold' }
        local ModeButtons = {}

        for _, Mode in next, Modes do
            local MB = {}
            local lbl = Library:CreateLabel({
                Active = false,
                Size = UDim2.new(1,0,0,16),
                TextSize = 12,
                Text = Mode,
                ZIndex = 15,
                Parent = ModeOuter,
            })

            function MB:Select()
                for _, b in next, ModeButtons do b:Deselect() end
                KeyPicker.Mode = Mode
                tween(lbl, 0.1, { TextColor3 = Library.AccentColor })
                Library.RegistryMap[lbl].Properties.TextColor3 = 'AccentColor'
                tween(ModeOuter, 0.15, { BackgroundTransparency = 1 })
                task.delay(0.15, function() ModeOuter.Visible = false end)
            end

            function MB:Deselect()
                KeyPicker.Mode = nil
                tween(lbl, 0.1, { TextColor3 = Library.FontColor })
                Library.RegistryMap[lbl].Properties.TextColor3 = 'FontColor'
            end

            lbl.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    MB:Select()
                    Library:AttemptSave()
                end
            end)

            if Mode == KeyPicker.Mode then MB:Select() end
            ModeButtons[Mode] = MB
        end

        function KeyPicker:Update()
            if Info.NoUI then return end
            local state = self:GetState()
            ContainerLabel.Text    = string.format('[%s] %s (%s)', self.Value, Info.Text, self.Mode)
            ContainerLabel.Visible = true
            local col = state and Library.AccentColor or Library.FontColor
            tween(ContainerLabel, 0.1, { TextColor3 = col })
            Library.RegistryMap[ContainerLabel].Properties.TextColor3 = state and 'AccentColor' or 'FontColor'

            local ySize, xSize = 0, 0
            for _, lbl in next, Library.KeybindContainer:GetChildren() do
                if lbl:IsA('TextLabel') and lbl.Visible then
                    ySize += 18
                    if lbl.TextBounds.X > xSize then xSize = lbl.TextBounds.X end
                end
            end
            Library.KeybindFrame.Size = UDim2.new(0, math.max(xSize+10,210), 0, ySize+23)
        end

        function KeyPicker:GetState()
            if self.Mode == 'Always' then return true
            elseif self.Mode == 'Hold' then
                if self.Value == 'None' then return false end
                local k = self.Value
                if k == 'MB1' or k == 'MB2' then
                    return k == 'MB1' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                        or k == 'MB2' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                end
                return InputService:IsKeyDown(Enum.KeyCode[self.Value])
            else
                return self.Toggled
            end
        end

        function KeyPicker:SetValue(Data)
            DisplayLabel.Text = Data[1]
            self.Value = Data[1]
            ModeButtons[Data[2]]:Select()
            self:Update()
        end

        function KeyPicker:OnClick(cb)   self.Clicked  = cb end
        function KeyPicker:OnChanged(cb) self.Changed  = cb; cb(self.Value) end

        if ParentObj.Addons then table.insert(ParentObj.Addons, KeyPicker) end

        function KeyPicker:DoClick()
            if ParentObj.Type == 'Toggle' and self.SyncToggleState then
                ParentObj:SetValue(not ParentObj.Value)
            end
            Library:SafeCallback(self.Callback, self.Toggled)
            Library:SafeCallback(self.Clicked,  self.Toggled)
        end

        local Picking = false

        PickOuter.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Picking = true
                DisplayLabel.Text = ''
                local Break, Text = false, ''
                task.spawn(function()
                    while not Break do
                        Text = Text == '...' and '.' or Text .. '.'
                        DisplayLabel.Text = Text
                        task.wait(0.4)
                    end
                end)
                task.wait(0.2)
                local ev
                ev = InputService.InputBegan:Connect(function(i)
                    local Key
                    if i.UserInputType == Enum.UserInputType.Keyboard then Key = i.KeyCode.Name
                    elseif i.UserInputType == Enum.UserInputType.MouseButton1 then Key = 'MB1'
                    elseif i.UserInputType == Enum.UserInputType.MouseButton2 then Key = 'MB2' end
                    Break = true; Picking = false
                    DisplayLabel.Text = Key; KeyPicker.Value = Key
                    Library:SafeCallback(KeyPicker.ChangedCallback, i.KeyCode or i.UserInputType)
                    Library:SafeCallback(KeyPicker.Changed, i.KeyCode or i.UserInputType)
                    Library:AttemptSave()
                    ev:Disconnect()
                end)
            elseif inp.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ModeOuter.BackgroundTransparency = T.PanelBG
                ModeOuter.Visible = true
                tween(ModeOuter, 0.15, { BackgroundTransparency = T.PanelBG - 0.1 })
            end
        end)

        Library:GiveSignal(InputService.InputBegan:Connect(function(inp)
            if not Picking then
                if KeyPicker.Mode == 'Toggle' then
                    local k = KeyPicker.Value
                    if (k == 'MB1' and inp.UserInputType == Enum.UserInputType.MouseButton1)
                    or (k == 'MB2' and inp.UserInputType == Enum.UserInputType.MouseButton2)
                    or (inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode.Name == k) then
                        KeyPicker.Toggled = not KeyPicker.Toggled
                        KeyPicker:DoClick()
                    end
                end
                KeyPicker:Update()
            end

            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                local p, s = ModeOuter.AbsolutePosition, ModeOuter.AbsoluteSize
                if Mouse.X < p.X or Mouse.X > p.X+s.X or Mouse.Y < (p.Y-21) or Mouse.Y > p.Y+s.Y then
                    tween(ModeOuter, 0.1, { BackgroundTransparency = 1 })
                    task.delay(0.1, function() ModeOuter.Visible = false end)
                end
            end
        end))

        Library:GiveSignal(InputService.InputEnded:Connect(function()
            if not Picking then KeyPicker:Update() end
        end))

        KeyPicker:Update()
        Options[Idx] = KeyPicker
        return self
    end

    BaseAddons.__index = Funcs
    BaseAddons.__namecall = function(t, k, ...) return Funcs[k](...) end
end

-- ═══════════════════════════════════════════════════════════════
-- BASE GROUPBOX  (all element constructors)
-- ═══════════════════════════════════════════════════════════════
local BaseGroupbox = {}

do
    local Funcs = {}

    function Funcs:AddBlank(Size)
        Library:Create('Frame', {
            BackgroundTransparency = 1,
            Size = UDim2.new(1,0,0,Size),
            ZIndex = 1,
            Parent = self.Container,
        })
    end

    function Funcs:AddLabel(Text, DoesWrap)
        local Label = {}
        local Container = self.Container

        local TextLabel = Library:CreateLabel({
            Size = UDim2.new(1,-4,0,15),
            TextSize = 14,
            Text = Text,
            TextWrapped = DoesWrap or false,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 5,
            Parent = Container,
        })

        if DoesWrap then
            local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
            TextLabel.Size = UDim2.new(1,-4,0,Y)
        else
            Library:Create('UIListLayout', {
                Padding = UDim.new(0,4),
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Right,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = TextLabel,
            })
        end

        Label.TextLabel = TextLabel
        Label.Container = Container

        function Label:SetText(t)
            TextLabel.Text = t
            if DoesWrap then
                local Y = select(2, Library:GetTextBounds(t, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
                TextLabel.Size = UDim2.new(1,-4,0,Y)
            end
            self:Resize()
        end

        if not DoesWrap then setmetatable(Label, BaseAddons) end

        self:AddBlank(5)
        self:Resize()
        return Label
    end

    -- ── BUTTON ───────────────────────────────────────────────
    function Funcs:AddButton(...)
        local Button = {}
        local function ProcessParams(_, obj, ...)
            local p = select(1, ...)
            if type(p) == 'table' then
                obj.Text = p.Text; obj.Func = p.Func
                obj.DoubleClick = p.DoubleClick; obj.Tooltip = p.Tooltip
            else
                obj.Text = select(1,...); obj.Func = select(2,...)
            end
            assert(type(obj.Func) == 'function', 'AddButton: `Func` callback missing.')
        end
        ProcessParams('Button', Button, ...)

        local Container = self.Container

        local function MakeBtn(b)
            local outer = Library:Create('Frame', {
                BackgroundColor3 = Glass.ElementBG,
                BorderSizePixel  = 0,
                Size = UDim2.new(1,-4,0,22),
                ZIndex = 5,
            })
            Library:Create('UICorner', { CornerRadius = UDim.new(0,5), Parent = outer })
            Library:Create('UIStroke', {
                Color = Glass.BorderBright, Transparency = T.BorderGlass+0.05,
                Thickness = 1, Parent = outer,
            })
            local lbl = Library:CreateLabel({
                Size = UDim2.new(1,0,1,0),
                TextSize = 14, Text = b.Text, ZIndex = 6, Parent = outer,
            })
            -- hover glow
            outer.MouseEnter:Connect(function()
                tween(outer, 0.12, { BackgroundColor3 = Glass.HoverBG })
            end)
            outer.MouseLeave:Connect(function()
                tween(outer, 0.15, { BackgroundColor3 = Glass.ElementBG })
            end)
            return outer, outer, lbl
        end

        Button.Outer, Button.Inner, Button.Label = MakeBtn(Button)
        Button.Outer.Parent = Container

        local function WaitForEvent(event, timeout, validator)
            local bind = Instance.new('BindableEvent')
            local conn = event:Once(function(...)
                bind:Fire(type(validator)=='function' and validator(...) and true or false)
            end)
            task.delay(timeout, function() conn:Disconnect(); bind:Fire(false) end)
            return bind.Event:Wait()
        end

        local function ValidateClick(inp)
            return not Library:MouseIsOverOpenedFrame()
                and inp.UserInputType == Enum.UserInputType.MouseButton1
        end

        local function InitEvents(b)
            b.Outer.InputBegan:Connect(function(inp)
                if not ValidateClick(inp) then return end
                if b.Locked then return end
                -- click press animation
                tween(b.Outer, 0.08, { BackgroundColor3 = Glass.Accent })
                task.delay(0.08, function() tween(b.Outer, 0.15, { BackgroundColor3 = Glass.ElementBG }) end)

                if b.DoubleClick then
                    tween(b.Label, 0.1, { TextColor3 = Glass.Accent })
                    b.Label.Text = 'Are you sure?'
                    b.Locked = true
                    local clicked = WaitForEvent(b.Outer.InputBegan, 0.5, ValidateClick)
                    tween(b.Label, 0.1, { TextColor3 = Library.FontColor })
                    b.Label.Text = b.Text
                    task.defer(rawset, b, 'Locked', false)
                    if clicked then Library:SafeCallback(b.Func) end
                    return
                end
                Library:SafeCallback(b.Func)
            end)
        end

        InitEvents(Button)

        function Button:AddTooltip(t)
            if type(t) == 'string' then Library:AddToolTip(t, self.Outer) end
            return self
        end

        function Button:AddButton(...)
            local Sub = {}
            ProcessParams('SubButton', Sub, ...)
            self.Outer.Size = UDim2.new(0.5,-2,0,22)
            Sub.Outer, Sub.Inner, Sub.Label = MakeBtn(Sub)
            Sub.Outer.Position = UDim2.new(1,3,0,0)
            Sub.Outer.Size = UDim2.fromOffset(self.Outer.AbsoluteSize.X-2, self.Outer.AbsoluteSize.Y)
            Sub.Outer.Parent = self.Outer
            function Sub:AddTooltip(t)
                if type(t) == 'string' then Library:AddToolTip(t, self.Outer) end
                return Sub
            end
            if type(Sub.Tooltip) == 'string' then Sub:AddTooltip(Sub.Tooltip) end
            InitEvents(Sub)
            return Sub
        end

        if type(Button.Tooltip) == 'string' then Button:AddTooltip(Button.Tooltip) end

        self:AddBlank(5)
        self:Resize()
        return Button
    end

    -- ── DIVIDER ───────────────────────────────────────────────
    function Funcs:AddDivider()
        self:AddBlank(2)
        local line = Library:Create('Frame', {
            BackgroundColor3 = Glass.BorderBright,
            BackgroundTransparency = T.BorderGlass,
            BorderSizePixel = 0,
            Size = UDim2.new(1,-8,0,1),
            ZIndex = 5,
            Parent = self.Container,
        })
        Library:Create('UICorner', { CornerRadius = UDim.new(1,0), Parent = line })
        self:AddBlank(9)
        self:Resize()
    end

    -- ── INPUT ─────────────────────────────────────────────────
    function Funcs:AddInput(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text`.')
        local Textbox = {
            Value = Info.Default or ''; Numeric = Info.Numeric or false;
            Finished = Info.Finished or false; Type = 'Input';
            Callback = Info.Callback or function() end;
        }
        local Container = self.Container

        Library:CreateLabel({
            Size = UDim2.new(1,0,0,15), TextSize = 14, Text = Info.Text,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = Container,
        })
        self:AddBlank(1)

        local BoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Glass.ElementBG, BorderSizePixel = 0,
            Size = UDim2.new(1,-4,0,22), ZIndex = 5, Parent = Container,
        })
        Library:Create('UICorner', { CornerRadius = UDim.new(0,5), Parent = BoxOuter })
        local stroke = Library:Create('UIStroke', {
            Color = Glass.BorderBright, Transparency = T.BorderGlass+0.05,
            Thickness = 1, Parent = BoxOuter,
        })

        BoxOuter.MouseEnter:Connect(function()
            tween(stroke, 0.12, { Transparency = T.BorderGlass - 0.15 })
        end)
        BoxOuter.MouseLeave:Connect(function()
            tween(stroke, 0.15, { Transparency = T.BorderGlass + 0.05 })
        end)

        local clip = Library:Create('Frame', {
            BackgroundTransparency = 1, ClipsDescendants = true,
            Position = UDim2.new(0,5,0,0), Size = UDim2.new(1,-5,1,0), ZIndex = 7, Parent = BoxOuter,
        })

        local Box = Library:Create('TextBox', {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0,0), Size = UDim2.fromScale(5,1),
            Font = Library.Font, PlaceholderColor3 = Glass.TextDim,
            PlaceholderText = Info.Placeholder or '',
            Text = Info.Default or '', TextColor3 = Glass.TextPrimary,
            TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 7, Parent = clip,
        })

        Box.Focused:Connect(function()
            tween(stroke, 0.15, { Transparency = T.BorderGlass - 0.3, Color = Glass.Accent })
        end)
        Box.FocusLost:Connect(function()
            tween(stroke, 0.2, { Transparency = T.BorderGlass + 0.05, Color = Glass.BorderBright })
        end)

        function Textbox:SetValue(Text)
            if Info.MaxLength and #Text > Info.MaxLength then Text = Text:sub(1, Info.MaxLength) end
            if self.Numeric and not tonumber(Text) and #Text > 0 then Text = self.Value end
            self.Value = Text; Box.Text = Text
            Library:SafeCallback(self.Callback, self.Value)
            Library:SafeCallback(self.Changed,  self.Value)
        end

        if Textbox.Finished then
            Box.FocusLost:Connect(function(enter)
                if not enter then return end
                Textbox:SetValue(Box.Text); Library:AttemptSave()
            end)
        else
            Box:GetPropertyChangedSignal('Text'):Connect(function()
                Textbox:SetValue(Box.Text); Library:AttemptSave()
            end)
        end

        local function UpdateCursor()
            local PADDING, reveal = 2, clip.AbsoluteSize.X
            if not Box:IsFocused() or Box.TextBounds.X <= reveal - 2*PADDING then
                Box.Position = UDim2.new(0, PADDING, 0, 0)
            else
                local cursor = Box.CursorPosition
                if cursor ~= -1 then
                    local sub   = Box.Text:sub(1, cursor-1)
                    local width = TextService:GetTextSize(sub, Box.TextSize, Box.Font, Vector2.new(math.huge, math.huge)).X
                    local cur   = Box.Position.X.Offset + width
                    if cur < PADDING then
                        Box.Position = UDim2.fromOffset(PADDING-width, 0)
                    elseif cur > reveal - PADDING - 1 then
                        Box.Position = UDim2.fromOffset(reveal-width-PADDING-1, 0)
                    end
                end
            end
        end

        task.spawn(UpdateCursor)
        Box:GetPropertyChangedSignal('Text'):Connect(UpdateCursor)
        Box:GetPropertyChangedSignal('CursorPosition'):Connect(UpdateCursor)
        Box.FocusLost:Connect(UpdateCursor)
        Box.Focused:Connect(UpdateCursor)

        Library:AddToRegistry(Box, { TextColor3 = 'FontColor' })

        function Textbox:OnChanged(f) self.Changed = f; f(self.Value) end

        self:AddBlank(5); self:Resize()
        Options[Idx] = Textbox
        return Textbox
    end

    -- ── TOGGLE ────────────────────────────────────────────────
    function Funcs:AddToggle(Idx, Info)
        assert(Info.Text, 'AddToggle: Missing `Text`.')
        local Toggle = {
            Value = Info.Default or false; Type = 'Toggle';
            Callback = Info.Callback or function() end;
            Addons = {}; Risky = Info.Risky;
        }
        local Container = self.Container

        local CheckOuter = Library:Create('Frame', {
            BackgroundColor3 = Glass.ElementBG, BorderSizePixel = 0,
            Size = UDim2.new(0,14,0,14), ZIndex = 5, Parent = Container,
        })
        Library:Create('UICorner', { CornerRadius = UDim.new(0,4), Parent = CheckOuter })
        local checkStroke = Library:Create('UIStroke', {
            Color = Glass.BorderBright, Transparency = T.BorderGlass,
            Thickness = 1, Parent = CheckOuter,
        })

        -- Checkmark icon
        local CheckMark = Library:Create('ImageLabel', {
            BackgroundTransparency = 1,
            Size = UDim2.new(0,10,0,10),
            Position = UDim2.new(0.5,0,0.5,0),
            AnchorPoint = Vector2.new(0.5,0.5),
            Image = 'rbxassetid://10709791437',  -- checkmark icon
            ImageColor3 = Color3.new(1,1,1),
            ImageTransparency = 1,
            ZIndex = 7,
            Parent = CheckOuter,
        })

        local ToggleLabel = Library:CreateLabel({
            Size = UDim2.new(0,216,1,0),
            Position = UDim2.new(1,6,0,0),
            TextSize = 14, Text = Info.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 6, Parent = CheckOuter,
        })

        Library:Create('UIListLayout', {
            Padding = UDim.new(0,4),
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = ToggleLabel,
        })

        local HitBox = Library:Create('Frame', {
            BackgroundTransparency = 1,
            Size = UDim2.new(0,170,1,0),
            ZIndex = 8, Parent = CheckOuter,
        })

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, HitBox)
        end

        function Toggle:Display()
            local on = self.Value
            -- Animate background
            tween(CheckOuter, 0.18, {
                BackgroundColor3 = on and Glass.Accent or Glass.ElementBG
            })
            -- Animate stroke
            tween(checkStroke, 0.18, {
                Color = on and Glass.Accent or Glass.BorderBright,
                Transparency = on and 0.4 or T.BorderGlass,
            })
            -- Animate checkmark
            tween(CheckMark, 0.15, { ImageTransparency = on and 0 or 1 })
            if on then
                -- Pop scale — spring bounce
                CheckMark.Size = UDim2.new(0,6,0,6)
                tweenSpring(CheckMark, 0.3, { Size = UDim2.new(0,10,0,10) })
            end

            Library.RegistryMap[CheckOuter] = Library.RegistryMap[CheckOuter] or { Properties = {} }
        end

        function Toggle:UpdateColors() self:Display() end

        function Toggle:OnChanged(f) self.Changed = f; f(self.Value) end

        function Toggle:SetValue(Bool)
            self.Value = not not Bool
            self:Display()
            for _, addon in next, self.Addons do
                if addon.Type == 'KeyPicker' and addon.SyncToggleState then
                    addon.Toggled = Bool; addon:Update()
                end
            end
            Library:SafeCallback(self.Callback, self.Value)
            Library:SafeCallback(self.Changed,  self.Value)
            Library:UpdateDependencyBoxes()
        end

        HitBox.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Toggle:SetValue(not Toggle.Value)
                Library:AttemptSave()
            end
        end)

        HitBox.MouseEnter:Connect(function()
            if not Toggle.Value then
                tween(CheckOuter, 0.1, { BackgroundColor3 = Glass.HoverBG })
            end
        end)
        HitBox.MouseLeave:Connect(function()
            if not Toggle.Value then
                tween(CheckOuter, 0.12, { BackgroundColor3 = Glass.ElementBG })
            end
        end)

        if Toggle.Risky then
            Library:RemoveFromRegistry(ToggleLabel)
            ToggleLabel.TextColor3 = Library.RiskColor
            Library:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' })
        end

        Toggle:Display()
        self:AddBlank(Info.BlankSize or 7)
        self:Resize()

        Toggle.TextLabel = ToggleLabel
        Toggle.Container = Container
        setmetatable(Toggle, BaseAddons)
        Toggles[Idx] = Toggle
        Library:UpdateDependencyBoxes()
        return Toggle
    end

    -- ── SLIDER ────────────────────────────────────────────────
    function Funcs:AddSlider(Idx, Info)
        assert(Info.Default and Info.Text and Info.Min and Info.Max and Info.Rounding,
            'AddSlider: Missing required fields.')

        local Slider = {
            Value = Info.Default; Min = Info.Min; Max = Info.Max;
            Rounding = Info.Rounding; MaxSize = 232; Type = 'Slider';
            Callback = Info.Callback or function() end;
        }
        local Container = self.Container

        if not Info.Compact then
            Library:CreateLabel({
                Size = UDim2.new(1,0,0,10), TextSize = 14, Text = Info.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Bottom,
                ZIndex = 5, Parent = Container,
            })
            self:AddBlank(3)
        end

        local TrackOuter = Library:Create('Frame', {
            BackgroundColor3 = Glass.ElementBG, BorderSizePixel = 0,
            Size = UDim2.new(1,-4,0,14), ZIndex = 5, Parent = Container,
        })
        Library:Create('UICorner', { CornerRadius = UDim.new(1,0), Parent = TrackOuter })
        local trackStroke = Library:Create('UIStroke', {
            Color = Glass.BorderBright, Transparency = T.BorderGlass+0.05,
            Thickness = 1, Parent = TrackOuter,
        })

        local Fill = Library:Create('Frame', {
            BackgroundColor3 = Glass.Accent, BorderSizePixel = 0,
            Size = UDim2.new(0,0,1,0), ZIndex = 6, Parent = TrackOuter,
        })
        Library:Create('UICorner', { CornerRadius = UDim.new(1,0), Parent = Fill })
        Library:AddToRegistry(Fill, { BackgroundColor3 = 'AccentColor' })

        -- Thumb
        local Thumb = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5,0.5),
            BackgroundColor3 = Color3.new(1,1,1),
            BorderSizePixel = 0,
            Position = UDim2.new(0,0,0.5,0),
            Size = UDim2.new(0,10,0,10),
            ZIndex = 8, Parent = TrackOuter,
        })
        Library:Create('UICorner', { CornerRadius = UDim.new(1,0), Parent = Thumb })

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1,0,1,0), TextSize = 13, ZIndex = 9, Parent = TrackOuter,
        })

        TrackOuter.MouseEnter:Connect(function()
            tween(trackStroke, 0.1, { Transparency = T.BorderGlass - 0.15 })
            tweenSpring(Thumb, 0.2, { Size = UDim2.new(0,12,0,12) })
        end)
        TrackOuter.MouseLeave:Connect(function()
            tween(trackStroke, 0.12, { Transparency = T.BorderGlass + 0.05 })
            tween(Thumb, 0.15, { Size = UDim2.new(0,10,0,10) })
        end)

        function Slider:Display()
            local suf = Info.Suffix or ''
            if Info.Compact then
                DisplayLabel.Text = Info.Text .. ': ' .. self.Value .. suf
            elseif Info.HideMax then
                DisplayLabel.Text = self.Value .. suf
            else
                DisplayLabel.Text = string.format('%s/%s', self.Value..suf, self.Max..suf)
            end
            local pct = (self.Value - self.Min) / (self.Max - self.Min)
            local px  = math.ceil(pct * self.MaxSize)
            tween(Fill,  0.08, { Size     = UDim2.new(0, px, 1, 0) })
            tween(Thumb, 0.08, { Position = UDim2.new(0, px, 0.5, 0) })
        end

        function Slider:OnChanged(f) self.Changed = f; f(self.Value) end

        local function Round(v)
            if self.Rounding == 0 then return math.floor(v) end
            return tonumber(string.format('%.'..self.Rounding..'f', v))
        end

        function Slider:SetValue(str)
            local n = tonumber(str)
            if not n then return end
            n = math.clamp(n, self.Min, self.Max)
            self.Value = n; self:Display()
            Library:SafeCallback(self.Callback, self.Value)
            Library:SafeCallback(self.Changed,  self.Value)
        end

        TrackOuter.InputBegan:Connect(function(inp)
            if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            if Library:MouseIsOverOpenedFrame() then return end
            tween(Thumb, 0.1, { BackgroundColor3 = Glass.AccentText })
            local mPos = Mouse.X
            local gPos = Fill.Size.X.Offset
            local diff = mPos - (Fill.AbsolutePosition.X + gPos)
            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                local nX = math.clamp(gPos + (Mouse.X - mPos) + diff, 0, Slider.MaxSize)
                local nV = Round(Library:MapValue(nX, 0, Slider.MaxSize, Slider.Min, Slider.Max))
                local old = Slider.Value; Slider.Value = nV; Slider:Display()
                if nV ~= old then
                    Library:SafeCallback(Slider.Callback, Slider.Value)
                    Library:SafeCallback(Slider.Changed,  Slider.Value)
                end
                RenderStepped:Wait()
            end
            tween(Thumb, 0.1, { BackgroundColor3 = Color3.new(1,1,1) })
            Library:AttemptSave()
        end)

        Slider:Display()
        self:AddBlank(Info.BlankSize or 6)
        self:Resize()
        Options[Idx] = Slider
        return Slider
    end

    -- ── DROPDOWN ─────────────────────────────────────────────
    function Funcs:AddDropdown(Idx, Info)
        if Info.SpecialType == 'Player' then Info.Values = GetPlayersString(); Info.AllowNull = true
        elseif Info.SpecialType == 'Team' then Info.Values = GetTeamsString(); Info.AllowNull = true end

        assert(Info.Values, 'AddDropdown: Missing Values.')
        assert(Info.AllowNull or Info.Default, 'AddDropdown: Missing default.')
        if not Info.Text then Info.Compact = true end

        local Dropdown = {
            Values = Info.Values; Value = Info.Multi and {};
            Multi = Info.Multi; Type = 'Dropdown';
            SpecialType = Info.SpecialType;
            Callback = Info.Callback or function() end;
        }
        local Container = self.Container

        if not Info.Compact then
            Library:CreateLabel({
                Size = UDim2.new(1,0,0,10), TextSize = 14, Text = Info.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Bottom,
                ZIndex = 5, Parent = Container,
            })
            self:AddBlank(3)
        end

        local DropOuter = Library:Create('Frame', {
            BackgroundColor3 = Glass.ElementBG, BorderSizePixel = 0,
            Size = UDim2.new(1,-4,0,22), ZIndex = 5, Parent = Container,
        })
        Library:Create('UICorner', { CornerRadius = UDim.new(0,5), Parent = DropOuter })
        local dropStroke = Library:Create('UIStroke', {
            Color = Glass.BorderBright, Transparency = T.BorderGlass+0.05,
            Thickness = 1, Parent = DropOuter,
        })

        local Arrow = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0,0.5),
            BackgroundTransparency = 1,
            Position = UDim2.new(1,-16,0.5,0),
            Size = UDim2.new(0,12,0,12),
            Image = 'http://www.roblox.com/asset/?id=6282522798',
            ZIndex = 7, Parent = DropOuter,
        })

        local ItemList = Library:CreateLabel({
            Position = UDim2.new(0,6,0,0), Size = UDim2.new(1,-6,1,0),
            TextSize = 13, Text = '--',
            TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
            ZIndex = 6, Parent = DropOuter,
        })

        DropOuter.MouseEnter:Connect(function()
            tween(dropStroke, 0.1, { Transparency = T.BorderGlass - 0.15 })
        end)
        DropOuter.MouseLeave:Connect(function()
            tween(dropStroke, 0.12, { Transparency = T.BorderGlass + 0.05 })
        end)

        local MAX_ITEMS = 8

        local ListOuter = Library:Create('Frame', {
            BackgroundColor3 = Glass.PanelBG,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 20, Visible = false,
            Parent = ScreenGui,
        })
        Library:Create('UICorner', { CornerRadius = UDim.new(0,6), Parent = ListOuter })
        Library:Create('UIStroke', {
            Color = Glass.BorderBright, Transparency = T.BorderGlass,
            Thickness = 1, Parent = ListOuter,
        })

        local function RecalcPos()
            ListOuter.Position = UDim2.fromOffset(
                DropOuter.AbsolutePosition.X,
                DropOuter.AbsolutePosition.Y + 24
            )
        end
        local function RecalcSize(y)
            ListOuter.Size = UDim2.fromOffset(
                DropOuter.AbsoluteSize.X,
                y or (MAX_ITEMS * 20 + 2)
            )
        end
        RecalcPos(); RecalcSize()
        DropOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalcPos)

        local Scroll = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1, BorderSizePixel = 0,
            CanvasSize = UDim2.new(0,0,0,0),
            Size = UDim2.new(1,0,1,0), ZIndex = 21,
            TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Glass.Accent,
            Parent = ListOuter,
        })
        Library:Create('UIListLayout', {
            Padding = UDim.new(0,0), FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder, Parent = Scroll,
        })

        function Dropdown:Display()
            local str = ''
            if Info.Multi then
                for _, v in next, Dropdown.Values do
                    if Dropdown.Value[v] then str ..= v .. ', ' end
                end
                str = str:sub(1, #str-2)
            else
                str = Dropdown.Value or ''
            end
            ItemList.Text = str == '' and '--' or str
        end

        function Dropdown:GetActiveValues()
            if Info.Multi then
                local n = 0
                for _ in next, Dropdown.Value do n += 1 end
                return n
            end
            return Dropdown.Value and 1 or 0
        end

        function Dropdown:BuildDropdownList()
            for _, c in next, Scroll:GetChildren() do
                if not c:IsA('UIListLayout') then c:Destroy() end
            end
            local count = 0
            local Buttons = {}

            for _, Value in next, Dropdown.Values do
                local T2 = {}
                count += 1

                local Btn = Library:Create('Frame', {
                    BackgroundColor3 = Glass.ElementBG,
                    BackgroundTransparency = 0.3,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1,0,0,22),
                    ZIndex = 23, Active = true,
                    Parent = Scroll,
                })

                local BtnLbl = Library:CreateLabel({
                    Active = false,
                    Size = UDim2.new(1,-8,1,0),
                    Position = UDim2.new(0,8,0,0),
                    TextSize = 13, Text = Value,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 25, Parent = Btn,
                })

                Btn.MouseEnter:Connect(function()
                    tween(Btn, 0.1, { BackgroundTransparency = 0, BackgroundColor3 = Glass.HoverBG })
                end)
                Btn.MouseLeave:Connect(function()
                    tween(Btn, 0.12, { BackgroundTransparency = 0.3, BackgroundColor3 = Glass.ElementBG })
                end)

                local Selected = Info.Multi and Dropdown.Value[Value] or Dropdown.Value == Value

                function T2:UpdateButton()
                    Selected = Info.Multi and Dropdown.Value[Value] or Dropdown.Value == Value
                    tween(BtnLbl, 0.1, {
                        TextColor3 = Selected and Library.AccentColor or Library.FontColor
                    })
                end

                BtnLbl.InputBegan:Connect(function(inp)
                    if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                    local try = not Selected
                    if Dropdown:GetActiveValues() == 1 and not try and not Info.AllowNull then return end
                    if Info.Multi then
                        Selected = try
                        Dropdown.Value[Value] = try or nil
                    else
                        Selected = try
                        Dropdown.Value = try and Value or nil
                        for _, b in next, Buttons do b:UpdateButton() end
                    end
                    T2:UpdateButton()
                    Dropdown:Display()
                    Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
                    Library:SafeCallback(Dropdown.Changed,  Dropdown.Value)
                    Library:AttemptSave()
                end)

                T2:UpdateButton()
                Buttons[Btn] = T2
            end

            Scroll.CanvasSize = UDim2.fromOffset(0, count*22+1)
            RecalcSize(math.clamp(count*22, 0, MAX_ITEMS*22)+1)
        end

        function Dropdown:SetValues(v) if v then self.Values = v end; self:BuildDropdownList() end

        function Dropdown:OpenDropdown()
            ListOuter.BackgroundTransparency = 1
            ListOuter.Visible = true
            tween(ListOuter, 0.18, { BackgroundTransparency = T.PanelBG })
            tween(Arrow, 0.18, { Rotation = 180 })
            Library.OpenedFrames[ListOuter] = true
        end

        function Dropdown:CloseDropdown()
            tween(ListOuter, 0.15, { BackgroundTransparency = 1 })
            tween(Arrow, 0.15, { Rotation = 0 })
            task.delay(0.15, function() ListOuter.Visible = false end)
            Library.OpenedFrames[ListOuter] = nil
        end

        function Dropdown:OnChanged(f) self.Changed = f; f(self.Value) end

        function Dropdown:SetValue(val)
            if self.Multi then
                local t = {}
                for v, _ in next, val do
                    if table.find(self.Values, v) then t[v] = true end
                end
                self.Value = t
            else
                self.Value = (not val or not table.find(self.Values, val)) and nil or val
            end
            self:BuildDropdownList()
            Library:SafeCallback(self.Callback, self.Value)
            Library:SafeCallback(self.Changed,  self.Value)
        end

        DropOuter.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if ListOuter.Visible then Dropdown:CloseDropdown() else Dropdown:OpenDropdown() end
            end
        end)

        InputService.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                local p, s = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize
                if Mouse.X < p.X or Mouse.X > p.X+s.X or Mouse.Y < (p.Y-23) or Mouse.Y > p.Y+s.Y then
                    Dropdown:CloseDropdown()
                end
            end
        end)

        Dropdown:BuildDropdownList()
        Dropdown:Display()

        local defaults = {}
        if type(Info.Default) == 'string' then
            local i = table.find(Dropdown.Values, Info.Default)
            if i then table.insert(defaults, i) end
        elseif type(Info.Default) == 'table' then
            for _, v in next, Info.Default do
                local i = table.find(Dropdown.Values, v)
                if i then table.insert(defaults, i) end
            end
        elseif type(Info.Default) == 'number' and Dropdown.Values[Info.Default] then
            table.insert(defaults, Info.Default)
        end

        for _, i in next, defaults do
            if Info.Multi then Dropdown.Value[Dropdown.Values[i]] = true
            else Dropdown.Value = Dropdown.Values[i]; break end
        end
        if next(defaults) then Dropdown:BuildDropdownList(); Dropdown:Display() end

        self:AddBlank(Info.BlankSize or 5)
        self:Resize()
        Options[Idx] = Dropdown
        return Dropdown
    end

    -- ── DEPENDENCY BOX ────────────────────────────────────────
    function Funcs:AddDependencyBox()
        local Depbox = { Dependencies = {} }
        local Container = self.Container

        local Holder = Library:Create('Frame', {
            BackgroundTransparency = 1,
            Size = UDim2.new(1,0,0,0),
            Visible = false, Parent = Container,
        })
        local Frame = Library:Create('Frame', {
            BackgroundTransparency = 1,
            Size = UDim2.new(1,0,1,0),
            Parent = Holder,
        })
        local Layout = Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = Frame,
        })

        function Depbox:Resize()
            Holder.Size = UDim2.new(1,0,0,Layout.AbsoluteContentSize.Y)
            self.Container:FindFirstAncestorWhichIsA('Frame') -- propagate up
            pcall(function() -- safe resize
                local gb = self
                while gb and gb.Resize do gb:Resize(); break end
            end)
        end

        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function() Depbox:Resize() end)
        Holder:GetPropertyChangedSignal('Visible'):Connect(function() Depbox:Resize() end)

        function Depbox:Update()
            for _, dep in next, self.Dependencies do
                if dep[1].Type == 'Toggle' and dep[1].Value ~= dep[2] then
                    tween(Holder, 0.15, { Size = UDim2.new(1,0,0,0) })
                    task.delay(0.15, function() Holder.Visible = false end)
                    return
                end
            end
            Holder.Visible = true
            tween(Holder, 0.2, { Size = UDim2.new(1,0,0,Layout.AbsoluteContentSize.Y) })
        end

        function Depbox:SetupDependencies(deps)
            for _, d in next, deps do
                assert(type(d)=='table' and d[1] and d[2]~=nil)
            end
            self.Dependencies = deps; self:Update()
        end

        Depbox.Container = Frame
        setmetatable(Depbox, BaseGroupbox)
        table.insert(Library.DependencyBoxes, Depbox)
        return Depbox
    end

    BaseGroupbox.__index = Funcs
    BaseGroupbox.__namecall = function(t, k, ...) return Funcs[k](...) end
end

-- ═══════════════════════════════════════════════════════════════
-- HUD ELEMENTS  (Watermark, Keybind frame, Notifications)
-- ═══════════════════════════════════════════════════════════════
do
    -- Notifications
    Library.NotificationArea = Library:Create('Frame', {
        BackgroundTransparency = 1,
        Position = UDim2.new(0,0,0,40),
        Size = UDim2.new(0,320,0,300),
        ZIndex = 100, Parent = ScreenGui,
    })
    Library:Create('UIListLayout', {
        Padding = UDim.new(0,6),
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = Library.NotificationArea,
    })

    -- Watermark
    local WMOuter = Library:Create('Frame', {
        BackgroundColor3 = Glass.PanelBG,
        BackgroundTransparency = T.PanelBG,
        BorderSizePixel = 0,
        Position = UDim2.new(0,100,0,-30),
        Size = UDim2.new(0,200,0,24),
        Visible = false, ZIndex = 200,
        Parent = ScreenGui,
    })
    Library:Create('UICorner', { CornerRadius = UDim.new(0,6), Parent = WMOuter })
    Library:Create('UIStroke', {
        Color = Glass.Accent, Transparency = 0.5, Thickness = 1, Parent = WMOuter,
    })
    -- accent glow bar
    local WMGlow = Library:Create('Frame', {
        BackgroundColor3 = Glass.Accent,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        Size = UDim2.new(1,0,0,2),
        ZIndex = 201, Parent = WMOuter,
    })
    Library:Create('UICorner', { CornerRadius = UDim.new(0,6), Parent = WMGlow })
    Library:AddToRegistry(WMGlow, { BackgroundColor3 = 'AccentColor' })

    local WMLabel = Library:CreateLabel({
        Position = UDim2.new(0,8,0,0),
        Size = UDim2.new(1,-8,1,0),
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 202, Parent = WMOuter,
    })
    Library.Watermark     = WMOuter
    Library.WatermarkText = WMLabel
    Library:MakeDraggable(WMOuter)

    function Library:SetWatermarkVisibility(bool)
        Library.Watermark.Visible = bool
    end

    function Library:SetWatermark(text)
        local X = Library:GetTextBounds(text, Library.Font, 13)
        WMOuter.Size = UDim2.new(0, X+20, 0, 24)
        WMLabel.Text = text
        Library:SetWatermarkVisibility(true)
    end

    -- Keybind frame
    local KBOuter = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0,0.5),
        BackgroundColor3 = Glass.PanelBG,
        BackgroundTransparency = T.PanelBG,
        BorderSizePixel = 0,
        Position = UDim2.new(0,10,0.5,0),
        Size = UDim2.new(0,220,0,24),
        Visible = false, ZIndex = 100,
        Parent = ScreenGui,
    })
    Library:Create('UICorner', { CornerRadius = UDim.new(0,7), Parent = KBOuter })
    Library:Create('UIStroke', {
        Color = Glass.BorderBright, Transparency = T.BorderGlass, Thickness = 1, Parent = KBOuter,
    })

    local KBAccent = Library:Create('Frame', {
        BackgroundColor3 = Glass.Accent,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        Size = UDim2.new(1,0,0,2),
        ZIndex = 101, Parent = KBOuter,
    })
    Library:Create('UICorner', { CornerRadius = UDim.new(0,7), Parent = KBAccent })
    Library:AddToRegistry(KBAccent, { BackgroundColor3 = 'AccentColor' }, true)

    Library:CreateLabel({
        Size = UDim2.new(1,0,0,22),
        Position = UDim2.fromOffset(6,2),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = 'Keybinds', ZIndex = 103, Parent = KBOuter,
    })

    local KBContainer = Library:Create('Frame', {
        BackgroundTransparency = 1,
        Size = UDim2.new(1,0,1,-22),
        Position = UDim2.new(0,0,0,22),
        ZIndex = 1, Parent = KBOuter,
    })
    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = KBContainer,
    })
    Library:Create('UIPadding', { PaddingLeft = UDim.new(0,6), Parent = KBContainer })

    Library.KeybindFrame     = KBOuter
    Library.KeybindContainer = KBContainer
    Library:MakeDraggable(KBOuter)
end

-- ── NOTIFICATIONS ─────────────────────────────────────────────
function Library:Notify(Text, Time)
    local X, Y = Library:GetTextBounds(Text, Library.Font, 13)
    Y = Y + 10

    local outer = Library:Create('Frame', {
        BackgroundColor3 = Glass.PanelBG,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 0, Y),
        ClipsDescendants = false,
        ZIndex = 100,
        Parent = Library.NotificationArea,
    })
    Library:Create('UICorner', { CornerRadius = UDim.new(0,7), Parent = outer })
    Library:Create('UIStroke', {
        Color = Glass.BorderBright, Transparency = T.BorderGlass, Thickness = 1, Parent = outer,
    })

    -- Accent left pill
    local pill = Library:Create('Frame', {
        BackgroundColor3 = Glass.Accent,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Position = UDim2.new(0,0,0,0),
        Size = UDim2.new(0,3,1,0),
        ZIndex = 102, Parent = outer,
    })
    Library:Create('UICorner', { CornerRadius = UDim.new(0,7), Parent = pill })
    Library:AddToRegistry(pill, { BackgroundColor3 = 'AccentColor' }, true)

    Library:CreateLabel({
        Position = UDim2.new(0,10,0,0),
        Size = UDim2.new(1,-10,1,0),
        Text = Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 13,
        ZIndex = 103,
        Parent = outer,
    })

    -- Slide in
    tween(outer, 0.25, { BackgroundTransparency = T.PanelBG, Size = UDim2.new(0, X+20, 0, Y) },
        Enum.EasingStyle.Back, Enum.EasingDirection.Out)

    task.spawn(function()
        task.wait(Time or 5)
        tween(outer, 0.2, { BackgroundTransparency = 1, Size = UDim2.new(0,0,0,Y) })
        task.wait(0.2)
        outer:Destroy()
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- WINDOW
-- ═══════════════════════════════════════════════════════════════
function Library:CreateWindow(...)
    local args   = { ... }
    local Config = { AnchorPoint = Vector2.zero }

    if type(...) == 'table' then
        Config = ...
    else
        Config.Title = args[1]; Config.AutoShow = args[2] or false
    end

    if type(Config.Title) ~= 'string' then Config.Title = 'Menu' end
    if type(Config.TabPadding)  ~= 'number' then Config.TabPadding  = 0 end
    if type(Config.MenuFadeTime) ~= 'number' then Config.MenuFadeTime = 0.25 end
    if typeof(Config.Position) ~= 'UDim2' then Config.Position = UDim2.fromOffset(175,50) end
    if typeof(Config.Size)     ~= 'UDim2' then Config.Size     = UDim2.fromOffset(560,620) end

    if Config.Center then
        Config.AnchorPoint = Vector2.new(0.5,0.5)
        Config.Position    = UDim2.fromScale(0.5,0.5)
    end

    local Window = { Tabs = {} }

    -- Outer shell: dark glass base
    local Outer = Library:Create('Frame', {
        AnchorPoint = Config.AnchorPoint,
        BackgroundColor3 = Glass.WindowBG,
        BackgroundTransparency = T.WindowBG,
        BorderSizePixel = 0,
        Position = Config.Position,
        Size = Config.Size,
        Visible = false,
        ZIndex = 1,
        Parent = ScreenGui,
    })
    Library:Create('UICorner', { CornerRadius = UDim.new(0,10), Parent = Outer })
    Library:Create('UIStroke', {
        Color = Glass.BorderBright, Transparency = T.BorderGlass - 0.05,
        Thickness = 1, Parent = Outer,
    })

    -- Subtle inner gradient (glass sheen)
    Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Color3.new(1,1,1)),
            ColorSequenceKeypoint.new(1,   Color3.fromRGB(180,180,220)),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0.92),
            NumberSequenceKeypoint.new(1,   0.97),
        }),
        Rotation = 120,
        Parent = Outer,
    })

    Library:MakeDraggable(Outer, 28)

    -- Title bar
    local TitleBar = Library:Create('Frame', {
        BackgroundColor3 = Glass.PanelBG,
        BackgroundTransparency = T.PanelBG + 0.05,
        BorderSizePixel = 0,
        Size = UDim2.new(1,0,0,30),
        ZIndex = 2, Parent = Outer,
    })
    Library:Create('UICorner', { CornerRadius = UDim.new(0,10), Parent = TitleBar })

    -- Accent line under title
    local TitleAccent = Library:Create('Frame', {
        BackgroundColor3 = Glass.Accent,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        Position = UDim2.new(0,0,1,-2),
        Size = UDim2.new(0,0,0,2),
        ZIndex = 3, Parent = TitleBar,
    })
    Library:Create('UICorner', { CornerRadius = UDim.new(0,2), Parent = TitleAccent })
    Library:AddToRegistry(TitleAccent, { BackgroundColor3 = 'AccentColor' })
    -- Animate line in
    tween(TitleAccent, 0.6, { Size = UDim2.new(1,0,0,2) }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

    local TitleLabel = Library:CreateLabel({
        Position = UDim2.new(0,10,0,0),
        Size = UDim2.new(0,0,1,0),
        Text = Config.Title,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 15,
        ZIndex = 3, Parent = TitleBar,
    })

    -- Body
    local Body = Library:Create('Frame', {
        BackgroundTransparency = 1,
        Position = UDim2.new(0,8,0,32),
        Size = UDim2.new(1,-16,1,-40),
        ZIndex = 1, Parent = Outer,
    })

    -- Tab strip
    local TabStrip = Library:Create('ScrollingFrame', {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0,0,0,0),
        Size = UDim2.new(1,0,0,26),
        CanvasSize = UDim2.new(0,0,0,0),
        ScrollBarThickness = 0,
        ZIndex = 2, Parent = Body,
    })
    Library:Create('UIListLayout', {
        Padding = UDim.new(0, Config.TabPadding + 2),
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = TabStrip,
    })

    -- Tab content area
    local TabContainer = Library:Create('Frame', {
        BackgroundColor3 = Glass.GroupBG,
        BackgroundTransparency = T.GroupBG,
        BorderSizePixel = 0,
        Position = UDim2.new(0,0,0,30),
        Size = UDim2.new(1,0,1,-30),
        ZIndex = 2, Parent = Body,
    })
    Library:Create('UICorner', { CornerRadius = UDim.new(0,8), Parent = TabContainer })
    Library:Create('UIStroke', {
        Color = Glass.BorderBright, Transparency = T.BorderGlass,
        Thickness = 1, Parent = TabContainer,
    })

    function Window:SetWindowTitle(t) TitleLabel.Text = t end

    function Window:AddTab(Name)
        local Tab = { Groupboxes = {}; Tabboxes = {} }

        local tabW = Library:GetTextBounds(Name, Library.Font, 13) + 16

        -- Tab button
        local TabBtn = Library:Create('Frame', {
            BackgroundColor3 = Glass.ElementBG,
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            Size = UDim2.new(0, tabW, 1, 0),
            ZIndex = 3, Parent = TabStrip,
        })
        Library:Create('UICorner', { CornerRadius = UDim.new(0,6), Parent = TabBtn })
        local tabStroke = Library:Create('UIStroke', {
            Color = Glass.BorderBright, Transparency = T.BorderGlass+0.1,
            Thickness = 1, Parent = TabBtn,
        })

        local TabBtnLabel = Library:CreateLabel({
            Size = UDim2.new(1,0,1,0),
            Text = Name, TextSize = 13, ZIndex = 4, Parent = TabBtn,
        })

        -- Underline indicator
        local TabLine = Library:Create('Frame', {
            BackgroundColor3 = Glass.Accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5,0),
            Position = UDim2.new(0.5,0,1,-2),
            Size = UDim2.new(0,0,0,2),
            ZIndex = 4, Parent = TabBtn,
        })
        Library:Create('UICorner', { CornerRadius = UDim.new(1,0), Parent = TabLine })
        Library:AddToRegistry(TabLine, { BackgroundColor3 = 'AccentColor' })

        -- Tab frame
        local TabFrame = Library:Create('Frame', {
            BackgroundTransparency = 1,
            Size = UDim2.new(1,0,1,0),
            Visible = false, ZIndex = 2, Parent = TabContainer,
        })

        local function MakeSide(xPos, xSize)
            local scroll = Library:Create('ScrollingFrame', {
                BackgroundTransparency = 1, BorderSizePixel = 0,
                Position = UDim2.new(xPos, 8, 0, 8),
                Size = UDim2.new(xSize, -12, 1, -12),
                CanvasSize = UDim2.new(0,0,0,0),
                BottomImage = '', TopImage = '',
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = Glass.Accent,
                ZIndex = 2, Parent = TabFrame,
            })
            Library:Create('UIListLayout', {
                Padding = UDim.new(0,8),
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                Parent = scroll,
            })
            scroll:FindFirstChildOfClass('UIListLayout'):GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                scroll.CanvasSize = UDim2.fromOffset(0, scroll:FindFirstChildOfClass('UIListLayout').AbsoluteContentSize.Y)
            end)
            return scroll
        end

        local LeftSide  = MakeSide(0,   0.5)
        local RightSide = MakeSide(0.5, 0.5)

        function Tab:ShowTab()
            for _, t in next, Window.Tabs do t:HideTab() end
            TabFrame.Visible = true
            -- Activate button
            tween(TabBtn,  0.18, { BackgroundTransparency = 0.1, BackgroundColor3 = Glass.HoverBG })
            tween(tabStroke, 0.18, { Transparency = T.BorderGlass - 0.2, Color = Glass.Accent })
            tween(TabBtnLabel, 0.15, { TextColor3 = Glass.TextPrimary })
            tween(TabLine, 0.2, { BackgroundTransparency = 0.2, Size = UDim2.new(0.7,0,0,2) })
        end

        function Tab:HideTab()
            TabFrame.Visible = false
            tween(TabBtn,  0.15, { BackgroundTransparency = 0.5, BackgroundColor3 = Glass.ElementBG })
            tween(tabStroke, 0.15, { Transparency = T.BorderGlass+0.1, Color = Glass.BorderBright })
            tween(TabBtnLabel, 0.15, { TextColor3 = Glass.TextSecondary })
            tween(TabLine, 0.15, { BackgroundTransparency = 1, Size = UDim2.new(0,0,0,2) })
        end

        function Tab:SetLayoutOrder(pos)
            TabBtn.LayoutOrder = pos
        end

        function Tab:AddGroupbox(Info)
            local Groupbox = {}

            local BoxFrame, _ = Library:CreateGlassFrame({
                Color = Glass.GroupBG,
                Transparency = T.GroupBG - 0.05,
                Size = UDim2.new(1,0,0,40),
                ZIndex = 3,
                Radius = 7,
                Parent = Info.Side == 1 and LeftSide or RightSide,
            }, true) -- with glow line

            local NameLabel = Library:CreateLabel({
                Position = UDim2.new(0,6,0,4),
                Size = UDim2.new(1,-6,0,16),
                TextSize = 13, Text = Info.Name,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = Glass.TextSecondary,
                ZIndex = 5, Parent = BoxFrame,
            })

            local Container = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Position = UDim2.new(0,4,0,22),
                Size = UDim2.new(1,-4,1,-22),
                ZIndex = 1, Parent = BoxFrame,
            })
            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = Container,
            })

            function Groupbox:Resize()
                local h = 0
                for _, el in next, self.Container:GetChildren() do
                    if not el:IsA('UIListLayout') and el.Visible then
                        h += el.Size.Y.Offset
                    end
                end
                tween(BoxFrame, 0.1, { Size = UDim2.new(1,0,0,22+h+4) })
            end

            Groupbox.Container = Container
            setmetatable(Groupbox, BaseGroupbox)
            Groupbox:AddBlank(3)
            Groupbox:Resize()
            Tab.Groupboxes[Info.Name] = Groupbox
            return Groupbox
        end

        function Tab:AddLeftGroupbox(Name)  return Tab:AddGroupbox({ Side=1; Name=Name }) end
        function Tab:AddRightGroupbox(Name) return Tab:AddGroupbox({ Side=2; Name=Name }) end

        function Tab:AddTabbox(Info)
            local Tabbox = { Tabs = {} }

            local BoxFrame, _ = Library:CreateGlassFrame({
                Color = Glass.GroupBG,
                Transparency = T.GroupBG - 0.05,
                Size = UDim2.new(1,0,0,40),
                ZIndex = 3, Radius = 7,
                Parent = Info.Side == 1 and LeftSide or RightSide,
            }, true)

            local TabboxBtnRow = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Position = UDim2.new(0,0,0,2),
                Size = UDim2.new(1,0,0,22),
                ZIndex = 5, Parent = BoxFrame,
            })
            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Left,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = TabboxBtnRow,
            })

            function Tabbox:AddTab(Name)
                local InnerTab = {}

                local Btn = Library:Create('Frame', {
                    BackgroundColor3 = Glass.ElementBG,
                    BackgroundTransparency = 0.5,
                    BorderSizePixel = 0,
                    Size = UDim2.new(0.5,0,1,0),
                    ZIndex = 6, Parent = TabboxBtnRow,
                })
                Library:Create('UICorner', { CornerRadius = UDim.new(0,5), Parent = Btn })

                local BtnLbl = Library:CreateLabel({
                    Size = UDim2.new(1,0,1,0),
                    TextSize = 13, Text = Name, ZIndex = 7, Parent = Btn,
                })

                local BtnLine = Library:Create('Frame', {
                    BackgroundColor3 = Glass.Accent,
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    AnchorPoint = Vector2.new(0.5,0),
                    Position = UDim2.new(0.5,0,1,-1),
                    Size = UDim2.new(0,0,0,1),
                    ZIndex = 7, Parent = Btn,
                })
                Library:Create('UICorner', { CornerRadius = UDim.new(1,0), Parent = BtnLine })
                Library:AddToRegistry(BtnLine, { BackgroundColor3 = 'AccentColor' })

                local InnerContainer = Library:Create('Frame', {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0,4,0,26),
                    Size = UDim2.new(1,-4,1,-26),
                    ZIndex = 1, Visible = false,
                    Parent = BoxFrame,
                })
                Library:Create('UIListLayout', {
                    FillDirection = Enum.FillDirection.Vertical,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = InnerContainer,
                })

                function InnerTab:Show()
                    for _, t in next, Tabbox.Tabs do t:Hide() end
                    InnerContainer.Visible = true
                    tween(Btn, 0.15, { BackgroundTransparency = 0.1, BackgroundColor3 = Glass.HoverBG })
                    tween(BtnLbl, 0.12, { TextColor3 = Glass.TextPrimary })
                    tween(BtnLine, 0.18, { BackgroundTransparency = 0.2, Size = UDim2.new(0.6,0,0,1) })
                    self:Resize()
                end

                function InnerTab:Hide()
                    InnerContainer.Visible = false
                    tween(Btn, 0.12, { BackgroundTransparency = 0.5, BackgroundColor3 = Glass.ElementBG })
                    tween(BtnLbl, 0.12, { TextColor3 = Glass.TextSecondary })
                    tween(BtnLine, 0.12, { BackgroundTransparency = 1, Size = UDim2.new(0,0,0,1) })
                end

                function InnerTab:Resize()
                    local n = 0
                    for _ in next, Tabbox.Tabs do n += 1 end
                    for _, b in next, TabboxBtnRow:GetChildren() do
                        if not b:IsA('UIListLayout') then
                            b.Size = UDim2.new(1/n,0,1,0)
                        end
                    end
                    if not InnerContainer.Visible then return end
                    local h = 0
                    for _, el in next, InnerTab.Container:GetChildren() do
                        if not el:IsA('UIListLayout') and el.Visible then
                            h += el.Size.Y.Offset
                        end
                    end
                    tween(BoxFrame, 0.1, { Size = UDim2.new(1,0,0,26+h+4) })
                end

                Btn.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                        InnerTab:Show()
                    end
                end)

                InnerTab.Container = InnerContainer
                Tabbox.Tabs[Name] = InnerTab
                setmetatable(InnerTab, BaseGroupbox)
                InnerTab:AddBlank(3)
                InnerTab:Resize()
                if #TabboxBtnRow:GetChildren() == 2 then InnerTab:Show() end
                return InnerTab
            end

            Tab.Tabboxes[Info.Name or ''] = Tabbox
            return Tabbox
        end

        function Tab:AddLeftTabbox(Name)  return Tab:AddTabbox({ Name=Name, Side=1 }) end
        function Tab:AddRightTabbox(Name) return Tab:AddTabbox({ Name=Name, Side=2 }) end

        TabBtn.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                Tab:ShowTab()
            end
        end)

        if #TabContainer:GetChildren() == 1 then Tab:ShowTab() end
        Window.Tabs[Name] = Tab
        return Tab
    end

    -- ── MENU TOGGLE ──────────────────────────────────────────
    local ModalElement = Library:Create('TextButton', {
        BackgroundTransparency = 1, Size = UDim2.new(0,0,0,0),
        Visible = true, Text = '', Modal = false, Parent = ScreenGui,
    })

    local Toggled, Fading = false, false

    function Library:Toggle()
        if Fading then return end
        local FadeTime = Config.MenuFadeTime
        Fading  = true
        Toggled = not Toggled
        ModalElement.Modal = Toggled

        if Toggled then
            Outer.Visible = true
            Outer.BackgroundTransparency = 1

            -- Slide in + fade
            Outer.Position = Config.Position + UDim2.new(0,0,0,-12)
            tween(Outer, FadeTime, {
                BackgroundTransparency = T.WindowBG,
                Position = Config.Position,
            }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

            -- Animated custom cursor
            task.spawn(function()
                local State = InputService.MouseIconEnabled
                local Cursor = Drawing.new('Triangle')
                Cursor.Thickness = 1; Cursor.Filled = true; Cursor.Visible = true
                local CO = Drawing.new('Triangle')
                CO.Thickness = 1; CO.Filled = false
                CO.Color = Color3.new(0,0,0); CO.Visible = true

                while Toggled and ScreenGui.Parent do
                    InputService.MouseIconEnabled = false
                    local m = InputService:GetMouseLocation()
                    Cursor.Color = Library.AccentColor
                    Cursor.PointA = m; Cursor.PointB = m + Vector2.new(16,6); Cursor.PointC = m + Vector2.new(6,16)
                    CO.PointA = Cursor.PointA; CO.PointB = Cursor.PointB; CO.PointC = Cursor.PointC
                    RenderStepped:Wait()
                end

                InputService.MouseIconEnabled = State
                Cursor:Remove(); CO:Remove()
            end)
        else
            tween(Outer, FadeTime * 0.8, {
                BackgroundTransparency = 1,
                Position = Config.Position + UDim2.new(0,0,0,8),
            })
            task.wait(FadeTime * 0.8)
            Outer.Visible = false
        end

        Fading = false
    end

    Library:GiveSignal(InputService.InputBegan:Connect(function(inp, processed)
        if type(Library.ToggleKeybind) == 'table' and Library.ToggleKeybind.Type == 'KeyPicker' then
            if inp.UserInputType == Enum.UserInputType.Keyboard
            and inp.KeyCode.Name == Library.ToggleKeybind.Value then
                task.spawn(Library.Toggle)
            end
        elseif inp.KeyCode == Enum.KeyCode.RightControl
        or (inp.KeyCode == Enum.KeyCode.RightShift and not processed) then
            task.spawn(Library.Toggle)
        end
    end))

    if Config.AutoShow then task.spawn(Library.Toggle) end

    Window.Holder = Outer
    return Window
end

-- ── PLAYER LIST SYNC ─────────────────────────────────────────
local function OnPlayerChange()
    local list = GetPlayersString()
    for _, v in next, Options do
        if v.Type == 'Dropdown' and v.SpecialType == 'Player' then
            v:SetValues(list)
        end
    end
end
Players.PlayerAdded:Connect(OnPlayerChange)
Players.PlayerRemoving:Connect(OnPlayerChange)

getgenv().Library = Library
return Library
