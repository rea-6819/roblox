-- =========================================================
-- 多機能ユーティリティ (Fullbright / Auto E / Timer / Top-down Map & ピン方向ガイド)
-- =========================================================
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- 二重起動防止
if getgenv and getgenv().UtilityGuiCleanup then
    getgenv().UtilityGuiCleanup()
end

-- ピン管理用テーブル
local pins = {}
local pinCount = 0

-- 天井パーツ復元用テーブル
local modifiedRoofs = {}
local roofTransparencyEnabled = false
local descendantAddedConn = nil

-- キャラクター状態保持用
local originalWalkSpeed = 16
local originalJumpPower = 50

-- ---------------------------------------------------------
-- GUI作成
-- ---------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UtilityGui"
screenGui.ResetOnSpawn = false
pcall(function()
    screenGui.Parent = player:WaitForChild("PlayerGui")
end)

-- 画面外ピン用コンテナ
local indicatorFolder = Instance.new("Folder")
indicatorFolder.Name = "PinIndicators"
indicatorFolder.Parent = screenGui

-- メインフレーム (メニュー)
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 240, 0, 550)
mainFrame.Position = UDim2.new(0, 20, 0.5, -275)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Text = "メニュー (L:メニュー / M:マップ)"
title.TextSize = 13
title.Font = Enum.Font.SourceSansBold
title.Parent = mainFrame

-- ---------------------------------------------------------
-- 1. フルブライト (トグル式)
-- ---------------------------------------------------------
local fbBtn = Instance.new("TextButton")
fbBtn.Size = UDim2.new(0.9, 0, 0, 26)
fbBtn.Position = UDim2.new(0.05, 0, 0, 36)
fbBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
fbBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
fbBtn.Text = "フルブライト: OFF"
fbBtn.Font = Enum.Font.SourceSansBold
fbBtn.TextSize = 12
fbBtn.Parent = mainFrame

local fullbrightEnabled = false
local fbConnection = nil
local defaultLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient
}

local function applyFullbright()
    Lighting.Brightness = 2
    Lighting.ClockTime = 14
    Lighting.FogEnd = 100000
    Lighting.GlobalShadows = false
    Lighting.Ambient = Color3.fromRGB(255, 255, 255)
    Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
end

local function restoreLighting()
    Lighting.Brightness = defaultLighting.Brightness
    Lighting.ClockTime = defaultLighting.ClockTime
    Lighting.FogEnd = defaultLighting.FogEnd
    Lighting.GlobalShadows = defaultLighting.GlobalShadows
    Lighting.Ambient = defaultLighting.Ambient
    Lighting.OutdoorAmbient = defaultLighting.OutdoorAmbient
end

local function toggleFullbright()
    fullbrightEnabled = not fullbrightEnabled
    if fullbrightEnabled then
        fbBtn.Text = "フルブライト: ON"
        fbBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 60)
        applyFullbright()
        fbConnection = RunService.RenderStepped:Connect(applyFullbright)
    else
        fbBtn.Text = "フルブライト: OFF"
        fbBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        if fbConnection then
            fbConnection:Disconnect()
            fbConnection = nil
        end
        restoreLighting()
    end
end
fbBtn.MouseButton1Click:Connect(toggleFullbright)

-- ---------------------------------------------------------
-- 2. Eキー連打 (Jキーで切り替え)
-- ---------------------------------------------------------
local autoEBtn = Instance.new("TextButton")
autoEBtn.Size = UDim2.new(0.9, 0, 0, 26)
autoEBtn.Position = UDim2.new(0.05, 0, 0, 66)
autoEBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
autoEBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoEBtn.Text = "E連打 (J): OFF"
autoEBtn.Font = Enum.Font.SourceSansBold
autoEBtn.TextSize = 12
autoEBtn.Parent = mainFrame

local autoEEnabled = false
local function toggleAutoE()
    autoEEnabled = not autoEEnabled
    if autoEEnabled then
        autoEBtn.Text = "E連打 (J): ON"
        autoEBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 60)
        task.spawn(function()
            while autoEEnabled do
                pcall(function()
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    task.wait(0.05)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                end)
                task.wait(0.05)
            end
        end)
    else
        autoEBtn.Text = "E連打 (J): OFF"
        autoEBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    end
end
autoEBtn.MouseButton1Click:Connect(toggleAutoE)

-- ---------------------------------------------------------
-- 3. マップ表示トグルボタン
-- ---------------------------------------------------------
local mapBtn = Instance.new("TextButton")
mapBtn.Size = UDim2.new(0.9, 0, 0, 26)
mapBtn.Position = UDim2.new(0.05, 0, 0, 96)
mapBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
mapBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
mapBtn.Text = "マップ視点 (M): OFF"
mapBtn.Font = Enum.Font.SourceSansBold
mapBtn.TextSize = 12
mapBtn.Parent = mainFrame

