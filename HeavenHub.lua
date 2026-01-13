--// Heaven - Working Local Test Suite
--// ESP + Nametags + Smooth Follow + Flight (BodyVelocity/BodyGyro) + WalkSpeed + FlySpeed + Clean GUI
--// Place in StarterPlayer > StarterPlayerScripts (LocalScript)

---------------- SERVICES ----------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

---------------- CONFIG ----------------
local ESP_FOLDER_NAME = "HeavenESPFolder"

local FOLLOW_RANGE = 100
local FOLLOW_OFFSET = CFrame.new(0, 0, -4)
local FOLLOW_SMOOTH_TIME = 0.15 -- smaller = snappier

local WALK_MIN, WALK_MAX = 8, 80
local FLY_MIN, FLY_MAX = 20, 300

local ESP_UPDATE_INTERVAL = 0.2

---------------- STATE ----------------
local guiVisible = true
local espEnabled = true
local followEnabled = false
local flyEnabled = false

local walkSpeed = 16
local flySpeed = 120

local keyDown = {} -- keyboard state

-- flight movers
local bodyVel, bodyGyro

-- per-player widgets cache
local widgets = {} -- [player] = {highlight=Highlight, tag=BillboardGui, label=TextLabel}

---------------- SMALL HELPERS ----------------
local function clamp(v, a, b)
	if v < a then return a end
	if v > b then return b end
	return v
end

local function expAlpha(dt, tau)
	-- frame-rate independent smoothing
	return 1 - math.exp(-dt / (tau > 0 and tau or 1e-6))
end

local function getMyHRP()
	local char = LocalPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function getMyHumanoid()
	local char = LocalPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

---------------- GUI ----------------
local gui = Instance.new("ScreenGui")
gui.Name = "HeavenGui"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local frame = Instance.new("Frame")
frame.Parent = gui
frame.Size = UDim2.fromOffset(340, 420)
frame.Position = UDim2.new(0, 16, 0.28, 0)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

local header = Instance.new("Frame")
header.Parent = frame
header.Size = UDim2.new(1, -24, 0, 56)
header.Position = UDim2.new(0, 12, 0, 10)
header.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
header.BorderSizePixel = 0
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

local watermark = Instance.new("TextLabel")
watermark.Parent = header
watermark.BackgroundTransparency = 1
watermark.Size = UDim2.new(1, -70, 1, 0)
watermark.Position = UDim2.new(0, 14, 0, 0)
watermark.Font = Enum.Font.GothamBlack
watermark.Text = "HEAVEN"
watermark.TextSize = 20
watermark.TextColor3 = Color3.fromRGB(160, 170, 255)
watermark.TextStrokeTransparency = 0.8
watermark.TextXAlignment = Enum.TextXAlignment.Left

local emblem = Instance.new("Frame")
emblem.Parent = header
emblem.Size = UDim2.new(0, 44, 0, 44)
emblem.Position = UDim2.new(1, -56, 0.5, -22)
emblem.BackgroundColor3 = Color3.fromRGB(90, 100, 255)
emblem.BorderSizePixel = 0
Instance.new("UICorner", emblem).CornerRadius = UDim.new(1, 0)

local emblemText = Instance.new("TextLabel")
emblemText.Parent = emblem
emblemText.BackgroundTransparency = 1
emblemText.Size = UDim2.new(1, 0, 1, 0)
emblemText.Font = Enum.Font.GothamSemibold
emblemText.Text = "H"
emblemText.TextScaled = true
emblemText.TextColor3 = Color3.fromRGB(240, 240, 255)
emblemText.TextStrokeTransparency = 0.8

local content = Instance.new("Frame")
content.Parent = frame
content.BackgroundTransparency = 1
content.Size = UDim2.new(1, -24, 1, -96)
content.Position = UDim2.new(0, 12, 0, 74)

