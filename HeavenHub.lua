--// Heaven: Upgraded Local Test Suite
--// ESP + Nametags + Smooth Follow + Flight + Clean UI + Animated Toggles
-- Place in StarterPlayer > StarterPlayerScripts (LocalScript)

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Config
local ESP_FOLDER_NAME = "HeavenESP"
local BASE_FILL_COLOR = Color3.fromRGB(255, 60, 60)
local OUTLINE_COLOR = Color3.fromRGB(255, 255, 255)

local FOLLOW_RANGE = 100
local FOLLOW_OFFSET = CFrame.new(0, 0, -4)
local SMOOTH_TIME = 0.15 -- smoothing time constant

local ESP_UPDATE_INTERVAL = 0.18 -- how often to update names/dist/alpha

-- State
local espEnabled = true
local followEnabled = false
local flyEnabled = false
local guiVisible = true
local invisibleEnabled = false

-- Flight settings
local flySpeed = 50 -- default
local flySpeedMin, flySpeedMax = 10, 200
local flyUpDownSpeed = 40

-- internal caches
local lastCharacter = nil
local playerWidgets = {} -- [player] = {highlight = Instance, tag = BillboardGui, label = TextLabel}
local keyState = {}

-- Helpers
local function clamp(v, a, b) if v < a then return a elseif v > b then return b else return v end end

-- GUI creation (cleaner look)
local gui = Instance.new("ScreenGui")
gui.Name = "HeavenGui"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui
gui.Enabled = true

local frame = Instance.new("Frame")
frame.Name = "MainFrame"
frame.Size = UDim2.fromOffset(320, 380)
frame.Position = UDim2.new(0, 16, 0.32, 0)
frame.AnchorPoint = Vector2.new(0, 0)
frame.BackgroundTransparency = 0
frame.BackgroundColor3 = Color3.fromRGB(18,18,20)
frame.BorderSizePixel = 0
frame.Parent = gui
frame.Active = true
frame.Draggable = true
frame.ClipsDescendants = false
local corner = Instance.new("UICorner", frame)
corner.CornerRadius = UDim.new(0, 14)

-- subtle gradient bar
local topBar = Instance.new("Frame", frame)
topBar.Size = UDim2.new(1, -20, 0, 48)
topBar.Position = UDim2.new(0, 10, 0, 10)
topBar.BackgroundTransparency = 0
topBar.BackgroundColor3 = Color3.fromRGB(36,36,44)
topBar.BorderSizePixel = 0
topBar.ClipsDescendants = true
topBar.AnchorPoint = Vector2.new(0,0)
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 12)

-- watermark (cooler)
local watermark = Instance.new("TextLabel", topBar)
watermark.Name = "Watermark"
watermark.Size = UDim2.new(0.7, 0, 1, 0)
watermark.Position = UDim2.new(0.04, 0, 0, 0)
watermark.BackgroundTransparency = 1
watermark.Font = Enum.Font.GothamBlack
watermark.Text = "HEAVEN"
watermark.TextSize = 26
watermark.TextColor3 = Color3.fromRGB(150,160,255)
watermark.TextTransparency = 0
watermark.TextStrokeTransparency = 0.7
watermark.TextXAlignment = Enum.TextXAlignment.Left

-- small emblem circle
local emblem = Instance.new("Frame", topBar)
emblem.Size = UDim2.new(0, 38, 0, 38)
emblem.Position = UDim2.new(1, -46, 0.5, -19)
emblem.BackgroundColor3 = Color3.fromRGB(85, 95, 255)
emblem.BorderSizePixel = 0
Instance.new("UICorner", emblem).CornerRadius = UDim.new(1, 0)
-- emblem inner glow
local eLabel = Instance.new("TextLabel", emblem)
eLabel.Size = UDim2.fromScale(1, 1)
eLabel.BackgroundTransparency = 1
eLabel.Text = "H"
eLabel.Font = Enum.Font.GothamSemibold
eLabel.TextScaled = true
eLabel.TextColor3 = Color3.fromRGB(235,235,255)
eLabel.TextStrokeTransparency = 0.7

-- content area
local content = Instance.new("Frame", frame)
content.Position = UDim2.new(0, 12, 0, 70)
content.Size = UDim2.new(1, -24, 1, -84)
content.BackgroundTransparency = 1

