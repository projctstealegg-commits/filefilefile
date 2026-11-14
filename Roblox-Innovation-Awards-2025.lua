--[[
    VIP DELS HUB | REAL ROBLOX-IMGUI + DYNAMIC ISLAND
    ImGui API follows the user's supplied depthso/Roblox-ImGUI example.

    Features:
      - Movement: WalkSpeed 16-200
      - Star Scanner: detects and highlights StarFragments
      - Auto Teleport to Star: locally moves the character to each detected
        fragment with a small landing offset; stops when disabled.
      - Dynamic Island: preserved launcher to hide/show the ImGui window.

    Install only in an experience you own or are authorized to test.
    This script does not fire the game's Trigger RemoteEvent or auto-claim
    fragments. The server must validate collection/pickup.
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

local generationKey = "_vipDelsStarImGuiGeneration"
local env = (type(getgenv) == "function" and getgenv()) or _G
env[generationKey] = (tonumber(env[generationKey]) or 0) + 1
local generation = env[generationKey]
local function alive()
    return env[generationKey] == generation
end

-- Remove previous launcher only; this script will recreate it below.
local oldToggle = PlayerGui:FindFirstChild("VIPDelsHubToggle")
if oldToggle then oldToggle:Destroy() end

-- Load the same ImGui library used in the supplied example.
local ImGui
do
    local sourceURL = "https://raw.githubusercontent.com/projctstealegg-commits/Roblox-ImGUI/refs/heads/main/ImGui.lua"
    local okHttp, source = pcall(function()
        return game:HttpGet(sourceURL)
    end)
    assert(okHttp and type(source) == "string" and #source > 1000,
        "VIP DELS HUB: unable to download Roblox-ImGUI: " .. tostring(source))
    assert(type(loadstring) == "function",
        "VIP DELS HUB: loadstring is unavailable in this runtime.")

    local okCompile, chunk = pcall(loadstring, source)
    assert(okCompile and type(chunk) == "function",
        "VIP DELS HUB: ImGui compile failed: " .. tostring(chunk))

    local okInit, result = pcall(chunk)
    assert(okInit, "VIP DELS HUB: ImGui initialization failed: " .. tostring(result))
    ImGui = result

    if type(ImGui) ~= "table" then
        local g = (type(getgenv) == "function" and getgenv()) or _G
        ImGui = g and (g.ImGui or g.RobloxImGui)
    end
    assert(type(ImGui) == "table" and type(ImGui.CreateWindow) == "function",
        "VIP DELS HUB: ImGui.CreateWindow API missing.")
end

local DEFAULT_SPEED = 16
local selectedSpeed = DEFAULT_SPEED
local speedEnabled = false
local savedSpeed = DEFAULT_SPEED

local scannerEnabled = false
local autoTeleportEnabled = false
local teleportBusy = false
local scanCount = 0
local nearestText = "Not scanned"
local teleportStatus = "Idle"
local highlights = {}
local visited = {}
local scanRunId = 0
local teleportRunId = 0

local function getCharacter()
    return LP.Character
end

local function getRoot()
    local character = getCharacter()
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local character = getCharacter()
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function getFragmentFolder()
    local minigame = workspace:FindFirstChild("StarFragmentsMinigame")
    return minigame and minigame:FindFirstChild("StarFragments")
end

local function getTargetPosition(target)
    if target:IsA("BasePart") then
        return target.Position
    elseif target:IsA("Model") then
        return target:GetPivot().Position
    end
    local part = target:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

local function getTargets()
    local folder = getFragmentFolder()
    local targets = {}
    if not folder then return targets end

    -- Use direct children as the collectible entries. This avoids counting
    -- every nested BasePart inside a Model as a separate star.
    for _, item in ipairs(folder:GetChildren()) do
        if item:IsA("BasePart") or item:IsA("Model") then
            local pos = getTargetPosition(item)
            if pos then
                table.insert(targets, {instance = item, position = pos})
            end
        end
    end
    return targets
end

local function clearHighlights()
    for instance, highlight in pairs(highlights) do
        if highlight then pcall(function() highlight:Destroy() end) end
        highlights[instance] = nil
    end
end

local function scanStars()
    local targets = getTargets()
    local root = getRoot()
    local seen = {}
    local nearest, nearestDistance

    for _, entry in ipairs(targets) do
        local target = entry.instance
        seen[target] = true

        if not highlights[target] then
            local h = Instance.new("Highlight")
            h.Name = "VIPDelsStarHighlight"
            h.Adornee = target
            h.FillColor = Color3.fromRGB(255, 205, 65)
            h.OutlineColor = Color3.fromRGB(255, 245, 190)
            h.FillTransparency = 0.55
            h.OutlineTransparency = 0
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Parent = target
            highlights[target] = h
        end

        if root then
            local distance = (root.Position - entry.position).Magnitude
            if not nearestDistance or distance < nearestDistance then
                nearestDistance = distance
                nearest = target
            end
        end
    end

    for target, highlight in pairs(highlights) do
        if not seen[target] or not target:IsDescendantOf(workspace) then
            if highlight then highlight:Destroy() end
            highlights[target] = nil
            visited[target] = nil
        end
    end

    scanCount = #targets
    if nearest and nearestDistance then
        nearestText = string.format("%s • %.1f studs", nearest.Name, nearestDistance)
    elseif #targets == 0 then
        nearestText = "No stars found / folder missing"
    else
        nearestText = "Character not ready"
    end
    return targets
end

local function teleportToTarget(target)
    local character = getCharacter()
    local root = getRoot()
    if not character or not root or not target or not target.Parent then
        return false, "Character or star unavailable"
    end

    local position = getTargetPosition(target)
    if not position then return false, "Star has no world position" end

    -- Land slightly above the target to avoid clipping into its geometry.
    local destination = CFrame.new(position + Vector3.new(0, 3, 0))
    local ok, err = pcall(function()
        character:PivotTo(destination)
    end)
    if not ok then return false, tostring(err) end
    return true
end

local function teleportToNearest()
    local targets = scanStars()
    local root = getRoot()
    if not root then
        teleportStatus = "Character not ready"
        return
    end

    local best, bestDistance
    for _, entry in ipairs(targets) do
        local distance = (root.Position - entry.position).Magnitude
        if not bestDistance or distance < bestDistance then
            best, bestDistance = entry.instance, distance
        end
    end

    if not best then
        teleportStatus = "No star target found"
        return
    end

    local ok, reason = teleportToTarget(best)
    teleportStatus = ok and ("Teleported to " .. best.Name) or ("Failed: " .. tostring(reason))
end

local function startAutoTeleport()
    autoTeleportEnabled = true
    teleportRunId += 1
    local myRun = teleportRunId

    task.spawn(function()
        while alive() and autoTeleportEnabled and teleportRunId == myRun do
            local targets = scanStars()
            local root = getRoot()

            if not root then
                teleportStatus = "Waiting for character"
                task.wait(1)
            else
                local nextTarget, nextDistance
                for _, entry in ipairs(targets) do
                    if not visited[entry.instance] then
                        local distance = (root.Position - entry.position).Magnitude
                        if not nextDistance or distance < nextDistance then
                            nextTarget = entry.instance
                            nextDistance = distance
                        end
                    end
                end

                if not nextTarget then
                    teleportStatus = (#targets == 0)
                        and "No stars detected"
                        or "All current stars visited; scanning for new ones"
                    task.wait(1.5)
                else
                    teleportBusy = true
                    local ok, reason = teleportToTarget(nextTarget)
                    if ok then
                        visited[nextTarget] = true
                        teleportStatus = "TP → " .. nextTarget.Name
                    else
                        teleportStatus = "TP failed: " .. tostring(reason)
                    end
                    teleportBusy = false
                    task.wait(0.8)
                end
            end
        end
        teleportBusy = false
    end)
end

local function stopAutoTeleport()
    autoTeleportEnabled = false
    teleportRunId += 1
    teleportBusy = false
    teleportStatus = "Auto teleport stopped"
end

-- Main ImGui window.
local Window = ImGui:CreateWindow({
    Title = "VIP DELS HUB  •  MOVEMENT + STAR TELEPORT",
    Size = UDim2.fromOffset(680, 500),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Border = true,
    BorderThickness = 2,
    BackgroundTransparency = 0.16,
    CornerRadius = UDim.new(0, 8),
    NoCollapse = false,
    NoResize = false,
    NoDrag = false,
})
pcall(function() Window:Center() end)

local MovementTab = Window:CreateTab({Name = "Movement"})
local MovementHeader = MovementTab:CollapsingHeader({
    Title = "WALK SPEED CONTROL",
    Open = true,
})
MovementHeader:Label({
    Text = "WalkSpeed adjustment • server validation may override client-side changes.",
})
MovementHeader:Slider({
    Label = "WalkSpeed",
    Format = "%s",
    Value = selectedSpeed,
    MinValue = 16,
    MaxValue = 200,
    ReadOnly = false,
    Callback = function(firstArg, secondArg)
        local value = tonumber(secondArg)
        if value == nil then value = tonumber(firstArg) end
        if not value then return end
        selectedSpeed = math.clamp(math.floor(value + 0.5), 16, 200)
        if speedEnabled then
            local humanoid = getHumanoid()
            if humanoid then humanoid.WalkSpeed = selectedSpeed end
        end
    end,
})
MovementHeader:Checkbox({
    Label = "Enable Speed",
    Value = false,
    Callback = function(_, value)
        speedEnabled = value == true
        local humanoid = getHumanoid()
        if not humanoid then return end
        if speedEnabled then
            savedSpeed = humanoid.WalkSpeed
            humanoid.WalkSpeed = selectedSpeed
        else
            humanoid.WalkSpeed = savedSpeed or DEFAULT_SPEED
        end
    end,
})
MovementHeader:Button({
    Text = "RESET WALK SPEED (16)",
    Callback = function()
        selectedSpeed = DEFAULT_SPEED
        local humanoid = getHumanoid()
        if humanoid then
            humanoid.WalkSpeed = speedEnabled and DEFAULT_SPEED or (savedSpeed or DEFAULT_SPEED)
        end
    end,
})

local StarTab = Window:CreateTab({Name = "Star Teleport"})
local StarHeader = StarTab:CollapsingHeader({
    Title = "STAR FRAGMENTS • AUTO DETECT / TELEPORT",
    Open = true,
})
StarHeader:Label({
    Text = "Target path: workspace.StarFragmentsMinigame.StarFragments (direct children).",
})

local statusTable = StarHeader:Table({
    RowBackground = true,
    Border = true,
    RowsFill = false,
    Size = UDim2.new(1, 0, 0, 130),
})

local function refreshStatus()
    statusTable:ClearRows()
    local rows = {
        "SCANNER: " .. (scannerEnabled and "ON" or "OFF"),
        "AUTO TELEPORT: " .. (autoTeleportEnabled and "ON" or "OFF"),
        "STARS FOUND: " .. tostring(scanCount),
        "NEAREST: " .. tostring(nearestText),
        "TELEPORT STATUS: " .. tostring(teleportStatus),
    }
    for _, line in ipairs(rows) do
        local row = statusTable:CreateRow()
        row:CreateColumn():Label({Text = line})
    end
end

StarHeader:Button({
    Text = "SCAN ALL STARS",
    Callback = function()
        scanStars()
        refreshStatus()
    end,
})
StarHeader:Button({
    Text = "TELEPORT TO NEAREST STAR",
    Callback = function()
        teleportToNearest()
        refreshStatus()
    end,
})
StarHeader:Checkbox({
    Label = "AUTO DETECT (2 SECOND REFRESH)",
    Value = false,
    Callback = function(_, value)
        scannerEnabled = value == true
        scanRunId += 1
        local myRun = scanRunId
        if scannerEnabled then
            task.spawn(function()
                while alive() and scannerEnabled and scanRunId == myRun do
                    scanStars()
                    refreshStatus()
                    task.wait(2)
                end
            end)
        else
            refreshStatus()
        end
    end,
})
StarHeader:Checkbox({
    Label = "AUTO TELEPORT THROUGH ALL STARS",
    Value = false,
    Callback = function(_, value)
        if value == true then
            startAutoTeleport()
        else
            stopAutoTeleport()
        end
        refreshStatus()
    end,
})
StarHeader:Button({
    Text = "RESET VISITED STAR LIST",
    Callback = function()
        visited = {}
        teleportStatus = "Visited list reset"
        refreshStatus()
    end,
})
StarHeader:Button({
    Text = "CLEAR STAR HIGHLIGHTS",
    Callback = function()
        clearHighlights()
        scanCount = 0
        nearestText = "Highlights cleared"
        refreshStatus()
    end,
})
StarHeader._native:Label({
    Text = "Note: teleport moves your local character only. This does not activate StarFragmentsMinigame.Trigger or guarantee server-side pickup."
})

-- Reapply selected movement setting after respawn when enabled.
LP.CharacterAdded:Connect(function(character)
    local humanoid = character:WaitForChild("Humanoid", 10)
    if humanoid and speedEnabled then
        task.wait(0.2)
        humanoid.WalkSpeed = selectedSpeed
    end
end)

-- ================================================================
-- DYNAMIC ISLAND LAUNCHER • PRESERVED FROM YOUR SUPPLIED MENU
-- Tap to hide/show the ImGui window; drag to reposition.
-- RightShift toggles the window on desktop.
-- ================================================================
do
    local oldToggleGui = PlayerGui:FindFirstChild("VIPDelsHubToggle")
    if oldToggleGui then oldToggleGui:Destroy() end

    local islandGui = Instance.new("ScreenGui")
    islandGui.Name = "VIPDelsHubToggle"
    islandGui.ResetOnSpawn = false
    islandGui.IgnoreGuiInset = true
    islandGui.DisplayOrder = 100000
    islandGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    islandGui.Parent = PlayerGui

    local island = Instance.new("TextButton")
    island.Name = "DynamicIsland"
    island.AnchorPoint = Vector2.new(0, 0)
    island.Position = UDim2.fromOffset(12, 271)
    island.Size = UDim2.fromOffset(132, 46)
    island.BackgroundColor3 = Color3.fromRGB(8, 9, 14)
    island.BackgroundTransparency = 0
    island.BorderSizePixel = 0
    island.AutoButtonColor = false
    island.Text = ""
    island.ZIndex = 20
    island.Parent = islandGui

    local islandCorner = Instance.new("UICorner")
    islandCorner.CornerRadius = UDim.new(0, 8)
    islandCorner.Parent = island

    local islandStroke = Instance.new("UIStroke")
    islandStroke.Color = Color3.fromRGB(214, 165, 66)
    islandStroke.Transparency = 0
    islandStroke.Thickness = 1.3
    islandStroke.Parent = island

    local logo = Instance.new("ImageLabel")
    logo.Name = "VIPDelsLogo"
    logo.BackgroundTransparency = 1
    logo.Size = UDim2.new(1, -2, 1, -2)
    logo.Position = UDim2.fromOffset(1, 1)
    logo.ScaleType = Enum.ScaleType.Fit
    logo.ZIndex = 21
    logo.Parent = island

    local fallback = Instance.new("TextLabel")
    fallback.Name = "LogoFallback"
    fallback.BackgroundTransparency = 1
    fallback.Size = UDim2.fromScale(1, 1)
    fallback.Font = Enum.Font.GothamBold
    fallback.Text = "♛ VIP DELS HUB"
    fallback.TextScaled = true
    fallback.TextColor3 = Color3.fromRGB(239, 193, 90)
    fallback.ZIndex = 21
    fallback.Parent = island

    task.spawn(function()
        local ok, asset = pcall(function()
            if type(getcustomasset) ~= "function" then return nil end
            local path = "VIP_DELS_HUB_Logo_HD.png"
            if type(isfile) == "function" and isfile(path) then
                return getcustomasset(path)
            end
            if type(writefile) ~= "function" then return nil end
            local bytes = game:HttpGet("https://cdn.phototourl.com/member/2026-10-26-2186a978-0302-4a49-a24d-0c0165f36df9.png")
            if type(bytes) ~= "string" or #bytes < 100 then return nil end
            writefile(path, bytes)
            return getcustomasset(path)
        end)
        if ok and asset and island.Parent then
            logo.Image = asset
            fallback.Visible = false
        end
    end)

    local status = Instance.new("TextLabel")
    status.Name = "MenuStatus"
    status.BackgroundColor3 = Color3.fromRGB(12, 13, 19)
    status.BackgroundTransparency = 0.15
    status.AnchorPoint = Vector2.new(1, 1)
    status.Position = UDim2.new(1, -5, 1, -4)
    status.Size = UDim2.fromOffset(34, 12)
    status.Font = Enum.Font.GothamBold
    status.Text = "OPEN"
    status.TextColor3 = Color3.fromRGB(244, 207, 121)
    status.TextSize = 8
    status.ZIndex = 22
    status.Parent = island
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 4)
    statusCorner.Parent = status

    local menuVisible = true
    local function setMenuVisible(visible)
        menuVisible = visible == true
        pcall(function()
            if type(Window.SetVisible) == "function" then
                Window:SetVisible(menuVisible)
            elseif type(Window.SetVisible) == "nil" then
                -- Some library revisions expose visibility only on the native window.
                if Window._native and type(Window._native.SetVisible) == "function" then
                    Window._native:SetVisible(menuVisible)
                end
            end
        end)
        status.Text = menuVisible and "OPEN" or "HIDDEN"
        status.TextColor3 = menuVisible
            and Color3.fromRGB(140, 205, 255)
            or Color3.fromRGB(160, 170, 185)
    end

    local activeTouch, touchStart, islandStart
    local dragged = false
    local ignoreActivationUntil = 0

    island.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch then return end
        if activeTouch then return end
        activeTouch = input
        touchStart = input.Position
        islandStart = island.AbsolutePosition
        dragged = false
    end)

    UIS.InputChanged:Connect(function(input)
        if input ~= activeTouch or not touchStart then return end
        local delta = input.Position - touchStart
        if delta.Magnitude > 12 then dragged = true end
        if not dragged then return end
        local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
        local sz = island.AbsoluteSize
        local x = math.clamp(islandStart.X + delta.X, 6, math.max(6, vp.X - sz.X - 6))
        local y = math.clamp(islandStart.Y + delta.Y, 6, math.max(6, vp.Y - sz.Y - 6))
        island.AnchorPoint = Vector2.new(0, 0)
        island.Position = UDim2.fromOffset(x, y)
    end)

    UIS.InputEnded:Connect(function(input)
        if input ~= activeTouch then return end
        if dragged then ignoreActivationUntil = os.clock() + 0.25 end
        activeTouch = nil
        touchStart = nil
        islandStart = nil
    end)

    island.Activated:Connect(function()
        if os.clock() < ignoreActivationUntil or dragged then
            dragged = false
            return
        end
        setMenuVisible(not menuVisible)
    end)

    UIS.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then
            setMenuVisible(not menuVisible)
        end
    end)
end

refreshStatus()

env.VIP_DELS_IMGUI_CLEANUP = function()
    env[generationKey] = generation + 1
    scannerEnabled = false
    stopAutoTeleport()
    clearHighlights()
    local launcher = PlayerGui:FindFirstChild("VIPDelsHubToggle")
    if launcher then launcher:Destroy() end
    pcall(function()
        if Window.SetVisible then Window:SetVisible(false) end
    end)
end

print("[VIP DELS HUB] Real ImGui + Dynamic Island + Star Teleport loaded.")
