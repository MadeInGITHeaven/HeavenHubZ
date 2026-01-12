--// Heaven - Full Local Test Suite (ESP restored + improved)
--// LocalScript: StarterPlayer > StarterPlayerScripts

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

-- ===== CONFIG =====
local FOLLOW_RANGE = 100
local FOLLOW_OFFSET = CFrame.new(0, 0, -4)
local FOLLOW_SMOOTH = 0.15 -- seconds time constant for smoothing

local WALK_MIN, WALK_MAX = 8, 80
local FLY_MIN, FLY_MAX = 20, 300
local ESP_UPDATE_INTERVAL = 0.16

local ESP_FOLDER_NAME = "HeavenESP"

-- ===== STATE =====
local guiVisible = true
local espEnabled = true
local followEnabled = false
local flyEnabled = false
local invisibleEnabled = false

local walkSpeed = 16
local flySpeed = 120

-- caches
local playerWidgets = {} -- map player -> {highlight, tagGui, label}
local lastCharacter = nil
local keyState = {}

-- ===== HELPERS =====
local function clamp(v, a, b) if v < a then return a elseif v > b then return v else return v end end
local function expAlpha(dt, tau) return 1 - math.exp(-dt / (tau > 0 and tau or 1e-6)) end

-- ensure local folder for highlight storage (so highlights survive respawns)
local function getESPFolder()
	local f = LocalPlayer:FindFirstChild(ESP_FOLDER_NAME)
	if f and f:IsA("Folder") then return f end
	local folder = Instance.new("Folder")
	folder.Name = ESP_FOLDER_NAME
	folder.Parent = LocalPlayer
	return folder
end

-- ===== UI =====
local gui = Instance.new("ScreenGui", PlayerGui)
gui.Name = "HeavenGui"
gui.ResetOnSpawn = false
gui.Enabled = true

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromOffset(340, 420)
frame.Position = UDim2.new(0, 16, 0.28, 0)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

local header = Instance.new("Frame", frame)
header.Size = UDim2.new(1, -24, 0, 56)
header.Position = UDim2.new(0, 12, 0, 10)
header.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
header.BorderSizePixel = 0
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

local watermark = Instance.new("TextLabel", header)
watermark.Size = UDim2.new(0.7, 0, 1, 0)
watermark.Position = UDim2.new(0.04, 0, 0, 0)
watermark.BackgroundTransparency = 1
watermark.Font = Enum.Font.GothamBlack
watermark.Text = "HEAVEN"
watermark.TextSize = 20
watermark.TextColor3 = Color3.fromRGB(160,170,255)
watermark.TextStrokeTransparency = 0.8
watermark.TextXAlignment = Enum.TextXAlignment.Left

local emblem = Instance.new("Frame", header)
emblem.Size = UDim2.new(0, 44, 0, 44)
emblem.Position = UDim2.new(1, -56, 0.5, -22)
emblem.BackgroundColor3 = Color3.fromRGB(90,100,255)
emblem.BorderSizePixel = 0
Instance.new("UICorner", emblem).CornerRadius = UDim.new(1, 0)

local emblemTxt = Instance.new("TextLabel", emblem)
emblemTxt.Size = UDim2.new(1, 0, 1, 0)
emblemTxt.BackgroundTransparency = 1
emblemTxt.Font = Enum.Font.GothamSemibold
emblemTxt.Text = "H"
emblemTxt.TextColor3 = Color3.fromRGB(240,240,255)
emblemTxt.TextScaled = true

local content = Instance.new("Frame", frame)
content.Size = UDim2.new(1, -24, 1, -96)
content.Position = UDim2.new(0, 12, 0, 74)
content.BackgroundTransparency = 1

-- button factory
local function makeButton(text, y)
	local btn = Instance.new("TextButton", content)
	btn.Size = UDim2.new(1, 0, 0, 40)
	btn.Position = UDim2.new(0, 0, 0, y)
	btn.BackgroundColor3 = Color3.fromRGB(28,28,36)
	btn.TextColor3 = Color3.fromRGB(235,235,235)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 15
	btn.Text = text
	btn.AutoButtonColor = false
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(44,44,56)}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(28,28,36)}):Play()
	end)
	return btn
end

local followBtn = makeButton("FOLLOW: OFF (G)", 0)
local flyBtn = makeButton("FLY: OFF (F)", 48)
local espBtn = makeButton("ESP: ON", 96)

