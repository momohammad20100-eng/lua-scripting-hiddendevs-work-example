local TweenService = game:GetService("TweenService")
local plr = game.Players.LocalPlayer
local input = game.ReplicatedStorage.Remotes.Input
local RunService = game:GetService("RunService")

local showcase = script.Parent.Parent.Parent.ShowcaseContainer
local nameLabel = showcase:WaitForChild("Header"):WaitForChild("Name")
local descLabel = showcase:WaitForChild("BG2"):WaitForChild("Desc")
local equipButton = showcase:WaitForChild("Equip")
local requirementLabel = script.Parent:WaitForChild("UnlockController"):WaitForChild("Container"):WaitForChild("Amount")
local viewport = showcase:WaitForChild("Item")
local clickSound = showcase:WaitForChild("Error")

local glovesButton = script.Parent.ScrollingFrame.Gloves.ImageButton
local woodenpackButton = script.Parent.ScrollingFrame.WoodenPack.ImageButton
local bamboostickButton = script.Parent.ScrollingFrame.BambooStick.ImageButton
local buckshotButton = script.Parent.ScrollingFrame.Buckshot.ImageButton
local foxMaskButton = script.Parent.ScrollingFrame.FoxMask.ImageButton

local currentItem = nil
local rotatingParts = {}
local playerKills = plr:WaitForChild("leaderstats"):WaitForChild("Total Kills")
local animLock = false

local function clearViewport()
	for _, v in pairs(viewport:GetChildren()) do
		if v:IsA("Model") or v:IsA("BasePart") then
			v:Destroy()
		end
	end
	currentItem = nil
	rotatingParts = {}
end

local function rotatePart(part, speed, axis)
	if part then
		rotatingParts[part] = {Speed = speed, Axis = axis}
	end
end

local function loadGloves()
	clearViewport()
	local model = game.ReplicatedStorage.Assets.ShowcaseCosmetics.Gloves.gloveleft:Clone()
	model.Parent = viewport
	currentItem = "gloveleft"
	local primary = model:IsA("Model") and model.PrimaryPart or model
	if primary then
		rotatePart(primary, 60, Vector3.new(60,0,0))
	end
end

local function loadWoodenPack()
	clearViewport()
	local model = game.ReplicatedStorage.Assets.ShowcaseCosmetics.WoodenPack.WoodenPack:Clone()
	model.Parent = viewport
	currentItem = "WoodenPack"
	rotatePart(model, 60, Vector3.new(0,60,0))
end

local function loadBambooStick()
	clearViewport()
	local model = game.ReplicatedStorage.Assets.ShowcaseCosmetics.BambooStick.Bamboo:Clone()
	model.Parent = viewport
	currentItem = "BambooStick"
	rotatePart(model, 60, Vector3.new(60,0,0))
end

local function loadBuckshot()
	clearViewport()
	local model = game.ReplicatedStorage.Assets.ShowcaseCosmetics.Buckshot.Buckshot:Clone()
	model.Parent = viewport
	currentItem = "Buckshot"
	rotatePart(model, 60, Vector3.new(0,60,0))
end

local function loadFoxMask()
	clearViewport()
	local model = game.ReplicatedStorage.Assets.ShowcaseCosmetics.FoxMask.FoxMask:Clone()
	model.Parent = viewport
	currentItem = "FoxMask"
	rotatePart(model, 60, Vector3.new(0,60,0))
end

