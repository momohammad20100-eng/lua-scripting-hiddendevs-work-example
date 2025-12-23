-- ServerScriptService/IntermissionServer

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local ServerStorage = game:GetService("ServerStorage")

local roundUIEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RoundUI")
local seatsFolder = workspace:WaitForChild("RoundSeats")

-- Lobby music
local lobbyMusic = SoundService:WaitForChild("LobbyMusic")
lobbyMusic.Looped = true

local MIN_PLAYERS = 2
local INTERMISSION_SECONDS = 10
local STARTING_SECONDS = 5
local ROUND_STARTS_SECONDS = 5
local BOTTLE_SPIN_SECONDS = 6

-- Show "X was chosen!" time
local CHOSEN_DISPLAY_SECONDS = 3

-- Tool setup
local REVOLVER_TOOL_NAME = "RevolverTool"

------------------------------------------------
-- Try to load BottleSpinner safely
------------------------------------------------
local BottleSpinner = nil
do
	local ok, result = pcall(function()
		return require(game.ServerScriptService:WaitForChild("BottleSpinner"))
	end)
	if ok then
		BottleSpinner = result
	else
		warn("❌ BottleSpinner failed to load. Bottle will NOT spin. Error:", result)
	end
end

------------------------------------------------
-- Music controls
------------------------------------------------
local function playLobbyMusic()
	if not lobbyMusic.IsPlaying then
		lobbyMusic:Play()
	end
end

local function stopLobbyMusic()
	if lobbyMusic.IsPlaying then
		lobbyMusic:Stop()
	end
end

------------------------------------------------
-- Revolver utilities (equip + cleanup)
------------------------------------------------
local function removeRevolverFromPlayer(player: Player)
	if not player then return end

	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		local t = backpack:FindFirstChild(REVOLVER_TOOL_NAME)
		if t then t:Destroy() end
	end

	if player.Character then
		local t = player.Character:FindFirstChild(REVOLVER_TOOL_NAME)
		if t then t:Destroy() end
	end
end

local function giveAndEquipRevolver(player: Player)
	local template = ServerStorage:FindFirstChild(REVOLVER_TOOL_NAME)
	if not template then
		warn("❌ Missing " .. REVOLVER_TOOL_NAME .. " in ServerStorage.")
		return
	end

	removeRevolverFromPlayer(player)

	local tool = template:Clone()
	tool.Parent = player:WaitForChild("Backpack")

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:EquipTool(tool)
	end
end

-- R6: reset shoulder transform so arm returns to normal
local function resetR6RightArm(player: Player)
	local char = player.Character
	if not char then return end
	local torso = char:FindFirstChild("Torso")
	if not torso then return end

	local motor = torso:FindFirstChild("Right Shoulder")
	if motor and motor:IsA("Motor6D") then
		motor.Transform = CFrame.new()
	end
end

------------------------------------------------
-- Seat utilities
------------------------------------------------
local function getSeats()
	local seats = {}
	for _, inst in ipairs(seatsFolder:GetDescendants()) do
		if inst:IsA("Seat") or inst:IsA("VehicleSeat") then
			table.insert(seats, inst)
		end
	end
	return seats
end

local function setLockedStates(humanoid, locked)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, not locked)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, not locked)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, not locked)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, not locked)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, not locked)
end

------------------------------------------------
-- HARD lock player to seat (weld) + SeatLocked attribute
------------------------------------------------
local function lockPlayerToSeat(player, seat)
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	local hrp = character:WaitForChild("HumanoidRootPart")

	-- ✅ NEW: if shot/ragdolled/dead, don't lock them
	if character:FindFirstChild("ShotByGun") then return nil end
	if character:FindFirstChild("RagdollConstraints") then return nil end
	if humanoid.Health <= 0 then return nil end

	-- seat occupied by someone else
	if seat.Occupant and seat.Occupant ~= humanoid then
		return nil
	end

	-- keep seats anchored during round (gun may unanchor when shot)
	if seat.Anchored == false then
		seat.Anchored = true
	end

	-- lock movement
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.AutoRotate = false
	humanoid.Jump = false
	setLockedStates(humanoid, true)

	-- kill momentum
	humanoid:Move(Vector3.zero, true)
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero

	-- move + sit
	hrp.CFrame = seat.CFrame * CFrame.new(0, 2, 0)
	task.wait(0.05)
	humanoid.Sit = true
	seat:Sit(humanoid)

	-- retry briefly
	local startTime = os.clock()
	while seat.Occupant ~= humanoid and os.clock() - startTime < 1.5 do
		task.wait(0.1)
		humanoid.Sit = true
		seat:Sit(humanoid)
	end

	if seat.Occupant ~= humanoid then
		warn("❌ Failed to seat:", player.Name)
		player:SetAttribute("SeatLocked", false)
		setLockedStates(humanoid, false)
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
		humanoid.AutoRotate = true
		return nil
	end

	-- weld lock
	local old = hrp:FindFirstChild("SeatLockWeld")
	if old then old:Destroy() end

	local weld = Instance.new("WeldConstraint")
	weld.Name = "SeatLockWeld"
	weld.Part0 = hrp
	weld.Part1 = seat
	weld.Parent = hrp

	player:SetAttribute("SeatLocked", true)

	-- if Roblox tries to unseat, re-seat (unless shot/unlocked)
	local seatedConn = humanoid.Seated:Connect(function(isSeated)
		if humanoid.Parent == nil then return end

		-- ✅ NEW: do not re-seat if shot/ragdolled/dead/unlocked
		if character:FindFirstChild("ShotByGun") then return end
		if character:FindFirstChild("RagdollConstraints") then return end
		if humanoid.Health <= 0 then return end
		if player:GetAttribute("SeatLocked") ~= true then return end

		-- ✅ NEW: if gun unanchored the seat/chair, do not re-seat
		if seat.Anchored == false then return end

		if isSeated == false then
			humanoid.Jump = false
			humanoid.Sit = true
			seat:Sit(humanoid)
		end
	end)

	-- unlock function
	return function()
		player:SetAttribute("SeatLocked", false)
		if seatedConn then seatedConn:Disconnect() end
		if weld then weld:Destroy() end

		setLockedStates(humanoid, false)
		humanoid.AutoRotate = true
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
	end