-- ---------------------------------------------------------
-- 4. 天井透過
-- ---------------------------------------------------------
local roofBtn = Instance.new("TextButton")
roofBtn.Size = UDim2.new(0.9, 0, 0, 26)
roofBtn.Position = UDim2.new(0.05, 0, 0, 126)
roofBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
roofBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
roofBtn.Text = "天井透過 (透かし): OFF"
roofBtn.Font = Enum.Font.SourceSansBold
roofBtn.TextSize = 12
roofBtn.Parent = mainFrame

local function getPlayerRoot()
    local char = player.Character
    if char then
        return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
    end
    return nil
end

local function getHumanoid()
    local char = player.Character
    if char then
        return char:FindFirstChildOfClass("Humanoid")
    end
    return nil
end

local function isRoofPart(obj, refPos)
    if not obj:IsA("BasePart") then return false end
    if player.Character and obj:IsDescendantOf(player.Character) then return false end
    if obj.Transparency >= 0.7 then return false end

    local name = obj.Name:lower()
    local hasRoofKeyword = name:find("roof") or name:find("ceil") or name:find("top") 
                        or name:find("upper") or name:find("cover") or name:find("attic")
                        or name:find("canopy") or name:find("floor")

    local s = obj.Size
    local isFlatAndWide = (s.Y <= s.X * 0.4 and s.Y <= s.Z * 0.4) and (s.X >= 4 and s.Z >= 4)
    local isHigher = (obj.Position.Y > refPos.Y + 5)

    return (hasRoofKeyword and isHigher) or (isFlatAndWide and isHigher)
end

local function processSinglePart(obj, refPos)
    if isRoofPart(obj, refPos) then
        if modifiedRoofs[obj] == nil then
            modifiedRoofs[obj] = obj.Transparency
        end
        obj.Transparency = 0.7
    end
end

local function scanAndApplyRoofTransparency()
    if not roofTransparencyEnabled then return end
    local root = getPlayerRoot()
    local refPos = root and root.Position or Vector3.new(0, 0, 0)

    for _, obj in ipairs(Workspace:GetDescendants()) do
        processSinglePart(obj, refPos)
    end
end

local function toggleRoofTransparency()
    roofTransparencyEnabled = not roofTransparencyEnabled
    if roofTransparencyEnabled then
        roofBtn.Text = "天井透過 (透かし): ON"
        roofBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 60)

        scanAndApplyRoofTransparency()

        if not descendantAddedConn then
            descendantAddedConn = Workspace.DescendantAdded:Connect(function(obj)
                if roofTransparencyEnabled and obj:IsA("BasePart") then
                    task.wait(0.05)
                    local root = getPlayerRoot()
                    local refPos = root and root.Position or Vector3.new(0, 0, 0)
                    processSinglePart(obj, refPos)
                end
            end)
        end
    else
        roofBtn.Text = "天井透過 (透かし): OFF"
        roofBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)

        if descendantAddedConn then
            descendantAddedConn:Disconnect()
            descendantAddedConn = nil
        end

        for part, origTrans in pairs(modifiedRoofs) do
            if part and part.Parent then
                part.Transparency = origTrans
            end
        end
        modifiedRoofs = {}
    end
end
roofBtn.MouseButton1Click:Connect(toggleRoofTransparency)

-- ---------------------------------------------------------
-- 5. タイマー
-- ---------------------------------------------------------
local timerBtn = Instance.new("TextButton")
timerBtn.Size = UDim2.new(0.9, 0, 0, 26)
timerBtn.Position = UDim2.new(0.05, 0, 0, 156)
timerBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
timerBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
timerBtn.Text = "タイマー: OFF"
timerBtn.Font = Enum.Font.SourceSansBold
timerBtn.TextSize = 12
timerBtn.Parent = mainFrame

local timerFrame = Instance.new("Frame")
timerFrame.Size = UDim2.new(0, 160, 0, 48)
timerFrame.Position = UDim2.new(1, -170, 0, 10)
timerFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
timerFrame.BackgroundTransparency = 0.45
timerFrame.BorderSizePixel = 0
timerFrame.Visible = false
timerFrame.Parent = screenGui

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(1, 0, 1, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
timerLabel.Font = Enum.Font.SourceSansBold
timerLabel.TextSize = 20
timerLabel.Text = "09:30 (Kで開始)"
timerLabel.Parent = timerFrame

local timerEnabled = false
local timerRunning = false
local timerSeconds = 570

local function startTimer()
    if not timerEnabled then return end
    timerSeconds = 570
    timerRunning = true
    timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)

    task.spawn(function()
        while timerRunning and timerSeconds > 0 and timerEnabled do
            local mins = math.floor(timerSeconds / 60)
            local secs = timerSeconds % 60
            timerLabel.Text = string.format("%02d:%02d", mins, secs)
            task.wait(1)
            if timerRunning and timerEnabled then
                timerSeconds = timerSeconds - 1
            end
        end
        if timerRunning and timerSeconds <= 0 and timerEnabled then
            timerLabel.Text = "00:00 (終了)"
            timerLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
        end
    end)
