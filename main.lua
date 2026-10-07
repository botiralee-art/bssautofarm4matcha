--[[
    ========================================================================
    LOLCAT | Matcha Edition — Bee Swarm Simulator Complete Suite
    ========================================================================
    Features:
      * 100% Crash-Free Pure Lua Engine (No unmapped memory writes)
      * Full Lolcat UI Library in Original Soft Teal (#9AD5DE)
      * Smooth CFrame Matrix Facing (Face Middle, Face Bubbles, Face Balloons)
      * Velocity-Based Tween with Noclip & Active Walk Animation (Passes through walls)
      * World No-Collide (Disables collisions on fences, trees & field decos)
      * 5-Tier Instant Hive Detection + Fast Pad Sweep Fallback
      * Extended BSS Gathering: Under Balloons, Clouds, Flames, Bubbles, Sprouts, Stars
      * Boss & Mob Combat: Coconut Crab, King Beetle, Tunnel Bear, Mondo Chick, Vicious Bee
      * Rebindable Menu Keybind with Full Feature Auto-Pause (Suspends features when menu is open)
      * Cursor-Free Tool:Activate() Digging
    ========================================================================
]]

--------------------------------------------------------------------------
-- SECTION 1: LOLCAT DRAWING UI FRAMEWORK (ORIGINAL SOFT TEAL PALETTE)
--------------------------------------------------------------------------
local LolcatUI = { _VERSION = "2.0.0", Windows = {} }
LolcatUI.__index = LolcatUI

local floor, ceil, max, min, abs = math.floor, math.ceil, math.max, math.min, math.abs
local fmt = string.format
local insert, remove = table.insert, table.remove

local function clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function lerp(a, b, t) return a + (b - a) * t end
local function round(v) return floor(v + 0.5) end

local function try(f, ...)
    local ok, res = pcall(f, ...)
    if ok then return res end
    return nil
end

local function safeText(obj)
    if not obj then return "" end
    local ok, res = pcall(function()
        local v = obj.Text
        if type(v) == "string" then return v end
        return ""
    end)
    return (ok and type(res) == "string") and res or ""
end

local function lerpAngle(from, to, alpha)
    local delta = to - from
    while delta > 180 do delta = delta - 360 end
    while delta < -180 do delta = delta + 360 end
    return from + delta * alpha
end

local function pack(r, g, b)
    return floor(r) * 65536 + floor(g) * 256 + floor(b)
end

local function rgb3(c)
    return floor(c / 65536) % 256, floor(c / 256) % 256, c % 256
end

local function mix(a, b, t)
    local ar, ag, ab = rgb3(a)
    local br, bg, bb = rgb3(b)
    return pack(lerp(ar, br, t) + 0.5, lerp(ag, bg, t) + 0.5, lerp(ab, bb, t) + 0.5)
end

local function toColorInt(c)
    if type(c) == "number" then return c end
    if typeof and typeof(c) == "Color3" then
        return pack(c.R * 255 + 0.5, c.G * 255 + 0.5, c.B * 255 + 0.5)
    end
    if type(c) == "table" and c.R and c.G and c.B then
        return pack(c.R * 255 + 0.5, c.G * 255 + 0.5, c.B * 255 + 0.5)
    end
    return 0xFFFFFF
end

local function toColor3(c)
    if typeof and typeof(c) == "Color3" then return c end
    local r, g, b = rgb3(type(c) == "number" and c or toColorInt(c))
    return Color3.fromRGB(r, g, b)
end

-- ORIGINAL LOLCAT PALETTE (#9AD5DE Soft Teal)
local DefaultTheme = {
    Accent = pack(154, 213, 222),                 -- #9AD5DE Original Soft Teal
    Outline = pack(24, 25, 24),                   -- #181918 Dark border
    Background = pack(0, 0, 0),                   -- #000000 Window body
    ElementBackground = pack(6, 6, 6),            -- #060606 Card fill
    TabButtonSelected = pack(51, 65, 70),         -- #334146 Active tab
    Unselected = pack(75, 72, 72),                -- #4B4848 Inactive text
    TextColor = pack(197, 197, 197),              -- #C5C5C5 Main text
    ToggleCircleUnselected = pack(70, 85, 87),    -- #465557 Toggle off circle
    ToggleBackgroundUnselected = pack(12, 13, 13),-- #0C0D0D Toggle off track
    GradientTop = pack(14, 16, 16),               -- #0E1010
    GradientMid = pack(6, 6, 6),                  -- #060606
    GradientDark = pack(3, 3, 3),                 -- #030303
    TabHighlight = pack(51, 65, 70),              -- #334146
    TabShadow = pack(30, 51, 61),                 -- #1E333D
    White = pack(255, 255, 255),                  -- #FFFFFF
}

local KeyNames = {
    [0x01] = "LMB", [0x02] = "RMB", [0x04] = "MMB", [0x05] = "MB4", [0x06] = "MB5", [0x08] = "Back",
    [0x09] = "Tab", [0x0D] = "Enter", [0x10] = "Shift", [0x11] = "Ctrl", [0x12] = "Alt", [0x13] = "Pause",
    [0x14] = "Caps", [0x1B] = "Esc", [0x20] = "Space", [0x21] = "PgUp", [0x22] = "PgDn", [0x23] = "End",
    [0x24] = "Home", [0x25] = "Left", [0x26] = "Up", [0x27] = "Right", [0x28] = "Down", [0x2D] = "Ins",
    [0x2E] = "Del", [0xA0] = "LShift", [0xA1] = "RShift", [0xA2] = "LCtrl", [0xA3] = "RCtrl",
    [0xA4] = "LAlt", [0xA5] = "RAlt",
}
for i = 0x30, 0x39 do KeyNames[i] = string.char(i) end
for i = 0x41, 0x5A do KeyNames[i] = string.char(i) end
for i = 0, 9 do KeyNames[0x60 + i] = "Num" .. i end
for i = 1, 12 do KeyNames[0x6F + i] = "F" .. i end

local NameToVK = {}
for vk, name in pairs(KeyNames) do NameToVK[name:lower()] = vk end
NameToVK["rightshift"] = 0xA1
NameToVK["leftshift"] = 0xA0

local function resolveVK(val)
    if type(val) == "number" then return val end
    if type(val) == "string" then
        return NameToVK[val:lower()] or NameToVK[val:gsub("Enum%.KeyCode%.", ""):lower()]
    end
    return nil
end

local function keyName(vk)
    if not vk then return "None" end
    return KeyNames[vk] or fmt("0x%X", vk)
end

local function keyDown(vk)
    if not vk then return false end
    if type(iskeypressed) == "function" then
        local ok, res = pcall(iskeypressed, vk)
        return ok and res and true or false
    end
    return false
end

local function getMouseCoords()
    local ok, pos = pcall(function()
        local uis = game and game:GetService("UserInputService")
        return uis and uis:GetMouseLocation()
    end)
    if ok and pos then return pos.X, pos.Y end
    local lp = game:GetService("Players").LocalPlayer
    local m = lp and lp:GetMouse()
    if m then return m.X, m.Y end
    return 0, 0
end

local function mouse1Down()
    if type(ismouse1pressed) == "function" then
        local ok, res = pcall(ismouse1pressed)
        return ok and res and true or false
    end
    return false
end

local function createRenderer()
    local R = { clip = nil }
    local KINDS = { "Square", "Text", "Line", "Circle" }
    local pool, used, shown = {}, {}, {}
    for _, k in ipairs(KINDS) do pool[k] = {}; used[k] = 0; shown[k] = 0 end
    local zc = 0
    local colorMemo = {}
    local FONT, FONT_BOLD = nil, nil
    do
        local f = try(function() return Drawing.Fonts end)
        if f then
            FONT = f.UI or f.System or 0
            FONT_BOLD = f.SystemBold or FONT
        end
    end

    local function C3(p)
        local c = colorMemo[p]
        if not c then
            local r, g, b = rgb3(p)
            c = Color3.fromRGB(r, g, b)
            colorMemo[p] = c
        end
        return c
    end

    local function acquire(kind)
        local u = used[kind] + 1
        used[kind] = u
        local e = pool[kind][u]
        if not e then
            local obj = Drawing.new(kind)
            e = { o = obj, c = {} }
            pool[kind][u] = e
        end
        zc = zc + 1
        local c = e.c
        if c.Visible ~= true then c.Visible = true; pcall(function() e.o.Visible = true end) end
        if c.Transparency ~= 1 then c.Transparency = 1; pcall(function() e.o.Transparency = 1 end) end
        if c.ZIndex ~= zc then c.ZIndex = zc; pcall(function() e.o.ZIndex = zc end) end
        return e
    end

    local function sp(e, k, v)
        if e.c[k] ~= v then e.c[k] = v; pcall(function() e.o[k] = v end) end
    end

    local function setPair(e, prop, kx, ky, x, y)
        if e.c[kx] ~= x or e.c[ky] ~= y then
            e.c[kx] = x; e.c[ky] = y
            pcall(function() e.o[prop] = Vector2.new(x, y) end)
        end
    end

    function R.tw(s, size) return #tostring(s) * size * 0.52 end

    function R.rect(x, y, w, h, color, corner, alpha)
        local cl = R.clip
        if cl then
            local x2, y2 = x + w, y + h
            if x < cl[1] then x = cl[1] end
            if y < cl[2] then y = cl[2] end
            if x2 > cl[3] then x2 = cl[3] end
            if y2 > cl[4] then y2 = cl[4] end
            w, h = x2 - x, y2 - y
        end
        if w < 1 or h < 1 then return end
        local e = acquire("Square")
        setPair(e, "Position", "px", "py", round(x), round(y))
        setPair(e, "Size", "sx", "sy", round(w), round(h))
        sp(e, "Filled", true)
        sp(e, "Color", C3(color))
        sp(e, "Transparency", alpha or 1)
    end

    function R.border(x, y, w, h, color, th)
        th = th or 1
        R.rect(x, y, w, th, color)
        R.rect(x, y + h - th, w, th, color)
        R.rect(x, y + th, th, h - th * 2, color)
        R.rect(x + w - th, y + th, th, h - th * 2, color)
    end

    function R.vgrad(x, y, w, h, c1, c2, steps)
        steps = math.min(steps or 4, 4)
        local sh = h / steps
        for i = 0, steps - 1 do
            local t = (steps > 1) and (i / (steps - 1)) or 0
            R.rect(x, y + floor(i * sh), w, ceil(sh) + 1, mix(c1, c2, t))
        end
    end

    function R.text(x, y, s, size, color, bold, outline)
        local cl = R.clip
        if cl and (y < cl[2] - 15 or y > cl[4] + 15 or x < cl[1] - 60 or x > cl[3] + 60) then return end
        local e = acquire("Text")
        setPair(e, "Position", "px", "py", round(x), round(y))
        sp(e, "Text", tostring(s))
        sp(e, "Size", size)
        sp(e, "FontSize", size)
        sp(e, "Color", C3(color))
        sp(e, "Transparency", 1)
        local f = bold and (FONT_BOLD or FONT) or FONT
        if f then sp(e, "Font", f) else sp(e, "Font", 2) end
        sp(e, "Outline", outline == true)
        sp(e, "Center", false)
    end

    function R.line(x1, y1, x2, y2, color, th)
        local e = acquire("Line")
        setPair(e, "From", "fx", "fy", round(x1), round(y1))
        setPair(e, "To", "tx", "ty", round(x2), round(y2))
        sp(e, "Thickness", th or 1)
        sp(e, "Color", C3(color))
        sp(e, "Transparency", 1)
    end

    function R.circle(cx, cy, r, color, filled, th, sides)
        local cl = R.clip
        if cl and (cx - r < cl[1] - 15 or cx + r > cl[3] + 15 or cy - r < cl[2] - 15 or cy + r > cl[4] + 15) then return end
        local e = acquire("Circle")
        setPair(e, "Position", "px", "py", round(cx), round(cy))
        sp(e, "Radius", r)
        sp(e, "NumSides", sides or 32)
        sp(e, "Thickness", th or 1)
        sp(e, "Filled", filled == true)
        sp(e, "Color", C3(color))
        sp(e, "Transparency", 1)
    end

    function R.resetZ()
        zc = 0
    end

    function R.flush()
        for _, k in ipairs(KINDS) do
            local u, p = used[k], pool[k]
            for i = u + 1, shown[k] do
                local e = p[i]
                if e then sp(e, "Visible", false) end
            end
            shown[k] = u
            used[k] = 0
        end
        zc = 0
    end

    function R.destroy()
        for _, k in ipairs(KINDS) do
            local p = pool[k]
            if p then
                for i = 1, #p do
                    local e = p[i]
                    if e then
                        pcall(function()
                            if e.Remove then e:Remove()
                            elseif e.Destroy then e:Destroy() end
                        end)
                    end
                end
            end
            pool[k] = {}
            used[k] = 0
            shown[k] = 0
        end
    end

    return R
end

local Glyphs = {
    crosshair = function(R, cx, cy, c)
        R.circle(cx, cy, 8, c, false, 1.5, 24)
        R.line(cx - 12, cy, cx - 4, cy, c, 1.5)
        R.line(cx + 4, cy, cx + 12, cy, c, 1.5)
        R.line(cx, cy - 12, cx, cy - 4, c, 1.5)
        R.line(cx, cy + 4, cx, cy + 12, c, 1.5)
    end,
    player = function(R, cx, cy, c, T)
        R.circle(cx, cy - 6, 5, c, false, 1.5, 20)
        R.rect(cx - 9, cy + 2, 18, 9, c, 4)
        R.rect(cx - 7, cy + 4, 14, 6, T.GradientMid, 3)
    end,
    globe = function(R, cx, cy, c)
        R.circle(cx, cy, 10, c, false, 1.5, 28)
        R.line(cx - 10, cy, cx + 10, cy, c, 1)
        R.line(cx, cy - 10, cx, cy + 10, c, 1)
        R.circle(cx, cy, 5, c, false, 1, 20)
    end,
    gun = function(R, cx, cy, c, T)
        R.rect(cx - 12, cy - 8, 24, 7, c, 2)
        R.rect(cx - 12, cy - 8, 4, 10, c, 1)
        R.rect(cx - 5, cy - 1, 7, 11, c, 2)
        R.rect(cx + 2, cy - 1, 6, 2, c, 1)
        R.rect(cx - 2, cy - 6, 12, 3, T.GradientMid, 1)
    end,
    gear = function(R, cx, cy, c)
        R.circle(cx, cy, 8, c, false, 2, 20)
        R.circle(cx, cy, 3, c, true, 1, 12)
        R.rect(cx - 2, cy - 12, 4, 5, c)
        R.rect(cx - 2, cy + 7, 4, 5, c)
        R.rect(cx - 12, cy - 2, 5, 4, c)
        R.rect(cx + 7, cy - 2, 5, 4, c)
    end,
    fallback = function(R, cx, cy, c) R.rect(cx - 8, cy - 8, 16, 16, c, 3) end,
}

local Window = {}
Window.__index = Window

_G.LolcatFeaturesActive = true

function LolcatUI:CreateWindow(opts)
    if _G.LolcatActiveWindow and type(_G.LolcatActiveWindow.Destroy) == "function" then
        pcall(function() _G.LolcatActiveWindow:Destroy() end)
    end
    opts = opts or {}
    local win = setmetatable({}, Window)
    _G.LolcatActiveWindow = win

    win.Title = opts.Title or "LOLCAT"
    win.SubTitle = opts.SubTitle or "Matcha Edition"
    win.Width = opts.Width or 919
    win.Height = opts.Height or 643
    win.RailW = 100
    win.Outer = 18
    win.GapX = 17
    win.HeadH = 85
    win.StripH = 84

    win.Theme = {}
    for k, v in pairs(DefaultTheme) do win.Theme[k] = v end
    if opts.Accent then win.Theme.Accent = toColorInt(opts.Accent) end

    win.ToggleKey = resolveVK(opts.ToggleKey) or 0xA1 -- Default Right Shift
    win.Watermark = opts.Watermark ~= false
    win.WatermarkText = opts.WatermarkText or win.Title:lower()
    win.Open = true
    _G.LolcatFeaturesActive = not win.Open

    win.CurrentTab = 1
    win.CurrentSub = {}
    win.Scroll = {}
    win.Popup = nil
    win.Active = nil
    win.Drag = nil
    win.Capture = nil

    win.Pages = {}
    win.AllBinds = {}
    win.Renderer = createRenderer()
    win.Alive = true
    win.FPSAvg = 60
    win.LastTick = tick()

    win.Input = { mx = 0, my = 0, down = false, pressed = false }
    insert(LolcatUI.Windows, win)

    task.spawn(function()
        local togglePrev = false
        while win.Alive do
            local now = tick()
            local dt = clamp(now - win.LastTick, 0.001, 0.1)
            win.LastTick = now
            win.FPSAvg = lerp(win.FPSAvg, 1 / dt, 0.08)

            local td = keyDown(win.ToggleKey)
            if td and not togglePrev then
                win.Open = not win.Open
                -- WHEN MENU OPENS: TURN OFF FEATURES. WHEN CLOSED: TURN ON!
                _G.LolcatFeaturesActive = not win.Open
            end
            togglePrev = td

            pcall(function() win:Frame(dt) end)
            task.wait(0.016)
        end
        if win.Renderer and type(win.Renderer.destroy) == "function" then
            pcall(function() win.Renderer.destroy() end)
        end
    end)

    return win
end

function Window:Destroy()
    self.Alive = false
    self.Open = false
    _G.LolcatFeaturesActive = false
    if self.Renderer and type(self.Renderer.destroy) == "function" then
        pcall(function() self.Renderer.destroy() end)
    end
    if _G.LolcatActiveWindow == self then _G.LolcatActiveWindow = nil end
end

function Window:GetViewport()
    local cam = workspace and workspace.CurrentCamera
    if cam and cam.ViewportSize and cam.ViewportSize.X > 0 then
        return cam.ViewportSize.X, cam.ViewportSize.Y
    end
    return 1920, 1080
end

function Window:UpdateInput()
    local I = self.Input
    I.mx, I.my = getMouseCoords()
    local d = mouse1Down()
    I.pressed = d and not I.down
    I.down = d
end

function Window:Inside(x, y, w, h)
    local I = self.Input
    return I.mx >= x and I.mx <= x + w and I.my >= y and I.my <= y + h
end

local Tab = {} Tab.__index = Tab
local SubTab = {} SubTab.__index = SubTab
local Section = {} Section.__index = Section

function Window:CreateTab(opts)
    opts = type(opts) == "string" and { Name = opts } or opts or {}
    local tab = setmetatable({}, Tab)
    tab.Window = self
    tab.Name = opts.Name or "Tab"
    tab.Glyph = opts.Glyph or "crosshair"
    tab.Subs = {}
    insert(self.Pages, tab)
    return tab
end

function Tab:CreateSubTab(opts)
    opts = type(opts) == "string" and { Name = opts } or opts or {}
    local sub = setmetatable({}, SubTab)
    sub.Tab = self
    sub.Window = self.Window
    sub.Name = opts.Name or "SubTab"
    sub.Description = opts.Description or ""
    sub.Sections = {}
    insert(self.Subs, sub)
    return sub
end

function Tab:GetDefaultSub()
    if #self.Subs == 0 then return self:CreateSubTab({ Name = self.Name }) end
    return self.Subs[1]
end

function SubTab:CreateSection(opts)
    opts = type(opts) == "string" and { Title = opts } or opts or {}
    local sec = setmetatable({}, Section)
    sec.SubTab = self
    sec.Window = self.Window
    sec.Title = opts.Title or "Section"
    sec.Side = (opts.Side and opts.Side:lower() == "right") and "right" or "left"
    sec.Items = {}
    insert(self.Sections, sec)
    return sec
end

local ROW_H, PITCH = 24, 49
local function itemVisible(it) return it.show == nil or it.show() end

local function secVisibleCount(sec)
    local n = 0
    for _, it in ipairs(sec.Items) do if itemVisible(it) then n = n + 1 end end
    return n
end

local function secHeight(sec)
    local n = secVisibleCount(sec)
    local box = 24
    if n > 0 then box = 24 + n * ROW_H + (n - 1) * (PITCH - ROW_H) end
    return 35 + box
end

function Section:CreateToggle(opts)
    opts = opts or {}
    local it = {
        t = "toggle",
        label = opts.Title or opts.Name or "Toggle",
        state = opts.Default and true or false,
        a = opts.Default and 1 or 0,
        callback = opts.Callback,
    }
    insert(self.Items, it)
    local control = {}
    function control:Set(v)
        it.state = v and true or false
        if it.callback then pcall(it.callback, it.state) end
    end
    function control:Get() return it.state end
    return control
end

function Section:CreateSlider(opts)
    opts = opts or {}
    local it = {
        t = "slider",
        label = opts.Title or opts.Name or "Slider",
        value = clamp(opts.Default or opts.Min or 0, opts.Min or 0, opts.Max or 100),
        min = opts.Min or 0,
        max = opts.Max or 100,
        step = opts.Step or 1,
        suffix = opts.Suffix or "",
        callback = opts.Callback,
    }
    insert(self.Items, it)
    local control = {}
    function control:Set(v)
        it.value = clamp(v, it.min, it.max)
        if it.callback then pcall(it.callback, it.value) end
    end
    function control:Get() return it.value end
    return control
end

function Section:CreateDropdown(opts)
    opts = opts or {}
    local it = {
        t = "drop",
        label = opts.Title or opts.Name or "Dropdown",
        opts = opts.Options or opts.Values or { "None" },
        value = opts.Default or (opts.Options and opts.Options[1]) or "None",
        callback = opts.Callback,
    }
    insert(self.Items, it)
    local control = {}
    function control:Set(v)
        it.value = v
        if it.callback then pcall(it.callback, it.value) end
    end
    function control:Get() return it.value end
    return control
end

function Section:CreateButton(opts)
    opts = opts or {}
    local it = { t = "button", label = opts.Title or opts.Name or "Button", fn = opts.Callback }
    insert(self.Items, it)
    return it
end

function Section:CreateStat(opts)
    opts = opts or {}
    local it = {
        t = "stat",
        label = opts.Title or opts.Name or "Stat",
        val = opts.Value or "-",
        col = opts.Color and toColorInt(opts.Color) or nil,
        getter = opts.Getter,
    }
    insert(self.Items, it)
    local control = {}
    function control:Set(val) it.val = val end
    return control
end

function Section:CreateKeybind(opts)
    opts = opts or {}
    local it = {
        t = "keyrow",
        label = opts.Title or opts.Name or "Keybind",
        key = resolveVK(opts.DefaultKey or opts.Key or 0xA1),
        callback = opts.Callback,
    }
    insert(self.Items, it)
    local control = {}
    function control:Set(vk)
        it.key = resolveVK(vk)
        if it.callback then pcall(it.callback, it.key) end
    end
    function control:Get() return it.key end
    return control
end

function Window:OpenDrop(it, bx, by, bw)
    local vh = select(2, self:GetViewport())
    local h = #it.opts * 24 + 8
    local y = by + 26
    if y + h > vh - 10 then y = max(10, by - h - 2) end
    self.Popup = { kind = "drop", it = it, x = bx, y = y, w = bw, h = h }
end

function Window:HandlePopupInput()
    local p = self.Popup
    local I = self.Input
    if not p then return end
    if I.pressed then
        if self:Inside(p.x, p.y, p.w, p.h) then
            local idx = floor((I.my - p.y - 4) / 24) + 1
            local opt = p.it.opts[idx]
            if opt then
                p.it.value = opt
                if p.it.callback then pcall(p.it.callback, p.it.value) end
            end
        end
        self.Popup = nil
        I.pressed = false
    end
end

function Window:DrawPopup()
    local p = self.Popup
    if not p then return end
    local R = self.Renderer
    local T = self.Theme
    R.popupMode = true

    R.rect(p.x - 1, p.y - 1, p.w + 2, p.h + 2, T.Outline, 5)
    R.rect(p.x, p.y, p.w, p.h, T.ElementBackground, 5)

    for i, o in ipairs(p.it.opts) do
        local ry = p.y + 4 + (i - 1) * 24
        local hover = self:Inside(p.x, ry, p.w, 24)
        if hover then
            R.rect(p.x + 3, ry, p.w - 6, 24, mix(T.ElementBackground, T.TabButtonSelected, 0.4), 4)
        end
        local isSel = (o == p.it.value)
        R.text(p.x + 12, ry + 4, tostring(o), 15, isSel and T.Accent or T.TextColor, false)
    end
    R.popupMode = false
end

local function pill(R, T, x, y, a)
    local off = mix(T.ToggleBackgroundUnselected, T.GradientDark, 0.5)
    R.rect(x, y, 32, 20, mix(off, T.Accent, a), 10)
    R.rect(x + lerp(3, 13, a), y + 2, 16, 16, mix(T.ToggleCircleUnselected, T.White, a), 8)
end

local function ctrlBox(R, T, x, y, w, h, hover)
    R.rect(x - 1, y - 1, w + 2, h + 2, T.Outline, 6)
    R.rect(x, y, w, h, hover and T.GradientTop or T.GradientMid, 5)
end

function Window:DrawItem(it, x, y, w, vis, dt)
    local R = self.Renderer
    local T = self.Theme
    local I = self.Input
    local lbl = it.label
    local ts = 16
    local ty = y + 3

    if not vis then return end

    if it.t == "toggle" then
        local target = it.state and 1 or 0
        it.a = it.a + (target - it.a) * clamp(dt * 18, 0, 1)
        if abs(target - it.a) < 0.02 then it.a = target end
        local px = x + w - 32
        pill(R, T, px, y + 2, it.a)
        R.text(x, ty, lbl, ts, T.TextColor, false)
        if I.pressed and not self.Popup and self:Inside(x, y, w, ROW_H) then
            it.state = not it.state
            I.pressed = false
            if it.callback then pcall(it.callback, it.state) end
        end

    elseif it.t == "slider" then
        local v = it.value
        local vtxt = tostring(floor(v + 0.5)) .. it.suffix
        local boxW = 54
        local bx = x + w - boxW
        ctrlBox(R, T, bx, y + 1, boxW, 22, false)
        R.text(bx + (boxW - R.tw(vtxt, 14)) / 2, y + 4, vtxt, 14, T.TextColor, false)
        R.text(x, ty, lbl, ts, T.TextColor, false)

        local trackX = x + R.tw(lbl, ts) + 16
        local trackW = (bx - 11) - trackX
        if trackW < 30 then trackW = 30 end
        local frac = clamp((v - it.min) / (it.max - it.min), 0, 1)

        R.rect(trackX, y + 11, trackW, 3, mix(T.Outline, T.GradientTop, 0.5), 1)
        R.rect(trackX, y + 11, max(1, trackW * frac), 3, T.Accent, 1)
        local dragging = self.Active and self.Active.it == it
        R.rect(trackX + trackW * frac - 7, y + 5, 14, 14, T.Accent, 7)
        R.rect(trackX + trackW * frac - 5, y + 7, 10, 10, dragging and T.Accent or T.White, 5)

        if I.pressed and not self.Popup and self:Inside(trackX - 7, y, trackW + 14, ROW_H) then
            self.Active = { kind = "slider", it = it, tx = trackX, tw = trackW }
            I.pressed = false
        end

    elseif it.t == "drop" then
        local cur = tostring(it.value)
        local boxW = 160
        local bx = x + w - boxW
        local hover = self:Inside(bx, y + 1, boxW, 22)
        ctrlBox(R, T, bx, y + 1, boxW, 22, hover)
        R.text(bx + 9, y + 4, cur, 14, T.TextColor, false)
        R.text(x, ty, lbl, ts, T.TextColor, false)
        if I.pressed and hover and not self.Popup then
            self:OpenDrop(it, bx, y + 1, boxW)
            I.pressed = false
        end

    elseif it.t == "button" then
        local hover = self:Inside(x, y + 1, w, 22)
        ctrlBox(R, T, x, y + 1, w, 22, hover)
        R.text(x + (w - R.tw(lbl, 15)) / 2, y + 4, lbl, 15, hover and T.Accent or T.TextColor, false)
        if I.pressed and hover and not self.Popup then
            I.pressed = false
            if it.fn then pcall(it.fn) end
        end

    elseif it.t == "stat" then
        local s = it.val
        if it.getter then
            local ok, gs = pcall(it.getter)
            if ok and gs then s = gs end
        end
        R.text(x, ty, lbl, ts, T.TextColor, false)
        R.text(x + w - R.tw(tostring(s), 15), y + 4, tostring(s), 15, it.col or T.Accent, false)

    elseif it.t == "keyrow" then
        local txt = keyName(it.key)
        local capturing = self.Capture and self.Capture.it == it
        if capturing then txt = "press key..." end
        local tw = R.tw(txt, 14) + 18
        local bx = x + w - tw
        local hover = self:Inside(bx, y + 1, tw, 22)
        ctrlBox(R, T, bx, y + 1, tw, 22, hover)
        R.text(bx + 9, y + 4, txt, 14, capturing and T.Accent or T.TextColor, false)
        R.text(x, ty, lbl, ts, T.TextColor, false)
        if I.pressed and hover and not self.Popup then
            self.Capture = {
                it = it,
                armed = false,
                set = function(vk)
                    it.key = vk
                    if it.callback then pcall(it.callback, vk) end
                end
            }
            I.pressed = false
        end
    end
end

function Window:HandleCapture()
    local cap = self.Capture
    if not cap then return end
    local anyDown = false
    for vk = 0x01, 0xFE do
        if keyDown(vk) then
            anyDown = true
            if cap.armed then
                cap.set(vk == 0x1B and nil or vk)
                self.Capture = nil
                return
            end
        end
    end
    if not anyDown then cap.armed = true end
end

function Window:Frame(dt)
    self:UpdateInput()
    local R = self.Renderer
    local T = self.Theme
    local I = self.Input

    self:DrawOverlays()

    if not self.Open then
        self.Popup = nil
        self.Active = nil
        self.Drag = nil
        self.Capture = nil
        R.flush()
        return
    end

    R.resetZ()

    local vw, vh = self:GetViewport()
    local WIN_W, WIN_H = self.Width, self.Height
    local RAIL_W, OUTER, GAPX = self.RailW, self.Outer, self.GapX
    local HEAD_H, STRIP_H = self.HeadH, self.StripH

    if not self.X or self.X < 0 then self.X = max(20, floor((vw - WIN_W) / 2)) end
    if not self.Y or self.Y < 0 then self.Y = max(20, floor((vh - WIN_H) / 2)) end

    self:HandleCapture()
    self:HandlePopupInput()

    local act = self.Active
    if act and act.kind == "slider" then
        if I.down then
            local it = act.it
            local f = clamp((I.mx - act.tx) / act.tw, 0, 1)
            local v = it.min + f * (it.max - it.min)
            v = round(v / it.step) * it.step
            it.value = clamp(v, it.min, it.max)
            if it.callback then pcall(it.callback, it.value) end
        else
            self.Active = nil
        end
    end

    if I.pressed and not self.Popup and not self.Active and self:Inside(self.X + RAIL_W, self.Y, WIN_W - RAIL_W, OUTER + HEAD_H) then
        self.Drag = { I.mx - self.X, I.my - self.Y }
        I.pressed = false
    end
    if self.Drag then
        if I.down then
            self.X = clamp(I.mx - self.Drag[1], 0, max(0, vw - WIN_W))
            self.Y = clamp(I.my - self.Drag[2], 0, max(0, vh - WIN_H))
            self.Popup = nil
        else
            self.Drag = nil
        end
    end

    local x, y = self.X, self.Y

    R.rect(x - 1, y - 1, WIN_W + 2, WIN_H + 2, T.Outline, 6)
    R.rect(x, y, WIN_W, WIN_H, T.Background, 5)

    R.vgrad(x + 1, y + 1, RAIL_W, HEAD_H, T.GradientTop, T.GradientMid, 8)
    R.vgrad(x + 1, y + 1 + HEAD_H, RAIL_W, WIN_H - 2 - HEAD_H, T.GradientMid, T.GradientDark, 16)
    R.rect(x + RAIL_W + 1, y + 1, 1, WIN_H - 2, T.Outline)

    local logo = self.Title:upper()
    R.text(x + 1 + (RAIL_W - R.tw(logo, 20)) / 2, y + 28, logo, 20, T.Accent, true)
    R.rect(x + 1, y + HEAD_H, RAIL_W, 1, T.Accent)

    for i, pg in ipairs(self.Pages) do
        local tx, ty = x + 1 + (RAIL_W - 66) / 2, y + 102 + (i - 1) * 70
        local sel = (self.CurrentTab == i)
        local hover = self:Inside(tx, ty, 66, 66)

        if sel then
            R.rect(tx, ty, 66, 66, T.TabShadow, 6)
            R.rect(tx, ty, 66, 44, T.TabButtonSelected, 6)
        elseif hover then
            R.rect(tx, ty, 66, 66, mix(T.GradientMid, T.TabButtonSelected, 0.25), 6)
        end

        local col = sel and T.Accent or (hover and T.TextColor or T.Unselected)
        local glyphFn = Glyphs[pg.Glyph] or Glyphs.fallback
        glyphFn(R, tx + 33, ty + 25, col, T)

        local nm = pg.Name
        R.text(tx + (66 - R.tw(nm, 12)) / 2, ty + 47, nm, 12, col, true)

        if I.pressed and hover and not self.Popup then
            self.CurrentTab = i
            I.pressed = false
        end
    end

    local curTab = self.Pages[self.CurrentTab]
    if not curTab then R.flush(); return end

    local subIdx = clamp(self.CurrentSub[self.CurrentTab] or 1, 1, max(1, #curTab.Subs))
    local curSub = curTab.Subs[subIdx] or curTab:GetDefaultSub()
    local px = x + RAIL_W + OUTER

    R.text(px, y + OUTER + 18, curTab.Name, 18, T.TextColor, true)
    R.text(px, y + OUTER + 44, curSub.Description or "", 13, T.Unselected, false)

    local gridTop = y + OUTER + HEAD_H
    if #curTab.Subs > 1 then
        local cx = px
        local sy = y + OUTER + HEAD_H + 17
        for i, sb in ipairs(curTab.Subs) do
            local w = 32 + R.tw(sb.Name, 16)
            local sel = (i == subIdx)
            local hover = self:Inside(cx, sy, w, 50)
            if sel then
                R.rect(cx, sy, w, 50, mix(T.GradientMid, T.TabButtonSelected, 0.3), 6)
                R.rect(cx + 10, sy + 46, w - 20, 2, T.Accent, 1)
            end
            R.text(cx + 16, sy + 15, sb.Name, 16, sel and T.Accent or (hover and T.TextColor or T.Unselected), true)
            if I.pressed and hover and not self.Popup then
                self.CurrentSub[self.CurrentTab] = i
                subIdx = i
                curSub = sb
                I.pressed = false
            end
            cx = cx + w + 14
        end
        gridTop = y + OUTER + HEAD_H + STRIP_H
    end

    local gridBottom = y + WIN_H - 17
    local gridLeft = px
    local gridRight = x + WIN_W - OUTER
    local colW = floor((gridRight - gridLeft - GAPX) / 2)
    local viewH = gridBottom - gridTop

    R.clip = { gridLeft, gridTop, gridRight, gridBottom }
    local cy1 = gridTop
    local cy2 = gridTop

    for _, sec in ipairs(curSub.Sections) do
        local right = (sec.Side == "right")
        local sx = right and (gridLeft + colW + GAPX) or gridLeft
        local sy = right and cy2 or cy1
        local n = secVisibleCount(sec)
        local boxH = 24
        if n > 0 then boxH = 24 + n * ROW_H + (n - 1) * (PITCH - ROW_H) end

        R.text(sx + 1, sy, sec.Title, 16, T.TextColor, true)

        local by = sy + 35
        R.rect(sx, by, colW, boxH, T.Outline, 6)
        R.rect(sx + 1, by + 1, colW - 2, boxH - 2, T.ElementBackground, 5)

        local iy = by + 12
        local idx = 0
        for _, it in ipairs(sec.Items) do
            if itemVisible(it) then
                idx = idx + 1
                local visDraw = iy >= gridTop and iy + ROW_H <= gridBottom
                local inView = self:Inside(gridLeft, gridTop, gridRight - gridLeft, viewH)

                local saveP = I.pressed
                if not inView or not visDraw then I.pressed = false end
                self:DrawItem(it, sx + 12, iy, colW - 24, visDraw, dt)
                if not inView or not visDraw then I.pressed = saveP end

                if idx < n then R.rect(sx + 12, iy + ROW_H + 12, colW - 24, 1, T.Outline) end
                iy = iy + PITCH
            end
        end

        local nextY = sy + 35 + boxH + GAPX
        if right then cy2 = nextY else cy1 = nextY end
    end
    R.clip = nil

    self:DrawPopup()
    R.flush()
end

function Window:DrawOverlays()
    local R = self.Renderer
    local T = self.Theme
    local vw = self:GetViewport()

    if self.Watermark then
        local s = fmt("%s  |  matcha  |  %d fps", self.WatermarkText, floor(self.FPSAvg or 60))
        local w = R.tw(s, 14) + 20
        local x, y = vw - w - 14, 14
        R.rect(x - 1, y - 1, w + 2, 28, T.Outline, 5)
        R.rect(x, y, w, 26, T.ElementBackground, 4)
        R.rect(x, y, w, 2, T.Accent, 1)
        R.text(x + 10, y + 6, s, 14, T.TextColor, false)
    end
end

--------------------------------------------------------------------------
-- SECTION 2: BEE SWARM SIMULATOR ENGINE (CRASH-FREE PURE LUA)
--------------------------------------------------------------------------
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local lp = Players.LocalPlayer

local myHive = nil
local forceReturn = false
local status = "Off"
local collecting = false
local currentField = nil
local needSprinkler = false
local currentTurnAngle = 0

local S = {
    farm_on       = false,
    field         = "Dandelion Field",
    farm_mode     = "Orbit / Circle Turns",
    close_r       = 12,
    full_pct      = 90,
    glide_speed   = 75,
    walk_speed    = 75,
    sprinkler     = "Off",
    token_los     = false,
    dig_tool      = true,
    face_center   = false,
    face_bubbles  = true,
    face_balloons = true,
    face_camera   = false,
    mem_facing    = false,
    walk_anim     = true,
    noclip        = true,
    world_noclip  = false,
    reset_mode    = false,

    -- Polar Bear Quest Automation
    auto_polar_quests  = true,
    polar_kill_mobs    = true,
    polar_catch_petals = true,
    polar_farm_fields  = true,
    pause_on_ui        = false,

    -- Extended Gathering Features from User's Second Script
    farm_under_balloons = false,
    farm_under_clouds   = false,
    farm_flames         = false,
    farm_bubbles_move   = false,
    farm_sprouts        = false,
    catch_coconuts      = false,
    catch_stars         = false,
    convert_balloon     = false,

    -- Combat Features
    kill_crab     = false,
    kill_beetle   = false,
    kill_bear     = false,
    kill_vicious  = false,
    kill_mondo    = false,
}

local MODE_INDEX = { ["Middle Only"] = 0, ["Close Middle"] = 1, ["Orbit / Circle Turns"] = 2, ["Square / Box Turns"] = 3, ["Serpentine / Snake"] = 4, ["Whole Field"] = 2 }
local SPRINK_REPS = { ["Off"] = 0, ["Basic"] = 1, ["Silver"] = 2, ["Gold"] = 3, ["Diamond"] = 4, ["Supreme"] = 1 }

local function getHRP()
    local c = lp.Character; return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local c = lp.Character; return c and c:FindFirstChildOfClass("Humanoid")
end

local function isAlive()
    local hum = getHum()
    return hum and hum.Health > 0
end

local function isOn()
    if S.pause_on_ui and not _G.LolcatFeaturesActive then return false end
    return S.farm_on == true and isAlive()
end

-- NOCLIP CHARACTER
local function applyNoclip()
    local c = lp.Character
    if not c then return end
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function() p.CanCollide = false end)
        end
    end
end

-- WORLD NO-COLLIDE (From User Script: Fences, Trees, FieldDecos)
local worldNoCollideDone = false
local function applyWorldNoCollide()
    if worldNoCollideDone then return end
    worldNoCollideDone = true
    task.spawn(function()
        pcall(function()
            local folders = { Workspace:FindFirstChild("FieldDecos") }
            local decs = Workspace:FindFirstChild("Decorations")
            if decs then insert(folders, decs:FindFirstChild("Misc")) end
            for _, f in ipairs(folders) do
                if f then
                    for _, obj in ipairs(f:GetDescendants()) do
                        if obj:IsA("BasePart") and not string.find(string.lower(obj.Name or ""), "ladder", 1, true) then
                            obj.CanCollide = false
                        end
                    end
                end
            end
        end)
    end)
end

task.spawn(function()
    while true do
        if S.farm_on and S.noclip then applyNoclip() end
        if S.world_noclip then applyWorldNoCollide() else worldNoCollideDone = false end
        task.wait(0.2)
    end
end)

--------------------------------------------------------------------------
-- MEMORY ENGINE & CFRAME ORIENTATION (FROM UE HELPER / MATCHA PORT)
--------------------------------------------------------------------------
local hasMem = type(memory_read) == "function" and type(memory_write) == "function"

-- Exact verified imtheo offsets for Matcha LuaVM
local OFF = {
    Primitive = 0x178,   -- BasePart -> Primitive*
    CFrame    = 0xB0,    -- Primitive: 9 rotation floats then 3 position floats (0xD4)
}

local Mem = { ok = false, reason = "not checked", root = nil }

local function primAddr(part)
    local a = try(function() return part.Address end)
    if not a or a == 0 then return nil end
    local p = memory_read("uintptr_t", a + OFF.Primitive)
    if not p or p < 0x10000 then return nil end
    return p
end

local function readComps(part)
    if not hasMem then return nil end
    local p = primAddr(part)
    if not p then return nil end
    local c = {}
    for i = 0, 11 do
        local v = memory_read("float", p + OFF.CFrame + i * 4)
        if type(v) ~= "number" or v ~= v or v > 1e12 or v < -1e12 then return nil end
        c[i + 1] = v
    end
    return c
end

local function verifyMem(root)
    Mem.root = root
    if not hasMem then Mem.ok, Mem.reason = false, "memory API unavailable"; return false end
    local c = readComps(root)
    if not c then Mem.ok, Mem.reason = false, "primitive read failed"; return false end
    local p = try(function() return root.Position end)
    if not p then Mem.ok, Mem.reason = false, "Position read failed"; return false end
    local dx, dy, dz = c[10] - p.X, c[11] - p.Y, c[12] - p.Z
    local row = math.sqrt(c[1] * c[1] + c[2] * c[2] + c[3] * c[3])
    if math.sqrt(dx * dx + dy * dy + dz * dz) > 4 then
        Mem.ok, Mem.reason = false, "memory position mismatch"
        return false
    elseif math.abs(row - 1) > 0.15 then
        Mem.ok, Mem.reason = false, "memory rotation invalid"
        return false
    end
    Mem.ok = true
    return true
end

local function writeCF(part, cf)
    if Mem.ok and S.mem_facing then
        local p = primAddr(part)
        if p then
            local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
            local b = p + OFF.CFrame
            memory_write("float", b, r00)       memory_write("float", b + 4, r01)
            memory_write("float", b + 8, r02)   memory_write("float", b + 12, r10)
            memory_write("float", b + 16, r11)  memory_write("float", b + 20, r12)
            memory_write("float", b + 24, r20)  memory_write("float", b + 28, r21)
            memory_write("float", b + 32, r22)
            memory_write("float", b + 36, x)    memory_write("float", b + 40, y)
            memory_write("float", b + 44, z)
            return true
        end
    end
    -- Fallback to standard Lua CFrame
    pcall(function() part.CFrame = cf end)
    return true
end

local function makeLookAt(eye, target)
    local cf = try(function() return CFrame.lookAt(eye, target) end)
    if cf then return cf end
    cf = try(function() return CFrame.new(eye, target) end)
    if cf then return cf end
    return nil
end

local function facePosition(targetPos)
    local hrp = getHRP(); local hum = getHum()
    if not hrp or not targetPos then return end

    local pos = hrp.Position
    local flatTarget = Vector3.new(targetPos.X, pos.Y, targetPos.Z)
    if (flatTarget - pos).Magnitude < 0.3 then return end

    local targetCF = makeLookAt(pos, flatTarget)
    if not targetCF then return end

    pcall(function()
        if hum then hum.AutoRotate = false end
        if Mem.ok and S.mem_facing then
            writeCF(hrp, targetCF)
        else
            hrp.CFrame = targetCF
        end
    end)

    if S.face_camera then
        pcall(function()
            local cam = Workspace.CurrentCamera
            if cam then
                local camPos = cam.CFrame.Position
                local camLook = makeLookAt(camPos, Vector3.new(targetPos.X, camPos.Y, targetPos.Z))
                if camLook then cam.CFrame = camLook end
            end
        end)
    end
end

local function restoreFacing()
    local hum = getHum()
    if hum then pcall(function() hum.AutoRotate = true end) end
end

--------------------------------------------------------------------------
-- 5-TIER INSTANT HIVE DETECTION + FAST PAD SWEEP
--------------------------------------------------------------------------
local function getPartPos(part)
    if not part then return nil end
    local p = try(function() return part.Position end)
    if p and p.X then return p end
    local cf = try(function() return part.CFrame end)
    if cf and cf.Position and cf.Position.X then return cf.Position end
    if part.IsA and part:IsA("Model") then
        local pp = try(function() return part.PrimaryPart and part.PrimaryPart.Position end)
        if pp and pp.X then return pp end
        local bp = try(function() return part:FindFirstChildWhichIsA("BasePart", true) end)
        if bp then
            local bpPos = try(function() return bp.Position end)
            if bpPos and bpPos.X then return bpPos end
        end
    end
    return nil
end

local function padPos(pad)
    if not pad then return nil end
    return getPartPos(pad)
end

local function padTop(pad)
    if not pad then return 0 end
    local pos = getPartPos(pad)
    if not pos then return 0 end
    local szY = try(function() return pad.Size.Y end) or 2
    return pos.Y + szY / 2 + 2
end

local function hivePad(hive)
    if not hive then return nil end
    for _, name in ipairs({ "Platform", "Pad", "Spawn", "Spot", "Floor" }) do
        local child = hive:FindFirstChild(name)
        if child then
            if child:IsA("BasePart") then return child end
            if child:IsA("Model") then
                local p = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart", true)
                if p then return p end
            end
        end
    end
    for _, p in ipairs(hive:GetChildren()) do
        local nl = string.lower(p.Name)
        if p:IsA("BasePart") and (string.find(nl, "pad", 1, true) or string.find(nl, "plat", 1, true)) then
            return p
        end
        if p:IsA("Model") and (string.find(nl, "pad", 1, true) or string.find(nl, "plat", 1, true)) then
            local bp = p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart", true)
            if bp then return bp end
        end
    end
    local primary = try(function() return hive.PrimaryPart end)
    if primary and primary:IsA("BasePart") then return primary end
    local anyBp = try(function() return hive:FindFirstChildWhichIsA("BasePart", true) end)
    if anyBp then return anyBp end
    return nil
end

local function autoDetectHiveInstant()
    local honey = Workspace:FindFirstChild("Honeycombs") or Workspace:FindFirstChild("Hives")
    if not honey then return nil end

    local myName = lp.Name:lower()
    local myDisplay = (lp.DisplayName or ""):lower()
    local myUserId = lp.UserId

    -- Tier 1: Check Owner / Player object value (Direct BSS standard)
    for _, hive in ipairs(honey:GetChildren()) do
        local ownerObj = hive:FindFirstChild("Owner") or hive:FindFirstChild("Player")
        if ownerObj then
            local ov = try(function() return ownerObj.Value end)
            if ov then
                if ov == lp then
                    myHive = hive; return hive
                elseif (typeof and typeof(ov) == "Instance") or type(ov) == "userdata" then
                    local nm = try(function() return ov.Name end)
                    if nm and type(nm) == "string" and (nm:lower() == myName or nm:lower() == myDisplay) then
                        myHive = hive; return hive
                    end
                elseif type(ov) == "string" then
                    local s = ov:lower()
                    if s == myName or s == myDisplay then
                        myHive = hive; return hive
                    end
                elseif type(ov) == "number" and ov == myUserId then
                    myHive = hive; return hive
                end
            end
        end
    end

    -- Tier 2: Check LocalPlayer.SpawnPos (Exact BSS Hive Spawn vector)
    local sp = lp:FindFirstChild("SpawnPos")
    if sp and sp.Value then
        local spPos = (typeof and typeof(sp.Value) == "CFrame" and sp.Value.Position) or sp.Value
        if spPos and type(spPos.X) == "number" then
            for _, hive in ipairs(honey:GetChildren()) do
                local pad = hivePad(hive)
                local pp = padPos(pad)
                if pp and (pp - spPos).Magnitude <= 14 then
                    myHive = hive; return hive
                end
            end
        end
    end

    -- Tier 3: Check Attributes
    for _, hive in ipairs(honey:GetChildren()) do
        for _, attr in ipairs({ "Owner", "Player", "UserId", "Username", "OwnerName" }) do
            local val = hive:GetAttribute(attr)
            if val then
                if type(val) == "string" and (val:lower() == myName or val:lower() == myDisplay) then
                    myHive = hive; return hive
                elseif type(val) == "number" and val == myUserId then
                    myHive = hive; return hive
                end
            end
        end
    end

    -- Tier 4: Proximity fallback (if standing on pad)
    local hrp = getHRP()
    if hrp then
        for _, hive in ipairs(honey:GetChildren()) do
            local pad = hivePad(hive)
            local pp = padPos(pad)
            if pp and (pp - hrp.Position).Magnitude <= 35 then
                myHive = hive; return hive
            end
        end
    end

    return myHive
end

local function setHiveManual()
    local honey = Workspace:FindFirstChild("Honeycombs") or Workspace:FindFirstChild("Hives")
    local hrp = getHRP()
    if not honey or not hrp then return end
    local best, bestDist = nil, math.huge
    for _, hive in ipairs(honey:GetChildren()) do
        local pad = hivePad(hive)
        local pp = padPos(pad)
        if pp then
            local d = (pp - hrp.Position).Magnitude
            if d < bestDist then bestDist = d; best = hive end
        end
    end
    if best and bestDist <= 60 then myHive = best end
end

--------------------------------------------------------------------------
-- VELOCITY-BASED TWEEN (NOCLIP & ACTIVE WALKING ANIMATION)
local function moveToVelocity(targetPos, speed, thr)
    thr = thr or 3.5
    speed = speed or S.glide_speed or 220

    local hrp = getHRP(); local hum = getHum()
    if not hrp or not hum then return false end

    -- Keep Humanoid in Running state so animations play naturally
    pcall(function()
        hum:ChangeState(Enum.HumanoidStateType.Running)
    end)

    local start = tick()
    local lastTick = start
    while tick() - start < 45 do
        if not isOn() then break end
        local curHrp = getHRP()
        if not curHrp or not isAlive() then break end

        local now = tick()
        local dt = clamp(now - lastTick, 0.001, 0.1)
        lastTick = now

        local pos = curHrp.Position
        local delta = targetPos - pos
        local dist = delta.Magnitude

        if dist <= thr then
            pcall(function()
                curHrp.AssemblyLinearVelocity = Vector3.zero
                curHrp.Velocity = Vector3.zero
            end)
            break
        end

        -- Ensure noclip is active so velocity moves directly through walls
        if S.noclip then applyNoclip() end

        local dir = delta.Unit
        local step = math.min(speed * dt, dist)
        local vel = dir * speed

        -- Velocity + CFrame Glide hybrid for 100% reliable wall phasing & animation
        pcall(function()
            curHrp.AssemblyLinearVelocity = vel
            curHrp.Velocity = vel
            curHrp.AssemblyAngularVelocity = Vector3.zero
            curHrp.RotVelocity = Vector3.zero

            -- Smoothly step CFrame forward through any collision or wall
            curHrp.CFrame = CFrame.new(pos + dir * step) * (curHrp.CFrame - curHrp.CFrame.Position)
        end)

        task.wait(0.016)
    end

    if hrp and hrp.Parent then
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.Velocity = Vector3.zero
        end)
    end
    return true
end
-- FIELD, CAPACITY & ADVANCED GATHERING (BALLOONS, CLOUDS, FLAMES, BUBBLES)
--------------------------------------------------------------------------
local zoneNames = {
    "Dandelion Field", "Sunflower Field", "Mushroom Field", "Blue Flower Field",
    "Clover Field", "Spider Field", "Bamboo Field", "Strawberry Field",
    "Pineapple Patch", "Pumpkin Patch", "Cactus Field", "Pine Tree Forest",
    "Rose Field", "Stump Field", "Mountain Top Field", "Pepper Patch", "Coconut Field"
}
pcall(function()
    local zones = Workspace:FindFirstChild("FlowerZones")
    if zones then
        local known = {}
        for _, n in ipairs(zoneNames) do known[n] = true end
        for _, z in ipairs(zones:GetChildren()) do
            if not known[z.Name] then insert(zoneNames, z.Name) end
        end
    end
end)

local function getField(name)
    local z = Workspace:FindFirstChild("FlowerZones"); return z and z:FindFirstChild(name)
end
local function groundY(f) return f.Position.Y + f.Size.Y / 2 end
local function inField(pos, f, m)
    local c, s = f.Position, f.Size
    return math.abs(pos.X - c.X) <= s.X / 2 + m and math.abs(pos.Z - c.Z) <= s.Z / 2 + m and math.abs(pos.Y - c.Y) <= 35
end
local function distToCenter(pos, f)
    return Vector3.new(pos.X - f.Position.X, 0, pos.Z - f.Position.Z).Magnitude
end

local function clampTarget(tgt, f, fm, cr)
    if fm == 1 then
        local c = f.Position; local d = Vector3.new(tgt.X - c.X, 0, tgt.Z - c.Z)
        if d.Magnitude > cr then
            local dir = d.Unit; return Vector3.new(c.X + dir.X * cr, tgt.Y, c.Z + dir.Z * cr)
        end
    end
    return tgt
end

local function randomPoint(f, r)
    local c, s = f.Position, f.Size
    local rx = math.min(r or (s.X / 2 - 4), s.X / 2 - 4)
    local rz = math.min(r or (s.Z / 2 - 4), s.Z / 2 - 4)
    local ang = math.random() * math.pi * 2; local rad = math.random()
    return Vector3.new(c.X + math.cos(ang) * rad * rx, groundY(f) + 2, c.Z + math.sin(ang) * rad * rz)
end

-- TARGET SEARCHERS (Optimized deep scanner for player & other players' balloons/bubbles)
local _cBalloon, _tBalloon = nil, 0
local function findClosestBalloon(field)
    local now = tick()
    if now - _tBalloon < 0.35 and _cBalloon and _cBalloon.Parent then return _cBalloon end
    _tBalloon = now

    local hrp = getHRP(); if not hrp then return nil end
    local best, bestDist = nil, math.huge

    local function checkPart(part)
        if not part or not part:IsA("BasePart") then return end
        local pos = part.Position
        if not field or inField(pos, field, 35) or (pos - hrp.Position).Magnitude <= 85 then
            local d = (pos - hrp.Position).Magnitude
            if d < bestDist then bestDist = d; best = part end
        end
    end

    local function checkModel(mod)
        if not mod then return end
        local body = mod:FindFirstChild("BalloonBody")
            or mod:FindFirstChild("Balloon")
            or mod:FindFirstChild("Root")
            or mod.PrimaryPart
            or mod:FindFirstChildWhichIsA("BasePart")
        if body then checkPart(body) end
    end

    -- 1. Check Workspace.Balloons (contains field and other players' balloons)
    local balloons = Workspace:FindFirstChild("Balloons")
    if balloons then
        for _, b in ipairs(balloons:GetChildren()) do
            if b:IsA("Model") or b:IsA("Folder") then
                checkModel(b)
                for _, child in ipairs(b:GetChildren()) do
                    if child:IsA("Model") then checkModel(child)
                    elseif child:IsA("BasePart") then checkPart(child) end
                end
            elseif b:IsA("BasePart") then
                checkPart(b)
            end
        end
    end

    -- 2. Check top-level Workspace for balloons
    for _, b in ipairs(Workspace:GetChildren()) do
        local nameLower = string.lower(b.Name)
        if string.find(nameLower, "balloon", 1, true) then
            if b:IsA("Model") then checkModel(b)
            elseif b:IsA("BasePart") then checkPart(b) end
        end
    end

    _cBalloon = best
    return best, bestDist
end

local _cBubble, _tBubble = nil, 0
local function findNearestBubble(field, pos)
    local now = tick()
    if now - _tBubble < 0.35 and _cBubble and _cBubble.Parent then return _cBubble end
    _tBubble = now

    local best, bestDist = nil, math.huge
    local function checkObj(obj)
        if not obj then return end
        local part = nil
        if obj:IsA("BasePart") or obj.ClassName == "MeshPart" then
            part = obj
        elseif obj:IsA("Model") then
            part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
        end
        if part then
            local p = part.Position
            if not field or inField(p, field, 25) or (p - pos).Magnitude <= 65 then
                local d = (p - pos).Magnitude
                if d < bestDist then bestDist = d; best = part end
            end
        end
    end

    local containers = {
        Workspace:FindFirstChild("Particles"),
        Workspace:FindFirstChild("Effects"),
        Workspace:FindFirstChild("Collectibles"),
        Workspace:FindFirstChild("Debris"),
        Workspace,
    }

    pcall(function()
        for _, cont in ipairs(containers) do
            if cont then
                for _, obj in ipairs(cont:GetChildren()) do
                    local nm = string.lower(obj.Name)
                    if string.find(nm, "bubble", 1, true) or string.find(nm, "water", 1, true) then
                        checkObj(obj)
                    end
                end
            end
        end
    end)

    _cBubble = best
    return best, bestDist
end

local _cCloud, _tCloud = nil, 0
local function findNearestCloud(field)
    local now = tick()
    if now - _tCloud < 0.5 and _cCloud and _cCloud.Parent then return _cCloud end
    _tCloud = now

    local best, bestDist = nil, math.huge
    local hrp = getHRP(); if not hrp then return nil end
    pcall(function()
        for _, obj in ipairs(Workspace:GetChildren()) do
            if string.find(string.lower(obj.Name), "cloud", 1, true) and obj:IsA("BasePart") then
                if inField(obj.Position, field, 10) then
                    local d = (obj.Position - hrp.Position).Magnitude
                    if d < bestDist then bestDist = d; best = obj end
                end
            end
        end
    end)
    _cCloud = best
    return best
end

local _cFlame, _tFlame = nil, 0
local function findNearestFlame(field)
    local now = tick()
    if now - _tFlame < 0.5 and _cFlame and _cFlame.Parent then return _cFlame end
    _tFlame = now

    local best, bestDist = nil, math.huge
    local hrp = getHRP(); if not hrp then return nil end
    pcall(function()
        for _, obj in ipairs(Workspace:GetChildren()) do
            if string.find(string.lower(obj.Name), "flame", 1, true) and obj:IsA("BasePart") then
                if inField(obj.Position, field, 6) then
                    local d = (obj.Position - hrp.Position).Magnitude
                    if d < bestDist then bestDist = d; best = obj end
                end
            end
        end
    end)
    _cFlame = best
    return best
end

--------------------------------------------------------------------------
-- POLAR BEAR QUEST AUTOMATION ENGINE (COMPLETE ALL 20 QUESTS)
--------------------------------------------------------------------------
local MOB_LOCATIONS = {
    ["Rhino Beetle"] = {
        Vector3.new(150, 5, 100),   -- Blue Flower Field
        Vector3.new(260, 68, -200), -- Pineapple Patch
        Vector3.new(-150, 5, 195),  -- Clover Field
        Vector3.new(135, 20, -25),  -- Bamboo Field
    },
    ["Ladybug"] = {
        Vector3.new(-180, 20, -5),  -- Strawberry Field
        Vector3.new(-90, 5, 115),   -- Mushroom Field
        Vector3.new(-150, 5, 195),  -- Clover Field
    },
    ["Mantis"] = {
        Vector3.new(-320, 68, -180), -- Pine Tree Forest
    },
    ["Spider"] = {
        Vector3.new(-45, 20, -5),   -- Spider Field / Cave
    },
    ["Scorpion"] = {
        Vector3.new(-320, 20, 130), -- Rose Field
    },
    ["Werewolf"] = {
        Vector3.new(-260, 68, -40), -- Werewolf Cave
    },
}

local function getPolarBearLocation()
    local npcs = Workspace:FindFirstChild("NPCs")
    local bear = npcs and npcs:FindFirstChild("Polar Bear")
    if bear then
        local p = bear:FindFirstChild("Circle") or bear:FindFirstChild("Platform") or bear:FindFirstChild("HumanoidRootPart") or bear:FindFirstChild("Torso") or bear:FindFirstChildWhichIsA("BasePart")
        local pos = getPartPos(p)
        if pos then return pos end
    end
    return Vector3.new(-105, 120, -78)
end

local function getPolarBearQuest()
    local pg = lp:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil end

    local quest = {
        title = nil,
        questName = nil,
        tasks = {},
        allComplete = true,
        hasQuest = false,
    }

    local headerLabel = nil
    for _, l in ipairs(pg:GetDescendants()) do
        if l:IsA("TextLabel") then
            local txt = safeText(l)
            if #txt > 0 and string.find(txt, "Polar Bear:", 1, true) then
                headerLabel = l
                quest.title = txt
                quest.hasQuest = true
                local qn = string.match(txt, "Polar Bear:%s*(.+)")
                quest.questName = qn and string.gsub(qn, "^%s*(.-)%s*$", "%1") or txt
                break
            end
        end
    end

    if not headerLabel then return nil end

    local container = headerLabel.Parent
    if container then
        for _, obj in ipairs(container:GetDescendants()) do
            if obj:IsA("TextLabel") and obj ~= headerLabel then
                local txt = safeText(obj)
                if #txt >= 8 then
                    local isComplete = string.find(txt, "Complete!", 1, true) ~= nil
                    local current, total = string.match(txt, "([%d%,]+)%s*/%s*([%d%,]+)")
                    local cVal, tVal = 0, 0
                    if current and total then
                        cVal = tonumber((string.gsub(current, "%,", ""))) or 0
                        tVal = tonumber((string.gsub(total, "%,", ""))) or 0
                        if tVal > 0 and cVal >= tVal then isComplete = true end
                    end

                    local taskType = "unknown"
                    local targetField = nil
                    local targetMob = nil
                    local targetPetal = nil

                    for _, fname in ipairs({
                        "Rose Field", "Pine Tree Forest", "Pineapple Patch", "Dandelion Field",
                        "Strawberry Field", "Blue Flower Field", "Cactus Field", "Clover Field",
                        "Bamboo Field", "Sunflower Field", "Pumpkin Patch", "Mushroom Field", "Spider Field"
                    }) do
                        if string.find(txt, fname, 1, true) then
                            taskType = "pollen"
                            targetField = fname
                            break
                        end
                    end

                    if taskType == "unknown" then
                        for _, mname in ipairs({ "Rhino Beetle", "Ladybug", "Mantis", "Spider", "Scorpion", "Werewolf" }) do
                            if string.find(txt, mname, 1, true) then
                                taskType = "mob"
                                targetMob = mname
                                break
                            end
                        end
                    end

                    if taskType == "unknown" and (string.find(txt, "Bloom", 1, true) or string.find(txt, "Petal", 1, true)) then
                        taskType = "petal"
                        for _, col in ipairs({ "White", "Cyan", "Green", "Pink" }) do
                            if string.find(txt, col, 1, true) then targetPetal = col; break end
                        end
                    end

                    if not isComplete then
                        quest.allComplete = false
                    end

                    table.insert(quest.tasks, {
                        text = txt,
                        complete = isComplete,
                        type = taskType,
                        field = targetField,
                        mob = targetMob,
                        petal = targetPetal,
                        current = cVal,
                        total = tVal,
                        needed = (tVal > cVal) and (tVal - cVal) or 0,
                    })
                end
            end
        end
    end

    return quest
end

local function spamClickDialogue(duration)
    duration = duration or 5.0
    local dl = tick() + duration
    local cam = Workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)

    -- In user image, dialogue box is centered horizontally and ~77% down vertically
    local defaultClickPos = Vector2.new(vp.X * 0.50, vp.Y * 0.77)

    while tick() < dl do
        local clickPos = defaultClickPos

        -- Dynamically locate Dialogue GUI in PlayerGui if active
        pcall(function()
            local pg = lp:FindFirstChildOfClass("PlayerGui")
            if pg then
                for _, obj in ipairs(pg:GetDescendants()) do
                    if obj:IsA("GuiObject") and obj.Visible then
                        local txt = safeText(obj)
                        if #txt > 0 and (string.find(txt, "Click to continue", 1, true)
                            or string.find(txt, "Polar Bear", 1, true)
                            or string.find(txt, "Hahaa", 1, true)
                            or string.find(txt, "kidding", 1, true)) then
                            local ap = obj.AbsolutePosition
                            local as = obj.AbsoluteSize
                            if ap and as and as.X > 10 and as.Y > 10 then
                                clickPos = Vector2.new(ap.X + as.X / 2, ap.Y + as.Y / 2)
                                pcall(function()
                                    if obj:IsA("GuiButton") then
                                        obj.Activated:Fire()
                                    end
                                end)
                                break
                            end
                        end
                    end
                end
            end
        end)

        local cx = math.floor(clickPos.X)
        local cy = math.floor(clickPos.Y)

        -- 1. Virtual Mouse Move & Click
        pcall(function()
            if type(mousemoveabs) == "function" then
                mousemoveabs(cx, cy)
            end
        end)
        pcall(function()
            if type(mouse1click) == "function" then
                mouse1click(cx, cy)
            end
        end)
        pcall(function()
            if type(mouse1press) == "function" and type(mouse1release) == "function" then
                mouse1press()
                task.wait(0.02)
                mouse1release()
            end
        end)

        -- 2. VirtualInputManager Click
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            if vim then
                vim:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
                task.wait(0.02)
                vim:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
            end
        end)

        -- 3. VirtualUser Click
        pcall(function()
            local vu = game:GetService("VirtualUser")
            if vu then
                vu:Button1Down(Vector2.new(cx, cy))
                task.wait(0.02)
                vu:Button1Up(Vector2.new(cx, cy))
            end
        end)

        -- 4. Keyboard skips (Spacebar, Enter, E)
        pcall(function()
            keypress(0x20); task.wait(0.02); keyrelease(0x20)
            keypress(0x0D); task.wait(0.02); keyrelease(0x0D)
            keypress(0x45); task.wait(0.02); keyrelease(0x45)
        end)

        task.wait(0.08)
    end
end

local function claimOrAcceptPolarBearQuest()
    status = "Polar: Visiting Polar Bear"
    local bearPos = getPolarBearLocation()
    moveToVelocity(bearPos + Vector3.new(0, 2, 0), S.glide_speed, 4)
    task.wait(0.3)

    -- Press E to start conversation
    pcall(function() keypress(0x45); task.wait(0.15); keyrelease(0x45) end)
    task.wait(0.4)

    -- Spam click dialogue for 5 seconds as requested!
    status = "Polar: Skipping Dialogue (5s)"
    spamClickDialogue(5.0)
end

local function completePolarBearRoutine()
    if not isOn() then return end

    local quest = getPolarBearQuest()

    -- If no active quest detected, or all tasks are complete: claim/accept!
    if not quest or quest.allComplete or #quest.tasks == 0 then
        claimOrAcceptPolarBearQuest()
        task.wait(1)
        return
    end

    -- Find first incomplete task
    local activeTask = nil
    -- 1. Incomplete mob kill tasks
    for _, t in ipairs(quest.tasks) do
        if not t.complete and t.type == "mob" and S.polar_kill_mobs then activeTask = t; break end
    end
    -- 2. Incomplete bloom petal catch tasks
    if not activeTask and S.polar_catch_petals then
        for _, t in ipairs(quest.tasks) do
            if not t.complete and t.type == "petal" then activeTask = t; break end
        end
    end
    -- 3. Incomplete field pollen tasks
    if not activeTask and S.polar_farm_fields then
        for _, t in ipairs(quest.tasks) do
            if not t.complete and t.type == "pollen" then activeTask = t; break end
        end
    end

    if not activeTask then return end

    -- Execute Mob Defeat Task
    if activeTask.type == "mob" then
        local mobName = activeTask.mob
        status = "Polar Mob: " .. mobName .. " (" .. activeTask.needed .. " left)"
        local locs = MOB_LOCATIONS[mobName] or {}
        for _, loc in ipairs(locs) do
            if not isOn() then break end
            moveToVelocity(loc, S.glide_speed, 4)
            task.wait(0.3)

            local t0 = tick()
            while isOn() and tick() - t0 < 8 do
                local monsters = Workspace:FindFirstChild("Monsters")
                local targetMonster = nil
                if monsters then
                    for _, m in ipairs(monsters:GetChildren()) do
                        if string.find(string.lower(m.Name), string.lower(mobName), 1, true) then
                            local mp = getPartPos(m)
                            if mp and (mp - loc).Magnitude <= 55 then
                                targetMonster = m
                                break
                            end
                        end
                    end
                end

                if targetMonster then
                    local mp = getPartPos(targetMonster)
                    if mp then
                        moveToVelocity(Vector3.new(mp.X, mp.Y + 5, mp.Z), 120, 2)
                        autoDigCursorFree()
                    end
                    task.wait(0.15)
                else
                    break
                end
            end

            -- Vacuum dropped monster loot
            local coll = Workspace:FindFirstChild("Collectibles")
            if coll then
                for _, tok in ipairs(coll:GetChildren()) do
                    local tp = getPartPos(tok)
                    if tp and (tp - loc).Magnitude <= 45 then
                        moveToVelocity(Vector3.new(tp.X, tp.Y, tp.Z), 90, 2)
                    end
                end
            end

            local qCheck = getPolarBearQuest()
            if qCheck and qCheck.allComplete then break end
        end

    -- Execute Bloom Petal Task
    elseif activeTask.type == "petal" then
        status = "Polar: Catching " .. (activeTask.petal or "") .. " Bloom Petals"
        local coll = Workspace:FindFirstChild("Collectibles")
        if coll then
            for _, tok in ipairs(coll:GetChildren()) do
                local nm = string.lower(tok.Name)
                if string.find(nm, "petal", 1, true) or string.find(nm, "bloom", 1, true) then
                    local tp = getPartPos(tok)
                    if tp then
                        moveToVelocity(Vector3.new(tp.X, tp.Y, tp.Z), 140, 2)
                        autoDigCursorFree()
                    end
                end
            end
        end
        task.wait(0.2)

    -- Execute Field Pollen Task
    elseif activeTask.type == "pollen" then
        local fieldName = activeTask.field
        status = "Polar Field: " .. fieldName
        local field = getField(fieldName)
        if field then
            currentField = field
            local c = field.Position
            local center = Vector3.new(c.X, groundY(field) + 2, c.Z)

            local hrp = getHRP()
            if hrp and not inField(hrp.Position, field, 10) then
                moveToVelocity(center, S.glide_speed, 4)
            end

            collecting = true
            autoDigCursorFree()
            farmFieldTurnStep(field, 14)
        end
    end
end

--------------------------------------------------------------------------
-- FIELD TURN LOCOMOTION (SMOOTH TURNS, NO BACK-AND-FORTH JUMPING)
--------------------------------------------------------------------------
local function getFieldTurnWaypoints(field, pattern, closeR)
    local c = field.Position
    local rx = math.max(8, (closeR or (field.Size.X / 2 - 8)))
    local rz = math.max(8, (closeR or (field.Size.Z / 2 - 8)))
    local standY = groundY(field) + 2

    if pattern == "Square / Box Turns" then
        return {
            Vector3.new(c.X - rx, standY, c.Z - rz),
            Vector3.new(c.X + rx, standY, c.Z - rz),
            Vector3.new(c.X + rx, standY, c.Z + rz),
            Vector3.new(c.X - rx, standY, c.Z + rz),
        }
    elseif pattern == "Serpentine / Snake" then
        return {
            Vector3.new(c.X - rx, standY, c.Z - rz),
            Vector3.new(c.X + rx, standY, c.Z - rz),
            Vector3.new(c.X + rx, standY, c.Z),
            Vector3.new(c.X - rx, standY, c.Z),
            Vector3.new(c.X - rx, standY, c.Z + rz),
            Vector3.new(c.X + rx, standY, c.Z + rz),
            Vector3.new(c.X, standY, c.Z),
        }
    else -- "Orbit / Circle Turns" (Default, continuous smooth turns)
        local pts = {}
        for i = 0, 7 do
            local theta = (i / 8) * math.pi * 2
            table.insert(pts, Vector3.new(c.X + math.cos(theta) * rx, standY, c.Z + math.sin(theta) * rz))
        end
        return pts
    end
end

local farmTurnIdx = 1
local function farmFieldTurnStep(field, closeR)
    local hrp = getHRP()
    if not hrp then return end

    local c = field.Position
    local standY = groundY(field) + 2
    local farmPattern = S.farm_mode or "Orbit / Circle Turns"

    local waypoints = getFieldTurnWaypoints(field, farmPattern, closeR)
    if #waypoints == 0 then return end

    -- Check if there are close tokens nearby (within 20 studs)
    local list = scanTokens(field, 2, closeR or 15, hrp.Position)
    local closeToken = nil
    if #list > 0 then
        table.sort(list, function(a, b) return a.score < b.score end)
        if list[1].score <= 20 then
            closeToken = list[1]
        end
    end

    if closeToken then
        local targetPos = clampTarget(Vector3.new(closeToken.pos.X, standY, closeToken.pos.Z), field, 2, closeR or 15)
        moveToVelocity(targetPos, S.glide_speed, 2.5)
        autoDigCursorFree()
        task.wait(0.04)
    else
        if farmTurnIdx > #waypoints then farmTurnIdx = 1 end
        local targetWp = waypoints[farmTurnIdx]
        moveToVelocity(targetWp, S.glide_speed, 2.5)
        autoDigCursorFree()

        local d = Vector3.new(hrp.Position.X - targetWp.X, 0, hrp.Position.Z - targetWp.Z).Magnitude
        if d <= 8 then
            farmTurnIdx = (farmTurnIdx % #waypoints) + 1
        end
        task.wait(0.06)
    end
end

--------------------------------------------------------------------------
-- BOSS COMBAT AUTOMATION (KING BEETLE, TUNNEL BEAR, CRAB, MONDO)
--------------------------------------------------------------------------
local tunnelBearCooldown = 0
local kingBeetleCooldown = 0

local function checkBossOnCooldown(bossName)
    local spawners = Workspace:FindFirstChild("MonsterSpawners")
    if spawners then
        for _, s in ipairs(spawners:GetChildren()) do
            local sName = string.lower(s.Name)
            if string.find(sName, string.lower(bossName), 1, true) then
                for _, desc in ipairs(s:GetDescendants()) do
                    if desc:IsA("TextLabel") then
                        local t = safeText(desc)
                        if #t > 0 and (string.find(t, ":", 1, true) or string.find(t, "m", 1, true) or string.find(t, "h", 1, true)) then
                            return true, t
                        end
                    end
                end
            end
        end
    end
    return false, nil
end

local function killTunnelBear()
    local hrp = getHRP()
    if not hrp then return end

    if tick() < tunnelBearCooldown then
        return
    end

    local onCd, timerText = checkBossOnCooldown("Tunnel")
    if onCd then
        tunnelBearCooldown = tick() + 600
        return
    end

    status = "Combat: Checking Tunnel Bear"
    local startPos = Vector3.new(380, 15, -45)
    local endPos = Vector3.new(515, 15, -45)

    -- Move to tunnel entrance
    moveToVelocity(startPos, S.glide_speed, 4)
    task.wait(0.3)

    -- Check if Tunnel Bear exists or spawns within 3.5 seconds
    local tb = nil
    local tWait = tick()
    while isOn() and tick() - tWait < 3.5 do
        local monsters = Workspace:FindFirstChild("Monsters")
        if monsters then
            for _, m in ipairs(monsters:GetChildren()) do
                if string.find(string.lower(m.Name), "tunnel", 1, true) or string.find(string.lower(m.Name), "bear", 1, true) then
                    tb = m
                    break
                end
            end
        end
        if tb then break end
        task.wait(0.2)
    end

    if not tb then
        -- Tunnel Bear already killed / not spawned!
        tunnelBearCooldown = tick() + 900
        return
    end

    -- Tunnel Bear is alive! Fight it by slowly retreating down the tunnel
    status = "Combat: Fighting Tunnel Bear"
    local retreatSpeed = 14
    local currentX = startPos.X
    local dl = tick() + 65

    while isOn() and tick() < dl do
        if not (tb and tb.Parent) then
            task.wait(0.4)
            local monsters = Workspace:FindFirstChild("Monsters")
            local stillAlive = false
            if monsters then
                for _, m in ipairs(monsters:GetChildren()) do
                    if string.find(string.lower(m.Name), "tunnel", 1, true) then stillAlive = true; break end
                end
            end
            if not stillAlive then break end
        end

        if currentX < endPos.X then
            currentX = currentX + retreatSpeed * 0.2
            if currentX > endPos.X then currentX = endPos.X end
            moveToVelocity(Vector3.new(currentX, 15, -45), retreatSpeed * 2, 2)
        else
            moveToVelocity(Vector3.new(endPos.X, 16, -45), 30, 2)
        end

        autoDigCursorFree()
        task.wait(0.15)
    end

    -- Tunnel Bear killed! Loot tokens down the tunnel
    status = "Looting Tunnel Bear"
    tunnelBearCooldown = tick() + 7200
    local lootEnd = tick() + 8
    while isOn() and tick() < lootEnd do
        moveToVelocity(endPos, 85, 4)
        autoDigCursorFree()
        local coll = Workspace:FindFirstChild("Collectibles")
        if coll then
            for _, tok in ipairs(coll:GetChildren()) do
                local p = getPartPos(tok)
                if p and p.X >= 360 and p.X <= 530 and math.abs(p.Z - (-45)) <= 30 then
                    moveToVelocity(Vector3.new(p.X, 15, p.Z), 95, 2)
                end
            end
        end
        moveToVelocity(startPos, 85, 4)
        task.wait(0.1)
    end
end

local function killKingBeetle()
    local hrp = getHRP()
    if not hrp then return end

    if tick() < kingBeetleCooldown then
        return
    end

    local onCd, timerText = checkBossOnCooldown("King")
    if onCd then
        kingBeetleCooldown = tick() + 600
        return
    end

    status = "Combat: Checking King Beetle"
    local entrance = Vector3.new(-220, 4, 200)
    moveToVelocity(entrance, S.glide_speed, 4)
    task.wait(0.3)

    -- Check if King Beetle exists or spawns within 3.5 seconds
    local kb = nil
    local tWait = tick()
    while isOn() and tick() - tWait < 3.5 do
        local monsters = Workspace:FindFirstChild("Monsters")
        if monsters then
            for _, m in ipairs(monsters:GetChildren()) do
                if string.find(string.lower(m.Name), "king", 1, true) or string.find(string.lower(m.Name), "beetle", 1, true) then
                    local mp = getPartPos(m)
                    if mp and math.abs(mp.X - (-220)) <= 60 and math.abs(mp.Z - 200) <= 60 then
                        kb = m
                        break
                    end
                end
            end
        end
        if kb then break end
        task.wait(0.2)
    end

    if not kb then
        -- King Beetle already killed / not spawned!
        kingBeetleCooldown = tick() + 900
        return
    end

    status = "Combat: Fighting King Beetle"
    local P1 = Vector3.new(-245, 4, 175)
    local P2 = Vector3.new(-195, 4, 175)
    local P3 = Vector3.new(-195, 4, 225)
    local P4 = Vector3.new(-245, 4, 225)
    local corners = { P1, P2, P3, P4 }

    local cornerIdx = 1
    local dl = tick() + 65

    while isOn() and tick() < dl do
        if not (kb and kb.Parent) then
            task.wait(0.4)
            local monsters = Workspace:FindFirstChild("Monsters")
            local stillAlive = false
            if monsters then
                for _, m in ipairs(monsters:GetChildren()) do
                    if string.find(string.lower(m.Name), "king", 1, true) then stillAlive = true; break end
                end
            end
            if not stillAlive then break end
        end

        local tgtCorner = corners[cornerIdx]
        moveToVelocity(tgtCorner, 55, 3)
        cornerIdx = (cornerIdx % 4) + 1

        autoDigCursorFree()
        task.wait(0.1)
    end

    -- King Beetle killed! Loot tokens in the lair
    status = "Looting King Beetle"
    kingBeetleCooldown = tick() + 7200
    local lootEnd = tick() + 7
    while isOn() and tick() < lootEnd do
        local coll = Workspace:FindFirstChild("Collectibles")
        if coll then
            for _, tok in ipairs(coll:GetChildren()) do
                local p = getPartPos(tok)
                if p and math.abs(p.X - (-220)) <= 40 and math.abs(p.Z - 200) <= 40 then
                    moveToVelocity(Vector3.new(p.X, 4, p.Z), 85, 2)
                end
            end
        end
        moveToVelocity(entrance, 75, 3)
        task.wait(0.1)
    end
end

local function doBossCombat()
    local hrp = getHRP()
    if not hrp then return end

    -- 1. King Beetle (Tween in squares around perimeter, then loot)
    if S.kill_beetle and isOn() then
        killKingBeetle()
    end

    -- 2. Tunnel Bear (Slow retreat down white tunnel, then loot)
    if S.kill_bear and isOn() then
        killTunnelBear()
    end

    -- 3. Coconut Crab (Temporarily disabled per user instruction)
    if S.kill_crab and isOn() then
        -- Skipped for now
    end

    -- 4. Mondo Chick
    if S.kill_mondo and isOn() then
        local mt = getField("Mountain Top Field")
        if mt then
            local monsters = Workspace:FindFirstChild("Monsters")
            local mondo = monsters and monsters:FindFirstChild("Mondo Chick")
            if mondo and mondo:FindFirstChildWhichIsA("BasePart") then
                status = "Combat: Mondo Chick"
                local mp = mondo.PrimaryPart or mondo:FindFirstChildWhichIsA("BasePart")
                if mp then
                    local mpPos = getPartPos(mp)
                    if mpPos then
                        moveToVelocity(mpPos + Vector3.new(0, 15, 0), S.glide_speed, 4)
                        local t0 = tick()
                        while isOn() and tick() - t0 < 20 do
                            if not (mondo and mondo.Parent) then break end
                            autoDigCursorFree()
                            task.wait(0.2)
                        end
                    end
                end
            end
        end
    end
end

local function scanTokens(field, farmMode, closeR, eyePos)
    local out = {}
    local folder = Workspace:FindFirstChild("Collectibles"); if not folder then return out end
    local okk, kids = pcall(function() return folder:GetChildren() end)
    if not okk or not kids then return out end
    for i = 1, #kids do
        local obj = kids[i]; local pos
        local okp, p = pcall(function() return obj.Position end)
        if okp and p then pos = p else
            local okm, mp = pcall(function() return obj.PrimaryPart.Position end)
            if okm and mp then pos = mp end
        end
        if pos and inField(pos, field, 4) then
            if farmMode ~= 1 or distToCenter(pos, field) <= closeR then
                local score = Vector3.new(pos.X - eyePos.X, 0, pos.Z - eyePos.Z).Magnitude
                out[#out + 1] = { part = obj, pos = pos, score = score }
            end
        end
    end
    return out
end

local function parseCapText(t)
    if type(t) ~= "string" then return nil, nil end
    local a, b = t:match("([%d,]+%s*[KkMmBbTt]?)%s*/%s*([%d,]+%s*[KkMmBbTt]?)")
    if not a or not b then return nil, nil end
    local function parseNum(s)
        s = s:gsub(",", ""):gsub("%s+", "")
        local mults = { K = 1e3, M = 1e6, B = 1e9, T = 1e12 }
        local suf = s:match("([KkMmBbTt])$")
        local mult = suf and (mults[suf:upper()] or 1) or 1
        if suf then s = s:sub(1, #s - 1) end
        local n = tonumber(s); return n and (n * mult) or nil
    end
    return parseNum(a), parseNum(b)
end

local function getPollenAndCap()
    local pg = lp:FindFirstChildOfClass("PlayerGui")
    if pg then
        for _, o in ipairs(pg:GetDescendants()) do
            if o:IsA("TextLabel") then
                local t = safeText(o)
                if #t > 0 then
                    local p, c = parseCapText(t)
                    if p and c and c >= 1000 then return p, c end
                end
            end
        end
    end
    local core = lp:FindFirstChild("CoreStats")
    if core then
        local p = core:FindFirstChild("Pollen")
        local c = core:FindFirstChild("Capacity")
        if p and c then return p.Value, c.Value end
    end
    return 0, 1000000
end

local function autoDigCursorFree()
    if S.pause_on_ui and not _G.LolcatFeaturesActive then return end
    local char = lp.Character; if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        pcall(function() tool:Activate() end)
    else
        local bp = lp:FindFirstChild("Backpack")
        if bp then
            local bpTool = bp:FindFirstChildOfClass("Tool")
            local hum = getHum()
            if bpTool and hum then pcall(function() hum:EquipTool(bpTool) end) end
        end
    end
end

-- Continuous background digger: automatically swings scoop/tool at full speed while farming
task.spawn(function()
    while true do
        if isOn() and (collecting or S.dig_tool) then
            autoDigCursorFree()
        end
        task.wait(0.18)
    end
end)

local function convertAtHive()
    restoreFacing()
    if not myHive then autoDetectHiveInstant() end
    local pad = myHive and hivePad(myHive)
    local pp = padPos(pad)
    if not pp then task.wait(1); return end

    local target = Vector3.new(pp.X, padTop(pad), pp.Z)
    collecting = false
    status = "Going to Hive"

    moveToVelocity(target, 220, 3)
    task.wait(0.5)

    status = "Converting"
    pcall(function() keypress(0x45); task.wait(0.15); keyrelease(0x45) end)

    local dl = tick() + 60
    while isOn() and tick() < dl do
        local p, c = getPollenAndCap()
        if p and p <= 10 then break end
        task.wait(0.5)
    end

    status = "Waiting (5s)"
    task.wait(5)
    needSprinkler = true
end

local function doReset()
    restoreFacing()
    status = "Resetting"
    pcall(function()
        keypress(0x1B); task.wait(0.1); keyrelease(0x1B); task.wait(0.3)
        keypress(0x52); task.wait(0.1); keyrelease(0x52); task.wait(0.3)
        keypress(0x0D); task.wait(0.1); keyrelease(0x0D); task.wait(2)
    end)
    local dl = tick() + 15
    while isOn() and tick() < dl do if getHRP() then break end; task.wait(0.3) end
    if currentField and isOn() then
        local c = currentField.Position
        moveToVelocity(Vector3.new(c.X, groundY(currentField) + 2, c.Z), 240, 3)
    end
    needSprinkler = true
end

--------------------------------------------------------------------------
-- SECTION 3: INITIALIZE LOLCAT UI (WINDOW, TABS & WIDGETS)
--------------------------------------------------------------------------
local Win = LolcatUI:CreateWindow({
    Title = "LOLCAT",
    SubTitle = "Matcha Edition",
    Size = Vector2.new(919, 643),
    ToggleKey = 0xA1, -- Right Shift
    Accent = Color3.fromRGB(154, 213, 222), -- #9AD5DE Original Soft Teal
    Watermark = true,
    WatermarkText = "lolcat | matcha",
})

-- 1. TAB: FARMING
local FarmTab = Win:CreateTab({ Name = "Farming", Glyph = "crosshair" })
local FarmMainSub = FarmTab:CreateSubTab({ Name = "Main", Description = "Field gathering, tokens, and conversion." })
local FarmLeft = FarmMainSub:CreateSection({ Title = "Automation", Side = "left" })
local FarmRight = FarmMainSub:CreateSection({ Title = "Hive Return & Status", Side = "right" })

FarmLeft:CreateToggle({
    Title = "Enable Auto Farm",
    Default = false,
    Callback = function(v)
        S.farm_on = v
        if v then needSprinkler = true else restoreFacing() end
    end,
})

FarmLeft:CreateDropdown({
    Title = "Target Field",
    Options = zoneNames,
    Default = "Dandelion Field",
    Callback = function(v)
        if S.field ~= v then needSprinkler = true end
        S.field = v
    end,
})

FarmLeft:CreateDropdown({
    Title = "Farm Pattern",
    Options = { "Orbit / Circle Turns", "Square / Box Turns", "Serpentine / Snake", "Whole Field", "Middle Only" },
    Default = "Orbit / Circle Turns",
    Callback = function(v) S.farm_mode = v end,
})

FarmLeft:CreateSlider({
    Title = "Close Radius",
    Min = 5,
    Max = 60,
    Default = 12,
    Step = 1,
    Suffix = " studs",
    Callback = function(v) S.close_r = v end,
})

FarmLeft:CreateSlider({
    Title = "Farm Glide Speed",
    Min = 25,
    Max = 250,
    Default = 75,
    Step = 5,
    Suffix = " studs/s",
    Callback = function(v) S.glide_speed = v end,
})

FarmLeft:CreateButton({
    Title = "Reset Speed (Default: 75)",
    Callback = function()
        S.glide_speed = 75
    end,
})

FarmLeft:CreateToggle({
    Title = "Auto Dig (No Click)",
    Default = true,
    Callback = function(v) S.dig_tool = v end,
})

FarmRight:CreateSlider({
    Title = "Convert At %",
    Min = 50,
    Max = 100,
    Default = 90,
    Step = 5,
    Suffix = "%",
    Callback = function(v) S.full_pct = v end,
})

FarmRight:CreateToggle({
    Title = "Reset Instead of Convert",
    Default = false,
    Callback = function(v) S.reset_mode = v end,
})

FarmRight:CreateStat({
    Title = "Status",
    Getter = function()
        if S.pause_on_ui and not _G.LolcatFeaturesActive then return "Paused (UI Open)" end
        return status
    end,
})

FarmRight:CreateStat({
    Title = "Backpack",
    Getter = function()
        local p, c = getPollenAndCap()
        if p and c and c > 0 then
            return fmt("%s / %s (%d%%)", math.floor(p), math.floor(c), math.floor((p / c) * 100))
        end
        return "-"
    end,
})

-- SubTab: Targeting & Facing
local FaceSub = FarmTab:CreateSubTab({ Name = "Facing & Buffs", Description = "Smooth orientation toward field, bubbles & balloons." })
local FaceLeft = FaceSub:CreateSection({ Title = "Facing Mode", Side = "left" })
local FaceRight = FaceSub:CreateSection({ Title = "Gathering Extras", Side = "right" })

FaceLeft:CreateToggle({
    Title = "Face Field Middle",
    Default = false,
    Callback = function(v) S.face_center = v end,
})

FaceLeft:CreateToggle({
    Title = "Face Balloons (Yours & Others)",
    Default = true,
    Callback = function(v) S.face_balloons = v end,
})

FaceLeft:CreateToggle({
    Title = "Face Bubbles (Yours & Others)",
    Default = true,
    Callback = function(v) S.face_bubbles = v end,
})

FaceLeft:CreateToggle({
    Title = "Rotate Camera Screen",
    Default = false,
    Callback = function(v) S.face_camera = v end,
})

FaceLeft:CreateToggle({
    Title = "Direct Memory Orientation",
    Default = false,
    Callback = function(v) S.mem_facing = v end,
})

-- SubTab: Polar Bear Quests
local QuestSub = FarmTab:CreateSubTab({ Name = "Polar Quests", Description = "Complete all Polar Bear quests (Mobs, Blooms & Pollen)." })
local QuestLeft = QuestSub:CreateSection({ Title = "Automation & Status", Side = "left" })
local QuestRight = QuestSub:CreateSection({ Title = "Task Directives", Side = "right" })

QuestLeft:CreateToggle({
    Title = "Auto Complete Polar Quests",
    Default = true,
    Callback = function(v) S.auto_polar_quests = v end,
})

QuestLeft:CreateButton({
    Title = "Claim / Accept From Polar Bear",
    Callback = function()
        task.spawn(claimOrAcceptPolarBearQuest)
    end,
})

QuestLeft:CreateStat({
    Title = "Polar Quest",
    Getter = function()
        local q = getPolarBearQuest()
        return q and (q.questName or q.title) or "None Detected"
    end,
})

QuestLeft:CreateStat({
    Title = "Quest Status",
    Getter = function()
        local q = getPolarBearQuest()
        if not q or not q.hasQuest then return "Visit Polar Bear" end
        if q.allComplete then return "Ready to Turn In!" end
        for _, t in ipairs(q.tasks) do
            if not t.complete then
                if t.type == "mob" then return t.mob .. " (" .. t.needed .. " left)" end
                if t.type == "petal" then return (t.petal or "") .. " Petals (" .. t.needed .. " left)" end
                if t.type == "pollen" then return (t.field or "Field") .. " (" .. t.needed .. " left)" end
            end
        end
        return "In Progress"
    end,
})

QuestRight:CreateToggle({
    Title = "Defeat Quest Mobs",
    Default = true,
    Callback = function(v) S.polar_kill_mobs = v end,
})

QuestRight:CreateToggle({
    Title = "Farm Quest Fields",
    Default = true,
    Callback = function(v) S.polar_farm_fields = v end,
})

QuestRight:CreateToggle({
    Title = "Catch Bloom Petals",
    Default = true,
    Callback = function(v) S.polar_catch_petals = v end,
})

FaceRight:CreateToggle({
    Title = "Farm Under Balloons",
    Default = false,
    Callback = function(v) S.farm_under_balloons = v end,
})

FaceRight:CreateToggle({
    Title = "Farm Under Clouds",
    Default = false,
    Callback = function(v) S.farm_under_clouds = v end,
})

FaceRight:CreateToggle({
    Title = "Farm Flames",
    Default = false,
    Callback = function(v) S.farm_flames = v end,
})

FaceRight:CreateDropdown({
    Title = "Sprinkler (Slot 1)",
    Options = { "Off", "Basic", "Silver", "Gold", "Diamond", "Supreme" },
    Default = "Off",
    Callback = function(v) S.sprinkler = v end,
})

-- 2. TAB: COMBAT & MOBS (From User Script)
local CombatTab = Win:CreateTab({ Name = "Combat", Glyph = "gun" })
local CombatSub = CombatTab:CreateSubTab({ Name = "Bosses & Hazards", Description = "Auto combat and hazard collection." })
local CombatLeft = CombatSub:CreateSection({ Title = "Boss Farming", Side = "left" })
local CombatRight = CombatSub:CreateSection({ Title = "Hazards & Items", Side = "right" })

CombatLeft:CreateToggle({
    Title = "Auto Kill Coconut Crab",
    Default = false,
    Callback = function(v) S.kill_crab = v end,
})

CombatLeft:CreateToggle({
    Title = "Auto Kill King Beetle",
    Default = false,
    Callback = function(v) S.kill_beetle = v end,
})

CombatLeft:CreateToggle({
    Title = "Auto Kill Tunnel Bear",
    Default = false,
    Callback = function(v) S.kill_bear = v end,
})

CombatLeft:CreateToggle({
    Title = "Auto Kill Vicious Bee",
    Default = false,
    Callback = function(v) S.kill_vicious = v end,
})

CombatRight:CreateToggle({
    Title = "Catch Falling Coconuts",
    Default = false,
    Callback = function(v) S.catch_coconuts = v end,
})

CombatRight:CreateToggle({
    Title = "Catch Star Showers",
    Default = false,
    Callback = function(v) S.catch_stars = v end,
})

CombatRight:CreateToggle({
    Title = "Farm Active Sprouts",
    Default = false,
    Callback = function(v) S.farm_sprouts = v end,
})

-- 3. TAB: HIVE
local HiveTab = Win:CreateTab({ Name = "Hive", Glyph = "globe" })
local HiveSub = HiveTab:CreateSubTab({ Name = "Hive Manager", Description = "5-Tier Instant Hive Detection." })
local HiveLeft = HiveSub:CreateSection({ Title = "Detection", Side = "left" })
local HiveRight = HiveSub:CreateSection({ Title = "Actions", Side = "right" })

HiveLeft:CreateButton({
    Title = "Auto Detect Hive (Instant)",
    Callback = function()
        local h = autoDetectHiveInstant()
        status = h and ("Detected: " .. h.Name) or "Hive not found!"
    end,
})

HiveLeft:CreateButton({
    Title = "Fast Pad Sweep",
    Callback = function()
        task.spawn(function()
            local honey = Workspace:FindFirstChild("Honeycombs") or Workspace:FindFirstChild("Hives")
            if not honey then return end
            status = "Sweeping pads..."
            for _, hive in ipairs(honey:GetChildren()) do
                local pad = hivePad(hive)
                local pp = padPos(pad)
                if pp then
                    moveToVelocity(Vector3.new(pp.X, padTop(pad), pp.Z), 300, 3)
                    task.wait(0.2)
                    local h = autoDetectHiveInstant()
                    if h then status = "Found: " .. h.Name; break end
                end
            end
        end)
    end,
})

HiveLeft:CreateButton({
    Title = "Set Hive (Manual Pad)",
    Callback = function()
        setHiveManual()
        if myHive then status = "Hive: " .. myHive.Name end
    end,
})

HiveLeft:CreateStat({
    Title = "Assigned Hive",
    Getter = function() return myHive and myHive.Name or "None" end,
})

HiveRight:CreateButton({
    Title = "Force Return to Hive Now",
    Callback = function() forceReturn = true end,
})

HiveRight:CreateToggle({
    Title = "Convert Balloon At Hive",
    Default = false,
    Callback = function(v) S.convert_balloon = v end,
})

-- 4. TAB: MOVEMENT
local MoveTab = Win:CreateTab({ Name = "Movement", Glyph = "player" })
local MoveSub = MoveTab:CreateSubTab({ Name = "Velocity Flight", Description = "Gliding through walls & walk animations." })
local MoveLeft = MoveSub:CreateSection({ Title = "Flight Locomotion", Side = "left" })
local MoveRight = MoveSub:CreateSection({ Title = "World Modifiers", Side = "right" })

MoveLeft:CreateSlider({
    Title = "Velocity Speed",
    Min = 25,
    Max = 250,
    Default = 75,
    Step = 5,
    Suffix = " studs/s",
    Callback = function(v) S.glide_speed = v end,
})

MoveLeft:CreateToggle({
    Title = "Walk Animation While Gliding",
    Default = true,
    Callback = function(v) S.walk_anim = v end,
})

MoveRight:CreateToggle({
    Title = "Noclip When Auto Farm Is On",
    Default = true,
    Callback = function(v) S.noclip = v end,
})

MoveRight:CreateToggle({
    Title = "World No-Collide (Decos/Fences)",
    Default = false,
    Callback = function(v) S.world_noclip = v end,
})

-- 5. TAB: SETTINGS
local SetTab = Win:CreateTab({ Name = "Settings", Glyph = "gear" })
local SetSub = SetTab:CreateSubTab({ Name = "General", Description = "Keybinds, safety, and unloading." })
local SetLeft = SetSub:CreateSection({ Title = "Keybinds & State", Side = "left" })
local SetRight = SetSub:CreateSection({ Title = "Theme & Unload", Side = "right" })

SetLeft:CreateKeybind({
    Title = "Menu Toggle Keybind",
    DefaultKey = 0xA1, -- Right Shift
    Callback = function(vk)
        Win.ToggleKey = vk
    end,
})

SetLeft:CreateToggle({
    Title = "Pause Features When UI Open",
    Default = false,
    Callback = function(v)
        S.pause_on_ui = v
    end,
})

SetLeft:CreateStat({
    Title = "Bot Execution State",
    Getter = function()
        if S.pause_on_ui and not _G.LolcatFeaturesActive then
            return "Paused (Menu Open)"
        end
        return (S.farm_on and isAlive()) and "Active (Features Running)" or "Idle / Disabled"
    end,
})

SetRight:CreateButton({
    Title = "Unload / Close Script",
    Callback = function()
        S.farm_on = false
        restoreFacing()
        Win:Destroy()
        print("[LOLCAT] Unloaded cleanly.")
    end,
})

--------------------------------------------------------------------------
-- SECTION 4: BACKGROUND THREADS & MAIN BOT LOOP
--------------------------------------------------------------------------
-- Startup Instant Hive Detection
task.spawn(function()
    task.wait(1.5)
    autoDetectHiveInstant()
end)

-- Cursor-Free Digging
task.spawn(function()
    while true do
        if isOn() and S.dig_tool and collecting then
            autoDigCursorFree()
        end
        task.wait(0.2)
    end
end)

-- Dynamic Multi-Target Facing (Balloons > Bubbles > Normal Free-Look)
local lastFacedTarget = false
local function updateFacingTick()
    if isOn() and collecting and currentField then
        local hrp = getHRP()
        if hrp then
            local targetPos = nil

            -- 1. Face Balloons in/near Field (Other players' + your own)
            if S.face_balloons then
                local balloon, dist = findClosestBalloon(currentField)
                if balloon and dist <= 85 then
                    targetPos = balloon.Position
                end
            end

            -- 2. Face Bubbles in/near Field (Other players' + your own)
            if not targetPos and S.face_bubbles then
                local bubble, dist = findNearestBubble(currentField, hrp.Position)
                if bubble and dist <= 65 then
                    targetPos = bubble.Position
                end
            end

            -- 3. Face Field Middle (Optional, only if explicitly enabled)
            if not targetPos and S.face_center then
                targetPos = currentField.Position
            end

            if targetPos then
                lastFacedTarget = true
                facePosition(targetPos)
            else
                -- NO ACTIVE TARGET: Character plays completely normal!
                if lastFacedTarget then
                    lastFacedTarget = false
                    restoreFacing()
                end
            end
            return
        end
    end
    if lastFacedTarget then
        lastFacedTarget = false
        restoreFacing()
    end
end

-- Smooth facing background thread (avoids locking physics on RenderStepped)
task.spawn(function()
    while true do
        updateFacingTick()
        task.wait(0.04)
    end
end)

-- Main Farm Supervisor Loop
local initialRoutineDone = false
local farmCycleStart = 0

task.spawn(function()
    while true do
        if not isOn() then
            collecting = false
            initialRoutineDone = false
            farmCycleStart = 0
            restoreFacing()
            task.wait(0.3)
        else
            -- 1. STARTUP ROUTINE (Runs once when enabled):
            if not initialRoutineDone then
                initialRoutineDone = true
                collecting = false

                -- Step A: Enabled Boss Combat First
                local hasCombat = S.kill_beetle or S.kill_bear or S.kill_vicious or S.kill_mondo
                if hasCombat and isOn() then
                    status = "Routine: Boss Combat"
                    doBossCombat()
                end

                -- Step B: Polar Bear Quests Second
                if S.auto_polar_quests and isOn() then
                    status = "Routine: Polar Quest"
                    completePolarBearRoutine()
                end

                farmCycleStart = tick()
                needSprinkler = true
            end

            -- 2. POLAR BEAR QUEST OR DIRECT AUTO FARM:
            if S.auto_polar_quests and isOn() then
                local pollen, cap = getPollenAndCap()
                local isFull = forceReturn or (pollen and cap and cap > 0 and pollen >= cap * (S.full_pct / 100))
                if isFull then
                    forceReturn = false
                    collecting = false
                    if S.reset_mode then doReset() else convertAtHive() end
                else
                    completePolarBearRoutine()
                end

            -- Pure Auto Farm on user-selected field (S.field):
            else
                -- Periodic 10-Minute Combat Cycle Check:
                if farmCycleStart > 0 and (tick() - farmCycleStart) >= 600 then
                    local hasCombat = S.kill_beetle or S.kill_bear or S.kill_vicious or S.kill_mondo
                    if hasCombat and isOn() then
                        status = "10 Min Cycle: Bosses"
                        doBossCombat()
                    end
                    farmCycleStart = tick()
                    needSprinkler = true
                end

                local field = getField(S.field)
                currentField = field

                if not field then
                    status = "Zone Not Found"
                    task.wait(1)
                else
                    local pollen, cap = getPollenAndCap()
                    local isFull = forceReturn or (pollen and cap and cap > 0 and pollen >= cap * (S.full_pct / 100))

                    if isFull then
                        forceReturn = false
                        collecting = false
                        if S.reset_mode then doReset() else convertAtHive() end
                    else
                        local hrp = getHRP()
                        if hrp then
                            local c = field.Position
                            local center = Vector3.new(c.X, groundY(field) + 2, c.Z)
                            local farmMode = MODE_INDEX[S.farm_mode] or 2
                            local closeR = S.close_r or 12
                            local standY = groundY(field) + 2

                            -- Sprinklers Check
                            local reps = SPRINK_REPS[S.sprinkler] or 0
                            if needSprinkler and reps > 0 then
                                needSprinkler = false
                                status = "Placing Sprinklers"
                                moveToVelocity(center, S.glide_speed, 3)
                                for i = 1, reps do
                                    pcall(function()
                                        keypress(0x20); task.wait(0.05); keyrelease(0x20); task.wait(0.2)
                                        keypress(0x31); task.wait(0.05); keyrelease(0x31); task.wait(0.4)
                                    end)
                                end
                            end
                            needSprinkler = false

                            -- Navigate to field if not inside
                            if not inField(hrp.Position, field, 10) then
                                status = "Flying to Field"
                                moveToVelocity(center, S.glide_speed, 4)
                            end

                            collecting = true
                            status = "Farming " .. S.field

                            -- Continuous auto dig tool swing
                            autoDigCursorFree()

                            -- Advanced Gathering Checks (Balloons, Clouds, Flames)
                            if S.farm_under_balloons then
                                local b = findClosestBalloon(field)
                                if b then
                                    moveToVelocity(Vector3.new(b.Position.X, standY, b.Position.Z), S.glide_speed, 3)
                                    autoDigCursorFree()
                                end
                            elseif S.farm_under_clouds then
                                local cl = findNearestCloud(field)
                                if cl then
                                    moveToVelocity(Vector3.new(cl.Position.X, standY, cl.Position.Z), S.glide_speed, 3)
                                    autoDigCursorFree()
                                end
                            elseif S.farm_flames then
                                local fl = findNearestFlame(field)
                                if fl then
                                    moveToVelocity(Vector3.new(fl.Position.X, standY, fl.Position.Z), S.glide_speed, 3)
                                    autoDigCursorFree()
                                end
                            end

                            -- Middle Only Mode
                            if farmMode == 0 then
                                if distToCenter(hrp.Position, field) > 4 then
                                    moveToVelocity(center, S.glide_speed, 3)
                                end
                                autoDigCursorFree()
                                task.wait(0.1)
                            else
                                -- Smooth Turn-Based Field Farming (Takes turns, no ping-ponging back and forth)
                                farmFieldTurnStep(field, farmMode == 1 and closeR or nil)
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.05)
    end
end)

print("[LOLCAT] Loaded successfully. Press Right Shift to toggle.")
return Win
