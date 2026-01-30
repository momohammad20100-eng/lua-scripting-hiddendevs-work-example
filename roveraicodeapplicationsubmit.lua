
local uis = game:GetService("UserInputService")
local rs = game:GetService("RunService")
local plr = game.Players.LocalPlayer
local rep = game:GetService("ReplicatedStorage")
local tweenser = game:GetService("TweenService")
local cam = workspace.CurrentCamera

local plrgui = plr:WaitForChild("PlayerGui")
local rovergui = plrgui:WaitForChild("RoverMenu")

local rover = nil
local controlling = false
local wobble = 0
local updatesend = 0
local curspeed = 0

local maxspeed = 25
local speedstep = 50
local maxdist = 500

local roverfolder = rep:WaitForChild("Rover")
local startevent = roverfolder.Events:WaitForChild("Start")
local endevent = roverfolder.Events:WaitForChild("End")
local posupdate = roverfolder.Events:WaitForChild("SetPos")
local drivesfx = roverfolder.Sounds:WaitForChild("DriveLoop")
local camsfx = roverfolder.Sounds:WaitForChild("Switch")

-- function sets up the gui elements for the rover menu
local function setupGUI()
	local sf = rovergui:WaitForChild("StartFrame")
	sf.Visible = true
	sf.Transparency = 1
	rovergui.CanvasGroup.AbortUI.Visible = false

	local pc = rovergui.CanvasGroup.Main.ProfileContainer
	pc.TextLabel.Text = plr.DisplayName
	pc.Profile.Image = "rbxthumb://type=AvatarHeadShot&id="..plr.UserId.."&w=420&h=420"

	updateMeters()
end

-- function updates the speed and radar meters in the gui
function updateMeters()
	local speedframe = rovergui.CanvasGroup.Main.SpeedContainer.Meter.Main
	local txt = rovergui.CanvasGroup.Main.SpeedContainer.Percentage
	local ratio = curspeed / maxspeed
	local tw = tweenser:Create(speedframe, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {Size = UDim2.new(ratio,0,0.83,0)})
	tw:Play()
	txt.Text = tostring(math.round(curspeed)).." studs per second"

	if rover and rover.PrimaryPart then
		local dist = (plr.Character:WaitForChild("HumanoidRootPart").Position - rover.PrimaryPart.Position).Magnitude
		local radarframe = rovergui.CanvasGroup.Main.RadarContainer.Meter.Main
		local frac = 1 - math.clamp(dist/maxdist,0,1)
		local tw2 = tweenser:Create(radarframe, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {Size = UDim2.new(frac,0,0.83,0)})
		tw2:Play()
	end
end

-- function aborts the rover control
-- it resets speed stops sounds restores camera and walk speed triggers end event
local function abortControl()
	if rover then
		rover.Data:WaitForChild("InUse").Value = false
	end
	controlling = false
	curspeed = 0

	if drivesfx.IsPlaying then drivesfx:Stop() end

	local sf = rovergui:WaitForChild("StartFrame")
	rovergui.CanvasGroup.Visible = true
	sf.Visible = true
	sf.Transparency = 1

	local tw = tweenser:Create(sf, TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {Transparency=0})
	tw:Play()
	tw.Completed:Wait()

	local humanoid = plr.Character:WaitForChild("Humanoid")
	cam.CameraType = Enum.CameraType.Custom
	cam.CameraSubject = humanoid

	rovergui.CanvasGroup.Visible = false
	local tw2 = tweenser:Create(sf, TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {Transparency=1})
	tw2:Play()
	tw2.Completed:Wait()

	sf.Visible = false
	humanoid.WalkSpeed = 16
	endevent:FireServer()
end

-- function adds a small wobble to the camera while driving
local function driveWobble(dt)
	wobble = wobble + dt*10
	if rover and rover:FindFirstChild("CamPart") then
		local base = rover.CamPart.CFrame
		local off = Vector3.new(math.sin(wobble)*0.25, math.cos(wobble*2)*0.15, 0)
		cam.CFrame = base * CFrame.new(off)
	end