-- slider factory
local function makeSlider(title, y, min, max, init)
	local label = Instance.new("TextLabel", content)
	label.Position = UDim2.new(0, 0, 0, y)
	label.Size = UDim2.new(1, 0, 0, 18)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(220,220,220)
	label.Text = title .. ": " .. tostring(math.floor(init))

	local bar = Instance.new("Frame", content)
	bar.Position = UDim2.new(0, 0, 0, y + 22)
	bar.Size = UDim2.new(1, 0, 0, 18)
	bar.BackgroundColor3 = Color3.fromRGB(38,38,48)
	Instance.new("UICorner", bar).CornerRadius = UDim.new(0,8)

	local fill = Instance.new("Frame", bar)
	fill.Size = UDim2.new((init - min)/(max - min), 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(100,110,255)
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 8)

	local dragging = false

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
	end)
	bar.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)
	bar.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local pos = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
			local val = min + pos * (max - min)
			fill.Size = UDim2.new(pos, 0, 1, 0)
			label.Text = title .. ": " .. tostring(math.floor(val))
			return val
		end
	end)

	-- returns function to set display value programmatically
	local function setVal(v)
		local t = math.clamp((v - min) / (max - min), 0, 1)
		fill:TweenSize(UDim2.new(t, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.12, true)
		label.Text = title .. ": " .. tostring(math.floor(v))
	end

	return setVal, bar, label
end

local setWalkDisplay, walkBar, walkLabel = makeSlider("Walk Speed", 144, WALK_MIN, WALK_MAX, walkSpeed)
local setFlyDisplay, flyBar, flyLabel = makeSlider("Fly Speed", 208, FLY_MIN, FLY_MAX, flySpeed)

-- ===== ESP: create widget per player =====
local function createWidgetForPlayer(player)
	if player == LocalPlayer then return end
	if playerWidgets[player] then return end

	-- Highlight stored under LocalPlayer folder
	local folder = getESPFolder()
	local highlight = Instance.new("Highlight")
	highlight.Name = player.Name
	highlight.Parent = folder
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = espEnabled

	-- Tag references (created when character/Head exists)
	local tagGui, label

	local function attach(char)
		-- attach highlight
		highlight.Adornee = char

		-- choose team-based color if available
		local teamColor = (player.Team and player.Team.TeamColor and player.Team.TeamColor.Color) or Color3.fromRGB(255,60,60)
		highlight.FillColor = teamColor
		highlight.OutlineColor = Color3.fromRGB(255,255,255)
		highlight.FillTransparency = 0.45

		-- create nametag on Head if not present
		local head = char:FindFirstChild("Head")
		if head and not head:FindFirstChild("HeavenNameTag") then
			tagGui = Instance.new("BillboardGui")
			tagGui.Name = "HeavenNameTag"
			tagGui.Adornee = head
			tagGui.AlwaysOnTop = true
			tagGui.Size = UDim2.new(0, 240, 0, 40)
			tagGui.StudsOffset = Vector3.new(0, 2.4, 0)
			tagGui.Parent = head

			local frameTag = Instance.new("Frame", tagGui)
			frameTag.Size = UDim2.new(1, 0, 1, 0)
			frameTag.BackgroundColor3 = Color3.fromRGB(22,22,26)
			frameTag.BackgroundTransparency = 0.18
			frameTag.BorderSizePixel = 0
			Instance.new("UICorner", frameTag).CornerRadius = UDim.new(0, 8)

			label = Instance.new("TextLabel", frameTag)
			label.Size = UDim2.new(1, -12, 1, -6)
			label.Position = UDim2.new(0, 6, 0, 3)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBold
			label.TextSize = 14
			label.TextColor3 = Color3.fromRGB(240,240,240)
			label.TextStrokeTransparency = 0.6
			label.Text = player.Name
		end
	end

	-- attach now if character present
	if player.Character then attach(player.Character) end
	player.CharacterAdded:Connect(function(char) task.wait(0.05); attach(char) end)

	playerWidgets[player] = {
		highlight = highlight,
		tagGuiGetter = function() return tagGui end,
		labelGetter = function() return label end,
	}
end

-- create widgets for existing players
for _, p in ipairs(Players:GetPlayers()) do createWidgetForPlayer(p) end
Players.PlayerAdded:Connect(createWidgetForPlayer)
Players.PlayerRemoving:Connect(function(pl)
	local w = playerWidgets[pl]
	if w then
		if w.highlight and w.highlight.Parent then w.highlight:Destroy() end
		local tg = w.tagGuiGetter and w.tagGuiGetter()
		if tg and tg.Parent then tg:Destroy() end
		playerWidgets[pl] = nil
	end
end)

-- ===== ESP update loop (batched) =====
spawn(function()
	while true do
		local start = tick()
		local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		for player, widget in pairs(playerWidgets) do
			pcall(function()
				local char = player.Character
				if not char then return end
				local hrp = char:FindFirstChild("HumanoidRootPart")
				local hum = char:FindFirstChildOfClass("Humanoid")
				if not hrp or not hum then return end

				-- update nametag text with HP + dist
				local label = widget.labelGetter and widget.labelGetter()
				if label and myHRP then
					local dist = math.floor((hrp.Position - myHRP.Position).Magnitude)
					label.Text = string.format("%s | %d HP | %d m", player.Name, math.max(0, math.floor(hum.Health)), dist)
				end

				-- distance-based transparency for highlight
				local highlight = widget.highlight
				if highlight and highlight.Parent and myHRP then
					local dist = (hrp.Position - myHRP.Position).Magnitude
					local t = clamp(dist / FOLLOW_RANGE, 0, 1)
					-- closer => less transparent
					highlight.FillTransparency = 0.15 + 0.7 * t
					highlight.Enabled = espEnabled
					-- if tag exists, enable/disable
					local tg = widget.tagGuiGetter and widget.tagGuiGetter()
					if tg and tg.Parent then
						tg.Enabled = espEnabled
					end
				end
			end)
		end
		local elapsed = tick() - start
		task.wait(math.max(0.04, ESP_UPDATE_INTERVAL - elapsed))
	end
end)

-- ===== Invisibility (local) =====
local function setInvisible(state)
	local char = LocalPlayer.Character
	if not char then return end
	for _, obj in ipairs(char:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.LocalTransparencyModifier = state and 1 or 0
		elseif obj:IsA("Decal") then
			obj.Transparency = state and 1 or 0
		end
	end
end

-- ===== Flight (BodyVelocity/BodyGyro) =====
local bodyVel, bodyGyro

local function startFly()
	local char = LocalPlayer.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return end

	-- ensure existing removed
	if bodyVel then bodyVel:Destroy() bodyVel = nil end
	if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end

	hum.PlatformStand = true

	bodyVel = Instance.new("BodyVelocity")
	bodyVel.Name = "HeavenBodyVelocity"
	bodyVel.MaxForce = Vector3.new(1e9, 1e9, 1e9)
	bodyVel.Velocity = Vector3.new(0,0,0)
	bodyVel.Parent = hrp

	bodyGyro = Instance.new("BodyGyro")
	bodyGyro.Name = "HeavenBodyGyro"
	bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
	bodyGyro.CFrame = hrp.CFrame
	bodyGyro.Parent = hrp
end

local function stopFly()
	if bodyVel then bodyVel:Destroy() bodyVel = nil end
	if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
	local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.PlatformStand = false
		hum.WalkSpeed = walkSpeed
	end
end

-- ===== FOLLOW helper =====
local function getNearestPlayer()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	local closest, shortest = nil, FOLLOW_RANGE
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and p.Character then
			local hrp2 = p.Character:FindFirstChild("HumanoidRootPart")
			local hum = p.Character:FindFirstChildOfClass("Humanoid")
			if hrp2 and hum and hum.Health > 0 then
				local d = (hrp2.Position - hrp.Position).Magnitude
				if d < shortest then
					shortest = d
					closest = p
				end
			end
		end
	end
	return closest
end

-- ===== UI behaviour handlers =====
espBtn.MouseButton1Click:Connect(function()
	espEnabled = not espEnabled
	espBtn.Text = "ESP: " .. (espEnabled and "ON" or "OFF")
	-- immediate toggle highlights & tags
	for _, widget in pairs(playerWidgets) do
		if widget.highlight and widget.highlight.Parent then widget.highlight.Enabled = espEnabled end
		local tg = widget.tagGuiGetter and widget.tagGuiGetter()
		if tg and tg.Parent then tg.Enabled = espEnabled end
	end
end)

followBtn.MouseButton1Click:Connect(function()
	followEnabled = not followEnabled
	followBtn.Text = "FOLLOW: " .. (followEnabled and "ON (G)" or "OFF (G)")
end)

flyBtn.MouseButton1Click:Connect(function()
	flyEnabled = not flyEnabled
	flyBtn.Text = "FLY: " .. (flyEnabled and "ON (F)" or "OFF (F)")
	if flyEnabled then startFly() else stopFly() end
end)

-- slider interactions
-- Walk slider
local function setWalkSpeed(v)
	walkSpeed = v
	setWalkDisplay and setWalkDisplay(v) -- safe call if exists in previous script (not required)
	local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if hum and not flyEnabled then
		hum.WalkSpeed = walkSpeed
	end
end
-- Fly slider
local function setFlySpeed(v)
	flySpeed = v
	setFlyDisplay and setFlyDisplay(v)
end

-- Note: we built makeSlider to return setVal earlier; connect those:
-- the earlier variables setWalkDisplay, setFlyDisplay exist in this code because we used the factory earlier
if setWalkDisplay then setWalkDisplay(walkSpeed) end
if setFlyDisplay then setFlyDisplay(flySpeed) end

-- ===== Input handling =====
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		keyState[input.KeyCode] = true
		if input.KeyCode == Enum.KeyCode.G then
			followEnabled = not followEnabled
			followBtn.Text = "FOLLOW: " .. (followEnabled and "ON (G)" or "OFF (G)")
		elseif input.KeyCode == Enum.KeyCode.F then
			flyEnabled = not flyEnabled
			flyBtn.Text = "FLY: " .. (flyEnabled and "ON (F)" or "OFF (F)")
			if flyEnabled then startFly() else stopFly() end
		elseif input.KeyCode == Enum.KeyCode.RightShift then
			guiVisible = not guiVisible
			gui.Enabled = guiVisible
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		keyState[input.KeyCode] = nil
	end
end)

-- allow clicking on slider bars to set values (improve UX)
-- walkBar & flyBar are defined earlier from makeSlider return; attach InputChanged to update values
if walkBar then
	local dragging = false
	walkBar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end end)
	walkBar.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
	walkBar.InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
			local pos = math.clamp((i.Position.X - walkBar.AbsolutePosition.X) / walkBar.AbsoluteSize.X, 0, 1)
			local val = WALK_MIN + pos * (WALK_MAX - WALK_MIN)
			setWalkSpeed(val)
			setWalkDisplay and setWalkDisplay(val)
		end
	end)
