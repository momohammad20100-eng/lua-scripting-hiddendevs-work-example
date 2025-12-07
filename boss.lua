
local Players = game:GetService("Players") -- get the Players service for local player
local TweenService = game:GetService("TweenService") -- tweening service for smooth animations
local ReplicatedStorage = game:GetService("ReplicatedStorage") -- storage for reusable assets
local RunService = game:GetService("RunService") -- for frame-based loops
local SoundService = game:GetService("SoundService") -- for handling sounds
local Debris = game:GetService("Debris") -- automatic cleanup for temporary objects
local UIS = game:GetService("UserInputService") -- handle user input events

-- reference to the local player and their character
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait() -- ensure character is loaded
local camera = workspace.CurrentCamera -- main camera reference

-- environment references
local triggerPart = workspace:WaitForChild("Touch") -- triggers cinematic sequence
local cameraPart = workspace:WaitForChild("cam") -- part used for camera positioning
local monument = workspace:WaitForChild("Monument") -- main monument model
local rotatePartOriginal = monument:WaitForChild("Handle") -- rotating handle for animation
local npc = workspace:WaitForChild("4ndrd") -- boss NPC model
local partsModel = monument:WaitForChild("Parts") -- sub-parts of monument to shrink

-- sound references
local shrinkSound = ReplicatedStorage:WaitForChild("shrinkSound") -- shrink sound effect
local mainMusic = ReplicatedStorage:WaitForChild("Bossfight") -- main boss fight music

-- store original handle properties for reset
local pumpkinHandleSize = rotatePartOriginal.Size
local baseCFrame = rotatePartOriginal.CFrame

-- misc variables
local t = 0 -- timer for sine oscillation
local used = false -- prevent multiple trigger activations
local cameraDistance = 100 -- offset for cinematic camera
local stopRedExplosion = false -- flag to stop red explosion loop
local heightOffset = 13/2 -- offset for NPC height
local npcHeightOffset = 5 -- additional NPC offset

-- NPC accessory reference
local accessoryHandle = npc:FindFirstChild("evil"):WaitForChild("Handle")

-- animation references
local animtrack
local animation = script:WaitForChild("cutscene") -- cutscene animation for NPC
local humanoid = npc:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")

-- load animation if possible
if animator and animation then
	animtrack = animator:LoadAnimation(animation)
end

-- blocking related variables
local blocking = false -- flag if player is blocking
local blockAnimTrack -- animator track for block
local chargeCount = 0 -- number of flame charges collected
local maxCharges = 6 -- maximum flame charges
local cinematicEnded = false -- flag to indicate end of cinematic
local flameChargeDisabled = false -- disable further charges

-- color table for projectiles
local colors = {
	Color3.fromRGB(12,202,255), -- blue
	Color3.fromRGB(255, 240, 37), -- yellow
	Color3.fromRGB(255, 74, 252), -- pink
	Color3.fromRGB(67, 255, 57), -- green
	Color3.fromRGB(255, 255, 255), -- white
	Color3.fromRGB(255, 35, 39) -- red
}

-- eagle references for rise sequence
local eagleFolder = workspace:WaitForChild("Eagles")
local eagleRiseSound = ReplicatedStorage:WaitForChild("rising")
local eagleRisen = false
local EAGLE_RISE_HEIGHT = 10 -- height eagles rise

-- red explosion references
local redExplosionTemplate = ReplicatedStorage:WaitForChild("Red")
local redExplosionLocation = workspace:WaitForChild("location")

-- continuously rotate handle up and down using sine wave
RunService.RenderStepped:Connect(function(dt)
	if rotatePartOriginal and rotatePartOriginal.Parent then
		t += dt
		local offset = math.sin(t*2)*1.5 -- calculate vertical oscillation
		local pos = baseCFrame.Position - Vector3.new(0,offset,0)
		-- maintain original rotation while applying vertical movement
		rotatePartOriginal.CFrame = CFrame.new(pos)*(rotatePartOriginal.CFrame-rotatePartOriginal.CFrame.Position)
	end
end)