local function makeButton(text, y)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 42)
	btn.Position = UDim2.new(0, 0, 0, y)
	btn.BackgroundColor3 = Color3.fromRGB(28,28,34)
	btn.TextColor3 = Color3.fromRGB(235,235,235)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 16
	btn.Text = text
	btn.AutoButtonColor = false
	btn.Parent = content
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

	local hoverTween = TweenService:Create(btn, TweenInfo.new(0.14, Enum.EasingStyle.Quad), {
		BackgroundColor3 = Color3.fromRGB(44,44,54),
		Size = UDim2.new(1, 6, 0, 44),
		Position = UDim2.new(0, -3, 0, y - 2)
	})
	local leaveTween = TweenService:Create(btn, TweenInfo.new(0.14, Enum.EasingStyle.Quad), {
		BackgroundColor3 = Color3.fromRGB(28,28,34),
		Size = UDim2.new(1, 0, 0, 42),
		Position = UDim2.new(0, 0, 0, y)
	})

	btn.MouseEnter:Connect(function() hoverTween:Play() end)
	btn.MouseLeave:Connect(function() leaveTween:Play() end)

	return btn
end

-- Buttons & controls positions
local btnESP = makeButton("ESP: ON", 0)
local btnFollow = makeButton("FOLLOW: OFF (G)", 56)
local btnFly = makeButton("FLY: OFF (F)", 112)

-- fly speed slider UI
local sliderFrame = Instance.new("Frame", content)
sliderFrame.Size = UDim2.new(1, 0, 0, 56)
sliderFrame.Position = UDim2.new(0, 0, 0, 178)
sliderFrame.BackgroundTransparency = 1
local sliderLabel = Instance.new("TextLabel", sliderFrame)
sliderLabel.Size = UDim2.new(1, 0, 0, 18)
sliderLabel.Position = UDim2.new(0, 0, 0, 0)
sliderLabel.BackgroundTransparency = 1
sliderLabel.Font = Enum.Font.Gotham
sliderLabel.TextSize = 14
sliderLabel.Text = "Fly Speed: " .. tostring(math.floor(flySpeed))
sliderLabel.TextColor3 = Color3.fromRGB(220,220,220)
sliderLabel.TextXAlignment = Enum.TextXAlignment.Left

local sliderBar = Instance.new("Frame", sliderFrame)
sliderBar.Size = UDim2.new(1, 0, 0, 18)
sliderBar.Position = UDim2.new(0, 0, 0, 26)
sliderBar.BackgroundColor3 = Color3.fromRGB(40,40,48)
Instance.new("UICorner", sliderBar).CornerRadius = UDim.new(0, 8)

local knob = Instance.new("Frame", sliderBar)
knob.Size = UDim2.new((flySpeed - flySpeedMin) / (flySpeedMax - flySpeedMin), 0, 1, 0)
knob.BackgroundColor3 = Color3.fromRGB(100,110,255)
Instance.new("UICorner", knob).CornerRadius = UDim.new(0, 8)