end

-- function handles player death fade using start frame and exits rover automatically
local function handleDeath()
	abortControl() -- auto exit rover when dead
	local sf = rovergui:WaitForChild("StartFrame")
	sf.Visible = true
	sf.Transparency = 1
	local twIn = tweenser:Create(sf, TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {Transparency=0})
	twIn:Play()
	twIn.Completed:Wait()
	wait(1)
	local twOut = tweenser:Create(sf, TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {Transparency=1})
	twOut:Play()
	twOut.Completed:Wait()
	sf.Visible = false
end

-- event triggered when the server starts rover control
startevent.OnClientEvent:Connect(function(r)
	rover = r
	if camsfx then camsfx:Play() end

	rover.Data:WaitForChild("InUse").Value = true
	setupGUI()
	plr.Character:WaitForChild("Humanoid").WalkSpeed = 0

	local sf = rovergui:WaitForChild("StartFrame")
	local tw = tweenser:Create(sf, TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {Transparency=0})
	tw:Play()
	tw.Completed:Wait()

	rovergui.CanvasGroup.Visible = true

	local tw2 = tweenser:Create(sf, TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {Transparency=1})
	tw2:Play()
	tw2.Completed:Wait()

	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = rover.CamPart.CFrame

	controlling = true
	wobble = 0
end)

-- render stepped loop updates rover movement and camera
rs.RenderStepped:Connect(function(dt)
	if not controlling or not rover or not rover.PrimaryPart then return end

	local root = plr.Character:WaitForChild("HumanoidRootPart")
	local dist = (root.Position - rover.PrimaryPart.Position).Magnitude
	if dist > maxdist then abortControl() return end

	local move = Vector3.new()
	if uis:IsKeyDown(Enum.KeyCode.W) then move -= rover.PrimaryPart.CFrame.RightVector end
	if uis:IsKeyDown(Enum.KeyCode.S) then move += rover.PrimaryPart.CFrame.RightVector end

	local cf = rover.PrimaryPart.CFrame
	if uis:IsKeyDown(Enum.KeyCode.A) then cf *= CFrame.Angles(0, math.rad(90*dt),0) end
	if uis:IsKeyDown(Enum.KeyCode.D) then cf *= CFrame.Angles(0, math.rad(-90*dt),0) end

	if move.Magnitude>0 then
		curspeed += (maxspeed - curspeed)/speedstep
		local rc = RaycastParams.new()
		rc.FilterDescendantsInstances = {rover}
		rc.FilterType = Enum.RaycastFilterType.Exclude
		local ray = workspace:Raycast(rover.PrimaryPart.Position, move * curspeed * dt * 5, rc)
		if ray then rover:SetPrimaryPartCFrame(cf) else rover:SetPrimaryPartCFrame(cf + move*dt*curspeed) end
		driveWobble(dt)
		if not drivesfx.IsPlaying then drivesfx:Play() end
	else
		if drivesfx.IsPlaying then drivesfx:Stop() end
		curspeed = 0
		wobble = 0
		rover:SetPrimaryPartCFrame(cf)
		if rover:FindFirstChild("CamPart") then cam.CFrame = rover.CamPart.CFrame end
	end

	updatesend += dt
	if updatesend > 2 then posupdate:FireServer(rover.PrimaryPart.CFrame) updatesend = 0 end
	updateMeters()
end)

-- input began listener checks for abort key press
uis.InputBegan:Connect(function(i,p)
	if p then return end
	if controlling and i.KeyCode == Enum.KeyCode.Q then abortControl() end
end)

-- connect humanoid died to death fade effect and auto exit
plr.Character:WaitForChild("Humanoid").Died:Connect(function()
	handleDeath()
end)

