local ts = game:GetService("TweenService")

local dataModule = require(script.DataModule)

local addInstances = dataModule.AddInstances
local saveData = dataModule.SaveData
local loadData = dataModule.LoadData

local check = require(game.ReplicatedStorage.Modules.Utils).MoveUtils.Check

-- this function builds all character value objects used for combat and tracking
local function createValues(char)
	local values = Instance.new("Folder", char)
	values.Name = "Values"

	-- stores current combo count
	local combo = Instance.new("NumberValue", values)
	combo.Name = "Combo"
	combo.Value = 0

	-- tracks if the character is awakened
	local awakened = Instance.new("BoolValue", values)
	awakened.Name = "Awakened"
	awakened.Value = false
	
	-- keeps track of kill streaks
	local killStreak = Instance.new("NumberValue", values)
	killStreak.Name = "Kill Streak"
	killStreak.Value = 0
	
	-- timer for keeping the character in combat
	local inCombat = Instance.new("NumberValue",values)
	inCombat.Name = "In Combat"
	inCombat.Value = 10
	
	-- slowly increments combat timer if character remains active
	task.spawn(function()
		while inCombat.Parent ~= nil do
			values:WaitForChild("In Combat").Value += 1
			task.wait(1)
		end
	end)
end

game.Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
		-- all characters are placed in the living folder for cleaner workspace handling
		char.Parent = workspace.Living
		char:WaitForChild("ForceField"):Destroy()
		
		createValues(char)

		local values = char:WaitForChild("Values")
		local hum = char:WaitForChild("Humanoid")
		local animator = hum:FindFirstChild("Animator")
		local hrp = char:WaitForChild("HumanoidRootPart")
		local currentCharacter = plr.Data:WaitForChild("CurrentCharacter")
		hum.RequiresNeck = false
		hum.BreakJointsOnDeath = false

		-- ensures autorun jump remains disabled even if roblox tries enabling it
		task.spawn(function()
			repeat
				hum.AutoJumpEnabled = false
			until hum.AutoJumpEnabled == false
		end)

		-- handles combat tag resetting and ragdoll logic
		values.ChildAdded:Connect(function(child)
			if child.Name == "Ragdoll" then
				require(script.RagdollModule):Ragdoll(char)
			end
			
			-- resets combat timer if the character isn't dashing or attacking
			if not check(char) and not values:FindFirstChild("Dashing") and not values:FindFirstChild("Forward Dashing") then
				values:WaitForChild("In Combat").Value = 0
			end
			
			-- attack actions reset combat timer
			if child.Name == "Attacking" and not values:FindFirstChild("M1") then
				values:WaitForChild("In Combat").Value = 0
			end
		end)

		-- unragdolls when the ragdoll flag is removed
		values.ChildRemoved:Connect(function(child)
			if child.Name == "Ragdoll" then
				if not values:FindFirstChild("Ragdoll") then
					require(script.RagdollModule):UnRagdoll(char)
				end
			end
		end)
		
		-- forces character to die if root part is removed
		char.ChildRemoved:Connect(function(child)
			if child.Name == "HumanoidRootPart" then
				hum.Health = 0
				hum.RequiresNeck = true
			end
		end)

		-- death physics and weapon dropping
		hum.Died:Connect(function()
			if not values:FindFirstChild("Ragdoll") then
				local ragdoll = Instance.new("IntValue", values)
				ragdoll.Name = "Ragdoll"

				local kb = Instance.new("BodyVelocity", hrp)
				kb.MaxForce = Vector3.new(10000,10000,10000)
				kb.Velocity = hrp.CFrame.LookVector * 5
				game.Debris:AddItem(kb, .2)
			end

			if char:FindFirstChild("Weapon") then
				local weapon = char:FindFirstChild("Weapon")
				weapon.Parent = workspace.Effects
				
				-- makes weapon collide once it's dropped
				if weapon:IsA("Part") then
					weapon.CanCollide = true
				end
				
				for i, v in pairs(weapon:GetChildren()) do
					if v:IsA("Part") then
						v.CanCollide = true
					end
				end

				weapon["Weapon Weld"]:Destroy()
				game.Debris:AddItem(weapon,10)
			end
		end)
	
		-- character specific weapon setup
		local humanoid = char:WaitForChild("Humanoid")

		if currentCharacter.Value == "SunSlayer" then
			-- equips sunslayer katana
			local weapon = game.ReplicatedStorage.Assets.Weapons["SunSlayer"].Katana:Clone()
			weapon.Name = "Weapon"
			weapon.Parent = char
			weapon.HandleR.Joint.Part1 = char:WaitForChild("Right Arm")

			humanoid.Died:Connect(function()
				if weapon and weapon.Parent then
					weapon:Destroy()
				end
			end)
		end

		if currentCharacter.Value == "KingOfTheMountains" then
			-- equips two swords for this character
			local weapon1 = game.ReplicatedStorage.Assets.Weapons["KingOfTheMountains"].Katana1:Clone()
			weapon1.Name = "Weapon"
			weapon1.Parent = char
			weapon1.HandleR.Joint.Part1 = char:WaitForChild("Right Arm")

			local weapon2 = game.ReplicatedStorage.Assets.Weapons["KingOfTheMountains"].Katana2:Clone()
			weapon2.Name = "Weapon"
			weapon2.Parent = char
			weapon2.HandleR.Joint.Part1 = char:WaitForChild("Left Arm")

			humanoid.Died:Connect(function()
				if weapon1 and weapon1.Parent then
					weapon1:Destroy()
				end
				if weapon2 and weapon2.Parent then
					weapon2:Destroy()
				end
			end)
		end

		-- gui handling + character module data loading
		local gui = plr.PlayerGui

		local characterModule = require(script.Characters[plr:WaitForChild("Data"):WaitForChild("CurrentCharacter").Value])
		
		plr:WaitForChild("MaxAwakening").Value = characterModule.MaxAwakening

		gui:WaitForChild("Awakening").Bar.TextLabel.Text = characterModule.UltimateName
		gui:WaitForChild("Awakening").Bar.TextLabel.TextLabel.Text = characterModule.UltimateName
		
		-- removes old moveset ui before adding the new character moveset
		if gui:WaitForChild("Hotbar"):FindFirstChild("MovesetHolder") then
			gui:FindFirstChild("Hotbar"):FindFirstChild("MovesetHolder"):Destroy()
		end
		
		local movesetholder = game.ReplicatedStorage.Assets.Movesets[plr:WaitForChild("Data"):WaitForChild("CurrentCharacter").Value]:FindFirstChild("MovesetHolder")
		
		if movesetholder then
			movesetholder:Clone().Parent = gui:WaitForChild("Hotbar")
		end

		-- assigns proper collision group for character parts
		for i, v in pairs(char:GetChildren()) do
			if v:IsA("Part") or v:IsA("MeshPart") or v:IsA("BasePart") then
				v.CollisionGroup = "Player"
			end
		end

		-- equips weapon for characters with a default weapon
		local weapon = game.ReplicatedStorage.Assets.Weapons:FindFirstChild(plr:WaitForChild("Data"):WaitForChild("CurrentCharacter").Value)

		if weapon and not char:FindFirstChild("Weapon") then
			local newWeapon = weapon:Clone()
			newWeapon.Name = "Weapon"
			newWeapon.Parent = char
			
			newWeapon["Weapon Weld"].Part1 = char:WaitForChild("Right Arm")
		end

		-- spawn protection highlight tween
		local highlight = Instance.new("Highlight",char)
		highlight.FillColor = Color3.fromRGB(255,255,255)

		local Info = TweenInfo.new(5)
		local Tween = ts:Create(highlight,Info,{FillTransparency = 1, OutlineTransparency = 1})
		Tween:Play()

		-- iframe flag used while highlight is fading
		local iFrames = Instance.new("IntValue",values)
		iFrames.Name = "IFrames"

		Tween.Completed:Connect(function()
			iFrames:Destroy()
		end)

		-- plays spawn animation and spawn sound
		local spawnAnimation = animator:LoadAnimation(game.ReplicatedStorage.Assets.Animations[plr:WaitForChild("Data"):WaitForChild("CurrentCharacter").Value]:WaitForChild("SpawnAnimation"))
		spawnAnimation:Play()
		
		local spawnSound = game.ReplicatedStorage.Assets.Effects[plr:WaitForChild("Data"):WaitForChild("CurrentCharacter").Value].Other:FindFirstChild("Spawn"):Clone()
		spawnSound.Parent = hrp
		spawnSound:Play()
		game.Debris:AddItem(spawnSound,spawnSound.TimeLength)
		
		-- cancels spawn animation if player moves or attacks
		task.spawn(function()
			while spawnAnimation.IsPlaying do
				if hum.MoveDirection.Magnitude > 0 or not check(char) or values:FindFirstChild("Attacking") then
					spawnAnimation:Stop()
					break
				end
				task.wait()
			end
		end)
		
		-- cancels spawn sound if player moves or attacks
		task.spawn(function()
			while spawnSound.IsPlaying do
				if hum.MoveDirection.Magnitude > 0 or not check(char) or values:FindFirstChild("Attacking") then
					spawnSound:Destroy()
					break
				end
				task.wait()
			end
		end)
		
		-- clears cooldowns on spawn
		require(game.ReplicatedStorage.Modules.CooldownModule):RemoveAll(plr)
		
		-- applies cosmetics
		for i, v in pairs(plr:WaitForChild("Cosmetics"):GetChildren()) do
			if v.Value then
				require(game.ServerScriptService.Game.Input.Cosmetics[v.Name]):GivePlr(plr.Character or plr.CharacterAdded:Wait())
			end
		end

		-- applies auras
		for i, v in pairs(plr:WaitForChild("Auras"):GetChildren()) do
			if v.Value then
				require(game.ServerScriptService.Game.Input.Auras[v.Name]):GivePlr(plr.Character or plr.CharacterAdded:Wait())
			end
		end
	end)
	
	-- initializes player data values
	addInstances(plr)
	loadData(plr)
	
	local char = plr.Character or plr.CharacterAdded:Wait()
	
	local values = char:WaitForChild("Values")
	local hum = char:WaitForChild("Humanoid")
	local animator = hum:FindFirstChild("Animator")
	local hrp = char:WaitForChild("HumanoidRootPart")
	
	local gui = plr.PlayerGui
	
	if gui:WaitForChild("Hotbar"):FindFirstChild("MovesetHolder") then
		gui:FindFirstChild("Hotbar"):FindFirstChild("MovesetHolder"):Destroy()
	end
	
	-- attaches new moveset ui after respawn
	local movesetholder = game.ReplicatedStorage.Assets.Movesets[plr:WaitForChild("Data"):WaitForChild("CurrentCharacter").Value]:FindFirstChild("MovesetHolder")

	if movesetholder then
		movesetholder:Clone().Parent = gui:WaitForChild("Hotbar")
	end
	
	-- weapon handling after respawn
	local weapon = game.ReplicatedStorage.Assets.Weapons:FindFirstChild(plr:WaitForChild("Data"):WaitForChild("CurrentCharacter").Value)

	if weapon and not char:FindFirstChild("Weapon") then
		local newWeapon = weapon:Clone()
		newWeapon.Name = "Weapon"
		newWeapon.Parent = char

		newWeapon["Weapon Weld"].Part1 = char:WaitForChild("Right Arm")
	end
	
	-- plays spawn animation on character auto-load
	local spawnAnimation = animator:LoadAnimation(game.ReplicatedStorage.Assets.Animations[plr:WaitForChild("Data"):WaitForChild("CurrentCharacter").Value]:WaitForChild("SpawnAnimation"))
	spawnAnimation:Play()

	local spawnSound = game.ReplicatedStorage.Assets.Effects[plr:WaitForChild("Data"):WaitForChild("CurrentCharacter").Value].Other:FindFirstChild("Spawn"):Clone()
	spawnSound.Parent = hrp
	spawnSound:Play()
	game.Debris:AddItem(spawnSound,spawnSound.TimeLength)
	
	-- interrupt logic again
	task.spawn(function()
		while spawnAnimation.IsPlaying do
			if hum.MoveDirection.Magnitude > 0 or not check(char) or values:FindFirstChild("Attacking") then
				spawnAnimation:Stop()
				break
			end
			task.wait()
		end
	end)

	task.spawn(function()
		while spawnSound.IsPlaying do
			if hum.MoveDirection.Magnitude > 0 or not check(char) or values:FindFirstChild("Attacking") then
				spawnSound:Destroy()
				break
			end
			task.wait()
		end
	end)
	
	-- reapplies cosmetics and auras
	for i, v in pairs(plr:WaitForChild("Cosmetics"):GetChildren()) do
		if v.Value then
			require(game.ServerScriptService.Game.Input.Cosmetics[v.Name]):GivePlr(char)
		end
	end

	for i, v in pairs(plr:WaitForChild("Auras"):GetChildren()) do
		if v.Value then
			require(game.ServerScriptService.Game.Input.Auras[v.Name]):GivePlr(char)
		end
	end
