--[[
    @Author: Zuka Tech
    @Date: 11/6/2025
    @Description: A modular, client-sided chat command system for Myself in Roblox.
                 This version includes a centralized command registry and a fully-featured
                 command bar with real-time auto-completion. --WIP
]]

-- === Secure Access Code Prompt ===
local ACCESS_CODES = {
    ["root"] = true,
}
local function showAccessPrompt()
    -- This section remains unchanged as it's for initial access.
    local sg = Instance.new("ScreenGui")
    sg.Name = "ZukaAccessPrompt"
    sg.ResetOnSpawn = false
    sg.Parent = game:GetService("CoreGui")
    local frame = Instance.new("Frame", sg)
    frame.Size = UDim2.new(0, 340, 0, 140)
    frame.Position = UDim2.new(0.5, -170, 0.5, -70)
    frame.BackgroundColor3 = Color3.fromRGB(30,30,40)
    frame.BorderSizePixel = 0
    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 10)
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -24, 0, 36)
    label.Position = UDim2.new(0, 12, 0, 10)
    label.BackgroundTransparency = 1
    label.Text = "Developer Key"
    label.Font = Enum.Font.Code
    label.TextSize = 18
    label.TextColor3 = Color3.fromRGB(200,220,255)
    label.TextXAlignment = Enum.TextXAlignment.Left
    local box = Instance.new("TextBox", frame)
    box.Size = UDim2.new(1, -24, 0, 36)
    box.Position = UDim2.new(0, 12, 0, 56)
    box.BackgroundColor3 = Color3.fromRGB(40,40,60)
    box.TextColor3 = Color3.fromRGB(255,255,255)
    box.Font = Enum.Font.Code
    box.TextSize = 18
    box.PlaceholderText = "got root?"
    box.Text = ""
    local okBtn = Instance.new("TextButton", frame)
    okBtn.Size = UDim2.new(0, 120, 0, 32)
    okBtn.Position = UDim2.new(1, -132, 1, -42)
    okBtn.BackgroundColor3 = Color3.fromRGB(60,120,200)
    okBtn.TextColor3 = Color3.fromRGB(255,255,255)
    okBtn.Font = Enum.Font.Code
    okBtn.TextSize = 16
    okBtn.Text = "Enter"
    local okCorner = Instance.new("UICorner", okBtn)
    okCorner.CornerRadius = UDim.new(0, 6)
    local result = Instance.new("TextLabel", frame)
    result.Size = UDim2.new(1, -24, 0, 20)
    result.Position = UDim2.new(0, 12, 1, -20)
    result.BackgroundTransparency = 1
    result.Text = ""
    result.Font = Enum.Font.Code
    result.TextSize = 14
    result.TextColor3 = Color3.fromRGB(255,80,80)
    result.TextXAlignment = Enum.TextXAlignment.Left
    local accessGranted = false
    local function tryAccess()
        if ACCESS_CODES[box.Text] then
            accessGranted = true
            sg:Destroy()
        else
            result.Text = "Wrong code. Try again."
        end
    end
    okBtn.MouseButton1Click:Connect(tryAccess)
    box.FocusLost:Connect(function(enter) if enter then tryAccess() end end)
    repeat task.wait() until accessGranted
end
showAccessPrompt()

-- ==========================================================
-- Services & Setup
-- ==========================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- Executor/Environment Dependencies
local function DoNotif(message, duration) print("NOTIFICATION: " .. tostring(message) .. " (for " .. tostring(duration) .. "s)") end
local function NaProtectUI(gui) if gui then gui.Parent = CoreGui or LocalPlayer:WaitForChild("PlayerGui") end; print("UI Protection applied to: " .. gui.Name) end
if not setclipboard then setclipboard = function(text) print("Clipboard (fallback): " .. text); DoNotif("setclipboard is not available. See console for output.", 5) end end

-- ==========================================================
-- Configuration
-- ==========================================================
local Prefix = ";"
local Commands = {}
local CommandInfo = {} -- For ;cmds UI, now populated by RegisterCommand
local Modules = {}

-- ==========================================================
-- NEW: Centralized Command Registration Function
-- ==========================================================
function RegisterCommand(info, func)
    if not info or not info.Name or not func then
        warn("Command registration failed: Missing info, name, or function.")
        return
    end

    local name = info.Name:lower()

    -- Ensure no duplicate commands or aliases are registered
    if Commands[name] then
        warn("Command registration skipped: Command '" .. name .. "' already exists.")
        return
    end

    -- 1. Add to the command execution table
    Commands[name] = func

    -- 2. Add aliases to the execution table
    if info.Aliases then
        for _, alias in ipairs(info.Aliases) do
            local aliasLower = alias:lower()
            if Commands[aliasLower] then
                warn("Alias '" .. aliasLower .. "' for command '" .. name .. "' conflicts with an existing command and was not registered.")
            else
                Commands[aliasLower] = func
            end
        end
    end

    -- 3. Add the detailed info to the list for the ;cmds UI
    table.insert(CommandInfo, info)
end