-- helper to set knob position and label
local function updateSliderDisplay()
	local t = (flySpeed - flySpeedMin) / (flySpeedMax - flySpeedMin)
	t = clamp(t, 0, 1)
	knob:TweenSize(UDim2.new(t, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.12, true)
	sliderLabel.Text = "Fly Speed: " .. tostring(math.floor(flySpeed))
end

-- attach drag to slider
local dragging = false
local function sliderInputBegan(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		return true
	end
end
local function sliderInputEnded(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
		return true
	end
end
sliderBar.InputBegan:Connect(sliderInputBegan)
sliderBar.InputEnded:Connect(sliderInputEnded)
sliderBar.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local abs = sliderBar.AbsoluteSize.X
		local pos = math.clamp((input.Position.X - sliderBar.AbsolutePosition.X) / abs, 0, 1)
		flySpeed = flySpeedMin + pos * (flySpeedMax - flySpeedMin)
		updateSliderDisplay()
	end
end)

updateSliderDisplay()

-- Utility: create or get ESP folder under LocalPlayer
local function getESPFolder()
	local f = LocalPlayer:FindFirstChild(ESP_FOLDER_NAME)
	if f and f:IsA("Folder") then return f end
	local folder = Instance.new("Folder")
	folder.Name = ESP_FOLDER_NAME
	folder.Parent = LocalPlayer
	return folder
end

-- Create per-player widgets (highlight + nametag)
local function createPlayerWidget(player)
	if player == LocalPlayer then return end
	if playerWidgets[player] then return end

	local folder = getESPFolder()
	local existing = folder:FindFirstChild(player.Name)
	-- create highlight stored in LocalPlayer folder
	local highlight = Instance.new("Highlight")
	highlight.Name = player.Name
	highlight.Parent = folder
	highlight.Enabled = espEnabled
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

	-- nametag will be parented to Head when available; we keep label reference
	local tagGui, label

	local function attachChar(char)
		pcall(function()
			highlight.Adornee = char
			-- set color to team if available
			local teamColor = (player.Team and player.Team.TeamColor) and player.Team.TeamColor.Color or BASE_FILL_COLOR
			highlight.FillColor = teamColor
			highlight.OutlineColor = OUTLINE_COLOR
			highlight.FillTransparency = 0.5

			-- create nametag if missing
			local head = char:FindFirstChild("Head")
			if head and not head:FindFirstChild("HeavenNameTag") then
				tagGui = Instance.new("BillboardGui")
				tagGui.Name = "HeavenNameTag"
				tagGui.Adornee = head
				tagGui.Size = UDim2.new(0, 220, 0, 36)
				tagGui.StudsOffset = Vector3.new(0, 2.4, 0)
				tagGui.AlwaysOnTop = true
				tagGui.Parent = head

				local frame = Instance.new("Frame", tagGui)
				frame.Size = UDim2.new(1, 0, 1, 0)
				frame.BackgroundTransparency = 0.25
				frame.BackgroundColor3 = Color3.fromRGB(20,20,26)
				frame.BorderSizePixel = 0
				Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

				label = Instance.new("TextLabel", frame)
				label.Size = UDim2.new(1, -12, 1, -6)
				label.Position = UDim2.new(0, 6, 0, 3)
				label.BackgroundTransparency = 1
				label.Font = Enum.Font.GothamBold
				label.TextSize = 14
				label.TextColor3 = Color3.fromRGB(240,240,240)
				label.TextStrokeTransparency = 0.6
				label.TextXAlignment = Enum.TextXAlignment.Center
				label.Text = player.Name
			end
		end)
	end

	-- attempt attach now if character exists
	if player.Character then attachChar(player.Character) end
	player.CharacterAdded:Connect(attachChar)

	playerWidgets[player] = {
		highlight = highlight,
		tagGui = function() return tagGui end,
		label = function() return label end,
	}

	-- cleanup when player leaves (PlayerRemoving handled later)
end

-- create widgets for existing players
for _, p in ipairs(Players:GetPlayers()) do createPlayerWidget(p) end
Players.PlayerAdded:Connect(createPlayerWidget)
Players.PlayerRemoving:Connect(function(pl)
	local w = playerWidgets[pl]
	if w then
		if w.highlight and w.highlight.Parent then w.highlight:Destroy() end
		local tg = w.tagGui and w.tagGui()
		if tg and tg.Parent then tg:Destroy() end
		playerWidgets[pl] = nil
	end
end)

-- efficiency: update nametags & dynamic transparency on an interval
spawn(function()
	while true do
		local start = tick()
		for player, widget in pairs(playerWidgets) do
			pcall(function()
				local char = player.Character
				if not char then return end
				local hrp = char:FindFirstChild("HumanoidRootPart")
				local hum = char:FindFirstChildOfClass("Humanoid")
				if not hrp or not hum then return end
				local label = widget.label and widget.label()
				if label then
					local dist = (hrp.Position - (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position or hrp.Position)).Magnitude
					label.Text = string.format("%s | %d HP | %d m", player.Name, math.floor(hum.Health), math.floor(dist))
				end
				-- dynamic fill transparency (closer -> less transparent)
				local highlight = widget.highlight
				if highlight and highlight.Parent then
					local dist = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and (hrp.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude or FOLLOW_RANGE
					local t = clamp(dist / FOLLOW_RANGE, 0, 1)
					-- closer -> lower transparency
					highlight.FillTransparency = 0.15 + 0.7 * t
				end
			end)
		end
		local elapsed = tick() - start
		task.wait(math.max(0.06, ESP_UPDATE_INTERVAL - elapsed))
	end
end)

-- invisibility (local-only visual)
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

-- flight logic
local function disableCollisionOnce(character)
	if not character then return end
	if character == lastCharacter then return end
	lastCharacter = character
	for _, obj in ipairs(character:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.CanCollide = false
		end
	end
end

-- key tracking for flight movement
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		keyState[input.KeyCode] = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		keyState[input.KeyCode] = nil
	end
end)

-- follow helper (exponential smoothing)
local function expAlpha(dt, tau)
	-- returns smoothing alpha between 0..1 given time step dt and time constant tau
	-- alpha = 1 - exp(-dt / tau)
	return 1 - math.exp(-dt / (tau > 0 and tau or 0.0001))
end

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

-- Button actions
btnESP.MouseButton1Click:Connect(function()
	espEnabled = not espEnabled
	btnESP.Text = "ESP: " .. (espEnabled and "ON" or "OFF")
	for _, h in ipairs(getESPFolder():GetChildren()) do
		if h:IsA("Highlight") then
			h.Enabled = espEnabled
		end
	end
end)

btnFollow.MouseButton1Click:Connect(function()
	followEnabled = not followEnabled
	btnFollow.Text = "FOLLOW: " .. (followEnabled and "ON (G)" or "OFF (G)")
end)

btnFly.MouseButton1Click:Connect(function()
	flyEnabled = not flyEnabled
	btnFly.Text = "FLY: " .. (flyEnabled and "ON (F)" or "OFF (F)")
	-- make sure PlatformStand toggles
	local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum.PlatformStand = flyEnabled end
	if not flyEnabled then setInvisible(false) end
end)

-- Keyboard toggles
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.G then
		followEnabled = not followEnabled
		btnFollow.Text = "FOLLOW: " .. (followEnabled and "ON (G)" or "OFF (G)")
	elseif input.KeyCode == Enum.KeyCode.F then
		flyEnabled = not flyEnabled
		btnFly.Text = "FLY: " .. (flyEnabled and "ON (F)" or "OFF (F)")
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.PlatformStand = flyEnabled end
	elseif input.KeyCode == Enum.KeyCode.RightShift then
		guiVisible = not guiVisible
		gui.Enabled = guiVisible
	end
end)

-- Main update loop
local lastTick = tick()
RunService.RenderStepped:Connect(function(dt)
	-- keep collision off once per respawn
	disableCollisionOnce(LocalPlayer.Character)

	-- ensure invisibility if enabled
	if invisibleEnabled then setInvisible(true) end

	-- handle flight movement (local-only)
	if flyEnabled then
		local char = LocalPlayer.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hrp and hum then
				-- control vector from camera orientation
				local cam = workspace.CurrentCamera
				local forward = cam.CFrame.LookVector
				local right = cam.CFrame.RightVector
				local up = Vector3.new(0,1,0)

				local move = Vector3.new(0,0,0)
				if keyState[Enum.KeyCode.W] then move = move + forward end
				if keyState[Enum.KeyCode.S] then move = move - forward end
				if keyState[Enum.KeyCode.A] then move = move - right end
				if keyState[Enum.KeyCode.D] then move = move + right end
				if keyState[Enum.KeyCode.Space] then move = move + up end
				if keyState[Enum.KeyCode.LeftShift] then move = move - up end

				if move.Magnitude > 0 then
					move = move.Unit * flySpeed
				end

				-- apply movement with simple kinematic step (frame rate independent)
				hrp.CFrame = hrp.CFrame + move * dt
			end
		end
	end

	-- smooth follow
	if followEnabled then
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local target = getNearestPlayer()
			if target and target.Character then
				local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
				if targetHRP then
					-- compute desired and use exponential smoothing
					local desired = targetHRP.CFrame * FOLLOW_OFFSET
					local alpha = expAlpha(dt, SMOOTH_TIME)
					hrp.CFrame = hrp.CFrame:Lerp(desired, alpha)
				end
			end
		end
	end

	-- small throttle: update widget attachments if character freshly spawned
	-- (attach nametags/highlights when char appears)
	for p, w in pairs(playerWidgets) do
		-- no-op; attachments handled in CharacterAdded connect earlier
	end

	lastTick = tick()
end)

-- initialize LocalPlayer character events
if LocalPlayer.Character then
	-- make sure invisibility default state
	if invisibleEnabled then setInvisible(true) end
end
LocalPlayer.CharacterAdded:Connect(function(char)
	-- ensure platform stand when flying
	local hum = char:WaitForChild("Humanoid", 5)
	if hum then hum.PlatformStand = flyEnabled end
	-- re-apply invisibility if enabled
	if invisibleEnabled then
		task.wait(0.05)
		setInvisible(true)
	end
	-- disable collisions once for new char
	disableCollisionOnce(char)
end)

-- small helper to expose folder (for internal functions)
function getESPFolder() return getESPFolder end

-- initial UI state
btnESP.Text = "ESP: " .. (espEnabled and "ON" or "OFF")
btnFollow.Text = "FOLLOW: " .. (followEnabled and "ON (G)" or "OFF (G)")
btnFly.Text = "FLY: " .. (flyEnabled and "ON (F)" or "OFF (F)")

-- final print
print("[Heaven] Local test UI loaded. Controls: G=Follow, F=Fly, RightShift=GUI toggle")