end)

-- saves data when player leaves
game.Players.PlayerRemoving:Connect(function(plr)
	saveData(plr)
end)

-- saves all players on shutdown
game:BindToClose(function()
	for i, player: Player in ipairs(game.Players:GetPlayers()) do
		saveData(player)
	end
end)

-- handles npc characters already in living folder on server start
for i, v in pairs(workspace.Living:GetChildren()) do
	if not game.Players:GetPlayerFromCharacter(v) then
		-- assigns npc collision group
		for i, idk in pairs(v:GetChildren()) do
			if idk:IsA("Part") or idk:IsA("MeshPart") or idk:IsA("BasePart") then
				idk.CollisionGroup = "Player"
			end
		end

		-- removes network ownership so server controls npc physics
		for _, basePart in ipairs(v:GetDescendants()) do
			if basePart:IsA("BasePart") then
				basePart:SetNetworkOwner(nil)
			end
		end

		createValues(v)

		local values = v:WaitForChild("Values")
		local hum = v:WaitForChild("Humanoid")
		local animator = hum:FindFirstChild("Animator")
		local hrp = v:WaitForChild("HumanoidRootPart")

		values.ChildAdded:Connect(function(child)
			if child.Name == "Ragdoll" then
				require(script.RagdollModule):Ragdoll(v)
			end
		end)

		values.ChildRemoved:Connect(function(child)
			if child.Name == "Ragdoll" then
				if not values:FindFirstChild("Ragdoll") then
					require(script.RagdollModule):UnRagdoll(v)
				end
			end
		end)

		hum.Died:Connect(function()
			local ragdoll = Instance.new("IntValue", values)
			ragdoll.Name = "Ragdoll"

			local kb = Instance.new("BodyVelocity", hrp)
			kb.MaxForce = Vector3.new(10000,10000,10000)
			kb.Velocity = hrp.CFrame.LookVector * 5
			game.Debris:AddItem(kb, .2)
		end)
	end