-- ==========================================================
-- NEW: Auto-Complete Module
-- ==========================================================
Modules.AutoComplete = {}; function Modules.AutoComplete:GetMatches(prefix)
    local matches = {}
    if typeof(prefix) ~= "string" or #prefix == 0 then return matches end
    prefix = prefix:lower()

    for cmdName, _ in pairs(Commands) do
        if cmdName:sub(1, #prefix) == prefix then
            table.insert(matches, cmdName)
        end
    end
    table.sort(matches) -- Keep the list clean and alphabetical
    return matches
end

-- ==========================================================
-- OVERHAULED: CommandBar Module with Auto-Completion
-- ==========================================================
Modules.CommandBar = { State = { UI = nil } }; function Modules.CommandBar:Toggle()
    if self.State.UI then self.State.UI:Destroy(); self.State.UI = nil; return end

    -- Create UI
    local ui = Instance.new("ScreenGui"); ui.Name = "CommandBarUI"; NaProtectUI(ui); self.State.UI = ui
    local container = Instance.new("Frame", ui)
    container.Size = UDim2.new(0, 450, 0, 32) -- Initial size, will expand for suggestions
    container.Position = UDim2.new(0.5, -225, 0, 10)
    container.BackgroundTransparency = 1

    local bar = Instance.new("Frame", container)
    bar.Size = UDim2.new(1, 0, 0, 32)
    bar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    bar.BackgroundTransparency = 0.2
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 6)

    local prefixLabel = Instance.new("TextLabel", bar)
    prefixLabel.Size = UDim2.new(0, 20, 1, 0); prefixLabel.Position = UDim2.fromOffset(5, 0)
    prefixLabel.BackgroundTransparency = 1; prefixLabel.Font = Enum.Font.Code
    prefixLabel.Text = Prefix; prefixLabel.TextColor3 = Color3.fromRGB(200, 220, 255); prefixLabel.TextSize = 18

    local textBox = Instance.new("TextBox", bar)
    textBox.Size = UDim2.new(1, -30, 1, 0); textBox.Position = UDim2.fromOffset(25, 0)
    textBox.BackgroundTransparency = 1; textBox.Font = Enum.Font.Code; textBox.Text = ""
    textBox.PlaceholderText = "Enter command..."; textBox.PlaceholderColor3 = Color3.fromRGB(150, 160, 180)
    textBox.TextColor3 = Color3.fromRGB(255, 255, 255); textBox.TextSize = 16; textBox.ClearTextOnFocus = false

    local suggestionsFrame = Instance.new("ScrollingFrame", container)
    suggestionsFrame.Size = UDim2.new(1, 0, 0, 120) -- Max height for suggestions
    suggestionsFrame.Position = UDim2.new(0, 0, 1, 4) -- Position below the bar
    suggestionsFrame.BackgroundTransparency = 0.2; suggestionsFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    suggestionsFrame.BorderSizePixel = 0; suggestionsFrame.ScrollBarThickness = 5; suggestionsFrame.Visible = false
    Instance.new("UICorner", suggestionsFrame).CornerRadius = UDim.new(0, 6)
    Instance.new("UIListLayout", suggestionsFrame).Padding = UDim.new(0, 2)

    -- Auto-Completion Logic
    local isScriptUpdatingText = false
    local MAX_SUGGESTIONS = 5

    local function clearSuggestions()
        suggestionsFrame.Visible = false
        suggestionsFrame:ClearAllChildren()
    end
    
    local function createSuggestionButton(text)
        local button = Instance.new("TextButton")
        button.Text = text; button.TextSize = 14; button.Font = Enum.Font.Code
        button.TextColor3 = Color3.fromRGB(230, 230, 230); button.TextXAlignment = Enum.TextXAlignment.Left
        button.BackgroundColor3 = Color3.fromRGB(55, 55, 55); button.BorderSizePixel = 0
        button.Size = UDim2.new(1, -8, 0, 22); button.Position = UDim2.fromOffset(4,0)
        button.Parent = suggestionsFrame
        
        button.MouseButton1Click:Connect(function()
            isScriptUpdatingText = true
            textBox.Text = text .. " "
            textBox:CaptureFocus()
            isScriptUpdatingText = false
            clearSuggestions()
        end)
    end

    local function updateSuggestions()
        if isScriptUpdatingText then return end
        clearSuggestions()
        local inputText = textBox.Text:match("^%s*(%S*)") -- Get only the first word
        if not inputText or #inputText == 0 then return end
        
        local matches = Modules.AutoComplete:GetMatches(inputText)
        if #matches > 0 then
            suggestionsFrame.Visible = true
            for i = 1, math.min(#matches, MAX_SUGGESTIONS) do
                createSuggestionButton(matches[i])
            end
        end
    end

    textBox.Changed:Connect(function(prop) if prop == "Text" then updateSuggestions() end end)
    textBox.FocusLost:Connect(function(enterPressed)
        if enterPressed and textBox.Text:len() > 0 then
            processCommand(Prefix .. textBox.Text)
            textBox.Text = ""
        end
        task.wait(0.1) -- Delay to allow suggestion clicks to register
        clearSuggestions()
    end)
    textBox.Focused:Connect(updateSuggestions)

    -- Drag Logic
    local function drag(o) local d,s,p; o.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then d,s,p=true,i.Position,o.Position;i.Changed:Connect(function()if i.UserInputState==Enum.UserInputState.End then d=false end end)end end); o.InputChanged:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseMovement and d then o.Position=UDim2.new(p.X.Scale,p.X.Offset+i.Position.X-s.X,p.Y.Scale,p.Y.Offset+i.Position.Y-s.Y)end end)end
    drag(container)

    DoNotif("Command bar enabled.", 3)
end

