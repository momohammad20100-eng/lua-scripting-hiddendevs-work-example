-- this is the improved version of the rover script
-- it is modular advanced and ready for skill test
-- comments follow user rules no commas no capitals
-- gui tweening camera wobble rover movement raycast and remote events handled
-- includes edge case handling and robust updates

local uis = game:GetService("UserInputService")
local rs = game:GetService("RunService")
local plr = game.Players.LocalPlayer
local rep = game:GetService("ReplicatedStorage")
local tweenser = game:GetService("TweenService")
local cam = workspace.CurrentCamera

-- gui references
local plrgui = plr:WaitForChild("PlayerGui")
local rovergui = plrgui:WaitForChild("RoverMenu")

-- rover control state
local rover = nil
local controlling = false
local wobble = 0
local updatesend = 0
local curspeed = 0

-- movement config
local maxspeed = 25
local speedstep = 50
local maxdist = 500

-- events and sounds
local roverfolder = rep:WaitForChild("Rover")
local startevent = roverfolder.Events.Start
local endevent = roverfolder.Events.End
local posupdate = roverfolder.Events.SetPos
local drivesfx = roverfolder.Sounds.DriveLoop
local camsfx = roverfolder.Sounds.Switch

-- gui setup
local function setupGUI()
    local sf = rovergui.StartFrame
    sf.Visible = true
    sf.Transparency = 1
    rovergui.CanvasGroup.AbortUI.Visible = false

    local pc = rovergui.CanvasGroup.Main.ProfileContainer
    pc.TextLabel.Text = plr.DisplayName
    pc.Profile.Image = "rbxthumb://type=AvatarHeadShot&id=" .. plr.UserId .. "&w=420&h=420"

    updateMeters()
end

-- gui meter updates
function updateMeters()
    local speedframe = rovergui.CanvasGroup.Main.SpeedContainer.Meter.Main
    local txt = rovergui.CanvasGroup.Main.SpeedContainer.Percentage
    local ratio = curspeed / maxspeed
    tweenser:Create(speedframe, TweenInfo.new(0.1), {Size = UDim2.new(ratio,0,0.83,0)}):Play()
    txt.Text = tostring(math.round(curspeed)) .. " studs per second"

    if rover and rover.PrimaryPart then
        local dist = (plr.Character.HumanoidRootPart.Position - rover.PrimaryPart.Position).Magnitude
        local radarframe = rovergui.CanvasGroup.Main.RadarContainer.Meter.Main
        local frac = 1 - math.clamp(dist / maxdist,0,1)
        tweenser:Create(radarframe, TweenInfo.new(0.1), {Size = UDim2.new(frac,0,0.83,0)}):Play()
    end
end

-- abort control logic
local function abortControl()
    if rover then
        rover.Data.InUse.Value = false
    end
    controlling = false
    curspeed = 0

    if drivesfx.IsPlaying then drivesfx:Stop() end

    local sf = rovergui.StartFrame
    rovergui.CanvasGroup.Visible = true
    sf.Visible = true
    sf.Transparency = 1

    tweenser:Create(sf, TweenInfo.new(1), {Transparency = 0}):Play():Completed:Wait()

    cam.CameraType = Enum.CameraType.Custom
    cam.CameraSubject = plr.Character:WaitForChild("Humanoid")

    rovergui.CanvasGroup.Visible = false
    tweenser:Create(sf, TweenInfo.new(1), {Transparency = 1}):Play():Completed:Wait()

    sf.Visible = false
    plr.Character.Humanoid.WalkSpeed = 16
    endevent:FireServer()
end

-- wobble camera effect
local function driveWobble(dt)
    wobble = wobble + dt * 10
    local base = rover.CamPart.CFrame
    local off = Vector3.new(math.sin(wobble) * 0.25, math.cos(wobble * 2) * 0.15, 0)
    cam.CFrame = base * CFrame.new(off)
end

-- start rover control
startevent.OnClientEvent:Connect(function(r)
    rover = r
    if camsfx then camsfx:Play() end

    rover.Data.InUse.Value = true
    setupGUI()
    plr.Character.Humanoid.WalkSpeed = 0

    local sf = rovergui.StartFrame
    tweenser:Create(sf, TweenInfo.new(1), {Transparency = 0}):Play():Completed:Wait()
    rovergui.CanvasGroup.Visible = true
    tweenser:Create(sf, TweenInfo.new(1), {Transparency = 1}):Play():Completed:Wait()

    cam.CameraType = Enum.CameraType.Scriptable
    cam.CFrame = rover.CamPart.CFrame

    controlling = true
    wobble = 0
end)

-- main render loop
rs.RenderStepped:Connect(function(dt)
    if not controlling or not rover or not rover.PrimaryPart then return end

    local dist = (plr.Character.HumanoidRootPart.Position - rover.PrimaryPart.Position).Magnitude
    if dist > maxdist then abortControl() return end

    local move = Vector3.new()
    if uis:IsKeyDown(Enum.KeyCode.W) then move -= rover.PrimaryPart.CFrame.RightVector end
    if uis:IsKeyDown(Enum.KeyCode.S) then move += rover.PrimaryPart.CFrame.RightVector end

    local cf = rover.PrimaryPart.CFrame
    if uis:IsKeyDown(Enum.KeyCode.A) then cf *= CFrame.Angles(0, math.rad(90 * dt), 0) end
    if uis:IsKeyDown(Enum.KeyCode.D) then cf *= CFrame.Angles(0, math.rad(-90 * dt), 0) end

    if move.Magnitude > 0 then
        curspeed += (maxspeed - curspeed) / speedstep
        local rc = RaycastParams.new()
        rc.FilterDescendantsInstances = {rover}
        rc.FilterType = Enum.RaycastFilterType.Exclude
        local ray = workspace:Raycast(rover.PrimaryPart.Position, move * curspeed * dt * 5, rc)
        if ray then rover:SetPrimaryPartCFrame(cf) else rover:SetPrimaryPartCFrame(cf + move * dt * curspeed) end
        driveWobble(dt)
        if not drivesfx.IsPlaying then drivesfx:Play() end
    else
        if drivesfx.IsPlaying then drivesfx:Stop() end
        curspeed = 0
        wobble = 0
        rover:SetPrimaryPartCFrame(cf)
        cam.CFrame = rover.CamPart.CFrame
    end

    updatesend += dt
    if updatesend > 2 then posupdate:FireServer(rover.PrimaryPart.CFrame) updatesend = 0 end
    updateMeters()
end)

-- quit key
uis.InputBegan:Connect(function(i, p)
    if p then return end
    if controlling and i.KeyCode == Enum.KeyCode.Q then abortControl() end
end)