end

local function toggleTimerEnable()
    timerEnabled = not timerEnabled
    if timerEnabled then
        timerBtn.Text = "タイマー: ON"
        timerBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 60)
        timerFrame.Visible = true
        timerLabel.Text = "09:30 (Kで開始)"
        timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    else
        timerBtn.Text = "タイマー: OFF"
        timerBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        timerRunning = false
        timerFrame.Visible = false
    end
end
timerBtn.MouseButton1Click:Connect(toggleTimerEnable)

-- ---------------------------------------------------------
-- 6. 座標指定ピン刺し入力エリア
-- ---------------------------------------------------------
local coordTitle = Instance.new("TextLabel")
coordTitle.Size = UDim2.new(0.9, 0, 0, 18)
coordTitle.Position = UDim2.new(0.05, 0, 0, 188)
coordTitle.BackgroundTransparency = 1
coordTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
coordTitle.Text = "-- 座標ピン設置 --"
coordTitle.Font = Enum.Font.SourceSansBold
coordTitle.TextSize = 12
coordTitle.Parent = mainFrame

local inputX = Instance.new("TextBox")
inputX.Size = UDim2.new(0.28, 0, 0, 24)
inputX.Position = UDim2.new(0.05, 0, 0, 208)
inputX.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
inputX.TextColor3 = Color3.fromRGB(255, 255, 255)
inputX.PlaceholderText = "X"
inputX.Text = ""
inputX.Font = Enum.Font.SourceSans
inputX.TextSize = 12
inputX.Parent = mainFrame

local inputY = Instance.new("TextBox")
inputY.Size = UDim2.new(0.28, 0, 0, 24)
inputY.Position = UDim2.new(0.36, 0, 0, 208)
inputY.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
inputY.TextColor3 = Color3.fromRGB(255, 255, 255)
inputY.PlaceholderText = "Y(任意)"
inputY.Text = ""
inputY.Font = Enum.Font.SourceSans
inputY.TextSize = 12
inputY.Parent = mainFrame

local inputZ = Instance.new("TextBox")
inputZ.Size = UDim2.new(0.28, 0, 0, 24)
inputZ.Position = UDim2.new(0.67, 0, 0, 208)
inputZ.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
inputZ.TextColor3 = Color3.fromRGB(255, 255, 255)
inputZ.PlaceholderText = "Z"
inputZ.Text = ""
inputZ.Font = Enum.Font.SourceSans
inputZ.TextSize = 12
inputZ.Parent = mainFrame

local addCoordPinBtn = Instance.new("TextButton")
addCoordPinBtn.Size = UDim2.new(0.9, 0, 0, 26)
addCoordPinBtn.Position = UDim2.new(0.05, 0, 0, 236)
addCoordPinBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 140)
addCoordPinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
addCoordPinBtn.Text = "座標でピン追加"
addCoordPinBtn.Font = Enum.Font.SourceSansBold
addCoordPinBtn.TextSize = 13
addCoordPinBtn.Parent = mainFrame

-- ---------------------------------------------------------
-- 7. ピン一覧 & 削除リスト
-- ---------------------------------------------------------
local listTitle = Instance.new("TextLabel")
listTitle.Size = UDim2.new(0.9, 0, 0, 18)
listTitle.Position = UDim2.new(0.05, 0, 0, 266)
listTitle.BackgroundTransparency = 1
listTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
listTitle.Text = "-- 設置済みピン一覧 --"
listTitle.Font = Enum.Font.SourceSansBold
listTitle.TextSize = 12
listTitle.Parent = mainFrame

local pinScroll = Instance.new("ScrollingFrame")
pinScroll.Size = UDim2.new(0.9, 0, 0, 190)
pinScroll.Position = UDim2.new(0.05, 0, 0, 286)
pinScroll.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
pinScroll.BorderSizePixel = 0
pinScroll.ScrollBarThickness = 4
pinScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
pinScroll.Parent = mainFrame

