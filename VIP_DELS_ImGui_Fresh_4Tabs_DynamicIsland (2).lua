-- VIP DELS HUB - Fresh ImGui UI
-- Only four empty tabs: Farm, Config, Player, Teleport.
-- No feature logic from the original script is included.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

-- Load Roblox-ImGui
local ImGui
do
    local SourceURL = "https://raw.githubusercontent.com/projctstealegg-commits/Roblox-ImGUI/refs/heads/main/ImGui.lua"

    local okHttp, source = pcall(function()
        return game:HttpGet(SourceURL)
    end)

    if not okHttp or type(source) ~= "string" or #source < 1000 then
        error("Unable to download Roblox-ImGui: " .. tostring(source))
    end

    if type(loadstring) ~= "function" then
        error("loadstring is unavailable in this executor.")
    end

    local okCompile, chunk = pcall(loadstring, source)
    if not okCompile or type(chunk) ~= "function" then
        error("Roblox-ImGui compile failed: " .. tostring(chunk))
    end

    local okInit, result = pcall(chunk)
    if not okInit then
        error("Roblox-ImGui initialization failed: " .. tostring(result))
    end

    ImGui = result

    if type(ImGui) ~= "table" then
        local okGlobal, globalImGui = pcall(function()
            local g = (getgenv and getgenv()) or _G
            return g and (g.ImGui or g.RobloxImGui)
        end)

        if okGlobal and type(globalImGui) == "table" then
            ImGui = globalImGui
        end
    end

    if type(ImGui) ~= "table" or type(ImGui.CreateWindow) ~= "function" then
        error("Roblox-ImGui loaded, but CreateWindow was not found.")
    end
end

local Camera = workspace.CurrentCamera

local function viewport()
    Camera = workspace.CurrentCamera or Camera
    return Camera and Camera.ViewportSize or Vector2.new(1280, 720)
end

local function windowSize()
    local v = viewport()
    local touch = UIS.TouchEnabled or v.X <= 800

    if touch then
        return UDim2.fromOffset(
            math.min(500, math.max(260, math.floor(v.X * 0.90))),
            math.min(530, math.max(220, math.floor(v.Y * 0.72)))
        )
    end

    return UDim2.fromOffset(700, 500)
end

local Window = ImGui:CreateWindow({
    Title = "VIP DELS HUB",
    Size = windowSize(),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Border = true,
    BorderThickness = 2,
    BackgroundTransparency = 0.16,
    CornerRadius = UDim.new(0, 8),
    NoCollapse = false,
    NoResize = false,
    NoDrag = false,
})

pcall(function()
    Window:Center()
end)

-- ============================================================
-- EMPTY TABS
-- ============================================================

Window:CreateTab({
    Name = "Farm",
})

Window:CreateTab({
    Name = "Config",
})

Window:CreateTab({
    Name = "Player",
})

Window:CreateTab({
    Name = "Teleport",
})


-- ============================================================
-- VIP DELS HUB • iOS DYNAMIC ISLAND MENU TOGGLE
-- Floating pill used to show/hide the fresh four-tab ImGui.
-- ============================================================
;(function()
    local PlayerGui = LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui")
    local oldToggleGui = PlayerGui:FindFirstChild("VIPDelsHubToggle")
    if oldToggleGui then
        oldToggleGui:Destroy()
    end

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
    island.Size = UDim2.fromOffset(110, 38)
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

    -- VIP DELS logo: load the same HD logo asset used by the original Dynamic Island.
    local logo = Instance.new("ImageLabel")
    logo.Name = "Logo"
    logo.BackgroundTransparency = 1
    logo.Size = UDim2.new(1, -2, 1, -2)
    logo.Position = UDim2.fromOffset(1, 1)
    logo.ScaleType = Enum.ScaleType.Fit
    logo.Image = ""
    logo.ZIndex = 21
    logo.Parent = island

    -- Text fallback only while the HD logo is being downloaded.
    local fallback = Instance.new("TextLabel")
    fallback.Name = "LogoFallback"
    fallback.BackgroundTransparency = 1
    fallback.Size = UDim2.fromScale(1, 1)
    fallback.Font = Enum.Font.GothamBold
    fallback.Text = "♛ VIP DELS HUB"
    fallback.TextScaled = true
    fallback.TextColor3 = Color3.fromRGB(239, 193, 90)
    fallback.ZIndex = 20
    fallback.Parent = island

    task.spawn(function()
        local ok, asset = pcall(function()
            if type(getcustomasset) ~= "function" then return nil end
            local path = "VIP_DELS_HUB_Logo_HD.png"
            if type(isfile) == "function" and isfile(path) then
                return getcustomasset(path)
            end
            if type(writefile) ~= "function" then return nil end

            local bytes = game:HttpGet(
                "https://cdn.phototourl.com/member/2026-10-26-2186a978-0302-4a49-a24d-0c0165f36df9.png"
            )

            if type(bytes) ~= "string" or #bytes < 100 then
                return nil
            end

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
    status.Position = UDim2.new(1, -3, 1, -2)
    status.Size = UDim2.fromOffset(28, 10)
    status.Font = Enum.Font.GothamBold
    status.Text = "OPEN"
    status.TextColor3 = Color3.fromRGB(140, 205, 255)
    status.TextSize = 7
    status.ZIndex = 22
    status.Parent = island

    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 4)
    statusCorner.Parent = status

    local menuVisible = true
    local function setMenuVisible(visible)
        menuVisible = visible
        Window:SetVisible(visible)
        status.Text = visible and "OPEN" or "HIDDEN"
        status.TextColor3 = visible
            and Color3.fromRGB(140, 205, 255)
            or Color3.fromRGB(160, 170, 185)
    end

    -- Touch drag moves the pill; a tap toggles the main ImGui window.
    local activeTouch = nil
    local touchStart = nil
    local islandStart = nil
    local dragged = false
    local ignoreActivationUntil = 0

    island.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        if activeTouch then
            return
        end

        activeTouch = input
        touchStart = input.Position
        islandStart = island.AbsolutePosition
        dragged = false
    end)

    UIS.InputChanged:Connect(function(input)
        if input ~= activeTouch or not touchStart then
            return
        end

        local delta = input.Position - touchStart
        if delta.Magnitude > 12 then
            dragged = true
        end
        if not dragged then
            return
        end

        local vp = viewport()
        local size = island.AbsoluteSize
        local x = math.clamp(islandStart.X + delta.X, 6, math.max(6, vp.X - size.X - 6))
        local y = math.clamp(islandStart.Y + delta.Y, 6, math.max(6, vp.Y - size.Y - 6))
        island.AnchorPoint = Vector2.new(0, 0)
        island.Position = UDim2.fromOffset(x, y)
    end)

    UIS.InputEnded:Connect(function(input)
        if input ~= activeTouch then
            return
        end
        if dragged then
            ignoreActivationUntil = os.clock() + 0.25
        end
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
end)()

-- Keep the window responsive after rotation/resize.
task.spawn(function()
    local last = viewport()

    while task.wait(1) do
        local current = viewport()

        if current ~= last then
            last = current

            pcall(function()
                if type(Window.SetSize) == "function" then
                    Window:SetSize(windowSize())
                end

                if type(Window.Center) == "function" then
                    Window:Center()
                end
            end)
        end
    end
end)