local function makeButton(text, y)
	local btn = Instance.new("TextButton")
	btn.Parent = content
	btn.Size = UDim2.new(1, 0, 0, 40)
	btn.Position = UDim2.new(0, 0, 0, y)
	btn.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 15
	btn.TextColor3 = Color3.fromRGB(235, 235, 235)
	btn.Text = text
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

	return btn
end

local function makeSlider(title, y, min, max, initial, onChange)
	local label = Instance.new("TextLabel")
	label.Parent = content
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 18)
	label.Position = UDim2.new(0, 0, 0, y)
	label.Font = Enum.Font.Gotham
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(220, 220, 220)
	label.TextXAlignment = Enum.TextXAlignment.Left

	local bar = Instance.new("Frame")
	bar.Parent = content
	bar.Size = UDim2.new(1, 0, 0, 18)
	bar.Position = UDim2.new(0, 0, 0, y + 22)
	bar.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
	bar.BorderSizePixel = 0
	Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 8)

	local fill = Instance.new("Frame")
	fill.Parent = bar
	fill.BackgroundColor3 = Color3.fromRGB(100, 110, 255)
	fill.BorderSizePixel = 0
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 8)

	local function setValue(v)
		v = clamp(v, min, max)
		local t = (v - min) / (max - min)
		fill.Size = UDim2.new(t, 0, 1, 0)
		label.Text = string.format("%s: %d", title, math.floor(v))
		onChange(v)
	end

	local dragging = false
	bar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			local pos = clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
			setValue(min + pos * (max - min))
		end
	end)
	bar.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	bar.InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
			local pos = clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
			setValue(min + pos * (max - min))
		end
	end)

	setValue(initial)
	return setValue
end

-- Buttons
local btnFollow = makeButton("FOLLOW: OFF (G)", 0)
local btnFly = makeButton("FLY: OFF (F)", 48)
local btnESP = makeButton("ESP: ON", 96)

-- Sliders
localreport = nil
local setWalk = makeSlider("Walk Speed", 150, WALK_MIN, WALK_MAX, walkSpeed, function(v)
	walkSpeed = v
	local hum = getMyHumanoid()
	if hum and not flyEnabled then
		hum.WalkSpeed = walkSpeed
	end
end)

local setFly = makeSlider("Fly Speed", 220, FLY_MIN, FLY_MAX, flySpeed, function(v)
	flySpeed = v
end)

---------------- ESP + NAMETAGS ----------------
local function getESPFolder()
	local folder = LocalPlayer:FindFirstChild(ESP_FOLDER_NAME)
	if folder and folder:IsA("Folder") then return folder end
	folder = Instance.new("Folder")
	folder.Name = ESP_FOLDER_NAME
	folder.Parent = LocalPlayer
	return folder
end

local function ensureWidget(player)
	if player == LocalPlayer then return end
	if widgets[player] then return end

	local folder = getESPFolder()

	local hl = Instance.new("Highlight")
	hl.Name = player.Name .. "_HL"
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.OutlineColor = Color3.fromRGB(255,255,255)
	hl.FillTransparency = 0.45
	hl.Enabled = espEnabled
	hl.Parent = folder

	local tag, label

	local function attach(char)
		hl.Adornee = char

		local teamColor = (player.Team and player.Team.TeamColor and player.Team.TeamColor.Color) or Color3.fromRGB(255, 60, 60)
		hl.FillColor = teamColor
		hl.Enabled = espEnabled

		local head = char:FindFirstChild("Head")
		if head then
			-- (re)create nametag if missing
			if not head:FindFirstChild("HeavenNameTag") then
				tag = Instance.new("BillboardGui")
				tag.Name = "HeavenNameTag"
				tag.Adornee = head
				tag.AlwaysOnTop = true
				tag.Size = UDim2.new(0, 240, 0, 40)
				tag.StudsOffset = Vector3.new(0, 2.4, 0)
				tag.Parent = head

				local bg = Instance.new("Frame", tag)
				bg.Size = UDim2.new(1, 0, 1, 0)
				bg.BackgroundColor3 = Color3.fromRGB(22,22,26)
				bg.BackgroundTransparency = 0.18
				bg.BorderSizePixel = 0
				Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

				label = Instance.new("TextLabel", bg)
				label.Size = UDim2.new(1, -12, 1, -6)
				label.Position = UDim2.new(0, 6, 0, 3)
				label.BackgroundTransparency = 1
				label.Font = Enum.Font.GothamBold
				label.TextSize = 14
				label.TextColor3 = Color3.fromRGB(240,240,240)
				label.TextStrokeTransparency = 0.6
				label.Text = player.Name
			else
				-- if it exists, grab it
				tag = head:FindFirstChild("HeavenNameTag")
				local bg = tag and tag:FindFirstChildOfClass("Frame")
				label = bg and bg:FindFirstChildOfClass("TextLabel")
			end

			if tag then
				tag.Enabled = espEnabled
			end
		end
	end

	if player.Character then
		attach(player.Character)
	end

	player.CharacterAdded:Connect(function(char)
		task.wait(0.05)
		attach(char)
	end)

	widgets[player] = { highlight = hl, tag = function() return tag end, label = function() return label end }