local pinListLayout = Instance.new("UIListLayout")
pinListLayout.Padding = UDim.new(0, 4)
pinListLayout.SortOrder = Enum.SortOrder.LayoutOrder
pinListLayout.Parent = pinScroll

pinListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    pinScroll.CanvasSize = UDim2.new(0, 0, 0, pinListLayout.AbsoluteContentSize.Y + 6)
end)

-- ---------------------------------------------------------
-- 8. アンロードボタン
-- ---------------------------------------------------------
local unloadBtn = Instance.new("TextButton")
unloadBtn.Size = UDim2.new(0.9, 0, 0, 30)
unloadBtn.Position = UDim2.new(0.05, 0, 0, 508)
unloadBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
unloadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
unloadBtn.Text = "アンロード"
unloadBtn.Font = Enum.Font.SourceSansBold
unloadBtn.TextSize = 13
unloadBtn.Parent = mainFrame

-- ---------------------------------------------------------
-- 9. ピン管理 & 画面上3D表示 & 画面外方向ガイド
-- ---------------------------------------------------------
local function getGroundY(x, z, fallbackY)
    local rayOrigin = Vector3.new(x, 1000, z)
    local rayDirection = Vector3.new(0, -2000, 0)
    local rayParams = RaycastParams.new()
    local ignoreList = {}
    if player.Character then table.insert(ignoreList, player.Character) end
    for part, _ in pairs(modifiedRoofs) do table.insert(ignoreList, part) end
    rayParams.FilterDescendantsInstances = ignoreList
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local result = Workspace:Raycast(rayOrigin, rayDirection, rayParams)
    if result then
        return result.Position.Y
    end
    return fallbackY or 5
end

local function removePin(pinId)
    local pinData = pins[pinId]
    if pinData then
        if pinData.WorldPart then pinData.WorldPart:Destroy() end
        if pinData.ListItem then pinData.ListItem:Destroy() end
        if pinData.Indicator then pinData.Indicator:Destroy() end
        pins[pinId] = nil
    end
end

