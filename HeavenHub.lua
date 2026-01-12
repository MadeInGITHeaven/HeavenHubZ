--// Heaven - Clean Ability Test Suite (LOCAL)
--// ESP + Follow + Ground Speed + Flight (FIXED) + Clean UI

---------------- SERVICES ----------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

---------------- CONFIG ----------------
local FOLLOW_RANGE = 100
local FOLLOW_OFFSET = CFrame.new(0, 0, -4)
local FOLLOW_SMOOTH = 0.15

local WALK_MIN, WALK_MAX = 8, 50
local FLY_MIN, FLY_MAX = 20, 200

---------------- STATE ----------------
local followEnabled = false
local flyEnabled = false
local guiVisible = true

local walkSpeed = 16
local flySpeed = 80

local moveKeys = {}

---------------- GUI ----------------
local gui = Instance.new("ScreenGui", PlayerGui)
gui.Name = "HeavenGui"
gui.ResetOnSpawn = false

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromOffset(320, 380)
frame.Position = UDim2.new(0, 16, 0.3, 0)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)

-- Header
local header = Instance.new("TextLabel", frame)
header.Size = UDim2.new(1, -20, 0, 44)
header.Position = UDim2.new(0, 10, 0, 10)
header.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
header.Text = "HEAVEN"
header.Font = Enum.Font.GothamBlack
header.TextSize = 26
header.TextColor3 = Color3.fromRGB(160, 170, 255)
header.TextStrokeTransparency = 0.7
header.BorderSizePixel = 0
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

local content = Instance.new("Frame", frame)
content.Position = UDim2.new(0, 12, 0, 64)
content.Size = UDim2.new(1, -24, 1, -76)
content.BackgroundTransparency = 1

---------------- UI HELPERS ----------------
local function makeButton(text, y)
	local b = Instance.new("TextButton", content)
	b.Size = UDim2.new(1, 0, 0, 40)
	b.Position = UDim2.new(0, 0, 0, y)
	b.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
	b.Text = text
	b.TextColor3 = Color3.fromRGB(235, 235, 235)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.AutoButtonColor = false
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)

	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), {
			BackgroundColor3 = Color3.fromRGB(45, 45, 60)
		}):Play()
	end)

	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), {
			BackgroundColor3 = Color3.fromRGB(28, 28, 36)
		}):Play()
	end)

	return b
end

local function makeSlider(title, y, min, max, valueCallback)
	local label = Instance.new("TextLabel", content)
	label.Position = UDim2.new(0, 0, 0, y)
	label.Size = UDim2.new(1, 0, 0, 18)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(220, 220, 220)

	local bar = Instance.new("Frame", content)
	bar.Position = UDim2.new(0, 0, 0, y + 22)
	bar.Size = UDim2.new(1, 0, 0, 18)
	bar.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
	Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 8)

	local fill = Instance.new("Frame", bar)
	fill.BackgroundColor3 = Color3.fromRGB(100, 110, 255)
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 8)

	local dragging = false

	local function update(v)
		local t = math.clamp((v - min) / (max - min), 0, 1)
		fill.Size = UDim2.new(t, 0, 1, 0)
		label.Text = title .. ": " .. math.floor(v)
	end

	bar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
		end
	end)

	bar.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	bar.InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
			local pos = (i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
			local v = min + math.clamp(pos, 0, 1) * (max - min)
			valueCallback(v)
			update(v)
		end
	end)

	return update
end

---------------- BUTTONS ----------------
local followBtn = makeButton("FOLLOW: OFF (G)", 0)
local flyBtn = makeButton("FLY: OFF (F)", 48)

local updateWalkSlider = makeSlider("Walk Speed", 100, WALK_MIN, WALK_MAX, function(v)
	walkSpeed = v
	local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if hum and not flyEnabled then
		hum.WalkSpeed = walkSpeed
	end
end)

local updateFlySlider = makeSlider("Fly Speed", 160, FLY_MIN, FLY_MAX, function(v)
	flySpeed = v
end)

updateWalkSlider(walkSpeed)
updateFlySlider(flySpeed)

---------------- FLIGHT SYSTEM ----------------
local bodyVel, bodyGyro

local function stopFly()
	if bodyVel then bodyVel:Destroy() bodyVel = nil end
	if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
	local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.PlatformStand = false
		hum.WalkSpeed = walkSpeed
	end
end

local function startFly()
	local char = LocalPlayer.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return end

	hum.PlatformStand = true

	bodyVel = Instance.new("BodyVelocity", hrp)
	bodyVel.MaxForce = Vector3.new(1e9, 1e9, 1e9)

	bodyGyro = Instance.new("BodyGyro", hrp)
	bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
end

---------------- INPUT ----------------
UserInputService.InputBegan:Connect(function(i, gpe)
	if gpe then return end
	moveKeys[i.KeyCode] = true

	if i.KeyCode == Enum.KeyCode.G then
		followEnabled = not followEnabled
		followBtn.Text = "FOLLOW: " .. (followEnabled and "ON (G)" or "OFF (G)")
	elseif i.KeyCode == Enum.KeyCode.F then
		flyEnabled = not flyEnabled
		flyBtn.Text = "FLY: " .. (flyEnabled and "ON (F)" or "OFF (F)")
		if flyEnabled then startFly() else stopFly() end
	elseif i.KeyCode == Enum.KeyCode.RightShift then
		guiVisible = not guiVisible
		gui.Enabled = guiVisible
	end
end)

UserInputService.InputEnded:Connect(function(i)
	moveKeys[i.KeyCode] = nil
end)

---------------- MAIN LOOP ----------------
RunService.RenderStepped:Connect(function(dt)
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")

	if flyEnabled and bodyVel and bodyGyro and hrp then
		local dir = Vector3.zero
		if moveKeys[Enum.KeyCode.W] then dir += Camera.CFrame.LookVector end
		if moveKeys[Enum.KeyCode.S] then dir -= Camera.CFrame.LookVector end
		if moveKeys[Enum.KeyCode.A] then dir -= Camera.CFrame.RightVector end
		if moveKeys[Enum.KeyCode.D] then dir += Camera.CFrame.RightVector end
		if moveKeys[Enum.KeyCode.Space] then dir += Vector3.yAxis end
		if moveKeys[Enum.KeyCode.LeftShift] then dir -= Vector3.yAxis end

		if dir.Magnitude > 0 then
			dir = dir.Unit * flySpeed
		end

		bodyVel.Velocity = dir
		bodyGyro.CFrame = Camera.CFrame
	end
end)

---------------- RESPAWN FIX ----------------
LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.1)
	if flyEnabled then
		startFly()
	else
		local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = walkSpeed end
	end
end)

print("[Heaven] Loaded clean test UI")
