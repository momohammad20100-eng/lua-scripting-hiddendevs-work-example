
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


local Platforms = {} -- Each platform will be a PlatformMeta object with movement and touch behavior and to store all Platforms inside the game

local Collectibles = {} -- Used for respawning and tracking existing collectibles and to store all collectible parts.

local PlayerScores = {} -- Key = Player object, Value = IntValue representing the score and to to store each player's score IntValue

local ActiveMultipliers = {} -- Key = Player object, Value = multiplier number (e.g., 1, 2, etc.) And to store each player's active score multiplier


--[[ 
Platform Metatable:
Encapsulates platform behavior, including creation, movement, touch interaction,
rotation tweening, and cleanup.
Using metatables allows multiple independent platforms with unique behaviors.
]]

local PlatformMeta = {} -- Table that will act as the class for platforms

PlatformMeta.__index = PlatformMeta -- This allows us to use PlatformMeta:new(), PlatformMeta:Update(), etc, and sets the metatable of the PlatformMeta to itself.


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
    -- Connect to the Touched event of the platform part
    local conn = self.Part.Touched:Connect(function(hit)
        -- Get the parent of whatever touched the platform (usually the character model)
        local character = hit.Parent

        -- Check if the character has a Humanoid (to verify it's a player)
        local humanoid = character:FindFirstChild("Humanoid")

        -- Get the HumanoidRootPart for applying velocity
        local root = character:FindFirstChild("HumanoidRootPart")

        -- Only proceed if both Humanoid and HumanoidRootPart exist
        if humanoid and root then
            -- Launch the player upward
            -- Y velocity = Config.LaunchPower
            -- X/Z velocity = small random offset (-10 to 10) for fun effect
            root.Velocity = Vector3.new(
                math.random(-10, 10),  -- X-axis random push
                Config.LaunchPower,     -- Y-axis upward launch
                math.random(-10, 10)   -- Z-axis random push
            )
        end
    end)

    -- Store this connection in the platform's Connections table for later cleanup
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
    -- Accumulate the elapsed time since the platform started moving.
    self.ElapsedTime = self.ElapsedTime + dt  

    -- Calculate a fraction for smooth movement using sine wave.
    -- This creates smooth in/out transitions as sin goes from 0 -> 1 -> 0.
    local fraction = math.sin(self.ElapsedTime / Config.MoveTime * math.pi)

    -- Linear movement along the Z-axis
    if self.Pattern == "linear" then
        -- Create an offset along the Z-axis based on the fraction
        local offset = Vector3.new(0, 0, fraction * Config.MoveDistance)
        -- Set the platform's new position by adding the offset to its original position
        self.Part.CFrame = CFrame.new(self.OriginalPosition + offset)

    -- Oscillating movement along the X-axis
    elseif self.Pattern == "oscillate" then
        -- Offset along X-axis using the same sine fraction
        local offset = Vector3.new(fraction * Config.MoveDistance, 0, 0)
        -- Update platform position
        self.Part.CFrame = CFrame.new(self.OriginalPosition + offset)

    -- Circular movement around the original position
    elseif self.Pattern == "circular" then
        -- Use elapsed time as angle to continuously rotate around origin
        local angle = self.ElapsedTime
        local radius = Config.MoveDistance / 2  -- Set radius of circular movement
        -- Calculate circular offset using cosine for X and sine for Z
        local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
        -- Update platform's position
        self.Part.CFrame = CFrame.new(self.OriginalPosition + offset)

    -- Zigzag movement along both X and Z axes
    elseif self.Pattern == "zigzag" then
        -- X movement oscillates faster (times 2) 
        local offsetX = math.sin(self.ElapsedTime * 2) * Config.MoveDistance
        -- Z movement oscillates differently (times 3) at half distance
        local offsetZ = math.sin(self.ElapsedTime * 3) * Config.MoveDistance / 2
        -- Update platform's position with combined X and Z offsets
        self.Part.CFrame = CFrame.new(self.OriginalPosition + Vector3.new(offsetX, 0, offsetZ))
    end
end

--[[ 
Destroy Function:
Disconnects all events and destroys the platform part.
Why: Proper cleanup prevents memory leaks and unintended behavior in live games.
]]

function PlatformMeta:Destroy()
	for _, conn in (self.Connections) do
		conn:Disconnect()
	end
	self.RotationTween:Cancel() -- Cancels the tween rotation.
	self.Part:Destroy() -- Destroys the part.
end

--[[ 
Platform Generation Loop:
Creates multiple platforms with varied patterns and positions.
Why: Variety in platform behavior increases course complexity and engages players.
]]

for i = 1, Config.PlatformCount do
    -- Calculate a position for this platform
    -- X is spaced out by platform width + 5 units
    -- Y is fixed at 5 units above the ground
    -- Z is randomized slightly between -5 and 5 to create variation
    local position = Vector3.new(
        i * (Config.PlatformSize.X + 5),  -- X position: spread platforms horizontally
        5,                                -- Y position: height of platform
        math.random(-5, 5)                -- Z position: small random offset for variation
    )

    -- Determine the movement pattern of the platform based on its index
    local pattern
    if i % 4 == 1 then
        pattern = "linear"     -- Every 1st platform in a group of 4 is linear
    elseif i % 4 == 2 then
        pattern = "oscillate"  -- 2nd is oscillate
    elseif i % 4 == 3 then
        pattern = "circular"   -- 3rd is circular
    else
        pattern = "zigzag"     -- 4th is zigzag
    end

    -- Create a new platform using the PlatformMeta class
    -- Pass in the calculated position, chosen pattern, and its index i
    local platform = PlatformMeta.new(position, pattern, i)

    -- Add this platform to the Platforms table for later updating/moving
    table.insert(Platforms, platform)
end

--[[ 
Player Leaderboard Setup:
Tracks player scores and initializes score multipliers.
Why: Integrates with the scoring system and allows leaderboard display in-game.
]]
Players.PlayerAdded:Connect(function(player)
    -- Create a folder to hold leaderboard stats for this player
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"      -- Roblox automatically recognizes "leaderstats" for the leaderboard GUI
    leaderstats.Parent = player           -- Parent it to the player so it's visible in the leaderboard

    -- Create an IntValue to track this player's score
    local score = Instance.new("IntValue")
    score.Name = Config.LeaderboardName  -- Name it according to your config (e.g., "Score")
    score.Value = 0                       -- Initial score is 0
    score.Parent = leaderstats            -- Put it inside the leaderstats folder

    -- Store a reference to this player's score in a table for easy access in scripts
    PlayerScores[player] = score

    -- Initialize a multiplier for this player (used for score bonuses, etc.)
    ActiveMultipliers[player] = 1
end)

-- When a player leaves the game
Players.PlayerRemoving:Connect(function(player)
    -- Clean up references to this player's data to prevent memory leaks
    PlayerScores[player] = nil
    ActiveMultipliers[player] = nil
end)

--[[ 
SpawnCollectible Function:
Creates a collectible above a platform and manages touch interaction.
Why: Encourages exploration, scores points, and integrates with multipliers.
]]
local function SpawnCollectible(position, index)
    -- Create a new Part to act as the collectible
    local part = Instance.new("Part")
    part.Size = Config.CollectibleSize     -- Set size from configuration
    part.Position = position               -- Set position in the world
    part.Anchored = true                   -- Keep it in place; it won't fall due to gravity
    part.BrickColor = BrickColor.Random()  -- Give it a random color for variety
    part.Name = "Collectible_"..index      -- Name it uniquely
    part.Parent = Workspace                -- Add it to the Workspace so it appears in-game

    -- Keep track of this collectible in a table for future reference if needed
    table.insert(Collectibles, part)

    -- Connect a Touched event to detect when a player touches the collectible
    local conn
    conn = part.Touched:Connect(function(hit)
        -- Get the player who touched the part (if it’s a character)
        local player = Players:GetPlayerFromCharacter(hit.Parent)
        if player and PlayerScores[player] then
            -- Add score for this player, multiplied by their active multiplier
            PlayerScores[player].Value = PlayerScores[player].Value + ActiveMultipliers[player]

            -- Disconnect the Touched event so it doesn’t trigger again
            conn:Disconnect()

            -- Remove the collectible from the game
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
    -- Choose a platform for this collectible
    -- Uses modulo to cycle through all platforms if there are more collectibles than platforms
    local plat = Platforms[(i - 1) % #Platforms + 1]

    -- Calculate the position for the collectible
    -- X and Z come from the platform, Y is raised by 5 units so the collectible floats above the platform
    -- Slight random offset in Z (-3 to 3) to avoid stacking collectibles exactly in the same spot
    local pos = plat.Part.Position + Vector3.new(0, 5, math.random(-3, 3))

    -- Spawn the collectible at the calculated position with a unique index
    SpawnCollectible(pos, i)
end


--[[ 
Camera Tween Setup:
Creates a continuous camera rotation for demo purposes.
Why: Highlights platforms dynamically and demonstrates TweenService usage.
]]

-- Get the current camera in the Workspace
local camera = Workspace.CurrentCamera

-- Create TweenInfo for the camera movement
-- 20 seconds duration, linear easing style, in/out easing direction
-- -1 repeats means infinite looping, true = reverses tween each time (back-and-forth)
local camTweenInfo = TweenInfo.new(
    20,                          -- Duration of 20 seconds
    Enum.EasingStyle.Linear,     -- Linear easing (constant speed)
    Enum.EasingDirection.InOut,  -- Smooth in/out transition
    -1,                          -- Repeat infinitely
    true                         -- Reverse tween after each cycle (ping-pong)
)

-- Define the goal CFrame for the camera
-- Moves camera to (0, CameraHeight, -50) and rotates by MaxCameraAngle radians on Y-axis
local camGoal = {
    CFrame = CFrame.new(0, Config.CameraHeight, -50) * 
            CFrame.Angles(0, Config.MaxCameraAngle, 0)
}

-- Create the tween for the camera using TweenService
local camTween = TweenService:Create(camera, camTweenInfo, camGoal)

-- Play the tween (starts moving the camera)
camTween:Play()


--[[ 
Collectible Respawn Loop:
Periodically checks and respawns missing collectibles.
Why: Maintains gameplay continuity and ensures persistent challenge.
]]

-- Start a new thread to handle periodic collectible respawning
task.spawn(function()
    while true do
        -- Wait 20 seconds before checking/respawning collectibles
        task.wait(20)

        -- Loop through all collectible slots
        for i = 1, Config.CollectibleCount do
            -- Check if the collectible is missing or has been destroyed
            if not Collectibles[i] or not Collectibles[i].Parent then
                -- Choose a platform to spawn the collectible on
                local plat = Platforms[(i - 1) % #Platforms + 1]

                -- Calculate a new position slightly above the platform with random Z offset
                local pos = plat.Part.Position + Vector3.new(0, 5, math.random(-3, 3))

                -- Spawn the collectible at the new position with the same index
                SpawnCollectible(pos, i)
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
    -- Create a new Part to represent the multiplier
    local part = Instance.new("Part")
    part.Size = Vector3.new(3, 3, 3)              -- Fixed size
    part.Position = position                       -- Position in the world
    part.Anchored = true                           -- Stay in place
    part.BrickColor = BrickColor.new("Bright yellow") -- Bright color for visibility
    part.Name = "Multiplier"                       -- Name for organization
    part.Parent = Workspace                         -- Add to Workspace so it appears in-game

    -- Connect a Touched event to detect when a player touches the multiplier
    local conn
    conn = part.Touched:Connect(function(hit)
        -- Get the player who touched it
        local player = Players:GetPlayerFromCharacter(hit.Parent)
        if player and PlayerScores[player] then
            -- Apply the multiplier to this player's active multiplier
            ActiveMultipliers[player] = multiplierValue

            -- After `duration` seconds, reset the multiplier back to 1
            task.delay(duration, function()
                if ActiveMultipliers[player] then
                    ActiveMultipliers[player] = 1
                end
            end)

            -- Disconnect the Touched event and remove the part
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
        -- Wait 30 seconds between each multiplier spawn
        task.wait(30)

        -- Choose a random platform from the Platforms table
        local plat = Platforms[math.random(1, #Platforms)]

        -- Position the multiplier slightly above the platform
        local pos = plat.Part.Position + Vector3.new(0, 5, 0)

        -- Spawn a multiplier at the calculated position
        -- This multiplier gives a 2x score boost and lasts Config.ScoreMultiplierTime seconds
        SpawnMultiplier(pos, 2, Config.ScoreMultiplierTime)
    end
end)