local function createPin(worldPos, customName)
    pinCount = pinCount + 1
    local pinId = pinCount
    local pinName = customName or string.format("Pin #%d", pinId)

    local worldPart = Instance.new("Part")
    worldPart.Name = "PinMarker_" .. pinId
    worldPart.Anchored = true
    worldPart.CanCollide = false
    worldPart.Transparency = 1
    worldPart.Position = worldPos
    worldPart.Size = Vector3.new(1, 1, 1)
    worldPart.Parent = Workspace

    -- 通常の3D空間内マーカー
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 110, 0, 54)
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Adornee = worldPart
    billboard.Parent = worldPart

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(1, 0, 0, 26)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = "📍 " .. pinName
    iconLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
    iconLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    iconLabel.TextStrokeTransparency = 0
    iconLabel.Font = Enum.Font.SourceSansBold
    iconLabel.TextSize = 16
    iconLabel.Parent = billboard

    local distLabel = Instance.new("TextLabel")
    distLabel.Size = UDim2.new(1, 0, 0, 20)
    distLabel.Position = UDim2.new(0, 0, 0, 26)
    distLabel.BackgroundTransparency = 1
    distLabel.Text = "0 studs"
    distLabel.TextColor3 = Color3.fromRGB(255, 230, 100)
    distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    distLabel.TextStrokeTransparency = 0
    distLabel.Font = Enum.Font.SourceSansBold
    distLabel.TextSize = 13
    distLabel.Parent = billboard

    -- 画面外にある時の「こっちにピンがあるよ」インジケーター矢印
    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 75, 0, 28)
    indicator.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    indicator.BackgroundTransparency = 0.2
    indicator.BorderSizePixel = 1
    indicator.BorderColor3 = Color3.fromRGB(255, 60, 60)
    indicator.Visible = false
    indicator.Parent = indicatorFolder

    local indCorner = Instance.new("UICorner")
    indCorner.CornerRadius = UDim.new(0, 6)
    indCorner.Parent = indicator

    local indLabel = Instance.new("TextLabel")
    indLabel.Size = UDim2.new(1, 0, 1, 0)
    indLabel.BackgroundTransparency = 1
    indLabel.Text = "📍 0m"
    indLabel.TextColor3 = Color3.fromRGB(255, 230, 100)
    indLabel.Font = Enum.Font.SourceSansBold
    indLabel.TextSize = 12
    indLabel.Parent = indicator

    local itemFrame = Instance.new("Frame")
    itemFrame.Size = UDim2.new(1, 0, 0, 30)
    itemFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
    itemFrame.BorderSizePixel = 0
    itemFrame.Parent = pinScroll

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0.68, 0, 1, 0)
    nameLabel.Position = UDim2.new(0.04, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
    nameLabel.Font = Enum.Font.SourceSans
    nameLabel.TextSize = 11
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Text = string.format("%s (%.0f, %.0f)", pinName, worldPos.X, worldPos.Z)
    nameLabel.Parent = itemFrame

    local delBtn = Instance.new("TextButton")
    delBtn.Size = UDim2.new(0.24, 0, 0.7, 0)
    delBtn.Position = UDim2.new(0.73, 0, 0.15, 0)
    delBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
    delBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    delBtn.Text = "削除"
    delBtn.Font = Enum.Font.SourceSansBold
    delBtn.TextSize = 11
    delBtn.Parent = itemFrame

    delBtn.MouseButton1Click:Connect(function()
        removePin(pinId)
    end)

    pins[pinId] = {
        Id = pinId,
        Position = worldPos,
        WorldPart = worldPart,
        DistLabel = distLabel,
        Indicator = indicator,
        IndLabel = indLabel,
        Billboard = billboard,
        ListItem = itemFrame
    }
end

addCoordPinBtn.MouseButton1Click:Connect(function()
    local x = tonumber(inputX.Text)
    local z = tonumber(inputZ.Text)
    if not x or not z then
        addCoordPinBtn.Text = "XとZを入力して下さい"
        task.delay(1.5, function()
            addCoordPinBtn.Text = "座標でピン追加"
        end)
        return
    end

    local root = getPlayerRoot()
    local defaultY = root and root.Position.Y or 10
    local y = tonumber(inputY.Text) or getGroundY(x, z, defaultY)

    createPin(Vector3.new(x, y, z))
    inputX.Text = ""
    inputY.Text = ""
    inputZ.Text = ""
end)

-- ---------------------------------------------------------
-- 10. 上空マップ & 6軸自由移動フリーカム
-- ---------------------------------------------------------
local mapModeActive = false
local isGroundView = false
local isFreecamActive = false

local mapCamPos = Vector3.new(0, 300, 0)
local mapCamHeight = 350
local isDraggingMap = false
local lastMousePos = Vector2.new(0, 0)

local freecamPos = Vector3.new(0, 0, 0)
local freecamYaw = 0
local freecamPitch = 0
local freecamSpeed = 60
local isRotatingGround = false

local lastHoverPos = Vector2.new(0, 0)
local hoverStillTime = 0
local lastRayHitPos = nil
local lastStreamRequestTime = 0
local lastScanTime = 0

local mapGuideFrame = Instance.new("Frame")
mapGuideFrame.Size = UDim2.new(0, 620, 0, 42)
mapGuideFrame.Position = UDim2.new(0.5, -310, 1, -55)
mapGuideFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
mapGuideFrame.BackgroundTransparency = 0.3
mapGuideFrame.BorderSizePixel = 0
mapGuideFrame.Visible = false
mapGuideFrame.Parent = screenGui

local mapGuideCorner = Instance.new("UICorner")
mapGuideCorner.CornerRadius = UDim.new(0, 8)
mapGuideCorner.Parent = mapGuideFrame

local mapGuideText = Instance.new("TextLabel")
mapGuideText.Size = UDim2.new(1, 0, 1, 0)
mapGuideText.BackgroundTransparency = 1
mapGuideText.TextColor3 = Color3.fromRGB(255, 255, 255)
mapGuideText.Font = Enum.Font.SourceSansBold
mapGuideText.TextSize = 12
mapGuideText.Text = "【マップ】左クリック: ピン | Nキー: 自由フリーカム | Vキー/静止: 見回し | 右ドラッグ: 回転 | M: 閉じる"
mapGuideText.Parent = mapGuideFrame

local function lockCharacter(locked)
    local root = getPlayerRoot()
    local hum = getHumanoid()
    if locked then
        if hum then
            originalWalkSpeed = hum.WalkSpeed
            originalJumpPower = hum.JumpPower
            hum.WalkSpeed = 0
            hum.JumpPower = 0
        end
        if root then root.Anchored = true end
    else
        if root then root.Anchored = false end
        if hum then
            hum.WalkSpeed = originalWalkSpeed > 0 and originalWalkSpeed or 16
            hum.JumpPower = originalJumpPower > 0 and originalJumpPower or 50
        end
    end
end

local function requestStreamLoad(targetPos)
    if player and player.RequestStreamAroundAsync then
        task.spawn(function()
            pcall(function()
                player:RequestStreamAroundAsync(targetPos)
            end)
        end)
    end
end

-- Vキー用: 地上定点見回し
local function enterGroundView(targetWorldPos)
    if not targetWorldPos then return end
    isGroundView = true
    isFreecamActive = false

    freecamPos = targetWorldPos + Vector3.new(0, 4.5, 0)
    requestStreamLoad(freecamPos)
    mapGuideText.Text = "【地上360°見回し中】右ドラッグ: 回転 | Vキー/WASD: マップに戻る | 左クリック: ピン"
end

-- Nキー用: 6軸完全自由移動フリーカム
local function enterFreecam(targetWorldPos)
    if not targetWorldPos then return end
    isFreecamActive = true
    isGroundView = false

    freecamPos = targetWorldPos + Vector3.new(0, 4.5, 0)
    freecamYaw = 0
    freecamPitch = 0
    requestStreamLoad(freecamPos)
    mapGuideText.Text = "【フリーカム】WASD: 前後左右 | Space/E: 上 | Shift/Q: 下 | Ctrl: 加速 | 右ドラッグ: 回転 | N: マップに戻る"
end

local function exitSpecialView()
    isGroundView = false
    isFreecamActive = false
    hoverStillTime = 0
    mapGuideText.Text = "【マップ】左クリック: ピン | Nキー: 自由フリーカム | Vキー/静止: 見回し | 右ドラッグ: 回転 | M: 閉じる"
end

local function toggleMapMode()
    mapModeActive = not mapModeActive
    if mapModeActive then
        mapBtn.Text = "マップ視点 (M): ON"
        mapBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 60)
        mapGuideFrame.Visible = true

        lockCharacter(true)

        local root = getPlayerRoot()
        local basePos = root and root.Position or Vector3.new(0, 0, 0)
        mapCamPos = Vector3.new(basePos.X, basePos.Y + mapCamHeight, basePos.Z)

        exitSpecialView()
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = CFrame.new(mapCamPos) * CFrame.Angles(math.rad(-90), 0, 0)
        camera.Focus = CFrame.new(basePos)
        requestStreamLoad(basePos)
    else
        mapBtn.Text = "マップ視点 (M): OFF"
        mapBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        mapGuideFrame.Visible = false
        exitSpecialView()

        lockCharacter(false)

        camera.CameraType = Enum.CameraType.Custom
        local root = getPlayerRoot()
        if root then camera.Focus = root.CFrame end
    end