local function updateEquipButton()
	requirementLabel.Visible = false
	equipButton.Active = true
	equipButton.AutoButtonColor = true

	if currentItem == "gloveleft" then
		equipButton.TEXT.Text = plr.Cosmetics.Gloves.Value and "UNEQUIP" or "EQUIP"
		requirementLabel.Visible = true
		requirementLabel.Text = "FREE"

	elseif currentItem == "WoodenPack" then
		if playerKills.Value < 0 then
			requirementLabel.Visible = true
			requirementLabel.Text = "10 KILLS"
			equipButton.Active = false
			equipButton.AutoButtonColor = false
			equipButton.TEXT.Text = "LOCKED"
		else
			equipButton.TEXT.Text = plr.Cosmetics.WoodenPack.Value and "UNEQUIP" or "EQUIP"
		end

	elseif currentItem == "BambooStick" then
		if playerKills.Value < 15 then
			requirementLabel.Visible = true
			requirementLabel.Text = "15 KILLS"
			equipButton.Active = false
			equipButton.AutoButtonColor = false
			equipButton.TEXT.Text = "LOCKED"
		else
			equipButton.TEXT.Text = plr.Cosmetics.BambooStick.Value and "UNEQUIP" or "EQUIP"
		end

	elseif currentItem == "Buckshot" then
		if playerKills.Value < 0 then
			requirementLabel.Visible = true
			requirementLabel.Text = "60 KILLS"
			equipButton.Active = false
			equipButton.AutoButtonColor = false
			equipButton.TEXT.Text = "LOCKED"
		else
			equipButton.TEXT.Text = plr.Cosmetics.Buckshot.Value and "UNEQUIP" or "EQUIP"
		end

	elseif currentItem == "FoxMask" then
		equipButton.TEXT.Text = plr.Cosmetics.FoxMask.Value and "UNEQUIP" or "EQUIP"
		requirementLabel.Visible = true
		requirementLabel.Text = "80 KILLS"
	end
end

local function openShowcaseFrame()
	if animLock then return end
	animLock = true

	showcase.Visible = true
	showcase.ClipsDescendants = true

	local frameScale = showcase:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	frameScale.Scale = 0
	frameScale.Parent = showcase

	local tween = TweenService:Create(frameScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	tween:Play()
	tween.Completed:Wait()

	animLock = false
end

equipButton.MouseButton1Click:Connect(function()
	if not equipButton.Active then return end
	clickSound:Play()

	if currentItem == "gloveleft" then
		input:FireServer({Request = "Cosmetic", Cosmetic = "Gloves"})
	elseif currentItem == "WoodenPack" then
		input:FireServer({Request = "Cosmetic", Cosmetic = "WoodenPack"})
	elseif currentItem == "BambooStick" then
		input:FireServer({Request = "Cosmetic", Cosmetic = "BambooStick"})
	elseif currentItem == "Buckshot" then
		input:FireServer({Request = "Cosmetic", Cosmetic = "Buckshot"})
	elseif currentItem == "FoxMask" then
		input:FireServer({Request = "Cosmetic", Cosmetic = "FoxMask"})
	end
end)

glovesButton.MouseButton1Click:Connect(function()
	clickSound:Play()
	nameLabel.Text = "Gloves"
	descLabel.Text = "Simple but stylish gloves."
	loadGloves()
	updateEquipButton()
	openShowcaseFrame()
end)

woodenpackButton.MouseButton1Click:Connect(function()
	clickSound:Play()
	nameLabel.Text = "Wooden Pack"
	descLabel.Text = "A sturdy wooden backpack."
	loadWoodenPack()
	updateEquipButton()
	openShowcaseFrame()
end)

bamboostickButton.MouseButton1Click:Connect(function()
	clickSound:Play()
	nameLabel.Text = "Bamboo Stick"
	descLabel.Text = "A simple bamboo stick."
	loadBambooStick()
	updateEquipButton()
	openShowcaseFrame()
end)

buckshotButton.MouseButton1Click:Connect(function()
	clickSound:Play()
	nameLabel.Text = "Buckshot"
	descLabel.Text = "A compact firearm that fires rapid blasts."
	loadBuckshot()
	updateEquipButton()
	openShowcaseFrame()
end)

foxMaskButton.MouseButton1Click:Connect(function()
	clickSound:Play()
	nameLabel.Text = "Fox Mask"
	descLabel.Text = "A mask that sharpens senses in battles."
	loadFoxMask()
	updateEquipButton()
	openShowcaseFrame()
end)

plr.Cosmetics.Gloves.Changed:Connect(updateEquipButton)
plr.Cosmetics.WoodenPack.Changed:Connect(updateEquipButton)
plr.Cosmetics.BambooStick.Changed:Connect(updateEquipButton)
plr.Cosmetics.Buckshot.Changed:Connect(updateEquipButton)
plr.Cosmetics.FoxMask.Changed:Connect(updateEquipButton)
playerKills.Changed:Connect(updateEquipButton)

RunService.RenderStepped:Connect(function(dt)
	for part, data in pairs(rotatingParts) do
		if part and part.Parent then
			part.CFrame = part.CFrame * CFrame.Angles(
				math.rad(data.Axis.X * dt),
				math.rad(data.Axis.Y * dt),
				math.rad(data.Axis.Z * dt)
			)
		end
	end
end)