end

-- handles npcs spawned later
workspace.Living.ChildAdded:Connect(function(v)
	if not game.Players:GetPlayerFromCharacter(v) then
		for i, idk in pairs(v:GetChildren()) do
			if idk:IsA("Part") or idk:IsA("MeshPart") or idk:IsA("BasePart") then
				idk.CollisionGroup = "Player"
			end
		end
		
		for _, basePart in ipairs(v:GetDescendants()) do
			if basePart:IsA("BasePart") then
				basePart:SetNetworkOwner(nil)
			end
		end
		
		createValues(v)

		local values = v:WaitForChild("Values")
		local hum = v:WaitForChild("Humanoid")
		local animator = hum:FindFirstChild("Animator")
		local hrp = v:WaitForChild("HumanoidRootPart")

		values.ChildAdded:Connect(function(child)
			if child.Name == "Ragdoll" then
				require(script.RagdollModule):Ragdoll(v)
			end
		end)

		values.ChildRemoved:Connect(function(child)
			if child.Name == "Ragdoll" then
				if not values:FindFirstChild("Ragdoll") then
					require(script.RagdollModule):UnRagdoll(v)
				end
			end
		end)

		hum.Died:Connect(function()
			local ragdoll = Instance.new("IntValue", values)
			ragdoll.Name = "Ragdoll"

			local kb = Instance.new("BodyVelocity", hrp)
			kb.MaxForce = Vector3.new(10000,10000,10000)
			kb.Velocity = hrp.CFrame.LookVector * 5
			game.Debris:AddItem(kb, .2)
		end)
	end
end)