-- function to reset accessory handle size and position
local function resetHandleSize()
	if accessoryHandle then
		accessoryHandle.Size = pumpkinHandleSize*5
		accessoryHandle.Transparency = 0
		accessoryHandle.CanCollide = true
		accessoryHandle.CFrame = baseCFrame*CFrame.new(0,-1.5,0)*CFrame.Angles(0,math.rad(180),0)
	end
end

-- block cooldown to prevent spamming
local blockCooldown = false

-- handle player input for blocking
UIS.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.E and not blocking and not blockCooldown then
		blocking = true
		blockCooldown = true
		local hum = character:FindFirstChildOfClass("Humanoid")
		if hum then
			local blockAnim = ReplicatedStorage:WaitForChild("block")
			if blockAnim then
				blockAnimTrack = hum:FindFirstChildOfClass("Animator"):LoadAnimation(blockAnim)
				blockAnimTrack.Looped = true
				blockAnimTrack:Play()
			end
			hum.WalkSpeed = 0 -- stop movement while blocking
		end

		task.delay(1, function()
			blocking = false
			if hum then hum.WalkSpeed = 16 end
			if blockAnimTrack then blockAnimTrack:Stop() end
			task.delay(1, function()
				blockCooldown = false -- reset cooldown
			end)
		end)
	end
end)

-- handle end of block input
UIS.InputEnded:Connect(function(input)
	if input.KeyCode==Enum.KeyCode.E and blocking then
		blocking = false
		local hum = character:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed=16 end
		if blockAnimTrack then blockAnimTrack:Stop() end
	end
end)