-- ==========================================================
-- Core Modules (Unchanged)
-- ==========================================================
Modules.Fly = { State = { IsActive = false, Speed = 75, SprintMultiplier = 2.5, Connections = {}, BodyMovers = {} } }; function Modules.Fly:SetSpeed(s) local n = tonumber(s); if n and n > 0 then self.State.Speed = n; DoNotif("Fly speed set to: " .. n, 3) else DoNotif("Invalid speed.", 3) end end; function Modules.Fly:Disable() if not self.State.IsActive then return end; self.State.IsActive = false; local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid"); if h then h.PlatformStand = false end; for _, m in pairs(self.State.BodyMovers) do if m.Parent then m:Destroy() end end; for _, c in ipairs(self.State.Connections) do c:Disconnect() end; table.clear(self.State.BodyMovers); table.clear(self.State.Connections); DoNotif("Fly disabled.", 3) end; function Modules.Fly:Enable() if self.State.IsActive then return end; local c = LocalPlayer.Character; if not c or not c.HumanoidRootPart or not c:FindFirstChildOfClass("Humanoid") then DoNotif("Character required.", 3); return end; self.State.IsActive = true; DoNotif("Fly Enabled.", 3); local h, hrp = c.Humanoid, c.HumanoidRootPart; h.PlatformStand = true; local g = Instance.new("BodyGyro", hrp); g.MaxTorque = Vector3.new(9e9, 9e9, 9e9); g.P = 20000; local v = Instance.new("BodyVelocity", hrp); v.MaxForce = Vector3.new(9e9, 9e9, 9e9); self.State.BodyMovers.Gyro, self.State.BodyMovers.Velocity = g, v; local k = {}; local function onInput(i, gp) if not gp then k[i.KeyCode] = (i.UserInputState == Enum.UserInputState.Begin) end end; table.insert(self.State.Connections, UserInputService.InputBegan:Connect(onInput)); table.insert(self.State.Connections, UserInputService.InputEnded:Connect(onInput)); local l = RunService.RenderStepped:Connect(function() if not self.State.IsActive or not hrp.Parent then return end; local cam = workspace.CurrentCamera; g.CFrame = cam.CFrame; local dir = Vector3.new(); if k[Enum.KeyCode.W] then dir += cam.CFrame.LookVector end; if k[Enum.KeyCode.S] then dir -= cam.CFrame.LookVector end; if k[Enum.KeyCode.D] then dir += cam.CFrame.RightVector end; if k[Enum.KeyCode.A] then dir -= cam.CFrame.RightVector end; if k[Enum.KeyCode.Space] or k[Enum.KeyCode.E] then dir += Vector3.yAxis end; if k[Enum.KeyCode.LeftControl] or k[Enum.KeyCode.Q] then dir -= Vector3.yAxis end; local s = k[Enum.KeyCode.LeftShift] and self.State.Speed * self.State.SprintMultiplier or self.State.Speed; v.Velocity = dir.Magnitude > 0 and dir.Unit * s or Vector3.zero end); table.insert(self.State.Connections, l) end; function Modules.Fly:Toggle() if self.State.IsActive then self:Disable() else self:Enable() end end
Modules.Noclip = { State = { IsActive = false, Connection = nil } }; function Modules.Noclip:Enable() if self.State.IsActive then return end; self.State.IsActive = true; self.State.Connection = RunService.Stepped:Connect(function() if LocalPlayer.Character then for _, p in ipairs(LocalPlayer.Character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end end); DoNotif("Noclip enabled.", 3) end; function Modules.Noclip:Disable() if not self.State.IsActive then return end; self.State.IsActive = false; if self.State.Connection then self.State.Connection:Disconnect(); self.State.Connection = nil end; DoNotif("Noclip disabled.", 3) end; function Modules.Noclip:Toggle() if self.State.IsActive then self:Disable() else self:Enable() end end
Modules.CommandsUI = { State = { UI = nil } }; function Modules.CommandsUI:Toggle() if self.State.UI then self.State.UI:Destroy(); self.State.UI = nil; return end; local u = Instance.new("ScreenGui"); u.Name = "CommandsUI"; NaProtectUI(u); self.State.UI = u; local f = Instance.new("Frame", u); f.Size = UDim2.fromOffset(450, 300); f.Position = UDim2.new(0.5, -225, 0.5, -150); f.BackgroundColor3 = Color3.fromRGB(35, 35, 45); Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8); local h = Instance.new("Frame", f); h.Size = UDim2.new(1, 0, 0, 32); h.BackgroundColor3 = Color3.fromRGB(25, 25, 35); local t = Instance.new("TextLabel", h); t.Size = UDim2.new(1, -30, 1, 0); t.Position = UDim2.fromOffset(10, 0); t.BackgroundTransparency = 1; t.Font = Enum.Font.Code; t.Text = "Zuka Commands"; t.TextColor3 = Color3.fromRGB(200, 220, 255); t.TextXAlignment = Enum.TextXAlignment.Left; t.TextSize = 16; local c = Instance.new("TextButton", h); c.Size = UDim2.fromOffset(32, 32); c.Position = UDim2.new(1, -32, 0, 0); c.BackgroundTransparency = 1; c.Font = Enum.Font.Code; c.Text = "X"; c.TextColor3 = Color3.fromRGB(200, 200, 220); c.TextSize = 20; c.MouseButton1Click:Connect(function() self:Toggle() end); local s = Instance.new("ScrollingFrame", f); s.Size = UDim2.new(1, -20, 1, -42); s.Position = UDim2.fromOffset(10, 37); s.BackgroundColor3 = f.BackgroundColor3; s.BorderSizePixel = 0; s.ScrollBarThickness = 6; local l = Instance.new("UIListLayout", s); l.Padding = UDim.new(0, 5); l.SortOrder = Enum.SortOrder.LayoutOrder; for _, info in ipairs(CommandInfo) do local text = Prefix .. info.Name; if info.Aliases and #info.Aliases > 0 then text = text .. " (" .. table.concat(info.Aliases, ", ") .. ")" end; text = text .. " - " .. (info.Description or ""); local label = Instance.new("TextLabel", s); label.Size = UDim2.new(1, 0, 0, 20); label.BackgroundTransparency = 1; label.Font = Enum.Font.Code; label.Text = text; label.TextColor3 = Color3.fromRGB(220, 220, 230); label.TextSize = 14; label.TextXAlignment = Enum.TextXAlignment.Left; label.TextWrapped = true; label.AutomaticSize = Enum.AutomaticSize.Y end; local function drag(o) local d, s, p; o.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then d, s, p = true, i.Position, o.Position; i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then d = false end end) end end); o.InputChanged:Connect(function(i) if (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) and d then local delta = i.Position - s; o.Position = UDim2.new(p.X.Scale, p.X.Offset + delta.X, p.Y.Scale, p.Y.Offset + delta.Y) end end) end; drag(f) end
-- (All other modules like Godmode, ESP, iBTools, etc. remain here, unchanged)
Modules.ClickFling = { State = { IsActive = false, Connection = nil, UI = nil } }; function Modules.ClickFling:Disable() self.State.IsActive = false; if self.State.UI then self.State.UI:Destroy() end; if self.State.Connection then self.State.Connection:Disconnect() end; self.State.UI, self.State.Connection = nil, nil; DoNotif("ClickFling Disabled.", 3) end; function Modules.ClickFling:Enable() self:Disable(); self.State.IsActive = true; local u = Instance.new("ScreenGui"); u.Name = "ClickFlingUI"; NaProtectUI(u); self.State.UI = u; local b = Instance.new("TextButton", u); b.Size = UDim2.fromOffset(120, 40); b.Text = "ClickFling: ON"; b.Position = UDim2.new(0.5, -60, 0, 10); b.TextColor3 = Color3.new(1, 1, 1); b.Font = Enum.Font.GothamBold; b.BackgroundColor3 = Color3.fromRGB(40, 40, 40); Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8); b.MouseButton1Click:Connect(function() self.State.IsActive = not self.State.IsActive; b.Text = "ClickFling: " .. (self.State.IsActive and "ON" or "OFF") end); local function drag(o) local d, s, p; o.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then d, s, p = true, i.Position, o.Position; i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then d = false end end) end end); o.InputChanged:Connect(function(i) if (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) and d then local delta = i.Position - s; o.Position = UDim2.new(p.X.Scale, p.X.Offset + delta.X, p.Y.Scale, p.Y.Offset + delta.Y) end end) end; drag(b); self.State.Connection = LocalPlayer:GetMouse().Button1Down:Connect(function() if not self.State.IsActive then return end; local t = LocalPlayer:GetMouse().Target; local p = t and t.Parent and Players:GetPlayerFromCharacter(t.Parent); if not p or p == LocalPlayer then return end; local oh = workspace.FallenPartsDestroyHeight; workspace.FallenPartsDestroyHeight = math.huge; local c, h, hrp, tc, th, thrp = LocalPlayer.Character, LocalPlayer.Character.Humanoid, LocalPlayer.Character.HumanoidRootPart, p.Character, p.Character.Humanoid, p.Character.HumanoidRootPart; if not (c and h and hrp and tc and th and thrp) then return end; local op = hrp.CFrame; local v = Instance.new("BodyVelocity", hrp); v.MaxForce = Vector3.new(math.huge, math.huge, math.huge); local st = tick(); repeat hrp.CFrame = thrp.CFrame * CFrame.new(0, 2, 0); task.wait() until (tick() - st) > 0.2 or not p.Parent; v:Destroy(); hrp.CFrame = op; workspace.FallenPartsDestroyHeight = oh; DoNotif("Flinging " .. p.Name, 2) end); DoNotif("ClickFling Enabled.", 5) end
Modules.Reach = { State = { UI = nil } }; function Modules.Reach:_getTool() return (LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")) or (LocalPlayer:FindFirstChildOfClass("Backpack") and LocalPlayer.Backpack:FindFirstChildOfClass("Tool")) end; function Modules.Reach:Apply(reachType, size) if self.State.UI then self.State.UI:Destroy() end; local tool = self:_getTool(); if not tool then return DoNotif("No tool equipped.", 3) end; local parts = {}; for _, p in ipairs(tool:GetDescendants()) do if p:IsA("BasePart") then table.insert(parts, p) end end; if #parts == 0 then return DoNotif("Tool has no parts.", 3) end; local ui = Instance.new("ScreenGui"); ui.Name = "ReachPartSelector"; NaProtectUI(ui); self.State.UI = ui; local frame = Instance.new("Frame", ui); frame.Size = UDim2.fromOffset(250, 200); frame.Position = UDim2.new(0.5, -125, 0.5, -100); frame.BackgroundColor3 = Color3.fromRGB(35, 35, 45); Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8); local title = Instance.new("TextLabel", frame); title.Size = UDim2.new(1, 0, 0, 30); title.BackgroundTransparency = 1; title.Font = Enum.Font.Code; title.Text = "Select a Part"; title.TextColor3 = Color3.fromRGB(200, 220, 255); title.TextSize = 16; local scroll = Instance.new("ScrollingFrame", frame); scroll.Size = UDim2.new(1, -20, 1, -40); scroll.Position = UDim2.fromOffset(10, 35); scroll.BackgroundColor3 = frame.BackgroundColor3; scroll.BorderSizePixel = 0; scroll.ScrollBarThickness = 6; local layout = Instance.new("UIListLayout", scroll); layout.Padding = UDim.new(0, 5); for _, part in ipairs(parts) do local btn = Instance.new("TextButton", scroll); btn.Size = UDim2.new(1, 0, 0, 30); btn.BackgroundColor3 = Color3.fromRGB(50, 50, 65); btn.TextColor3 = Color3.fromRGB(220, 220, 230); btn.Font = Enum.Font.Code; btn.Text = part.Name; btn.TextSize = 14; Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4); btn.MouseButton1Click:Connect(function() if not part.Parent then ui:Destroy(); return DoNotif("Part gone.", 3) end; if not part:FindFirstChild("OGSize3") then local v = Instance.new("Vector3Value", part); v.Name = "OGSize3"; v.Value = part.Size end; if part:FindFirstChild("FunTIMES") then part.FunTIMES:Destroy() end; local sb = Instance.new("SelectionBox", part); sb.Adornee = part; sb.Name = "FunTIMES"; sb.LineThickness = 0.02; sb.Color3 = reachType == "box" and Color3.fromRGB(0,100,255) or Color3.fromRGB(255,0,0); if reachType == "box" then part.Size = Vector3.one * size else part.Size = Vector3.new(part.Size.X, part.Size.Y, size) end; part.Massless = true; ui:Destroy(); self.State.UI = nil; DoNotif("Applied reach.", 3) end) end end; function Modules.Reach:Reset() local tool = self:_getTool(); if not tool then return DoNotif("No tool to reset.", 3) end; for _, p in ipairs(tool:GetDescendants()) do if p:IsA("BasePart") then if p:FindFirstChild("OGSize3") then p.Size = p.OGSize3.Value; p.OGSize3:Destroy() end; if p:FindFirstChild("FunTIMES") then p.FUNTIMES:Destroy() end end end; DoNotif("Tool reach reset.", 3) end
Modules.IDE = { State = { UI = nil } }; function Modules.IDE:Toggle() if self.State.UI then self.State.UI:Destroy(); self.State.UI = nil; return end; local u = Instance.new("ScreenGui"); u.Name = "IDE_UI"; NaProtectUI(u); self.State.UI = u; local f = Instance.new("Frame", u); f.Size = UDim2.fromOffset(550, 400); f.Position = UDim2.new(0.5, -275, 0.5, -200); f.BackgroundColor3 = Color3.fromRGB(35, 35, 45); Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8); local h = Instance.new("Frame", f); h.Size = UDim2.new(1, 0, 0, 32); h.BackgroundColor3 = Color3.fromRGB(25, 25, 35); local t = Instance.new("TextLabel", h); t.Size = UDim2.new(1, -30, 1, 0); t.Position = UDim2.fromOffset(10, 0); t.BackgroundTransparency = 1; t.Font = Enum.Font.Code; t.Text = "Zuka IDE"; t.TextColor3 = Color3.fromRGB(200, 220, 255); t.TextXAlignment = Enum.TextXAlignment.Left; t.TextSize = 16; local c = Instance.new("TextButton", h); c.Size = UDim2.fromOffset(32, 32); c.Position = UDim2.new(1, -32, 0, 0); c.BackgroundTransparency = 1; c.Font = Enum.Font.Code; c.Text = "X"; c.TextColor3 = Color3.fromRGB(200, 200, 220); c.TextSize = 20; c.MouseButton1Click:Connect(function() self:Toggle() end); local sf = Instance.new("ScrollingFrame", f); sf.Size = UDim2.new(1, -20, 1, -82); sf.Position = UDim2.fromOffset(10, 37); sf.BackgroundColor3 = Color3.fromRGB(25, 25, 35); sf.BorderSizePixel = 0; sf.ScrollBarThickness = 8; local tb = Instance.new("TextBox", sf); tb.Size = UDim2.new(1, 0, 0, 0); tb.AutomaticSize = Enum.AutomaticSize.Y; tb.BackgroundColor3 = Color3.fromRGB(25, 25, 35); tb.MultiLine = true; tb.Font = Enum.Font.Code; tb.TextColor3 = Color3.fromRGB(220, 220, 230); tb.TextSize = 14; tb.TextXAlignment = Enum.TextXAlignment.Left; tb.TextYAlignment = Enum.TextYAlignment.Top; tb.ClearTextOnFocus = false; local eb = Instance.new("TextButton", f); eb.Size = UDim2.fromOffset(100, 30); eb.Position = UDim2.new(1, -120, 1, -40); eb.BackgroundColor3 = Color3.fromRGB(80, 160, 80); eb.Font = Enum.Font.Code; eb.Text = "Execute"; eb.TextColor3 = Color3.white; eb.TextSize = 16; Instance.new("UICorner", eb).CornerRadius = UDim.new(0, 5); local cb = Instance.new("TextButton", f); cb.Size = UDim2.fromOffset(80, 30); cb.Position = UDim2.new(1, -210, 1, -40); cb.BackgroundColor3 = Color3.fromRGB(180, 80, 80); cb.Font = Enum.Font.Code; cb.Text = "Clear"; cb.TextColor3 = Color3.white; cb.TextSize = 16; Instance.new("UICorner", cb).CornerRadius = UDim.new(0, 5); eb.MouseButton1Click:Connect(function() local code = tb.Text; if #code > 0 then local s, r = pcall(function() local f, e = loadstring(code); if typeof(f) ~= "function" then error("Syntax error: " .. tostring(e or f)) end; setfenv(f, getfenv()); f() end); if s then DoNotif("Script executed.", 3) else DoNotif("Error: " .. tostring(r), 6) end end end); cb.MouseButton1Click:Connect(function() tb.Text = "" end); local function drag(o) local d, s, p; o.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then d, s, p = true, i.Position, o.Position; i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then d = false end end) end end); o.InputChanged:Connect(function(i) if (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) and d then local delta = i.Position - s; o.Position = UDim2.new(p.X.Scale, p.X.Offset + delta.X, p.Y.Scale, p.Y.Offset + delta.Y) end end) end; drag(f) end
Modules.ESP = { State = { IsActive = false, Connection = nil, TrackedPlayers = {} } }; function Modules.ESP:Toggle() self.State.IsActive = not self.State.IsActive; if self.State.IsActive then self.State.Connection = RunService.RenderStepped:Connect(function() local currentPlayerSet = {}; for _, player in ipairs(Players:GetPlayers()) do if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") then currentPlayerSet[player] = true; if not self.State.TrackedPlayers[player] then local char = player.Character; local head = char.Head; local highlight = Instance.new("Highlight"); highlight.FillColor = Color3.fromRGB(255, 60, 60); highlight.OutlineColor = Color3.fromRGB(255, 255, 255); highlight.FillTransparency = 0.8; highlight.OutlineTransparency = 0.3; highlight.Parent = char; local billboard = Instance.new("BillboardGui"); billboard.Adornee = head; billboard.AlwaysOnTop = true; billboard.Size = UDim2.new(0, 200, 0, 50); billboard.StudsOffset = Vector3.new(0, 2.5, 0); billboard.Parent = head; local nameLabel = Instance.new("TextLabel", billboard); nameLabel.Size = UDim2.new(1, 0, 0.5, 0); nameLabel.Text = player.Name; nameLabel.BackgroundTransparency = 1; nameLabel.Font = Enum.Font.Code; nameLabel.TextSize = 18; nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255); local teamLabel = Instance.new("TextLabel", billboard); teamLabel.Size = UDim2.new(1, 0, 0.5, 0); teamLabel.Position = UDim2.new(0, 0, 0.5, 0); teamLabel.BackgroundTransparency = 1; teamLabel.Font = Enum.Font.Code; teamLabel.TextSize = 14; if player.Team then teamLabel.Text = player.Team.Name; teamLabel.TextColor3 = player.Team.TeamColor.Color else teamLabel.Text = "No Team"; teamLabel.TextColor3 = Color3.fromRGB(200, 200, 200) end; self.State.TrackedPlayers[player] = {Highlight = highlight, Billboard = billboard} end end end; for player, data in pairs(self.State.TrackedPlayers) do if not currentPlayerSet[player] then data.Highlight:Destroy(); data.Billboard:Destroy(); self.State.TrackedPlayers[player] = nil end end end) else if self.State.Connection then self.State.Connection:Disconnect(); self.State.Connection = nil end; for _, data in pairs(self.State.TrackedPlayers) do data.Highlight:Destroy(); data.Billboard:Destroy() end; self.State.TrackedPlayers = {} end; DoNotif("ESP " .. (self.State.IsActive and "Enabled" or "Disabled"), 3) end
Modules.ClickTP = { State = { IsActive = false, Connection = nil } }; function Modules.ClickTP:Toggle() self.State.IsActive = not self.State.IsActive; if self.State.IsActive then local mouse = LocalPlayer:GetMouse(); self.State.Connection = UserInputService.InputBegan:Connect(function(i,gp) if not gp and i.KeyCode == Enum.KeyCode.LeftControl then local hrp = LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart; if hrp then hrp.CFrame = mouse.Hit end end end) else if self.State.Connection then self.State.Connection:Disconnect(); self.State.Connection = nil end end; DoNotif("Click TP " .. (self.State.IsActive and "Enabled" or "Disabled"), 3) end
Modules.GrabTools = { State = { IsActive = false, Connection = nil } }; function Modules.GrabTools:Toggle() self.State.IsActive = not self.State.IsActive; if self.State.IsActive then self.State.Connection = workspace.ChildAdded:Connect(function(c) if c:IsA("Tool") then local bp = LocalPlayer:FindFirstChildOfClass("Backpack"); if bp then c:Clone().Parent = bp; DoNotif("Grabbed " .. c.Name, 2) end end end) else if self.State.Connection then self.State.Connection:Disconnect(); self.State.Connection = nil end end; DoNotif("Grab Tools " .. (self.State.IsActive and "Enabled" or "Disabled"), 3) end
Modules.WallWalk = { State = { IsActive = false, Connection = nil } }; function Modules.WallWalk:Enable() if self.State.IsActive then return end; self.State.IsActive = true; local char = LocalPlayer.Character; if not (char and char:FindFirstChild("HumanoidRootPart")) then DoNotif("Character required for WallWalk.", 3); self.State.IsActive = false; return end; local raycastParams = RaycastParams.new(); raycastParams.FilterType = Enum.RaycastFilterType.Blacklist; raycastParams.FilterDescendantsInstances = {char}; self.State.Connection = RunService.RenderStepped:Connect(function() local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if not (self.State.IsActive and hrp) then return end; local origin = hrp.Position; local result = workspace:Raycast(origin, Vector3.new(0, -5, 0), raycastParams); if result then workspace.Gravity = -result.Normal * 196.2 end end); DoNotif("WallWalk enabled.", 3) end; function Modules.WallWalk:Disable() if not self.State.IsActive then return end; self.State.IsActive = false; if self.State.Connection then self.State.Connection:Disconnect(); self.State.Connection = nil end; workspace.Gravity = Vector3.new(0, -196.2, 0); DoNotif("WallWalk disabled.", 3) end; function Modules.WallWalk:Toggle() if self.State.IsActive then self:Disable() else self:Enable() end end
Modules.AntiKick = { State = { IsHooked = false, Originals = { kicks = {} } } }; function Modules.AntiKick:Enable() if self.State.IsHooked then return end; local getRawMetatable = (debug and debug.getmetatable) or getrawmetatable; local setReadOnly = setreadonly or (make_writeable and function(t, ro) if ro then make_readonly(t) else make_writeable(t) end end); if not (getRawMetatable and setReadOnly and newcclosure and hookfunction and getnamecallmethod) then return DoNotif("Your environment does not support the required functions for AntiKick.", 5) end; local meta = getRawMetatable(game); if not meta then return DoNotif("Could not get game metatable.", 3) end; if not LocalPlayer then return DoNotif("LocalPlayer not found.", 3) end; self.State.Originals.namecall = meta.__namecall; self.State.Originals.index = meta.__index; self.State.Originals.newindex = meta.__newindex; for _, kickFunc in ipairs({ LocalPlayer.Kick, LocalPlayer.kick }) do if type(kickFunc) == "function" then local originalKick; originalKick = hookfunction(kickFunc, newcclosure(function(self, ...) if self == LocalPlayer then DoNotif("Kick blocked (direct hook).", 2); return end; return originalKick(self, ...) end)); self.State.Originals.kicks[kickFunc] = originalKick end end; setReadOnly(meta, false); meta.__namecall = newcclosure(function(self, ...) local method = getnamecallmethod(); if self == LocalPlayer and method and method:lower() == "kick" then DoNotif("Kick blocked (__namecall).", 2); return end; return self.State.Originals.namecall(self, ...) end); meta.__index = newcclosure(function(self, key) if self == LocalPlayer then local k = tostring(key):lower(); if k:find("kick") or k:find("destroy") then DoNotif("Blocked access to: " .. tostring(key), 2); return function() end end end; return self.State.Originals.index(self, key) end); meta.__newindex = newcclosure(function(self, key, value) if self == LocalPlayer then local k = tostring(key):lower(); if k:find("kick") or k:find("destroy") then DoNotif("Blocked overwrite of: " .. tostring(key), 2); return end end; return self.State.Originals.newindex(self, key, value) end); setReadOnly(meta, true); self.State.IsHooked = true; DoNotif("Anti-Kick enabled.", 3) end; function Modules.AntiKick:Disable() if not self.State.IsHooked then return end; local getRawMetatable = (debug and debug.getmetatable) or getrawmetatable; local setReadOnly = setreadonly or (make_writeable and function(t, ro) if ro then make_readonly(t) else make_writeable(t) end end); if unhookfunction then for func, orig in pairs(self.State.Originals.kicks) do unhookfunction(func) end end; local meta = getRawMetatable and getRawMetatable(game); if meta and setReadOnly then setReadOnly(meta, false); meta.__namecall = self.State.Originals.namecall; meta.__index = self.State.Originals.index; meta.__newindex = self.State.Originals.newindex; setReadOnly(meta, true) end; self.State.IsHooked = false; self.State.Originals = { kicks = {} }; DoNotif("Anti-Kick disabled.", 3) end; function Modules.AntiKick:Toggle() if self.State.IsHooked then self:Disable() else self:Enable() end end
Modules.Decompiler = {State = {IsInitialized = false}}; function Modules.Decompiler:Initialize() if self.State.IsInitialized then return DoNotif("Decompiler is already initialized.", 3) end; if not getscriptbytecode then return DoNotif("Decompiler Error: 'getscriptbytecode' is not available in your environment.", 5) end; local httpRequest = (syn and syn.request) or http_request; if not httpRequest then return DoNotif("Decompiler Error: A compatible HTTP POST function (e.g., syn.request) is required.", 5) end; task.spawn(function() local API_URL = "http://api.plusgiant5.com"; local last_call_time = 0; local function callAPI(endpoint, scriptInstance) local success, bytecode = pcall(getscriptbytecode, scriptInstance); if not success then DoNotif("Failed to get bytecode: " .. tostring(bytecode), 4); return end; local time_elapsed = os.clock() - last_call_time; if time_elapsed < 0.5 then task.wait(0.5 - time_elapsed) end; local success, httpResult = pcall(httpRequest, {Url = API_URL .. endpoint, Body = bytecode, Method = "POST", Headers = { ["Content-Type"] = "text/plain" }}); last_call_time = os.clock(); if not success then DoNotif("HTTP request failed: " .. tostring(httpResult), 5); return end; if httpResult.StatusCode == 200 then return httpResult.Body else DoNotif("API Error " .. httpResult.StatusCode .. ": " .. httpResult.StatusMessage, 4); return end end; local function decompile_func(scriptInstance) if not (scriptInstance and (scriptInstance:IsA("LocalScript") or scriptInstance:IsA("ModuleScript"))) then warn("Decompile target must be a LocalScript or ModuleScript instance."); return nil end; return callAPI("/konstant/decompile", scriptInstance) end; local function disassemble_func(scriptInstance) if not (scriptInstance and (scriptInstance:IsA("LocalScript") or scriptInstance:IsA("ModuleScript"))) then warn("Disassemble target must be a LocalScript or ModuleScript instance."); return nil end; return callAPI("/konstant/disassemble", scriptInstance) end; local env = getfenv(); env.decompile = decompile_func; env.disassemble = disassemble_func; self.State.IsInitialized = true; DoNotif("Decompiler initialized.", 4); DoNotif("Use 'decompile(script_instance)' in the IDE or your executor.", 6) end) end
Modules.Godmode = { State = { IsEnabled = false, Method = nil, UI = nil, Connection = nil, LastHealth = 100 } }; function Modules.Godmode:_CleanupUI() if self.State.UI then self.State.UI:Destroy(); self.State.UI = nil end end; function Modules.Godmode:Disable() if not self.State.IsEnabled then return end; self:_CleanupUI(); local char = LocalPlayer.Character; if self.State.Method == "ForceField" and char then local ff = char:FindFirstChild("ZukaGodmodeFF"); if ff then ff:Destroy() end elseif self.State.Method == "HealthLock" and self.State.Connection then self.State.Connection:Disconnect(); self.State.Connection = nil end; self.State.IsEnabled = false; self.State.Method = nil; DoNotif("Godmode OFF", 2) end; function Modules.Godmode:EnableForceField() self:Disable(); local char = LocalPlayer.Character; if not char then return DoNotif("Character not found.", 3) end; local ff = Instance.new("ForceField", char); ff.Name = "ZukaGodmodeFF"; self.State.IsEnabled = true; self.State.Method = "ForceField"; DoNotif("Godmode ON (ForceField)", 2) end; function Modules.Godmode:EnableHealthLock() self:Disable(); local char = LocalPlayer.Character; local humanoid = char and char:FindFirstChildOfClass("Humanoid"); if not humanoid then return DoNotif("Humanoid not found.", 3) end; self.State.LastHealth = humanoid.Health; self.State.Connection = humanoid.HealthChanged:Connect(function(newHealth) if newHealth < self.State.LastHealth and newHealth > 0 then humanoid.Health = self.State.LastHealth else self.State.LastHealth = newHealth end end); self.State.IsEnabled = true; self.State.Method = "HealthLock"; DoNotif("Godmode ON (Health Lock)", 2) end; function Modules.Godmode:ShowMenu() self:_CleanupUI(); local gui = Instance.new("ScreenGui"); gui.Name = "GodmodeUI"; NaProtectUI(gui); self.State.UI = gui; local frame = Instance.new("Frame", gui); frame.Size = UDim2.fromOffset(250, 210); frame.Position = UDim2.new(0.5, -125, 0.5, -105); frame.BackgroundColor3 = Color3.fromRGB(35, 35, 45); Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8); local title = Instance.new("TextLabel", frame); title.Size = UDim2.new(1, 0, 0, 30); title.BackgroundTransparency = 1; title.Font = Enum.Font.Code; title.Text = "Godmode Methods"; title.TextColor3 = Color3.fromRGB(200, 220, 255); title.TextSize = 16; local buttonContainer = Instance.new("Frame", frame); buttonContainer.Size = UDim2.new(1, -20, 1, -40); buttonContainer.Position = UDim2.fromOffset(10, 35); buttonContainer.BackgroundTransparency = 1; local list = Instance.new("UIListLayout", buttonContainer); list.Padding = UDim.new(0, 5); list.SortOrder = Enum.SortOrder.LayoutOrder; local function makeButton(text, callback) local btn = Instance.new("TextButton", buttonContainer); btn.Size = UDim2.new(1, 0, 0, 35); btn.BackgroundColor3 = Color3.fromRGB(50, 50, 65); btn.TextColor3 = Color3.fromRGB(220, 220, 230); btn.Font = Enum.Font.Code; btn.Text = text; btn.TextSize = 14; Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4); btn.MouseButton1Click:Connect(callback); return btn end; makeButton("Enable: ForceField (Visual)", function() self:_CleanupUI(); self:EnableForceField() end); makeButton("Enable: Health Lock (Silent)", function() self:_CleanupUI(); self:EnableHealthLock() end); if self.State.IsEnabled then makeButton("Disable Godmode", function() self:_CleanupUI(); self:Disable() end) end; makeButton("Close", function() self:_CleanupUI() end).BackgroundColor3 = Color3.fromRGB(180, 80, 80) end; function Modules.Godmode:HandleCommand(args) local choice = args[1] and args[1]:lower() or nil; if choice == "strong" or choice == "forcefield" or choice == "ff" then return self:EnableForceField() end; if choice == "hook" or choice == "hooking" or choice == "healthlock" or choice == "lock" then return self:EnableHealthLock() end; if choice == "off" or choice == "disable" then return self:Disable() end; self:ShowMenu() end
Modules.iBTools = { State = { IsActive = false, Tool = nil, UI = nil, Highlight = nil, Connections = {}, History = {}, SaveHistory = {}, CurrentPart = nil, CurrentMode = "delete" } }; function Modules.iBTools:_CleanupUI() if self.State.UI then self.State.UI:Destroy() end; if self.State.Highlight then self.State.Highlight:Destroy() end; for _, conn in ipairs(self.State.Connections) do conn:Disconnect() end; self.State.UI, self.State.Highlight = nil, nil; table.clear(self.State.Connections) end; function Modules.iBTools:Disable() if not self.State.IsActive then return end; self:_CleanupUI(); if self.State.Tool then self.State.Tool:Destroy() end; self.State = { IsActive = false, Tool = nil, UI = nil, Highlight = nil, Connections = {}, History = {}, SaveHistory = {}, CurrentPart = nil, CurrentMode = "delete" }; DoNotif("iBTools unloaded.", 3) end; function Modules.iBTools:Enable() if self.State.IsActive then return DoNotif("iBTools is already active.", 3) end; local backpack = LocalPlayer:FindFirstChildOfClass("Backpack"); if not backpack then return DoNotif("Backpack not found.", 3) end; self.State.IsActive = true; self.State.Tool = Instance.new("Tool", backpack); self.State.Tool.Name = "iBTools"; self.State.Tool.RequiresHandle = false; self.State.Tool.Equipped:Connect(function(mouse) local state = self.State; state.Highlight = Instance.new("SelectionBox"); state.Highlight.Name = "iBToolsSelection"; state.Highlight.LineThickness = 0.04; state.Highlight.Color3 = Color3.fromRGB(0, 170, 255); state.Highlight.Parent = workspace.CurrentCamera; local function formatVectorString(vec) return string.format("Vector3.new(%s,%s,%s)", tostring(vec.X), tostring(vec.Y), tostring(vec.Z)) end; local function updateStatus(part) if not state.UI then return end; local statusLabel = state.UI:FindFirstChild("Panel", true) and state.UI.Panel:FindFirstChild("Status"); if not statusLabel then return end; local targetText = "none"; if part then targetText = part:GetFullName() end; statusLabel.Text = string.format("Mode: %s | Target: %s", state.CurrentMode:upper(), targetText) end; local function setTarget(part) if part and not part:IsA("BasePart") then part = nil end; state.CurrentPart = part; if state.Highlight then state.Highlight.Adornee = part end; updateStatus(part) end; local modeHandlers = { delete = function(part) table.insert(state.History, {part = part, parent = part.Parent, cframe = part.CFrame}); table.insert(state.SaveHistory, {name = part.Name, position = part.Position}); part.Parent = nil; setTarget(nil); DoNotif("Deleted '"..part.Name.."'", 2) end, anchor = function(part) part.Anchored = not part.Anchored; updateStatus(part); DoNotif(string.format("%s anchored %s", part.Name, part.Anchored and "enabled" or "disabled"), 2) end, collide = function(part) part.CanCollide = not part.CanCollide; updateStatus(part); DoNotif(string.format("%s CanCollide %s", part.Name, part.CanCollide and "enabled" or "disabled"), 2) end }; local uiActions = { setMode = function(mode) state.CurrentMode = mode; updateStatus(state.CurrentPart) end, undo = function() local r = table.remove(state.History); if r then r.part.Parent = r.parent; pcall(function() r.part.CFrame = r.cframe end); setTarget(r.part); DoNotif("Restored '"..r.part.Name.."'", 2) else DoNotif("Nothing to undo.", 2) end end, copy = function() if #state.SaveHistory == 0 then return DoNotif("No deleted parts to export.", 3) end; local l = {}; for _, d in ipairs(state.SaveHistory) do table.insert(l, string.format("for _,v in ipairs(workspace:FindPartsInRegion3(Region3.new(%s, %s), nil, math.huge)) do if v.Name == %q then v:Destroy() end end", formatVectorString(d.position), formatVectorString(d.position), d.name)) end; setclipboard(table.concat(l, "\n")); DoNotif("Copied delete script to clipboard.", 3) end }; local gui = Instance.new("ScreenGui"); gui.Name = "iBToolsUI"; NaProtectUI(gui); self.State.UI = gui; local f = Instance.new("Frame", gui); f.Name = "Panel"; f.Size = UDim2.new(0, 240, 0, 260); f.Position = UDim2.new(0.05, 0, 0.4, 0); f.BackgroundColor3 = Color3.fromRGB(26, 26, 26); Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8); local h = Instance.new("Frame", f); h.Name = "Header"; h.Size = UDim2.new(1, 0, 0, 36); h.BackgroundColor3 = Color3.fromRGB(38, 38, 38); h.Active = true; local t = Instance.new("TextLabel", h); t.BackgroundTransparency=1;t.Font=Enum.Font.GothamSemibold;t.Text="iB Tools";t.Size=UDim2.new(1,-40,1,0);t.Position=UDim2.new(0,12,0,0);t.TextColor3=Color3.new(1,1,1);t.TextXAlignment=Enum.TextXAlignment.Left;local s=Instance.new("TextLabel",f);s.Name="Status";s.BackgroundTransparency=1;s.Size=UDim2.new(1,-24,0,20);s.Position=UDim2.new(0,12,0,40);s.Font=Enum.Font.Code;s.TextColor3=Color3.fromRGB(200,200,200);s.TextXAlignment=Enum.TextXAlignment.Left;s.Text="Mode: DELETE | Target: none";local bH=Instance.new("Frame",f);bH.BackgroundTransparency=1;bH.Size=UDim2.new(1,-24,1,-72);bH.Position=UDim2.new(0,12,0,68);local l=Instance.new("UIListLayout",bH);l.Padding=UDim.new(0,6);local mB={};local function btn(txt)local b=Instance.new("TextButton",bH);b.Name=txt;b.Size=UDim2.new(1,0,0,32);b.Font=Enum.Font.GothamSemibold;b.Text=txt;b.TextColor3=Color3.new(1,1,1);b.TextSize=14;local c=Instance.new("UICorner",b);c.CornerRadius=UDim.new(0,5);return b end;local function rMB()for m,b in pairs(mB)do b.BackgroundColor3=(state.CurrentMode==m and Color3.fromRGB(80,110,255)or Color3.fromRGB(52,52,52))end end;for m,lbl in pairs({delete="Delete",anchor="Toggle Anchor",collide="Toggle CanCollide"})do local b=btn(lbl);mB[m]=b;b.MouseButton1Click:Connect(function()uiActions.setMode(m);rMB()end)end;btn("Undo Last Delete").MouseButton1Click:Connect(uiActions.undo);btn("Copy Delete Script").MouseButton1Click:Connect(uiActions.copy);local function drag(o,h) local d,s,p; h.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then d,s,p=true,i.Position,o.Position;i.Changed:Connect(function()if i.UserInputState==Enum.UserInputState.End then d=false end end)end end); h.InputChanged:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseMovement and d then o.Position=UDim2.new(p.X.Scale,p.X.Offset+i.Position.X-s.X,p.Y.Scale,p.Y.Offset+i.Position.Y-s.Y)end end)end;drag(f,h);rMB(); table.insert(state.Connections, mouse.Move:Connect(function() setTarget(mouse.Target) end)); table.insert(state.Connections, mouse.Button1Down:Connect(function() if state.CurrentPart then modeHandlers[state.CurrentMode](state.CurrentPart) end end)) end); self.State.Tool.Unequipped:Connect(function() self:_CleanupUI() end); self.State.Tool.AncestryChanged:Connect(function(_, parent) if not parent then self:Disable() end end); DoNotif("iBTools loaded. Equip the tool to use it.", 3) end; function Modules.iBTools:Toggle() if self.State.IsActive then self:Disable() else self:Enable() end end

-- ==========================================================
-- Command Definitions (Now using RegisterCommand)
-- ==========================================================
-- System & UI Commands
RegisterCommand({Name = "cmds", Aliases = {"help"}, Description = "Shows this command list."}, function() Modules.CommandsUI:Toggle() end)
RegisterCommand({Name = "cmdbar", Aliases = {"cbar"}, Description = "Toggles the private command bar."}, function() Modules.CommandBar:Toggle() end)
RegisterCommand({Name = "ide", Aliases = {}, Description = "Opens a script execution window."}, function() Modules.IDE:Toggle() end)
RegisterCommand({Name = "decompile", Aliases = {"decomp", "disassemble"}, Description = "Initializes the Konstant decompiler functions."}, function() Modules.Decompiler:Initialize() end)

-- Player Modification Commands
RegisterCommand({Name = "fly", Aliases = {}, Description = "Toggles smooth flight mode."}, function() Modules.Fly:Toggle() end)
RegisterCommand({Name = "flyspeed", Aliases = {}, Description = "Sets fly speed. ;flyspeed [num]"}, function(args) Modules.Fly:SetSpeed(args[1]) end)
RegisterCommand({Name = "speed", Aliases = {}, Description = "Sets walkspeed. ;speed [num]"}, function(args) local s=tonumber(args[1]); local h=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid"); if not h then DoNotif("Humanoid not found!", 3) return end; if s and s > 0 then h.WalkSpeed = s; DoNotif("WalkSpeed set to: " .. s, 3) else DoNotif("Invalid speed.", 3) end end)
RegisterCommand({Name = "noclip", Aliases = {}, Description = "Toggles walking through walls."}, function() Modules.Noclip:Toggle() end)
RegisterCommand({Name = "wallwalk", Aliases = {"ww"}, Description = "Toggles walking on walls."}, function() Modules.WallWalk:Toggle() end)
RegisterCommand({Name = "godmode", Aliases = {"god"}, Description = "Toggles invincibility. Use ;god [method|off] or ;god for a menu."}, function(args) Modules.Godmode:HandleCommand(args) end)
RegisterCommand({Name = "ungodmode", Aliases = {"ungod"}, Description = "Disables invincibility."}, function() Modules.Godmode:Disable() end)
RegisterCommand({Name = "goto", Aliases = {}, Description = "Teleports to a player. ;goto [player]"}, function(args) local name=tostring(args[1]):lower(); if not name then return DoNotif("Specify a player.", 3) end; for _, plr in ipairs(Players:GetPlayers()) do if plr.Name:lower():sub(1, #name) == name then local hrp=LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart; local thrp=plr.Character and plr.Character.HumanoidRootPart; if hrp and thrp then hrp.CFrame=thrp.CFrame + Vector3.new(0,3,0); DoNotif("Teleported to "..plr.Name, 3) else DoNotif("Target has no character.",3) end; return end end; DoNotif("Player not found.", 3) end)
RegisterCommand({Name = "reverse", Aliases = {}, Description = "Reverses your character direction."}, function() local hrp = LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart; if hrp then hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.pi, 0) end end)

-- Combat & Interaction Commands
RegisterCommand({Name = "reach", Aliases = {"swordreach"}, Description = "Extends sword reach. ;reach [num]"}, function(args) Modules.Reach:Apply("directional", tonumber(args[1]) or 15) end)
RegisterCommand({Name = "boxreach", Aliases = {}, Description = "Creates a box hitbox. ;boxreach [num]"}, function(args) Modules.Reach:Apply("box", tonumber(args[1]) or 15) end)
RegisterCommand({Name = "resetreach", Aliases = {"unreach"}, Description = "Resets tool reach to normal."}, function() Modules.Reach:Reset() end)
RegisterCommand({Name = "clickfling", Aliases = {}, Description = "Enables click to fling players."}, function() Modules.ClickFling:Enable() end)
RegisterCommand({Name = "unclickfling", Aliases = {}, Description = "Disables click to fling."}, function() Modules.ClickFling:Disable() end)
RegisterCommand({Name = "clicktp", Aliases = {}, Description = "Hold Left CTRL to teleport to cursor."}, function() Modules.ClickTP:Toggle() end)

-- Utility Commands
RegisterCommand({Name = "esp", Aliases = {}, Description = "Toggles player outline, name, and team."}, function() Modules.ESP:Toggle() end)
RegisterCommand({Name = "antikick", Aliases = {"ak"}, Description = "Hooks metamethods to prevent being kicked."}, function() Modules.AntiKick:Toggle() end)
RegisterCommand({Name = "grabtools", Aliases = {}, Description = "Auto-grabs tools that appear."}, function() Modules.GrabTools:Toggle() end)
RegisterCommand({Name = "ibtools", Aliases = {}, Description = "Loads a building helper tool for deleting/modifying parts."}, function() Modules.iBTools:Toggle() end)

-- Loadstring / External Script Commands
local function loadstringCmd(url, notif) pcall(function() loadstring(game:HttpGet(url))() end); DoNotif(notif, 3) end
RegisterCommand({Name = "zuka", Aliases = {}, Description = "Loads Zuka's personal executor/admin panel."}, function() loadstringCmd("https://raw.githubusercontent.com/scriptlisenbe-stack/luaprojectse3/refs/heads/main/ZukasFunBoxOpenSource.lua", "Loading Zuka's Gui...") end)
RegisterCommand({Name = "dex", Aliases = {}, Description = "Opens the Dark Dex explorer for developers."}, function() loadstringCmd("https://raw.githubusercontent.com/scriptlisenbe-stack/luaprojectse3/refs/heads/main/CustomDex.lua", "Loading Dex++") end)
RegisterCommand({Name = "scripthub", Aliases = {"hub"}, Description = "Opens a versatile script hub GUI."}, function() loadstringCmd("https://raw.githubusercontent.com/ltseverydayyou/Nameless-Admin/main/ScriptHubNA.lua", "Loading Script Hub...") end)
RegisterCommand({Name = "teleportgui", Aliases = {"tpui", "uviewer"}, Description = "Opens a GUI to teleport to other game places."}, function() loadstringCmd("https://raw.githubusercontent.com/ltseverydayyou/uuuuuuu/main/Universe%20Viewer", "Loading Teleport GUI...") end)
RegisterCommand({Name = "aimbot", Aliases = {}, Description = "Loads an aimbot script."}, function() loadstringCmd("https://raw.githubusercontent.com/ItsIYce/Iyce/refs/heads/main/main.lua", "Loading Aimbot...") end)
RegisterCommand({Name = "scriptsearcher", Aliases = {"ssearch"}, Description = "Opens a GUI to search for in-game scripts."}, function() loadstringCmd("https://raw.githubusercontent.com/bloxtech1/luaprojects2/refs/heads/main/scriptsearcher.lua", "Loading Script Searcher...") end)
RegisterCommand({Name = "flyr15", Aliases = {}, Description = "Loads a specific R15 flight script."}, function() loadstringCmd("https://raw.githubusercontent.com/396abc/Script/refs/heads/main/FlyR15.lua", "Loading R15 Fly...") end)
RegisterCommand({Name = "flingaddon", Aliases = {"flingui"}, Description = "Loads a GUI addon for flinging players."}, function() loadstringCmd("https://raw.githubusercontent.com/bloxtech1/luaprojects2/refs/heads/main/flingaddon.lua", "Loading Fling Addon...") end)
RegisterCommand({Name = "s0ulzv4", Aliases = {"s0ulz"}, Description = "Loads the s0ulzV4 script hub."}, function() loadstringCmd("https://raw.githubusercontent.com/scriptlisenbe-stack/luaprojectse3/refs/heads/main/s0ulzV4.lua", "Loading s0ulzV4...") end)

-- Aura Command Integration (Adapted)
local auraConn, auraViz
RegisterCommand({Name = "aura", Aliases = {}, Description = "Continuously damages nearby players. ;aura [distance]"}, function(args)
	local dist=tonumber(args[1]) or 20
	if not firetouchinterest then return DoNotif("firetouchinterest unsupported",2) end
	if auraConn then auraConn:Disconnect() end; if auraViz then auraViz:Destroy() end
	auraViz=Instance.new("Part", workspace); auraViz.Shape=Enum.PartType.Ball; auraViz.Size=Vector3.new(dist*2,dist*2,dist*2)
	auraViz.Transparency=0.8; auraViz.Color=Color3.fromRGB(255,0,0); auraViz.Material=Enum.Material.Neon
	auraViz.Anchored=true; auraViz.CanCollide=false
	local function getHandle() local c=LocalPlayer.Character; if not c then return end; local t=c:FindFirstChildWhichIsA("Tool"); if not t then return end; return t:FindFirstChild("Handle") or t:FindFirstChildWhichIsA("BasePart") end
	auraConn=RunService.RenderStepped:Connect(function()
		local handle, root = getHandle(), LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart
		if not handle or not root then return end
		auraViz.CFrame=root.CFrame
		for _,plr in ipairs(Players:GetPlayers()) do
			if plr~=LocalPlayer and plr.Character then
				local hum=plr.Character:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health>0 then
					for _,part in ipairs(plr.Character:GetChildren()) do
						if part:IsA("BasePart") and (part.Position-handle.Position).Magnitude<=dist then
							firetouchinterest(handle,part,0); task.wait(); firetouchinterest(handle,part,1); break
						end
					end
				end
			end
		end
	end)
	DoNotif("Aura enabled at "..dist,1.2)
end)
RegisterCommand({Name = "unaura", Aliases = {}, Description = "Stops aura loop and removes visualizer."}, function()
	if auraConn then auraConn:Disconnect(); auraConn=nil end
	if auraViz then auraViz:Destroy(); auraViz=nil end
	DoNotif("Aura disabled",1.2)
end)

-- ==========================================================
-- Centralized Command Processor
-- ==========================================================
function processCommand(message)
    if not message:sub(1, #Prefix) == Prefix then return end
    local args = {}; for word in message:sub(#Prefix + 1):gmatch("%S+") do table.insert(args, word) end
    if #args == 0 then return end
    local cmdName = table.remove(args, 1):lower()
    local cmdFunc = Commands[cmdName]
    if cmdFunc then pcall(cmdFunc, args) else DoNotif("Unknown command: " .. cmdName, 3) end
end

-- ==========================================================
-- Input Handlers
-- ==========================================================
LocalPlayer.Chatted:Connect(processCommand)
Modules.CommandBar:Toggle() -- Start with the command bar open by default
DoNotif("Zuka Command Handler v18 (AutoComplete) | Prefix: '" .. Prefix .. "' | ;cmds for help", 6)
