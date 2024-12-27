local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))
local RunService = game:GetService("RunService")
local Player = game.Players.LocalPlayer
local controls = require(Player.PlayerScripts.PlayerModule):GetControls()
local Blur = game:GetService("Lighting").Blur

--Remote
local RemoteFunction = ReplicatedStorage:FindFirstChild("RemoteFunction")
local RemoteEvent = ReplicatedStorage:FindFirstChild("RemoteEvent")

--Require
local ToolsModule = require("ToolsModule")
local UIProviderModule = require("UIProviderModule")
local PlayerDataModule = require("ReplicatedPlayerData")

--UI
local FirstTimePlayedGui = UIProviderModule:GetUI("FirstTimePlayedGui")
local SelectCreatureTypeFrame = FirstTimePlayedGui:WaitForChild("SelectCreatureTypeFrame")
local SelectCreatureColorFrame = FirstTimePlayedGui:WaitForChild("SelectCreatureColorFrame")
local ShowCreaturesObtainedFrame = FirstTimePlayedGui:WaitForChild("ShowCreaturesObtainedFrame")
local ColorPicker = SelectCreatureColorFrame:WaitForChild("ColorPicker")

local CreatureTypeSelected = nil
local FavoriteColorSelected = nil

local function ChangeVisibiltyAllGUI(value)
    local guis = Player.PlayerGui:WaitForChild("StarterGuiSync")
	for _, gui in pairs(guis:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Name ~= "PositionningGui" then
            gui.Enabled = value
        end
	end
end

local function MakeCreatureModelViewport(creatureData)
    local CreatureModel = ReplicatedStorage.Assets.CreaturesModels[creatureData.CreatureType.."Character"]:Clone()
	CreatureModel.Name = creatureData.CreatureType.."Model"

	--clean model for showing
	CreatureModel.CanShowStatus:Destroy()
	CreatureModel.EnvironmentMaterial:Destroy()
	CreatureModel.ProximityDetection:Destroy()
	CreatureModel.EffectHead:Destroy()
	CreatureModel.CollisionFront:Destroy()
	CreatureModel.CollisionBack:Destroy()
	CreatureModel.CameraMaintenance:Destroy()
	CreatureModel.CreatureID:Destroy()
	CreatureModel.MaintenancePos:Destroy()
	CreatureModel.PrimaryPart.Anchored = true
	CreatureModel.PrimaryPart.CanQuery = true
	CreatureModel.PrimaryPart.CanCollide = false
	CreatureModel.RootPart.CanCollide = false
	
    --allow to update color and material of horse part horse
	for _, child in pairs(CreatureModel:GetChildren()) do
		if string.lower(child.Name):match("mane") then
			local t = creatureData["ManeColor"]
			child.Color = Color3.new(t.r, t.g, t.b)
			child.Material = creatureData["PartsMaterial"].Mane
		elseif string.lower(child.Name):match("marking") then
			local t = creatureData["Color"]
			child.Color = Color3.new(t.r, t.g, t.b)
			child.Material = creatureData["PartsMaterial"].Marking
		elseif string.lower(child.Name):match("tail") then
			local t = creatureData["TailColor"]
			child.Color = Color3.new(t.r, t.g, t.b)
			child.Material = creatureData["PartsMaterial"].Tail
		elseif string.lower(child.Name):match("socks") then
			local t = creatureData["SocksColor"]
			child.Color = Color3.new(t.r, t.g, t.b)
			child.Material = creatureData["PartsMaterial"].Socks
		end
	end

    --if viewport its to show in list creatures collection
    local ViewportFrame = ShowCreaturesObtainedFrame[creatureData.Gender.."ViewportFrame"]
	if ViewportFrame then
		CreatureModel.Parent = ViewportFrame
		local camera = Instance.new("Camera")
		local target = CreatureModel.PrimaryPart
		ViewportFrame.CurrentCamera = camera
		camera.Parent = ViewportFrame
		camera.CameraType = Enum.CameraType.Scriptable
		camera.MaxAxisFieldOfView = 50
		local cameraOffset = Vector3.new(0, 0.25, 12)
		camera.Focus = target.CFrame

        local i = 0
		local function RotateCreature()
			if i == 360 then
				i=0
			end
			local rotatedCFrame = CFrame.Angles(0, math.rad(i), 0)
            rotatedCFrame = CFrame.new(target.Position) * rotatedCFrame
            camera.CFrame = rotatedCFrame:ToWorldSpace(CFrame.new(cameraOffset))
			i+=1
		end

		--Rotation for Model horse and render in world
		RunService:BindToRenderStep("RotateModel"..creatureData.Gender, Enum.RenderPriority.Camera.Value + 1, RotateCreature)

        --[[ --Set IDLE Animation
		local animator = CreatureModel.Humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local animationTrack = animator:LoadAnimation(ReplicatedStorage.Assets.Animations[creatureData.CreatureType].Idle)
			animationTrack:Play()
		end ]]
	end
end

SelectCreatureTypeFrame.SelectSpeciesFrame.Cat.Activated:Connect(function()
   CreatureTypeSelected = "Cat"
   SelectCreatureTypeFrame.Visible = false
   SelectCreatureColorFrame.Visible = true
end)

SelectCreatureTypeFrame.SelectSpeciesFrame.Horse.Activated:Connect(function()
    CreatureTypeSelected = "Horse"
    SelectCreatureTypeFrame.Visible = false
    SelectCreatureColorFrame.Visible = true
 end)

 SelectCreatureColorFrame.StartBtn.Activated:Connect(function()
    local r = tonumber(ColorPicker.RGBInput.R.TextBox.Text)
    local g = tonumber(ColorPicker.RGBInput.G.TextBox.Text)
    local b = tonumber(ColorPicker.RGBInput.B.TextBox.Text)

    local c = Color3.fromRGB(r,g,b)

    FavoriteColorSelected = {r=c.R,g=c.G,b=c.B}

    SelectCreatureColorFrame.Visible = false

    local FemaleCreature = RemoteFunction.FirstTimePlayed.CreateCreatureFirstTime:InvokeServer(CreatureTypeSelected, FavoriteColorSelected, "Female")
    local MaleCreature = RemoteFunction.FirstTimePlayed.CreateCreatureFirstTime:InvokeServer(CreatureTypeSelected, FavoriteColorSelected, "Male")

    if FemaleCreature and MaleCreature then
        MakeCreatureModelViewport(FemaleCreature)
        MakeCreatureModelViewport(MaleCreature)
        ShowCreaturesObtainedFrame.Visible = true
		RemoteFunction:WaitForChild("SetValueOf"):InvokeServer("FirstTime", false)
    else
        warn("ERROR DURING CREATION OF FIRST CREATURES")
    end
 end)

 ShowCreaturesObtainedFrame.ShowCollectionBtn.Activated:Connect(function()
    ChangeVisibiltyAllGUI(true)

    ShowCreaturesObtainedFrame.Visible = false
    FirstTimePlayedGui.Enabled = false
    controls:Enable()
    local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.CFrame = Player.Character.HumanoidRootPart.CFrame
    Blur.Enabled = false

    RunService:UnbindFromRenderStep("RotateModelMale")
    RunService:UnbindFromRenderStep("RotateModelFemale")
	
	for id, data in pairs(PlayerDataModule.LocalData.CreaturesCollection) do
		RemoteFunction:WaitForChild("InvokHorsePlayer"):InvokeServer(id)
		break
	end

	task.wait(0.1)

	local CreatureCollection = UIProviderModule:GetUI("HorsesCollectionGui")
    CreatureCollection.Background.Visible = true
 end)

 RemoteEvent.FirstTimePlayed.InitFirstTimeGui.OnClientEvent:Connect(function()
    Blur.Enabled = true
    ChangeVisibiltyAllGUI(false)
    FirstTimePlayedGui.Enabled = true
    controls:Disable()
    local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = workspace.FirstTimeCamera.CFrame
 end)