end
mapBtn.MouseButton1Click:Connect(toggleMapMode)

local updateConnection = RunService.RenderStepped:Connect(function(dt)
    local root = getPlayerRoot()
    local playerPos = root and root.Position or Vector3.new(0, 0, 0)
    local vpSize = camera.ViewportSize

    -- ピンの距離更新 & 画面外方向ガイドの計算
    for _, pin in pairs(pins) do
        local dist = math.floor((playerPos - pin.Position).Magnitude)
        pin.DistLabel.Text = tostring(dist) .. " studs"

        local screenPos, onScreen = camera:WorldToViewportPoint(pin.Position)
        if onScreen and screenPos.Z > 0 then
            pin.Billboard.Enabled = true
            pin.Indicator.Visible = false
        else
            pin.Billboard.Enabled = false
            pin.Indicator.Visible = true
            pin.IndLabel.Text = string.format("📍 %d studs", dist)

            local screenCenter = Vector2.new(vpSize.X / 2, vpSize.Y / 2)
            local dir = Vector2.new(screenPos.X - screenCenter.X, screenPos.Y - screenCenter.Y)
            if screenPos.Z < 0 then dir = -dir end

            local angle = math.atan2(dir.Y, dir.X)
            local edgeMargin = 45
            local clampedX = math.clamp(screenCenter.X + math.cos(angle) * (screenCenter.X - edgeMargin), edgeMargin, vpSize.X - edgeMargin)
            local clampedY = math.clamp(screenCenter.Y + math.sin(angle) * (screenCenter.Y - edgeMargin), edgeMargin, vpSize.Y - edgeMargin)

            pin.Indicator.Position = UDim2.new(0, clampedX - 37, 0, clampedY - 14)
        end
    end

    if mapModeActive then
        local now = tick()
        if roofTransparencyEnabled and now - lastScanTime > 1.2 then
            lastScanTime = now
            scanAndApplyRoofTransparency()
        end

        if isFreecamActive then
            -- 6軸自由移動フリーカム処理
            local rotCFrame = CFrame.Angles(0, math.rad(freecamYaw), 0) * CFrame.Angles(math.rad(freecamPitch), 0, 0)
            
            local moveVec = Vector3.new(0, 0, 0)
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec = moveVec + Vector3.new(0, 0, -1) end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec = moveVec + Vector3.new(0, 0, 1) end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec = moveVec + Vector3.new(-1, 0, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec = moveVec + Vector3.new(1, 0, 0) end

            local upDown = 0
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.E) then upDown = upDown + 1 end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then upDown = upDown - 1 end

            local speedMultiplier = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and 2.5 or 1.0
            local currentSpeed = freecamSpeed * speedMultiplier * dt

            local worldMove = rotCFrame:VectorToWorldSpace(moveVec) + Vector3.new(0, upDown, 0)
            if worldMove.Magnitude > 0 then
                worldMove = worldMove.Unit * currentSpeed
            end

            freecamPos = freecamPos + worldMove
            camera.CFrame = CFrame.new(freecamPos) * rotCFrame
            camera.Focus = CFrame.new(freecamPos)

            if now - lastStreamRequestTime > 0.5 then
                lastStreamRequestTime = now
                requestStreamLoad(freecamPos)
            end

        elseif isGroundView then
            -- Vキー定点見回し処理
            local rotCFrame = CFrame.Angles(0, math.rad(freecamYaw), 0) * CFrame.Angles(math.rad(freecamPitch), 0, 0)
            camera.CFrame = CFrame.new(freecamPos) * rotCFrame
            camera.Focus = CFrame.new(freecamPos)

            if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.A)
            or UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.D) then
                exitSpecialView()
            end
        else
            -- 上空マップ移動処理
            local moveVec = Vector3.new(0, 0, 0)
            local speed = (mapCamHeight / 300) * 200 * dt

            if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
                moveVec = moveVec + Vector3.new(0, 0, -speed)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
                moveVec = moveVec + Vector3.new(0, 0, speed)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
                moveVec = moveVec + Vector3.new(-speed, 0, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
                moveVec = moveVec + Vector3.new(speed, 0, 0)
            end

            mapCamPos = Vector3.new(mapCamPos.X + moveVec.X, mapCamHeight, mapCamPos.Z + moveVec.Z)
            camera.CFrame = CFrame.new(mapCamPos) * CFrame.Angles(math.rad(-90), 0, 0)
            camera.Focus = CFrame.new(mapCamPos.X, 0, mapCamPos.Z)

            if now - lastStreamRequestTime > 0.5 then
                lastStreamRequestTime = now
                requestStreamLoad(Vector3.new(mapCamPos.X, 0, mapCamPos.Z))
            end

            local curMouse = UserInputService:GetMouseLocation()
            local unitRay = camera:ViewportPointToRay(curMouse.X, curMouse.Y)
            local rayParams = RaycastParams.new()
            local ignoreList = {}
            if player.Character then table.insert(ignoreList, player.Character) end
            for part, _ in pairs(modifiedRoofs) do table.insert(ignoreList, part) end
            rayParams.FilterDescendantsInstances = ignoreList
            rayParams.FilterType = Enum.RaycastFilterType.Exclude

            local hit = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 5000, rayParams)
            if hit then
                lastRayHitPos = hit.Position
            end

            local mouseMoveDist = (curMouse - lastHoverPos).Magnitude
            if mouseMoveDist < 15 and not isDraggingMap and moveVec.Magnitude == 0 then
                hoverStillTime = hoverStillTime + dt
            else
                hoverStillTime = 0
                lastHoverPos = curMouse
            end

            if hoverStillTime >= 1.2 and lastRayHitPos then
                enterGroundView(lastRayHitPos)
            end
        end
    end