end

if flyBar then
	local dragging = false
	flyBar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end end)
	flyBar.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
	flyBar.InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
			local pos = math.clamp((i.Position.X - flyBar.AbsolutePosition.X) / flyBar.AbsoluteSize.X, 0, 1)
			local val = FLY_MIN + pos * (FLY_MAX - FLY_MIN)
			setFlySpeed(val)
			setFlyDisplay and setFlyDisplay(val)
		end
	end)
end

-- ===== Main loops =====
-- Movement / flight / follow loop (RenderStepped)
RunService.RenderStepped:Connect(function(dt)
	-- apply walk speed (non-flying)
	local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if hum and not flyEnabled then
		if hum.WalkSpeed ~= walkSpeed then hum.WalkSpeed = walkSpeed end
	end

	-- flight velocity & gyro if active
	if flyEnabled and bodyVel and bodyGyro then
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local dir = Vector3.new()
			if keyState[Enum.KeyCode.W] then dir = dir + Camera.CFrame.LookVector end
			if keyState[Enum.KeyCode.S] then dir = dir - Camera.CFrame.LookVector end
			if keyState[Enum.KeyCode.A] then dir = dir - Camera.CFrame.RightVector end
			if keyState[Enum.KeyCode.D] then dir = dir + Camera.CFrame.RightVector end
			if keyState[Enum.KeyCode.Space] then dir = dir + Vector3.yAxis end
			if keyState[Enum.KeyCode.LeftShift] then dir = dir - Vector3.yAxis end

			local velocity = Vector3.new()
			if dir.Magnitude > 0 then
				velocity = dir.Unit * flySpeed
			end
			bodyVel.Velocity = velocity
			bodyGyro.CFrame = Camera.CFrame
		end
	end

	-- follow logic with exponential smoothing
	if followEnabled then
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local target = getNearestPlayer()
			if target and target.Character then
				local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
				if targetHRP then
					local desired = targetHRP.CFrame * FOLLOW_OFFSET
					local alpha = expAlpha(dt, FOLLOW_SMOOTH)
					hrp.CFrame = hrp.CFrame:Lerp(desired, alpha)
				end
			end
		end
	end
end)

