--// Heaven - ESP Only (LocalScript)
--// Highlight + simple nametag (name only). No distance/HP logic.
--// Place in StarterPlayer > StarterPlayerScripts

---------------- SERVICES ----------------
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

---------------- CONFIG ----------------
local ESP_FOLDER_NAME = "HeavenESPFolder"

local USE_TEAM_COLOR = true
local DEFAULT_FILL_COLOR = Color3.fromRGB(255, 60, 60)
local OUTLINE_COLOR = Color3.fromRGB(255, 255, 255)

local FILL_TRANSPARENCY = 0.45
local OUTLINE_TRANSPARENCY = 0

---------------- STATE ----------------
local espEnabled = true
local guiVisible = true

-- widgets cache
local widgets = {} -- [player] = {highlight=Highlight, tag=BillboardGui}

---------------- HELPERS ----------------
local function getESPFolder()
	local folder = LocalPlayer:FindFirstChild(ESP_FOLDER_NAME)
	if folder and folder:IsA("Folder") then return folder end
	folder = Instance.new("Folder")
	folder.Name = ESP_FOLDER_NAME
	folder.Parent = LocalPlayer
	return folder
end

local function getFillColorFor(player)
	if USE_TEAM_COLOR and player.Team and player.Team.TeamColor then
		return player.Team.TeamColor.Color
	end
	return DEFAULT_FILL_COLOR
end

local function applyESPEnabled(player, enabled)
	local w = widgets[player]
	if not w then return end
	if w.highlight then w.highlight.Enabled = enabled end
	if w.tag and w.tag.Parent then w.tag.Enabled = enabled end
end

---------------- GUI ----------------
local gui = Instance.new("ScreenGui")
gui.Name = "HeavenESPGui"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local frame = Instance.new("Frame")
frame.Parent = gui
frame.Size = UDim2.fromOffset(260, 120)
frame.Position = UDim2.new(0, 16, 0.35, 0)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

local header = Instance.new("TextLabel")
header.Parent = frame
header.Size = UDim2.new(1, -20, 0, 40)
header.Position = UDim2.new(0, 10, 0, 10)
header.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
header.BorderSizePixel = 0
header.Font = Enum.Font.GothamBlack
header.Text = "HEAVEN • ESP"
header.TextSize = 16
header.TextColor3 = Color3.fromRGB(160, 170, 255)
header.TextStrokeTransparency = 0.85
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

local btn = Instance.new("TextButton")
btn.Parent = frame
btn.Size = UDim2.new(1, -20, 0, 40)
btn.Position = UDim2.new(0, 10, 0, 60)
btn.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
btn.BorderSizePixel = 0
btn.AutoButtonColor = false
btn.Font = Enum.Font.GothamBold
btn.TextSize = 15
btn.TextColor3 = Color3.fromRGB(235, 235, 235)
btn.Text = "ESP: ON"
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

btn.MouseEnter:Connect(function()
	TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
		BackgroundColor3 = Color3.fromRGB(44, 44, 56)
	}):Play()
end)
btn.MouseLeave:Connect(function()
	TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
		BackgroundColor3 = Color3.fromRGB(28, 28, 36)
	}):Play()
end)

---------------- ESP CREATION ----------------
local function ensureESP(player)
	if player == LocalPlayer then return end
	if widgets[player] then return end

	local folder = getESPFolder()

	local hl = Instance.new("Highlight")
	hl.Name = player.Name .. "_HL"
	hl.Parent = folder
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.FillColor = getFillColorFor(player)
	hl.OutlineColor = OUTLINE_COLOR
	hl.FillTransparency = FILL_TRANSPARENCY
	hl.OutlineTransparency = OUTLINE_TRANSPARENCY
	hl.Enabled = espEnabled

	local tag -- BillboardGui

	local function attach(char)
		hl.Adornee = char
		hl.FillColor = getFillColorFor(player)
		hl.Enabled = espEnabled

		local head = char:FindFirstChild("Head")
		if head then
			-- create if missing
			local existing = head:FindFirstChild("HeavenNameTag")
			if existing and existing:IsA("BillboardGui") then
				tag = existing
			else
				tag = Instance.new("BillboardGui")
				tag.Name = "HeavenNameTag"
				tag.Adornee = head
				tag.AlwaysOnTop = true
				tag.Size = UDim2.new(0, 200, 0, 32)
				tag.StudsOffset = Vector3.new(0, 2.3, 0)
				tag.Parent = head

				local bg = Instance.new("Frame", tag)
				bg.Size = UDim2.new(1, 0, 1, 0)
				bg.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
				bg.BackgroundTransparency = 0.2
				bg.BorderSizePixel = 0
				Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

				local label = Instance.new("TextLabel", bg)
				label.Size = UDim2.new(1, -12, 1, -6)
				label.Position = UDim2.new(0, 6, 0, 3)
				label.BackgroundTransparency = 1
				label.Font = Enum.Font.GothamBold
				label.TextSize = 14
				label.TextColor3 = Color3.fromRGB(240, 240, 240)
				label.TextStrokeTransparency = 0.65
				label.Text = player.Name
			end

			tag.Enabled = espEnabled
		end
	end

	if player.Character then attach(player.Character) end
	player.CharacterAdded:Connect(function(char)
		task.wait(0.05)
		attach(char)
	end)

	widgets[player] = { highlight = hl, tag = tag }
end

-- init existing players
for _, p in ipairs(Players:GetPlayers()) do
	ensureESP(p)
end

Players.PlayerAdded:Connect(ensureESP)

Players.PlayerRemoving:Connect(function(p)
	local w = widgets[p]
	if w then
		if w.highlight and w.highlight.Parent then w.highlight:Destroy() end
		if w.tag and w.tag.Parent then w.tag:Destroy() end
		widgets[p] = nil
	end
end)

---------------- TOGGLES ----------------
btn.MouseButton1Click:Connect(function()
	espEnabled = not espEnabled
	btn.Text = "ESP: " .. (espEnabled and "ON" or "OFF")

	for p, _ in pairs(widgets) do
		applyESPEnabled(p, espEnabled)
	end
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		guiVisible = not guiVisible
		gui.Enabled = guiVisible
	end
end)

print("[Heaven ESP] Loaded. RightShift toggles GUI.")
