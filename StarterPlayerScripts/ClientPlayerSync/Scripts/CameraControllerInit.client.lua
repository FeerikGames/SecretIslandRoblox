local StarterPlayer = game:GetService("StarterPlayer")

local CameraController = require(StarterPlayer.StarterPlayerScripts.ClientPlayerSync.Modules:WaitForChild("CameraController"))
local LocalPlayer = game.Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))

local WalkSpeedModule = require("WalkSpeedModule")
local ToolsModule = require("ToolsModule")

local RemoteEvent:Folder = game.ReplicatedStorage.SharedSync.RemoteEvent
local CameraEnabled:boolean

--CameraController.SetTarget(Character.PrimaryPart)
--CameraController.SetEnabled(true)

RemoteEvent.CreatureEvolution.SetupCameraEvolution.OnClientEvent:Connect(function(activate:boolean)
    local CreaturesFolder:Folder = game.Workspace:FindFirstChild("CreaturesFolder")
    local CreatureModel:Model = CreaturesFolder:FindFirstChild("Creature_"..LocalPlayer.Name)
    local ui = LocalPlayer.PlayerGui:FindFirstChild("InteractionUI")
    
    if activate then
        if CreatureModel then
            ToolsModule.EnableOtherUI(false, {})
            -- Disable interaction panel with creature during evolution
            CreatureModel:SetAttribute("CanInteractWith", false)
            if ui then
                ui.Enabled = false -- Check if evolution have start with InteractionUI, if yes disable during evolution
            end

            -- Disable default camera and get status of ii
            CameraEnabled = CameraController.GetEnabled()
            CameraController.SetEnabled(false)
        
            -- Positonning camera for see evolution animation
            local camera = workspace.CurrentCamera
            camera.CameraType = Enum.CameraType.Scriptable
            camera.CFrame = CreatureModel:GetPivot()
            camera.CFrame = camera.CFrame + camera.CFrame:VectorToWorldSpace(Vector3.new(-8,0,-8))
            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, CreatureModel:GetPivot().Position)
        
            -- Disable player movement
            WalkSpeedModule.SetControlsPlayerAndCreature(false)
        end
    else
        if CreatureModel then
            ToolsModule.EnableOtherUI(true, {})
            -- Enable again interaction panel with creature after evolve
            CreatureModel:SetAttribute("CanInteractWith", true)
            if ui then
                ui.Enabled = true -- Check if evolution have start with InteractionUI, if yes enable again it
            end
        end

        WalkSpeedModule.SetControlsPlayerAndCreature(true)
        if CameraEnabled then
			CameraController.SetEnabled(true)
		else
			local camera = workspace.CurrentCamera
			camera.CameraType = Enum.CameraType.Custom
		end
    end
end)