-- periodic housekeeping & ensure body objects are present when flying
RunService.Heartbeat:Connect(function()
	-- ensure bodyVel/bodyGyro objects exist if flyEnabled
	if flyEnabled and (not bodyVel or not bodyGyro) then
		-- try to start fly (will create them)
		startFly()
	end
	-- ensure invisibility if toggled
	if invisibleEnabled then setInvisible(true) end
end)

-- attach on respawn to reapply walkSpeed/fly PlatformStand etc
LocalPlayer.CharacterAdded:Connect(function(char)
	task.wait(0.08)
	-- reapply walk speed if not flying
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = walkSpeed
		hum.PlatformStand = flyEnabled
	end
	-- reapply invisibility local modifier
	if invisibleEnabled then
		task.wait(0.05)
		setInvisible(true)
	end
end)

-- Final initial UI text state
espBtn.Text = "ESP: " .. (espEnabled and "ON" or "OFF")
followBtn.Text = "FOLLOW: " .. (followEnabled and "ON (G)" or "OFF (G)")
flyBtn.Text = "FLY: " .. (flyEnabled and "ON (F)" or "OFF (F)")
setWalkDisplay and setWalkDisplay(walkSpeed)
setFlyDisplay and setFlyDisplay(flySpeed)

print("[Heaven] ESP + GUI + Flight + Follow loaded (local test)")