end)

-- ---------------------------------------------------------
-- マップ操作イベント
-- ---------------------------------------------------------
local inputMapConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if mapModeActive then
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local mouseLoc = UserInputService:GetMouseLocation()
            local unitRay = camera:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)

            local rayParams = RaycastParams.new()
            local ignoreList = {}
            if player.Character then table.insert(ignoreList, player.Character) end
            for part, _ in pairs(modifiedRoofs) do table.insert(ignoreList, part) end
            rayParams.FilterDescendantsInstances = ignoreList
            rayParams.FilterType = Enum.RaycastFilterType.Exclude

            local hit = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 5000, rayParams)
            if hit then
                createPin(hit.Position)
            else
                local t = -unitRay.Origin.Y / unitRay.Direction.Y
                local hitPos = unitRay.Origin + unitRay.Direction * t
                createPin(hitPos)
            end

        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            if isGroundView or isFreecamActive then
                isRotatingGround = true
            else
                isDraggingMap = true
            end
            lastMousePos = UserInputService:GetMouseLocation()

        -- Nキー: 完全自由移動フリーカムのトグル
        elseif input.KeyCode == Enum.KeyCode.N then
            if isFreecamActive then
                exitSpecialView()
            else
                local mouseLoc = UserInputService:GetMouseLocation()
                local unitRay = camera:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)

                local rayParams = RaycastParams.new()
                local ignoreList = {}
                if player.Character then table.insert(ignoreList, player.Character) end
                for part, _ in pairs(modifiedRoofs) do table.insert(ignoreList, part) end
                rayParams.FilterDescendantsInstances = ignoreList
                rayParams.FilterType = Enum.RaycastFilterType.Exclude

                local hit = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 5000, rayParams)
                local targetPos = hit and hit.Position or lastRayHitPos
                if targetPos then
                    enterFreecam(targetPos)
                end
            end

        -- Vキー: 地上定点見回しのトグル
        elseif input.KeyCode == Enum.KeyCode.V then
            if isGroundView then
                exitSpecialView()
            else
                if lastRayHitPos then
                    enterGroundView(lastRayHitPos)
                end
            end

        elseif input.KeyCode == Enum.KeyCode.C then
            local root = getPlayerRoot()
            if root then
                mapCamPos = Vector3.new(root.Position.X, mapCamHeight, root.Position.Z)
                requestStreamLoad(root.Position)
                if isGroundView or isFreecamActive then
                    enterFreecam(root.Position)
                end
            end
        end
    end
