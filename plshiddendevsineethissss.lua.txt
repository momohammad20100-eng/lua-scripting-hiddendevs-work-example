--[[
This script demonstrates an interactive obstacle course with moving platforms,
collectibles, dynamic scoring, camera motion, and power-ups.
All comments focus on reasoning: explaining why each block exists and how it interacts
with other components.
]]

--[[ 
Services:
We acquire the necessary Roblox services for creating gameplay features.
Players: to track when players join and leave, and to manage scoring.
TweenService: to animate platforms and camera smoothly.
RunService: to perform frame-based updates for movement.
Workspace: to create parts dynamically.
ReplicatedStorage: optional for storing modules or remote events.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--[[ 
Configuration Table:
All gameplay parameters are centralized here for easy adjustment.
Changing values here allows testing difficulty, platform behavior, or scoring
without modifying core logic.
]]
local Config = {
	PlatformCount = 15,                 -- Number of platforms to generate; affects course length
	PlatformSize = Vector3.new(10,1,10),-- Standard platform size; keeps collisions predictable
	MoveDistance = 30,                  -- Maximum movement offset for platforms; increases challenge
	MoveTime = 3,                        -- Time for a full movement cycle; affects player timing
	LaunchPower = 50,                    -- Upward velocity applied when players touch platforms
	CollectibleCount = 30,               -- Total collectibles; ensures multiple scoring opportunities
	CollectibleSize = Vector3.new(2,2,2),-- Visual size of collectibles; noticeable but non-obstructive
	LeaderboardName = "ObstacleScore",   -- Name of IntValue for leaderboard integration
	ScoreMultiplierTime = 10,            -- Duration of temporary score multipliers; encourages continuous play
	MaxCameraAngle = math.rad(360),      -- Maximum rotation angle for camera demonstration
	CameraHeight = 20                     -- Height of camera for clear overview of the course
}

--[[ 
Tables for managing game objects and state:
Platforms: stores all platform instances for update and cleanup.
Collectibles: stores all active collectibles for respawn logic.
PlayerScores: maps players to IntValues for leaderboard updates.
ActiveMultipliers: tracks temporary scoring multipliers for each player.
]]
local Platforms = {}
local Collectibles = {}
local PlayerScores = {}
local ActiveMultipliers = {}

--[[ 
Platform Metatable:
Encapsulates platform behavior, including creation, movement, touch interaction,
rotation tweening, and cleanup.
Using metatables allows multiple independent platforms with unique behaviors.
]]
local PlatformMeta = {}
PlatformMeta.__index = PlatformMeta

--[[ 
Platform Constructor:
Creates a platform part in Workspace, sets movement pattern, initializes touch and rotation,
and prepares event connections for cleanup.
]]
function PlatformMeta.new(position, pattern, index)
	local self = setmetatable({}, PlatformMeta)

	self.Part = Instance.new("Part")
	self.Part.Size = Config.PlatformSize
	self.Part.Position = position
	self.Part.Anchored = true                 -- Anchor to allow scripted movement
	self.Part.BrickColor = BrickColor.Random()-- Random color for visual variety
	self.Part.Name = "Platform_" .. index
	self.Part.Parent = Workspace

	self.OriginalPosition = position          -- Store base position for movement offsets
	self.Pattern = pattern                    -- Movement pattern: linear, oscillate, circular, zigzag
	self.ElapsedTime = 0                       -- Time tracker for movement calculations
	self.Direction = 1                          -- Optional: used for reversing movement if needed
	self.Connections = {}                       -- Stores event connections for cleanup

	self:SetupTouch()                          -- Initialize player interaction
	self:SetupRotationTween()                  -- Initialize visual rotation tween

	return self
end

--[[ 
SetupTouch Function:
Attaches a Touched event to the platform.
When a player touches the platform, they are launched upward with optional horizontal variance.
Why: Provides immediate feedback, dynamic movement challenge, and integrates with scoring logic.
]]
function PlatformMeta:SetupTouch()
	local conn = self.Part.Touched:Connect(function(hit)
		local character = hit.Parent
		local humanoid = character:FindFirstChild("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if humanoid and root then
			-- Launch player upward with small X/Z randomness for fun
			root.Velocity = Vector3.new(math.random(-10,10), Config.LaunchPower, math.random(-10,10))
		end
	end)
	table.insert(self.Connections, conn)
end

--[[ 
SetupRotationTween Function:
Creates a continuous rotation tween on the platform's Y-axis.
Why: Enhances visual feedback, adds dynamic motion, and demonstrates TweenService usage.
]]
function PlatformMeta:SetupRotationTween()
	local tweenInfo = TweenInfo.new(
		2,                           -- Duration of tween
		Enum.EasingStyle.Linear,     -- Smooth rotation
		Enum.EasingDirection.InOut,  -- Back-and-forth easing
		-1,                          -- Repeat indefinitely
		true                         -- Auto-reverse tween
	)
	local goal = {CFrame = self.Part.CFrame * CFrame.Angles(0, math.rad(180), 0)}
	local tween = TweenService:Create(self.Part, tweenInfo, goal)
	tween:Play()
	self.RotationTween = tween
end

--[[ 
Update Function:
Called every frame to move platforms based on their movement pattern.
Patterns: linear, oscillate, circular, zigzag.
Why: Frame-based updates provide smooth motion. Different patterns challenge player timing and positioning.
]]
function PlatformMeta:Update(dt)
	self.ElapsedTime = self.ElapsedTime + dt
	local fraction = math.sin(self.ElapsedTime / Config.MoveTime * math.pi)

	if self.Pattern == "linear" then
		local offset = Vector3.new(0, 0, fraction * Config.MoveDistance)
		self.Part.CFrame = CFrame.new(self.OriginalPosition + offset)
	elseif self.Pattern == "oscillate" then
		local offset = Vector3.new(fraction * Config.MoveDistance, 0, 0)
		self.Part.CFrame = CFrame.new(self.OriginalPosition + offset)
	elseif self.Pattern == "circular" then
		local angle = self.ElapsedTime
		local radius = Config.MoveDistance / 2
		local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		self.Part.CFrame = CFrame.new(self.OriginalPosition + offset)
	elseif self.Pattern == "zigzag" then
		local offsetX = math.sin(self.ElapsedTime * 2) * Config.MoveDistance
		local offsetZ = math.sin(self.ElapsedTime * 3) * Config.MoveDistance / 2
		self.Part.CFrame = CFrame.new(self.OriginalPosition + Vector3.new(offsetX,0,offsetZ))
	end
end

--[[ 
Destroy Function:
Disconnects all events and destroys the platform part.
Why: Proper cleanup prevents memory leaks and unintended behavior in live games.
]]
function PlatformMeta:Destroy()
	for _, conn in pairs(self.Connections) do
		conn:Disconnect()
	end
	self.RotationTween:Cancel()
	self.Part:Destroy()
end

--[[ 
Platform Generation Loop:
Creates multiple platforms with varied patterns and positions.
Why: Variety in platform behavior increases course complexity and engages players.
]]
for i = 1, Config.PlatformCount do
	local position = Vector3.new(i*(Config.PlatformSize.X+5),5,math.random(-5,5))
	local pattern
	if i % 4 == 1 then
		pattern = "linear"
	elseif i % 4 == 2 then
		pattern = "oscillate"
	elseif i % 4 == 3 then
		pattern = "circular"
	else
		pattern = "zigzag"
	end
	local platform = PlatformMeta.new(position, pattern, i)
	table.insert(Platforms, platform)
end

--[[ 
Player Leaderboard Setup:
Tracks player scores and initializes score multipliers.
Why: Integrates with the scoring system and allows leaderboard display in-game.
]]
Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	local score = Instance.new("IntValue")
	score.Name = Config.LeaderboardName
	score.Value = 0
	score.Parent = leaderstats
	PlayerScores[player] = score
	ActiveMultipliers[player] = 1
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerScores[player] = nil
	ActiveMultipliers[player] = nil
end)

--[[ 
SpawnCollectible Function:
Creates a collectible above a platform and manages touch interaction.
Why: Encourages exploration, scores points, and integrates with multipliers.
]]
local function SpawnCollectible(position,index)
	local part = Instance.new("Part")
	part.Size = Config.CollectibleSize
	part.Position = position
	part.Anchored = true
	part.BrickColor = BrickColor.Random()
	part.Name = "Collectible_"..index
	part.Parent = Workspace
	table.insert(Collectibles, part)

	local conn
	conn = part.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and PlayerScores[player] then
			PlayerScores[player].Value = PlayerScores[player].Value + ActiveMultipliers[player]
			conn:Disconnect()
			part:Destroy()
		end
	end)
end

--[[ 
Initial Collectible Spawn:
Spawns collectibles on each platform at different positions.
Why: Ensures players have multiple scoring opportunities from the start.
]]
for i = 1, Config.CollectibleCount do
	local plat = Platforms[(i-1) % #Platforms + 1]
	local pos = plat.Part.Position + Vector3.new(0,5,math.random(-3,3))
	SpawnCollectible(pos,i)
end


--[[ 
Camera Tween Setup:
Creates a continuous camera rotation for demo purposes.
Why: Highlights platforms dynamically and demonstrates TweenService usage.
]]
local camera = Workspace.CurrentCamera
local camTweenInfo = TweenInfo.new(20,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,-1,true)
local camGoal = {CFrame = CFrame.new(0,Config.CameraHeight,-50) * CFrame.Angles(0,Config.MaxCameraAngle,0)}
local camTween = TweenService:Create(camera,camTweenInfo,camGoal)
camTween:Play()

--[[ 
Collectible Respawn Loop:
Periodically checks and respawns missing collectibles.
Why: Maintains gameplay continuity and ensures persistent challenge.
]]
task.spawn(function()
	while true do
		task.wait(20)
		for i = 1, Config.CollectibleCount do
			if not Collectibles[i] or not Collectibles[i].Parent then
				local plat = Platforms[(i-1) % #Platforms + 1]
				local pos = plat.Part.Position + Vector3.new(0,5,math.random(-3,3))
				SpawnCollectible(pos,i)
			end
		end
	end
end)

--[[ 
Score Multiplier Power-Up:
Spawns temporary multipliers at random positions to incentivize risk-taking.
Why: Encourages players to move strategically, increases dynamic scoring, and demonstrates timed effects.
]]
local function SpawnMultiplier(position, multiplierValue, duration)
	local part = Instance.new("Part")
	part.Size = Vector3.new(3,3,3)
	part.Position = position
	part.Anchored = true
	part.BrickColor = BrickColor.new("Bright yellow")
	part.Name = "Multiplier"
	part.Parent = Workspace

	local conn
	conn = part.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and PlayerScores[player] then
			ActiveMultipliers[player] = multiplierValue
			task.delay(duration, function()
				if ActiveMultipliers[player] then
					ActiveMultipliers[player] = 1
				end
			end)
			conn:Disconnect()
			part:Destroy()
		end
	end)
end

--[[ 
Periodic Multiplier Spawn:
Spawns a multiplier on a random platform every 30 seconds.
Why: Keeps gameplay engaging and rewards attentive players dynamically.
]]
task.spawn(function()
	while true do
		task.wait(30)
		local plat = Platforms[math.random(1,#Platforms)]
		local pos = plat.Part.Position + Vector3.new(0,5,0)
		SpawnMultiplier(pos, 2, Config.ScoreMultiplierTime)
	end
end)

--[[ 
Platform Color Shift:
Changes platform colors gradually over time for visual feedback and variation.
Why: Enhances visual dynamics and provides subtle cues to players about platform activity.
]]
RunService.RenderStepped:Connect(function(dt)
	for _, plat in pairs(Platforms) do
		local color = plat.Part.Color
		local h,s,v = Color3.toHSV(color)
		h = (h + dt/10) % 1
		plat.Part.Color = Color3.fromHSV(h,s,v)
	end
end)