end

for _, p in ipairs(Players:GetPlayers()) do
	ensureWidget(p)
end
Players.PlayerAdded:Connect(ensureWidget)
Players.PlayerRemoving:Connect(function(p)
	local w = widgets[p]
	if w then
		if w.highlight and w.highlight.Parent then w.highlight:Destroy() end
		local tg = w.tag and w.tag()
		if tg and tg.Parent then tg:Destroy() end
		widgets[p] = nil
	end
end)

-- Update ESP text & transparency periodically
task.spawn(function()
	while true do
		local myHRP = getMyHRP()
		for p, w in pairs(widgets) do
			local ok = pcall(function()
				local char = p.Character
				if not char or not myHRP then return end
				local hrp = char:FindFirstChild("HumanoidRootPart")
				local hum = char:FindFirstChildOfClass("Humanoid")
				if not hrp or not hum then return end

				-- update label
				local lbl = w.label and w.label()
				if lbl then
					local dist = math.floor((hrp.Position - myHRP.Position).Magnitude)
					lbl.Text = string.format("%s | %d HP | %dm", p.Name, math.floor(math.max(hum.Health, 0)), dist)
				end

				-- distance-based transparency
				local hl = w.highlight
				if hl then
					local dist = (hrp.Position - myHRP.Position).Magnitude
					local t = clamp(dist / FOLLOW_RANGE, 0, 1)
					hl.FillTransparency = 0.15 + 0.7 * t
					hl.Enabled = espEnabled
				end

				local tg = w.tag and w.tag()
				if tg then
					tg.Enabled = espEnabled
				end
			end)
		end
		task.wait(ESP_UPDATE_INTERVAL)
	end
end)

---------------- FOLLOW ----------------
local function getNearestPlayer()
	local myHRP = getMyHRP()
	if not myHRP then return nil end

	local closest, best = nil, FOLLOW_RANGE
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and p.Character then
			local hrp = p.Character:FindFirstChild("HumanoidRootPart")
			local hum = p.Character:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.Health > 0 then
				local d = (hrp.Position - myHRP.Position).Magnitude
				if d < best then
					best = d
					closest = p
				end
			end
		end
	end
	return closest
end

---------------- FLIGHT ----------------
local function startFly()
	local char = LocalPlayer.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return end

	-- cleanup first
	if bodyVel then bodyVel:Destroy() bodyVel = nil end
	if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end

	hum.PlatformStand = true

	bodyVel = Instance.new("BodyVelocity")
	bodyVel.MaxForce = Vector3.new(1e9, 1e9, 1e9)
	bodyVel.Velocity = Vector3.new(0, 0, 0)
	bodyVel.Parent = hrp

	bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
	bodyGyro.CFrame = Camera.CFrame
	bodyGyro.Parent = hrp
end

local function stopFly()
	if bodyVel then bodyVel:Destroy() bodyVel = nil end
	if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end

	local hum = getMyHumanoid()
	if hum then
		hum.PlatformStand = false
		hum.WalkSpeed = walkSpeed
	end