-- function to spawn flames / projectiles
local function flameMove(name,speed,flameColor)
	if name=="flamecharge" and (chargeCount>=maxCharges or flameChargeDisabled) then return end
	local proj = ReplicatedStorage:WaitForChild(name):Clone()
	proj.CFrame = npc:FindFirstChild("HumanoidRootPart").CFrame
	proj.Parent = workspace
	local bv = Instance.new("BodyVelocity",proj)
	bv.MaxForce = Vector3.new(1e5,1e5,1e5)
	Debris:AddItem(bv,2)
	local hitOnce = false
	local followConnection
	-- projectile follows player
	followConnection = RunService.RenderStepped:Connect(function()
		if proj and proj.Parent then
			local direction = (character.PrimaryPart.Position - proj.Position).Unit
			bv.Velocity = direction*speed
		else
			if followConnection then followConnection:Disconnect() end
		end
	end)
	-- customize particle color if present
	if proj:FindFirstChild("Attachment") then
		for _,p in ipairs(proj.Attachment:GetChildren()) do
			if p:IsA("ParticleEmitter") then
				p.Color = ColorSequence.new(flameColor)
			end
		end
	end
	-- handle collision
	proj.Touched:Connect(function(hit)
		if hit:IsDescendantOf(character) and not hitOnce then
			hitOnce=true
			if not blocking and name~="flamecharge" then
				local hum = character:FindFirstChildOfClass("Humanoid")
				if hum then hum:TakeDamage(1) end
				local bv2 = Instance.new("BodyVelocity",character.PrimaryPart)
				bv2.Velocity = Vector3.new(0,50,0)
				Debris:AddItem(bv2,0.2)
			elseif name=="flamecharge" then
				local tool = player.Character:FindFirstChildOfClass("Tool")
				if tool and tool.Name=="Diamond" then
					chargeCount+=1
					local clone = tool:Clone()
					clone.Name="Diamond_Charge"..chargeCount
					clone.Parent=player.Backpack
					if clone:FindFirstChild("Handle") then
						clone.Handle.Material=Enum.Material.Neon
						clone.Handle.Color=colors[math.clamp(chargeCount,1,#colors)]
					end
					if chargeCount==maxCharges then
						local origDiamond=player.Character:FindFirstChild("Diamond")
						if origDiamond then origDiamond:Destroy() end
						flameChargeDisabled=true
					end
				end
			end
			proj:Destroy()
			if followConnection then followConnection:Disconnect() end
		end
	end)
end

-- infinite loop to spawn flames for boss attack
local function attackLoop()
	while true do
		flameMove("Flame1",100,colors[1])
		task.wait(3)
		flameMove("Flame2",100,colors[2])
		task.wait(3)
		flameMove("Flame3",100,colors[3])
		task.wait(3)
		if chargeCount<maxCharges and math.random(1,100)<=100 then
			flameMove("flamecharge",120,colors[math.clamp(chargeCount+1,1,#colors)])
		else
			flameMove("Flame4",100,colors[4])
		end
		task.wait(3)
	end
end

-- simple camera shake effect
local function shakeCamera(intensity,duration)
	local startTime=tick()
	local connection
	connection=RunService.RenderStepped:Connect(function()
		local elapsed=tick()-startTime
		if elapsed>duration then connection:Disconnect() return end
		local offset=Vector3.new(math.random(-100,100)/100,math.random(-100,100)/100,math.random(-100,100)/100)*intensity
		camera.CFrame=camera.CFrame+offset
	end)
end

-- function to animate eagles rising into the air
local function riseEagles()
	if eagleRisen then return end
	eagleRisen=true
	for _,eagle in ipairs(eagleFolder:GetDescendants()) do
		if eagle:IsA("Model") then
			for _,obj in ipairs(eagle:GetDescendants()) do
				if obj:IsA("BasePart") then
					obj.Anchored=true
					local riseTween=TweenService:Create(obj,TweenInfo.new(3,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{CFrame=obj.CFrame+Vector3.new(0,EAGLE_RISE_HEIGHT,0)})
					riseTween:Play()
				end
			end
		end
	end
	eagleRiseSound:Play()
	shakeCamera(2.5,3)
end

-- shrink NPC parts at the end of cutscene
local function shrinkNpcParts()
	for _,obj in ipairs(npc:GetDescendants()) do
		if obj:IsA("BasePart") then obj.Size=obj.Size*0.1 end
	end
end

-- loop to create red explosion effects
local function redExplosionLoop()
	while true do
		if stopRedExplosion then break end 
		task.wait(6.5)

		for i = 1, 200 do
			if stopRedExplosion then return end  
			task.spawn(function()
				if stopRedExplosion then return end

				local RedClone = redExplosionTemplate:Clone()
				RedClone.Parent = workspace

				local randomX = math.random(redExplosionLocation.Position.X - redExplosionLocation.Size.X/2, redExplosionLocation.Position.X + redExplosionLocation.Size.X/2)
				local randomZ = math.random(redExplosionLocation.Position.Z - redExplosionLocation.Size.Z/2, redExplosionLocation.Position.Z + redExplosionLocation.Size.Z/2)
				RedClone.Position = Vector3.new(randomX, redExplosionLocation.Position.Y, randomZ)

				local OriginalSize = RedClone.Size
				RedClone.Size = Vector3.new(0,0,0)
				local growTween = TweenService:Create(RedClone, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = OriginalSize})
				growTween:Play()
				growTween.Completed:Wait()
				ReplicatedStorage:WaitForChild("explosion"):Play()

				local attachment = RedClone:FindFirstChildOfClass("Attachment")
				if attachment then
					for _, emitter in pairs(attachment:GetChildren()) do
						if emitter:IsA("ParticleEmitter") then
							emitter:Emit(emitter:GetAttribute("Rate") or emitter.Rate)
						end
					end
				end

				local hitRegistered = false
				RedClone.Touched:Connect(function(hit)
					if hitRegistered then return end
					local hum = hit.Parent:FindFirstChildOfClass("Humanoid")
					if hum and hit:IsDescendantOf(character) then
						hitRegistered = true
						hum:TakeDamage(1)
					end
				end)

				task.wait(2)
				if not RedClone or not RedClone.Parent then return end
				local vanishTween = TweenService:Create(RedClone, TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Size = Vector3.new(0,0,0)})
				vanishTween:Play()
				vanishTween.Completed:Wait()
				RedClone:Destroy()
			end)
		end
	end
end

-- cinematic sequence function for cutscene
local function Cinematic()
	if animtrack then animtrack:Play() end
	local framesFolder = ReplicatedStorage:WaitForChild("cutscene"):WaitForChild("Frames")
	local npcPos = npc.PrimaryPart.Position + Vector3.new(0, heightOffset + npcHeightOffset, 0)
	local forward = npc.PrimaryPart.CFrame.LookVector
	local startCameraPos = npcPos + forward * math.abs(cameraDistance)
	local originCFrame = framesFolder:GetChildren()[1] and framesFolder:GetChildren()[1].Value or CFrame.new()
	camera.CameraType = Enum.CameraType.Scriptable
	local frameTime = 0
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		frameTime += dt * 60
		local neededFrame = framesFolder:FindFirstChild(tonumber(math.ceil(frameTime)))
		if neededFrame then
			local localOffset = originCFrame:ToObjectSpace(neededFrame.Value).Position
			local cameraPosThis = startCameraPos + localOffset
			camera.CFrame = CFrame.new(cameraPosThis, npcPos)
		else
			connection:Disconnect()
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = cameraPart.CFrame
			for _, obj in ipairs(npc:GetDescendants()) do
				if obj:IsA("BasePart") then
					local isHead = (obj.Name == "Head")
					local isAccessoryHandle = obj:IsDescendantOf(npc:FindFirstChildOfClass("Accessory"))
					if not isAccessoryHandle and not isHead then obj.Transparency = 1 end
					obj.CanCollide = false
				end
				if obj:IsA("ParticleEmitter") or obj:IsA("Beam") then obj.Enabled = false end
			end
			npc:SetPrimaryPartCFrame(baseCFrame * CFrame.new(0, npcHeightOffset, 0) * CFrame.Angles(0, math.rad(180), 0))
			resetHandleSize()
			for i = 1,6 do
				local part = partsModel:FindFirstChild(tostring(i))
				if part then
					part.CanCollide = false
					local particle = part:FindFirstChildOfClass("ParticleEmitter")
					if particle then particle.Enabled = true end
					local sound = shrinkSound:Clone()
					sound.Parent = SoundService
					sound:Play()
					Debris:AddItem(sound, sound.TimeLength+1)
					local shrink = TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.In), {Size=Vector3.new(0.1,0.1,0.1)})
					shrink:Play()
					shrink.Completed:Wait()
					part:Destroy()
					shakeCamera(2.5,0.2)
				end
			end
			shrinkNpcParts()
			local charHRP = character:WaitForChild("HumanoidRootPart")
			local backTween = TweenService:Create(camera, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame=CFrame.new(charHRP.Position+Vector3.new(0,5,10), charHRP.Position)})
			backTween:Play()
			backTween.Completed:Wait()
			camera.CameraType = Enum.CameraType.Custom
			cinematicEnded = true
			if npc and npc:FindFirstChild("Humanoid") then
				local loopAnim = script:FindFirstChild("LoopAnimation")
				if loopAnim then
					local animTrack = npc.Humanoid:FindFirstChildOfClass("Animator"):LoadAnimation(loopAnim)
					animTrack.Looped = true
					animTrack:Play()
				end
			end
			task.spawn(attackLoop)
			task.spawn(redExplosionLoop)
			local musicClone = mainMusic:Clone()
			musicClone.Parent = SoundService
			musicClone.Looped = true
			musicClone:Play()
			Debris:AddItem(musicClone, math.huge)
		end
	end)