end)

local inputMapEndConnection = UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        isDraggingMap = false
        isRotatingGround = false
    end
end)

local inputMapMoveConnection = UserInputService.InputChanged:Connect(function(input)
    if mapModeActive then
        if input.UserInputType == Enum.UserInputType.MouseWheel and not isGroundView and not isFreecamActive then
            local delta = input.Position.Z
            mapCamHeight = math.clamp(mapCamHeight - (delta * 60), 80, 1500)
            mapCamPos = Vector3.new(mapCamPos.X, mapCamHeight, mapCamPos.Z)

        elseif input.UserInputType == Enum.UserInputType.MouseMovement then
            local currentMouse = UserInputService:GetMouseLocation()
            local delta = currentMouse - lastMousePos
            lastMousePos = currentMouse

            if (isGroundView or isFreecamActive) and isRotatingGround then
                freecamYaw = freecamYaw - (delta.X * 0.35)
                freecamPitch = math.clamp(freecamPitch - (delta.Y * 0.35), -80, 80)

            elseif not isGroundView and not isFreecamActive and isDraggingMap then
                local factor = (mapCamHeight / 600)
                mapCamPos = Vector3.new(mapCamPos.X - (delta.X * factor), mapCamHeight, mapCamPos.Z - (delta.Y * factor))
            end
        end
    end
end)

-- ---------------------------------------------------------
-- アンロード処理
-- ---------------------------------------------------------
local inputConnection = nil

local function cleanup()
    if mapModeActive then
        mapModeActive = false
        lockCharacter(false)
        camera.CameraType = Enum.CameraType.Custom
    end

    if descendantAddedConn then
        descendantAddedConn:Disconnect()
        descendantAddedConn = nil
    end

    for part, origTrans in pairs(modifiedRoofs) do
        if part and part.Parent then
            part.Transparency = origTrans
        end
    end
    modifiedRoofs = {}
    roofTransparencyEnabled = false

    timerEnabled = false
    timerRunning = false

    autoEEnabled = false
    if fbConnection then
        fbConnection:Disconnect()
        fbConnection = nil
    end
    restoreLighting()

    if updateConnection then updateConnection:Disconnect() end
    if inputMapConnection then inputMapConnection:Disconnect() end
    if inputMapEndConnection then inputMapEndConnection:Disconnect() end
    if inputMapMoveConnection then inputMapMoveConnection:Disconnect() end
    if inputConnection then inputConnection:Disconnect() end

    for _, pin in pairs(pins) do
        if pin.WorldPart then pin.WorldPart:Destroy() end
        if pin.Indicator then pin.Indicator:Destroy() end
    end
    pins = {}

    if screenGui then screenGui:Destroy() end
    if getgenv then getgenv().UtilityGuiCleanup = nil end
end

unloadBtn.MouseButton1Click:Connect(cleanup)
if getgenv then
    getgenv().UtilityGuiCleanup = cleanup
end

-- ---------------------------------------------------------
-- キー入力処理 (J, K, L, M)
-- ---------------------------------------------------------
inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    -- Jキー: E連打トグル
    if input.KeyCode == Enum.KeyCode.J then
        toggleAutoE()

    -- Kキー: タイマー開始
    elseif input.KeyCode == Enum.KeyCode.K then
        if timerEnabled then
            startTimer()
        end

    -- Lキー: メインメニュー表示 / 非表示
    elseif input.KeyCode == Enum.KeyCode.L then
        mainFrame.Visible = not mainFrame.Visible

    -- Mキー: マップ視点トグル
    elseif input.KeyCode == Enum.KeyCode.M then
        toggleMapMode()
    end
end)