end

---------------- INPUT ----------------
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end

	if input.UserInputType == Enum.UserInputType.Keyboard then
		keyDown[input.KeyCode] = true

		if input.KeyCode == Enum.KeyCode.RightShift then
			guiVisible = not guiVisible
			gui.Enabled = guiVisible
		elseif input.KeyCode == Enum.KeyCode.G then
			followEnabled = not followEnabled
			btnFollow.Text = "FOLLOW: " .. (followEnabled and "ON (G)" or "OFF (G)")
		elseif input.KeyCode == Enum.KeyCode.F then
			flyEnabled = not flyEnabled
			btnFly.Text = "FLY: " .. (flyEnabled and "ON (F)" or "OFF (F)")
			if flyEnabled then startFly() else stopFly() end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		keyDown[input.KeyCode] = nil
	end
end)

-- button clicks
btnFollow.MouseButton1Click:Connect(function()
	followEnabled = not followEnabled
	btnFollow.Text = "FOLLOW: " .. (followEnabled and "ON (G)" or "OFF (G)")
end)

btnFly.MouseButton1Click:Connect(function()
	flyEnabled = not flyEnabled
	btnFly.Text = "FLY: " .. (flyEnabled and "ON (F)" or "OFF (F)")
	if flyEnabled then startFly() else stopFly() end
end)

btnESP.MouseButton1Click:Connect(function()
	espEnabled = not espEnabled
	btnESP.Text = "ESP: " .. (espEnabled and "ON" or "OFF")
	-- immediate apply
	for _, w in pairs(widgets) do
		if w.highlight then w.highlight.Enabled = espEnabled end
		local tg = w.tag and w.tag()
		if tg then tg.Enabled = espEnabled end
	end
end)

---------------- MAIN LOOP ----------------
RunService.RenderStepped:Connect(function(dt)
	-- maintain walk speed while grounded
	local hum = getMyHumanoid()
	if hum and not flyEnabled then
		if hum.WalkSpeed ~= walkSpeed then
			hum.WalkSpeed = walkSpeed
		end
	end

	-- flight movement
	if flyEnabled and bodyVel and bodyGyro then
		local dir = Vector3.new(0, 0, 0)
		if keyDown[Enum.KeyCode.W] then dir += Camera.CFrame.LookVector end
		if keyDown[Enum.KeyCode.S] then dir -= Camera.CFrame.LookVector end
		if keyDown[Enum.KeyCode.A] then dir -= Camera.CFrame.RightVector end
		if keyDown[Enum.KeyCode.D] then dir += Camera.CFrame.RightVector end
		if keyDown[Enum.KeyCode.Space] then dir += Vector3.yAxis end
		if keyDown[Enum.KeyCode.LeftShift] then dir -= Vector3.yAxis end

		if dir.Magnitude > 0 then
			bodyVel.Velocity = dir.Unit * flySpeed
		else
			bodyVel.Velocity = Vector3.new(0, 0, 0)
		end
		bodyGyro.CFrame = Camera.CFrame
	end

	-- follow smoothing
	if followEnabled then
		local myHRP = getMyHRP()
		if myHRP then
			local target = getNearestPlayer()
			if target and target.Character then
				local thrp = target.Character:FindFirstChild("HumanoidRootPart")
				if thrp then
					local desired = thrp.CFrame * FOLLOW_OFFSET
					local alpha = expAlpha(dt, FOLLOW_SMOOTH_TIME)
					myHRP.CFrame = myHRP.CFrame:Lerp(desired, alpha)
				end
			end
		end
	end
end)

-- Respawn handling
LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.1)
	local hum = getMyHumanoid()
	if hum then
		hum.WalkSpeed = walkSpeed
		hum.PlatformStand = flyEnabled
	end
	if flyEnabled then
		startFly()
	end
end)

print("[Heaven] Loaded. Keys: G=Follow, F=Fly, RightShift=GUI. Sliders: Walk/Fly speed.")