end

-- trigger cutscene on touching part
triggerPart.Touched:Connect(function(hit)
	if hit.Parent == character and not used then
		used = true

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		local teleportTarget = workspace:WaitForChild("TP")
		local shrinkPart = workspace:WaitForChild("Monument"):WaitForChild("monument"):WaitForChild("Shrink")

		if humanoid and root then
			humanoid.PlatformStand = true
			root.Anchored = true
			root.CFrame = teleportTarget.CFrame + Vector3.new(0, 5, 0)
		end

		camera.CameraType = Enum.CameraType.Scriptable
		local tween = TweenService:Create(camera, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = cameraPart.CFrame})
		tween:Play()
		tween.Completed:Wait()

		task.wait(1.5)

		local direction = (cameraPart.Position - rotatePartOriginal.Position).Unit
		local goalCFrame = CFrame.new(rotatePartOriginal.Position, rotatePartOriginal.Position + direction)
		local tween2 = TweenService:Create(rotatePartOriginal, TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = goalCFrame})
		tween2:Play()
		tween2.Completed:Wait()

		task.wait(1.5)

		for _, obj in ipairs(rotatePartOriginal:GetDescendants()) do
			if obj:IsA("ParticleEmitter") or obj:IsA("Beam") then
				obj.Enabled = false
			end
		end

		local fade = TweenService:Create(rotatePartOriginal, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Transparency = 1})
		fade:Play()
		fade.Completed:Wait()

		local shrinkTween = TweenService:Create(shrinkPart, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = Vector3.new(0, 0, 0)})
		shrinkTween:Play()
		shrinkTween.Completed:Wait()
		shrinkPart:Destroy()

		npc:SetPrimaryPartCFrame(baseCFrame * CFrame.new(0, npcHeightOffset, 0) * CFrame.Angles(0, math.rad(180), 0))
		resetHandleSize()
		rotatePartOriginal:Destroy()

		Cinematic()

		wait(10)
		local collid  = workspace:WaitForChild("Barriers"):WaitForChild("collid")
		collid.CanCollide = true

		if humanoid and root then
			humanoid.PlatformStand = false
			root.Anchored = false
		end
	end
