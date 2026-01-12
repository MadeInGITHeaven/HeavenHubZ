--// Heaven Test Ability Script
--// ESP + Nametags + Smooth Follow + Invisibility + Animated GUI

---------------- SERVICES ----------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

---------------- CONFIG ----------------
local ESP_FOLDER_NAME = "ESPFolder"

local FILL_COLOR = Color3.fromRGB(255, 0, 0)
local OUTLINE_COLOR = Color3.fromRGB(255, 255, 255)
local FILL_TRANSPARENCY = 0.5
local OUTLINE_TRANSPARENCY = 0

local FOLLOW_RANGE = 100
local FOLLOW_OFFSET = CFrame.new(0, 0, -4)
local SMOOTH_TIME = 0.15

---------------- STATE ----------------
local espEnabled = true
local followEnabled = false
local invisibleEnabled = false
local guiVisible = true
local lastCharacter

---------------- GUI ----------------
local gui = Instance.new("ScreenGui")
gui.Name = "HeavenGui"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(0.22, 0.32)
frame.Position = UDim2.fromScale(0.02, 0.32)
frame.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)

-- Watermark
local watermark = Instance.new("TextLabel")
watermark.Size = UDim2.fromScale(1, 0.12)
watermark.BackgroundTransparency = 1
watermark.Text = "Heaven"
watermark.Font = Enum.Font.GothamBold
watermark.TextScaled = true
watermark.TextTransparency = 0.2
watermark.TextColor3 = Color3.fromRGB(170, 170, 255)
watermark.Parent = frame

---------------- BUTTON FACTORY ----------------
local function makeButton(text, y)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromScale(0.9, 0.18)
	btn.Position = UDim2.fromScale(0.05, y)
	btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamBold
	btn.TextScaled = true
	btn.Text = text
	btn.AutoButtonColor = false
	btn.Parent = frame
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)

	-- hover animation
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15), {
			BackgroundColor3 = Color3.fromRGB(55, 55, 55),
			Size = UDim2.fromScale(0.93, 0.19)
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15), {
			BackgroundColor3 = Color3.fromRGB(35, 35, 35),
			Size = UDim2.fromScale(0.9, 0.18)
		}):Play()
	end)

	return btn
end

local espButton = makeButton("ESP: ON", 0.16)
local followButton = makeButton("FOLLOW: OFF (G)", 0.38)
local invisButton = makeButton("INVISIBLE: OFF", 0.60)

---------------- ESP ----------------
local function getESPFolder()
	local folder = LocalPlayer:FindFirstChild(ESP_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = ESP_FOLDER_NAME
		folder.Parent = LocalPlayer
	end
	return folder
end

local function createESP(player)
	if player == LocalPlayer then return end
	local folder = getESPFolder()
	if folder:FindFirstChild(player.Name) then return end

	local h = Instance.new("Highlight")
	h.Name = player.Name
	h.FillColor = FILL_COLOR
	h.OutlineColor = OUTLINE_COLOR
	h.FillTransparency = FILL_TRANSPARENCY
	h.OutlineTransparency = OUTLINE_TRANSPARENCY
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Enabled = espEnabled
	h.Parent = folder

	local function attach(char)
		h.Adornee = char
		local head = char:FindFirstChild("Head")
		if head and not head:FindFirstChild("NameTag") then
			local bill = Instance.new("BillboardGui")
			bill.Name = "NameTag"
			bill.Size = UDim2.fromScale(4, 1)
			bill.StudsOffset = Vector3.new(0, 2.5, 0)
			bill.AlwaysOnTop = true
			bill.Parent = head

			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = player.Name
			label.Font = Enum.Font.GothamBold
			label.TextScaled = true
			label.TextColor3 = Color3.new(1, 1, 1)
			label.TextStrokeTransparency = 0
			label.Parent = bill
		end
	end

	if player.Character then attach(player.Character) end
	player.CharacterAdded:Connect(attach)
end

for _, p in ipairs(Players:GetPlayers()) do createESP(p) end
Players.PlayerAdded:Connect(createESP)

---------------- INVISIBILITY ----------------
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

---------------- FOLLOW HELPERS ----------------
local function disableCollisionOnce(character)
	if character == lastCharacter then return end
	lastCharacter = character
	for _, p in ipairs(character:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
		end
	end
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

---------------- BUTTON LOGIC ----------------
espButton.MouseButton1Click:Connect(function()
	espEnabled = not espEnabled
	espButton.Text = "ESP: " .. (espEnabled and "ON" or "OFF")
	for _, h in ipairs(getESPFolder():GetChildren()) do
		if h:IsA("Highlight") then
			h.Enabled = espEnabled
		end
	end
end)

followButton.MouseButton1Click:Connect(function()
	followEnabled = not followEnabled
	followButton.Text = "FOLLOW: " .. (followEnabled and "ON (G)" or "OFF (G)")
end)

invisButton.MouseButton1Click:Connect(function()
	invisibleEnabled = not invisibleEnabled
	invisButton.Text = "INVISIBLE: " .. (invisibleEnabled and "ON" or "OFF")
	setInvisible(invisibleEnabled)
end)

---------------- KEYBINDS ----------------
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end

	if input.KeyCode == Enum.KeyCode.G then
		followEnabled = not followEnabled
		followButton.Text = "FOLLOW: " .. (followEnabled and "ON (G)" or "OFF (G)")
	elseif input.KeyCode == Enum.KeyCode.RightShift then
		guiVisible = not guiVisible
		gui.Enabled = guiVisible
	end
end)

---------------- MAIN LOOP ----------------
RunService.RenderStepped:Connect(function(dt)
	disableCollisionOnce(LocalPlayer.Character)
	if invisibleEnabled then setInvisible(true) end
	if not followEnabled then return end

	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local target = getNearestPlayer()
	if not target or not target.Character then return end

	local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
	if not targetHRP then return end

	local desired = targetHRP.CFrame * FOLLOW_OFFSET
	local alpha = math.clamp(dt / SMOOTH_TIME, 0, 1)
	hrp.CFrame = hrp.CFrame:Lerp(desired, alpha)
end)