end

local function seatAllPlayers()
	local seats = getSeats()
	local players = Players:GetPlayers()

	if #seats == 0 then
		warn("❌ No seats in Workspace.RoundSeats")
		return {}
	end

	local unlockers = {}
	for i, player in ipairs(players) do
		local seat = seats[i]
		if seat then
			local ok, unlock = pcall(function()
				return lockPlayerToSeat(player, seat)
			end)
			if ok and typeof(unlock) == "function" then
				table.insert(unlockers, unlock)
			elseif not ok then
				warn("❌ Seating error for", player.Name, unlock)
			end
		end
	end

	return unlockers
end

------------------------------------------------
-- Main loop
------------------------------------------------
print("✅ Intermission system running")

while true do
	playLobbyMusic()

	-- WAITING FOR PLAYERS
	while #Players:GetPlayers() < MIN_PLAYERS do
		local current = #Players:GetPlayers()
		roundUIEvent:FireAllClients("WaitingForPlayers", current, MIN_PLAYERS)
		task.wait(1)
	end

	-- Intermission
	for t = INTERMISSION_SECONDS, 1, -1 do
		if #Players:GetPlayers() < MIN_PLAYERS then break end
		roundUIEvent:FireAllClients("Intermission", t)
		task.wait(1)
	end
	if #Players:GetPlayers() < MIN_PLAYERS then continue end

	-- Starting
	for t = STARTING_SECONDS, 1, -1 do
		if #Players:GetPlayers() < MIN_PLAYERS then break end
		roundUIEvent:FireAllClients("Starting", t)
		task.wait(1)
	end
	if #Players:GetPlayers() < MIN_PLAYERS then continue end

	stopLobbyMusic()
	roundUIEvent:FireAllClients("Hide")

	-- ✅ NEW: clear ShotByGun + ragdoll folders from previous rounds
	for _, plr in ipairs(Players:GetPlayers()) do
		local ch = plr.Character
		if ch then
			local tag = ch:FindFirstChild("ShotByGun")
			if tag then tag:Destroy() end

			local rag = ch:FindFirstChild("RagdollConstraints")
			if rag then rag:Destroy() end
		end
	end

	-- Seat and lock
	local unlockers = seatAllPlayers()

	-- Round starts countdown
	for t = ROUND_STARTS_SECONDS, 1, -1 do
		roundUIEvent:FireAllClients("RoundStartsIn", t)
		task.wait(1)
	end

	------------------------------------------------
	-- Bottle phase
	------------------------------------------------
	roundUIEvent:FireAllClients("BottleSpinning")

	local chosenPlayer: Player? = nil

	if BottleSpinner and type(BottleSpinner.Spin) == "function" then
		local ok, result = pcall(function()
			return BottleSpinner.Spin(BOTTLE_SPIN_SECONDS)
		end)

		if ok then
			chosenPlayer = result
		else
			warn("❌ BottleSpinner.Spin() error:", result)
			task.wait(BOTTLE_SPIN_SECONDS)
		end
	else
		warn("⚠️ BottleSpinner missing or has no Spin(duration). Showing UI only.")
		task.wait(BOTTLE_SPIN_SECONDS)
	end

	print("🍼 Bottle landed on:", chosenPlayer and chosenPlayer.Name or "Nobody")

	-- Show chosen message + give revolver to shooter
	if chosenPlayer then
		roundUIEvent:FireAllClients("UserChosen", chosenPlayer.Name)

		-- ✅ mark shooter + equip tool
		chosenPlayer:SetAttribute("IsShooter", true)
		giveAndEquipRevolver(chosenPlayer)
	else
		roundUIEvent:FireAllClients("UserChosen", "Nobody")
	end

	task.wait(CHOSEN_DISPLAY_SECONDS)

	roundUIEvent:FireAllClients("Hide")
	roundUIEvent:FireAllClients("RoundBegin")

	-- Placeholder round duration while locked
	task.wait(10)

	-- ✅ cleanup shooter at end of round
	if chosenPlayer then
		chosenPlayer:SetAttribute("IsShooter", false)
		resetR6RightArm(chosenPlayer)
		removeRevolverFromPlayer(chosenPlayer)
	end

	-- Unlock at end of placeholder
	for _, unlock in ipairs(unlockers) do
		pcall(unlock)
	end
end