end)

-- handle animation marker events
animtrack:GetMarkerReachedSignal("SCREAM"):Connect(function()
	local scream = ReplicatedStorage:WaitForChild("scream")
	scream:Play()
end)

-- continuously check charge count to trigger eagles rising
task.spawn(function()
	while true do
		task.wait(0.5)
		if chargeCount>=maxCharges then
			riseEagles()
			break
		end
	end
end)

-- update eagle proximity prompts based on charges
local function updateEaglePrompts()
	for _, eagle in ipairs(eagleFolder:GetDescendants()) do
		if eagle:IsA("Model") then
			local prompt = eagle:FindFirstChildWhichIsA("ProximityPrompt", true)
			if prompt then
				if eagle:GetAttribute("Charged") then
					prompt.Enabled = false
					local eyes = eagle:FindFirstChild("Eyes")
					if eyes then
						for _, partName in ipairs({"1", "2"}) do
							local part = eyes:FindFirstChild(partName)
							if part then
								for _, beam in ipairs(part:GetChildren()) do
									if beam:IsA("Beam") then
										beam.Enabled = true
									end
								end
							end
						end
					end
				else
					local tool = player.Character:FindFirstChildOfClass("Tool")
					prompt.Enabled = tool and tool.Name:match("Diamond_Charge") and true or false
				end

				prompt.Triggered:Connect(function(playerTrigger)
					ReplicatedStorage:WaitForChild("triggered"):Play()
					local tool = playerTrigger.Character and playerTrigger.Character:FindFirstChildOfClass("Tool")
					if tool and tool.Name:match("Diamond_Charge") then
						local chargeNum = tonumber(tool.Name:match("%d+"))
						local color = colors[math.clamp(chargeNum, 1, #colors)]
						ReplicatedStorage:WaitForChild("ColorEagle"):FireServer(eagle, color)
						eagle:SetAttribute("Charged", true)
						prompt.Enabled = false
						tool:Destroy()

						local eyes = eagle:FindFirstChild("Eyes")
						if eyes then
							local soundPlayed = false
							for _, partName in ipairs({"1", "2"}) do
								local part = eyes:FindFirstChild(partName)
								if part then
									for _, beam in ipairs(part:GetChildren()) do
										if beam:IsA("Beam") then
											wait(1)
											beam.Transparency = NumberSequence.new(0)
											beam.Color = ColorSequence.new(color)
											if not soundPlayed then
												local s = ReplicatedStorage:WaitForChild("beam"):Clone()
												s.Parent = SoundService
												s:Play()
												Debris:AddItem(s, s.TimeLength)
												soundPlayed = true
											end
										end
									end
								end
							end
						end
					end
				end)
			end
		end
	end
end

-- update prompts every frame
RunService.RenderStepped:Connect(updateEaglePrompts)

