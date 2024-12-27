local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local controls = require(game:GetService("Players").LocalPlayer.PlayerScripts.PlayerModule):GetControls()
local SelfieMode = require(ReplicatedStorage:WaitForChild("SelfieMode"))
local RunService = game:GetService("RunService")
local InteractionUI = {}

local LocalPlayer = Players.LocalPlayer
local mouse = LocalPlayer:GetMouse()

local Assets = ReplicatedStorage:WaitForChild("SharedSync").Assets
local ToolsModule = require("ToolsModule")
local WalkSpeedModule = require("WalkSpeedModule")
local PlayerDataModule = require("ReplicatedPlayerData")
local CameraController = require(game:GetService("StarterPlayer").StarterPlayerScripts.ClientPlayerSync.Modules:WaitForChild("CameraController"))
local UIAnimationModule = require("UIAnimationModule")
local GameDataModule = require("GameDataModule")
local EnvironmentModule = require("EnvironmentModule")

local GetRemoteEvent = require("GetRemoteEvent")
local InteractionEvent = GetRemoteEvent("InteractionEvent")
local UIProviderModule = require("UIProviderModule")
local RemoteFunction = ReplicatedStorage.SharedSync.RemoteFunction
local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local BindableEvent = ReplicatedStorage.SharedSync.BindableEvent
local HorseEvents = ReplicatedStorage.SharedSync.HorseEvents
local UtilFunctions = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("UtilFunctions"))

-- Stock

local InteractionUIInstances = {}
local InteractionObjects = {}
local cameraLastPosition = nil
local isCameraMaintenance = false

--PARAMETERS

local ProgressBarSpeed = 0.005
local debounce = true
local coolDown = 0.15

local CreatureInteractionGui = UIProviderModule:GetUI("CreatureInteractionGui")
--return of changed event custom allo to launch function .Disconnect() -> remove from Binds the event connected (See ReplicatedPlayerData Changed function)
local CreatureLocalDataEventChanged = nil

local CreatureIsMounted = false

local rotationTask = nil
local EvolveButtonConnect = nil

local function AnimateGiveHealth(player, value)
    local gui = Instance.new("ScreenGui")
    local frame = CreatureInteractionGui.Template.CreatureHealthAnim:Clone()
    frame.Parent = gui
    gui.Parent = player.PlayerGui

    local rX = Random.new():NextNumber(0.4,0.6)
    frame.Size = UDim2.fromScale(0.1,0.1)
    frame.Position = UDim2.fromScale(rX,0.5)
    frame.Visible = true

    frame.Value.Text = value
    frame.Value.TextColor3 = Color3.fromRGB(139, 234, 30)
    local info = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0)
    local goals = {Position = UDim2.fromScale(rX, 0.17)}
    local tween = TweenService:Create(frame, info, goals)
    gui.Enabled = true
    tween:Play()
    tween.Completed:Connect(function()
        gui:Destroy()
    end)
end

local function CloneUI()
    local InteractionUIInstance = Assets:WaitForChild("InteractionUI"):Clone()
    InteractionUIInstance.Parent = LocalPlayer:WaitForChild("PlayerGui")

    return InteractionUIInstance
end

local function ClearUI(InteractionUIInstance)
    local exist = CreatureInteractionGui:FindFirstChild("Main")
    if exist then
        exist:Destroy()
    end

    for _,Button in pairs(InteractionUIInstance.Main:GetChildren()) do
        if Button:IsA("TextButton") or Button:IsA("ImageButton") then
            Button:Destroy()
        end
    end
end

local function transformCamera(Horse)
    CameraController.SetEnabled(false)
    local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable

    cameraLastPosition = camera.CFrame
    isCameraMaintenance = true
    controls:Disable()
    LocalPlayer.Character.PrimaryPart.AssemblyLinearVelocity  = Vector3.new(0,0,0)
	--LocalPlayer.Character.HumanoidRootPart.CFrame = Horse.MaintenancePos.CFrame	--reset position player to make good feel with launch auction house field

    if rotationTask ~= nil then
        rotationTask:Disconnect()
    end

    local smoothTime = 0.5;

	local cameraInitialDistance = (camera.CFrame.Position -  LocalPlayer.Character.PrimaryPart.CFrame.Position).Magnitude
    local cameraInitialRotationX, cameraInitialRotationY, cameraInitialRotationZ  = camera.CFrame:ToOrientation()
    local progressTime = 0
	local cameraTargetDistance = (Horse.CameraMaintenance.CFrame.Position -  LocalPlayer.Character.PrimaryPart.CFrame.Position).Magnitude
    local cameraTargetRotationX, cameraTargetRotationY, cameraTargetRotationZ = Horse.CameraMaintenance.CFrame:ToOrientation()

    rotationTask = RunService.RenderStepped:connect(function(deltaTime)
        if not isCameraMaintenance then
            rotationTask:Disconnect()
            rotationTask = nil
        end

        progressTime += deltaTime
        local progress = math.min(1, progressTime / smoothTime)
        local newCameraDistance = UtilFunctions.Lerp(cameraInitialDistance, cameraTargetDistance, progress )
		local newCameraRotationX = UtilFunctions.Lerp(cameraInitialRotationX, cameraTargetRotationX, progress )
		local newCameraRotationY = UtilFunctions.Lerp(cameraInitialRotationY, cameraTargetRotationY, progress )
		local newCameraRotationZ = UtilFunctions.Lerp(cameraInitialRotationZ, cameraTargetRotationZ, progress )

        local newCameraRotation = CFrame.fromOrientation(newCameraRotationX, newCameraRotationY,newCameraRotationZ )

		camera.CFrame = newCameraRotation + LocalPlayer.Character.PrimaryPart.CFrame.Position  - newCameraRotation.LookVector * newCameraDistance
    end)
end

--Little function allow to return value text for button mount / dismount with good value about if is mounted by rider or not
local function GetTextIsMount(Adornee)
    Adornee.Parent:WaitForChild("Seat")
    local exist = Adornee.Parent.Seat:FindFirstChild("Rider")
    local Rider = false
    if exist then
        Rider = exist.Value
    end
    return Rider and "Dismount" or "Mount"
end

local function ResetCamera(enableCustoCam)
    local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
    isCameraMaintenance = false
    controls:Enable()

    --this check is for not relaunch true camera custom when reset is call by dismount close ui interaction
    if enableCustoCam then
        CameraController.SetEnabled(true)
    end
    
    if rotationTask ~= nil then
        rotationTask:Disconnect()
        rotationTask = nil
    end

    --if cameraLastPosition then
    --    camera.CFrame = cameraLastPosition
    --    cameraLastPosition = nil
   -- end
end

local function UpdateProgressBarUI(NewProgress, goal, progress, fromServer, type, originProgress)
    if fromServer then
        NewProgress.Info.Text = progress.." / "..goal
        if type then
            NewProgress.Info.Text = type .. " : " .. NewProgress.Info.Text
            if type == "Fed" then
                local stockFood = PlayerDataModule.LocalData.TotalHarvests
                NewProgress.Info.Text = NewProgress.Info.Text .. " (stock : ".. stockFood ..")"
                NewProgress.Full.Visible = false
            end
        end
    end

    local valueIncrement = progress/goal
    local oneOverProgress
    if valueIncrement == 0 then
        --can't do 1/0, just make oneOverProgress = 0
        oneOverProgress = not NewProgress.Name:match("Exp") and 0 or 1
    else
        oneOverProgress = 1/valueIncrement
    end

    --make color excepted if progressbar are a exp bar
    if not NewProgress.Name:match("Exp") then
        --here we setup the color of progress bar depending of pourcent of empty
        if valueIncrement <= 0.3 then
            NewProgress.Clipping.Top.ImageColor3 = Color3.fromRGB(255, 61, 64)
        elseif valueIncrement > 0.3 and valueIncrement < 0.7 then
            NewProgress.Clipping.Top.ImageColor3 = Color3.fromRGB(255, 136, 17)
        else
            NewProgress.Clipping.Top.ImageColor3 = Color3.fromRGB(139, 234, 30)
        end

        --manage size of progress bar
        if originProgress then
            local originValue = originProgress/goal
            NewProgress.Clipping.Size = UDim2.new(originValue, 0, 1, 0)
            while NewProgress.Clipping.Size.X.Scale < valueIncrement do
                NewProgress.Clipping.Size += UDim2.new(ProgressBarSpeed, 0, 0, 0)
                task.wait()
            end
        end
        NewProgress.Clipping.Size = UDim2.new(valueIncrement, 0, 1, 0) -- set Clipping size to {progress, 0, 1, 0}
    
        NewProgress.Clipping.Top.Size = UDim2.new(oneOverProgress, 0, 1, 0) -- set Top size to {1/progress, 0, 1, 0}
    else
        -- sepcific behavior for exp bar for work with background gradient fix
        if originProgress then
            local originValue = originProgress/goal
            NewProgress.Clipping.Size = UDim2.new(1-originValue, 0, 1, 0)
            while NewProgress.Clipping.Size.X.Scale < valueIncrement do
                NewProgress.Clipping.Size += UDim2.new(1-ProgressBarSpeed, 0, 0, 0)
                task.wait()
            end
        end
        NewProgress.Clipping.Size = UDim2.new(1-valueIncrement, 0, 1, 0) -- set Clipping size to {progress, 0, 1, 0}
    
        NewProgress.Clipping.Top.Size = UDim2.new(oneOverProgress, 0, 1, 0) -- set Top size to {1/progress, 0, 1, 0}
    end

end

local function HealthBehavior(isMounted, CreatureID)
    if game.PlaceId == EnvironmentModule.GetPlaceId("FashionShow") then
        return
    end
	if isMounted then
        local healthProgressBar = CreatureInteractionGui:FindFirstChild("HealthProgressBar")
        local expProgressBar = CreatureInteractionGui:FindFirstChild("ExpProgressBar")
		if healthProgressBar and expProgressBar then
            local creatureData = PlayerDataModule.LocalData.CreaturesCollection[CreatureID]
            local health = creatureData["Health"]
            local exp = creatureData["Exp"]
            local locked = creatureData["LockExp"]
            local expMax

            expProgressBar.LockExp.Visible = locked
            expProgressBar.IconImg.Image = GameDataModule.DropCollectablesWithBorders[creatureData.Race.."Crystal"]
            --expProgressBar.Clipping.Top.ImageColor3 = GameDataModule.RaceEvolutionTable[creatureData.Level].Color

            if exp then
                expMax = RemoteFunction.CreatureEvolution.GetLevelPalierExp:InvokeServer(creatureData.Level)
                if expMax then
                    if expMax == "N/A" then
                        expProgressBar.Info.Text = "Level Max"
                    else
                        expProgressBar.Info.Text = exp.."/"..expMax
                        
                        -- If exp et max xp are equals and locked, creature can evolve, make behavior of shortcut button for activate evolution
                        if exp >= expMax then
                            expProgressBar.Info.Visible = false
                            expProgressBar.EvolveBtn.Visible = true
                            expProgressBar.LockExp.ImageTransparency = 1

                            -- Check no last behavior of button is set
                            if EvolveButtonConnect then
                                EvolveButtonConnect:Disconnect()
                            end

                            UIAnimationModule.AnimateExpProgressBarFeedback(expProgressBar)

                            -- create behavior for evolve creature ID when player want and show it on the EXP progress bar
                            EvolveButtonConnect = expProgressBar.EvolveBtn.Activated:Connect(function()
                                UIAnimationModule.AnimateExpProgressBarFeedback(expProgressBar, true)
                                RemoteEvent.CreatureEvolution.LaunchEvolve:FireServer(CreatureID)
                                expProgressBar.Info.Visible = true
                                expProgressBar.EvolveBtn.Visible = false
                                expProgressBar.LockExp.ImageTransparency = 0
                                EvolveButtonConnect:Disconnect()
                            end)
                        else
                            UIAnimationModule.AnimateExpProgressBarFeedback(expProgressBar, true)
                            expProgressBar.Info.Visible = true
                            expProgressBar.EvolveBtn.Visible = false
                            expProgressBar.LockExp.ImageTransparency = 0
                        end

                        expProgressBar.Visible = game.PlaceId ~= EnvironmentModule.GetPlaceId("FashionShow") and true or false
                        UpdateProgressBarUI(expProgressBar, expMax, exp)
                    end
                end
            end

            if health then
                HorseEvents.HorseEvent:FireServer("Health", health.Value)

                healthProgressBar.Info.Text = health.Value.."/"..health.Max
                healthProgressBar.Visible = game.PlaceId ~= EnvironmentModule.GetPlaceId("FashionShow") and true or false
                UpdateProgressBarUI(healthProgressBar, health.Max, health.Value)

                if CreatureLocalDataEventChanged then
                    print("TEST DISCONNECT", CreatureLocalDataEventChanged)
                    CreatureLocalDataEventChanged.Disconnect()
                    CreatureLocalDataEventChanged = nil
                end

                CreatureLocalDataEventChanged = PlayerDataModule:Changed("CreaturesCollection."..CreatureID, function(OldValue,Value)
                    healthProgressBar.Info.Text = Value.Health.Value.."/"..health.Max
                    UpdateProgressBarUI(healthProgressBar, health.Max, Value.Health.Value)

                    if Value.Health.Value > OldValue.Health.Value then
                        AnimateGiveHealth(LocalPlayer, Value.Health.Value - OldValue.Health.Value)
                    end

                    expProgressBar.LockExp.Visible = Value.LockExp
                    expProgressBar.IconImg.Image = GameDataModule.DropCollectablesWithBorders[Value.Race.."Crystal"]
                    --expProgressBar.Clipping.Top.ImageColor3 = GameDataModule.RaceEvolutionTable[Value.Level].Color

                    local maxExp = RemoteFunction.CreatureEvolution.GetLevelPalierExp:InvokeServer(Value.Level)
                    if maxExp == "N/A" then
                        expProgressBar.Info.Text = "Level Max"
                    else
                        expProgressBar.Info.Text = Value.Exp.."/"..maxExp

                        -- If exp et max xp are equals and locked, creature can evolve, make behavior of shortcut button for activate evolution
                        if Value.Exp >= maxExp then
                            expProgressBar.Info.Visible = false
                            expProgressBar.EvolveBtn.Visible = true
                            expProgressBar.LockExp.ImageTransparency = 1

                            -- Check no last behavior of button is set
                            if EvolveButtonConnect then
                                EvolveButtonConnect:Disconnect()
                            end

                            -- create behavior for evolve creature ID when player want and show it on the EXP progress bar
                            EvolveButtonConnect = expProgressBar.EvolveBtn.Activated:Connect(function()
                                UIAnimationModule.AnimateExpProgressBarFeedback(expProgressBar, true)
                                RemoteEvent.CreatureEvolution.LaunchEvolve:FireServer(CreatureID)
                                expProgressBar.Info.Visible = true
                                expProgressBar.EvolveBtn.Visible = false
                                expProgressBar.LockExp.ImageTransparency = 0
                                EvolveButtonConnect:Disconnect()
                            end)
                        else
                            UIAnimationModule.AnimateExpProgressBarFeedback(expProgressBar, true)
                            expProgressBar.Info.Visible = true
                            expProgressBar.EvolveBtn.Visible = false
                            expProgressBar.LockExp.ImageTransparency = 0
                        end

                        UpdateProgressBarUI(expProgressBar, maxExp, Value.Exp)
                    end

                    --make this event only if health have changed
                    if OldValue.Health.Value ~= Value.Health.Value then
                        HorseEvents.HorseEvent:FireServer("Health", Value.Health.Value)
                    end
                end)
            end
		end
	else
        local healthProgressBar = CreatureInteractionGui:FindFirstChild("HealthProgressBar")
        local expProgressBar = CreatureInteractionGui:FindFirstChild("ExpProgressBar")
		if healthProgressBar and expProgressBar then
            healthProgressBar.Visible = false
            expProgressBar.Visible = false
            if CreatureLocalDataEventChanged then
                CreatureLocalDataEventChanged.Disconnect()
                CreatureLocalDataEventChanged = nil
            end
        end
	end
end

function InteractionUI:CloseMenu()
    for _, InteractionUIInstance in pairs(InteractionUIInstances) do
        self:Hide(InteractionUIInstance)
    end
    for _, InteractionObject in pairs(InteractionObjects) do
        if InteractionObject.OnInteractionEnded then
            InteractionObject.OnInteractionEnded()
            InteractionObject.OnInteractionEnded = nil
            ResetCamera(false)
        end
    end
end

function InteractionUI:Show(Adornee,DataTable, index, otherCreatureData)
    local InteractionObject = {}
    local AnimationAutoCare = false

    local InteractionUIInstance = CloneUI()
    InteractionUIInstance.Adornee = Adornee
    InteractionUIInstance.Enabled = true

    if LocalPlayer.PlayerGui:FindFirstChild("ShowMaintenanceBar") then
        LocalPlayer.PlayerGui.ShowMaintenanceBar.Enabled = false
        LocalPlayer.PlayerGui.ShowMaintenanceBar.Adornee = nil
    end

    local result = nil
    if not otherCreatureData then
        local CreatureID = Adornee.Parent:WaitForChild("CreatureID")
        result = PlayerDataModule.LocalData.CreaturesCollection[CreatureID.Value].Maintenance

        --if result return something, it's okay its horse player and it's found data so create buttons actions
        if not result then
            return
        end
    end
    
    local function PopulateButtons(CurrentTable, CurrentName)
        ClearUI(InteractionUIInstance)
        for Name,Value in pairs(CurrentTable) do
            local NewProgress = nil
            local NewButton = nil
            
            if CurrentName == "Actions" then
                WalkSpeedModule.SetControlsPlayerAndCreature(false)
                if Name == "Mount" then
                    NewButton = InteractionUIInstance.ExampleImgButton:Clone()
                    NewButton.TextLabel.Text = GetTextIsMount(Adornee)
                    NewButton.Parent = InteractionUIInstance.Main
                    NewButton.Visible = true
                    NewButton.LayoutOrder = Value.index
                else
                    transformCamera(Adornee.Parent)
                    if Value.isInteractible then
                        NewProgress = InteractionUIInstance.ProgressBarButton:Clone()
                    else
                        NewProgress = InteractionUIInstance.ProgressBar:Clone()
                    end
                    local colorVal = Value.folderIndex / 3 * 88
                    NewProgress.ImageColor3 = Color3.fromRGB(colorVal, colorVal, colorVal)

                    if Value.folderIndex == 1 then
                        NewProgress.Size = UDim2.new(UDim.new(1.25,0),UDim.new(0.1,0))
                    elseif Value.folderIndex == 2 then
                        NewProgress.Size = UDim2.new(UDim.new(1,0),UDim.new(0.1,0))
                    else
                        NewProgress.Size = UDim2.new(UDim.new(0.9,0),UDim.new(0.1,0))
                    end
    
                    --setup progress bar and get button of it for this action
                    
                    local progressValue
                    local progressMax
                    if result[Name] then
                        progressValue = result[Name].Value
                        progressMax = result[Name].Max
                    else
                        local progressData = PlayerDataModule.LocalData.CreaturesCollection[Adornee.Parent.CreatureID.Value][Name]
                        if progressData then
                            progressValue = progressData.Value
                            progressMax = progressData.Max
                        end
                    end
                    NewProgress.Name = Name
                    NewProgress.Info.Text = Value.barName .. " : " .. progressValue
                    if Name == "Fed" then
                        NewProgress.Info.Text = NewProgress.Info.Text
                        NewProgress.Full.Visible = false
                    end
                    NewProgress.Goal.Value = progressMax
                    NewProgress.Progress.Value = progressValue
                    NewProgress.Parent = InteractionUIInstance.Main
                    NewProgress.Visible = true
                    NewProgress.LayoutOrder = Value.index
                    NewButton = NewProgress:FindFirstChild("Example")
                    UpdateProgressBarUI(NewProgress, progressMax, progressValue)
                end
            else
                NewButton = InteractionUIInstance.Example:Clone()
                if Name == "Mount" then
                    NewButton.Text = GetTextIsMount(Adornee)
                elseif Name == "PowerSize" then
                    NewButton.Text = Name
                    NewButton.TextTransparency = 1
                    local costUI = CreatureInteractionGui.Template.CostFrameButton:Clone()
                    costUI.Parent = NewButton
                    costUI.Visible = true
                elseif Name == "ShowUI" then
                    NewButton.Text = "Show UI"
                elseif Name == "Actions" then
                    NewButton.Text = "Care"
                else
                    NewButton.Text = Name
                end
                NewButton.Parent = InteractionUIInstance.Main
                NewButton.Visible = true
            end

            if NewProgress and NewProgress.Name == "Fed" then
                NewProgress.Full.Activated:Connect(function()
                    if not debounce then
                        return
                    end
                    debounce = false
                    task.delay(coolDown, function()
                        debounce = true
                    end)
                    Value.func(InteractionUIInstance, true)
                end)
            end

            if NewButton then
                NewButton.Activated:Connect(function()
                    if Value.func then
                        if not debounce then
                            return
                        end
                        debounce = false
                        task.delay(coolDown, function()
                            debounce = true
                        end)
                        
                        if Name == "Mount"then
                            --check rider value to know if mouted or not and send good value to mount dismount creature
                            local Rider = Adornee.Parent.Seat:FindFirstChild("Rider")
                            if Rider then
                                CreatureIsMounted = Rider.Value and true or false
                            end
                            
                            self:Hide(InteractionUIInstance)
                            Value.func(InteractionUIInstance, CreatureIsMounted)
                        elseif Name == "ShowUI" or Name == "PowerSize" then
                            self:Hide(InteractionUIInstance)
                            Value.func(InteractionUIInstance)
                        elseif Name == "Genes" then
                            Value.func(InteractionUIInstance)
                            NewButton:Destroy()
                        else
                            result = PlayerDataModule.LocalData.CreaturesCollection[Adornee.Parent.CreatureID.Value].Maintenance
                            if Name == "Fed" then
                                if result[Name].Value < result[Name].Max then
                                    Value.func(InteractionUIInstance)
                                end
                            else
                                if result[Name].Value < result[Name].Max then
                                    Value.func(InteractionUIInstance)
                                end
                            end
                        end
                    else
                        PopulateButtons(Value, Name)
                        InteractionUIInstance.StudsOffset = Vector3.new(10,0,0)
                        InteractionUIInstance.Size = UDim2.fromOffset(500,450)
                    end
                end)
            end
            
            --here we check number element to display in the billboard UI and setup best visual ui if current table element to display superior to 4
            --!be carrful it's temporaly fix, if we have more more element to display, we need to update or change this!
            if ToolsModule.LengthOfDic(CurrentTable) > 4 then
                InteractionUIInstance.Main.Size = UDim2.new(1,0,0.5,0)
                InteractionUIInstance.Main.UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
                InteractionUIInstance.Size = UDim2.new(0,200,0,250)
            end
        end

        local CloseButton = InteractionUIInstance.ExampleImgButton:Clone()
        CloseButton.ImageColor3 = Color3.fromRGB(255, 61, 64)
        if CurrentName == "Actions" then
            CloseButton.Size = UDim2.new(UDim.new(1.25,0),UDim.new(0.1,0))
        end
        CloseButton.TextLabel.Text = "Close"
        CloseButton.Parent = InteractionUIInstance.Main
        CloseButton.Visible = true
        CloseButton.LayoutOrder = 100

        CloseButton.Activated:Connect(function()
            self:Hide(InteractionUIInstance)
            --check if Main are in ScreenGui or not to destroy it when is close
            if CloseButton then
                if CloseButton:FindFirstAncestorWhichIsA("ScreenGui") then
                    CloseButton.Parent:Destroy()
                end
            end
            
            if InteractionObject.OnInteractionEnded then
                if CurrentName == "Actions" then
                    AnimationAutoCare = false
                    WalkSpeedModule.SetControlsPlayerAndCreature(true)
                    --check rider value to know if mouted or not and set properly the ResetCamera
                    local Rider = Adornee.Parent.Seat:FindFirstChild("Rider")
                    if Rider.Value then
                        ResetCamera(true)
                    else
                        ResetCamera(false)
                        HealthBehavior(nil)
                    end
                    --InteractionObject.OnInteractionEnded("Return")
                    InteractionObject.OnInteractionEnded()
                    InteractionObject.OnInteractionEnded = nil
                    ToolsModule.EnableOtherUI(true, {"CreatureInteractionGui"})
                    UIProviderModule:GetUI("PositionningGui").PositionningGuiBtn.Visible = true
                    UIProviderModule:GetUI("AllButtonsMainMenusGui").ShopItemsGuiBtn.Visible = true
                else
                    InteractionObject.OnInteractionEnded()
                    InteractionObject.OnInteractionEnded = nil
                end
            end

        end)

        if CurrentName == "Actions" then
            ToolsModule.EnableOtherUI(false, {"CreatureInteractionGui", "ShopItemsGui"})
            UIProviderModule:GetUI("PositionningGui").PositionningGuiBtn.Visible = false
            UIProviderModule:GetUI("AllButtonsMainMenusGui").ShopItemsGuiBtn.Visible = false
            InteractionUIInstance.Main.Position = UDim2.fromScale(0.725,0.55)
            InteractionUIInstance.Main.Size = UDim2.fromScale(0.2,0.8)
            InteractionUIInstance.Main.UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
            InteractionUIInstance.Main.Parent = CreatureInteractionGui

            HealthBehavior(true, Adornee.Parent.CreatureID.Value)
        end
    end

    if index == "Maintenance" then
        
        PopulateButtons(DataTable.Actions, "Actions")

        -- If player have buy gamepass Automatic_Care, apply automatic maintenance of animals
        if RemoteFunction.CheckPlayerHasGamepass:InvokeServer(GameDataModule.Gamepasses.Automatic_Care.ProductID) then
            AnimationAutoCare = true
            task.spawn(function()
                for Name, Value in pairs(DataTable.Actions) do
                    if AnimationAutoCare then
                        local txtClone = UIProviderModule:GetUI("FeedBackScreenGui").Template.TextLabel:Clone()
                        txtClone.Parent = CreatureInteractionGui
                        txtClone.Text = "Automatic "..Name.." apply !"
                        UIAnimationModule.AnimateFadeInOutTextObjectUI(txtClone)
                    end

                    for i=1, 10 do
                        if Name == "Fed" and PlayerDataModule.LocalData.TotalHarvests <= 0 then
                            Value.func(InteractionUIInstance)
                            break
                        end
                        
                        Value.func(InteractionUIInstance)
                        if AnimationAutoCare then
                            task.wait(0.1)
                        end
                    end
                end
            end)
        end

        --[[ InteractionUIInstance.StudsOffset = Vector3.new(10,0,0)
        InteractionUIInstance.Size = UDim2.fromOffset(500,450)
        InteractionUIInstance.Main.Position = UDim2.fromScale(0.28,0)
        InteractionUIInstance.Main.Size = UDim2.fromScale(0.4,1) ]]
    else
        PopulateButtons(DataTable)
    end

    InteractionObjects[#InteractionObjects+1] = InteractionObject
    InteractionUIInstances[#InteractionUIInstances+1] = InteractionUIInstance
    return InteractionObject
end

function InteractionUI:Hide(InteractionUIInstance)
    --search all possible ui interaction replica and delete it
    for _, ui in pairs(LocalPlayer:WaitForChild("PlayerGui"):GetChildren()) do
        if ui.Name == "InteractionUI" then
            ui:Destroy()
        end
    end
    InteractionUIInstance:Destroy()
    InteractionUI.Adornee = nil
end

function InteractionUI:InitQuickShowMaintenanceStatus()
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    local ShowMaintenanceBar
    local exist = PlayerGui:FindFirstChild("ShowMaintenanceBar")
    if exist then
        ShowMaintenanceBar = exist
    else
        ShowMaintenanceBar = Assets.ShowMaintenanceBar:Clone()
        ShowMaintenanceBar.Parent = PlayerGui
    end

    if connect then
        connect:Disconnect()
    end

    local lastTarget = nil
    local showConnection = nil
    local showOtherConnection = nil

    local function Disable()
        --mouse.Icon = "rbxasset://SystemCursors/PointingHand"
        LocalPlayer.PlayerGui.ShowMaintenanceBar.Enabled = false
        LocalPlayer.PlayerGui.ShowMaintenanceBar.Adornee = nil
        lastTarget = nil
        if showConnection then
            showConnection:Disconnect()
        end
        if showOtherConnection then
            showOtherConnection:Disconnect()
        end
    end
    
    local function MouseDetectHorse(mobile)
        -- We check if Target mouse is an part name CollectablesDetector, if yes we ignore it for player mouse (work if click on other animal or player animal)
        if mouse.Target then
            if mouse.Target.Name == "CollectablesDetector" then
                mouse.TargetFilter = mouse.Target
            end
        end
        
        --we get the target to check and not make all with mouse.Target because target can change during checking process
        local target = mouse.Target
        if target then
            if target.Parent and target.Parent ~= game.Workspace and target.Name ~= "CollectablesDetector" then
                if target.Parent:FindFirstChild("CanShowStatus") then
                    if not LocalPlayer.PlayerGui:FindFirstChild("InteractionUI") and not target.Parent.PrimaryPart:FindFirstChild("ShowMaintenanceBar") and not SelfieMode.isSelfieModeOpen() then
                        if target.Parent ~= lastTarget then
                            --check if creature is creature of player
                            local creatureData = PlayerDataModule.LocalData.CreaturesCollection[target.Parent.CreatureID.Value]
                            if creatureData then
                                --If yes, we can check datahealth and setup click/touch interaction for show InteractionUI
                                local result = creatureData["Health"]
                                if result then
                                    --mouse.Icon = "rbxasset://SystemCursors/PointingHand"
                                    --setup healthBar
                                    lastTarget = target.Parent and target.Parent or nil
                                    --Here we check if we can interact or not with model creature
                                    if not lastTarget:GetAttribute("CanInteractWith") then
                                        Disable()
                                        return
                                    end
                                    LocalPlayer.PlayerGui.ShowMaintenanceBar.ProgressBar.Info.Text = result.Value.."/"..result.Max
                                    LocalPlayer.PlayerGui.ShowMaintenanceBar.ProgressBar.NameValue.Text = "Health"
                                    UpdateProgressBarUI(LocalPlayer.PlayerGui.ShowMaintenanceBar.ProgressBar, result.Max, result.Value)
                                    
                                    --setup visibility of health bar
                                    LocalPlayer.PlayerGui.ShowMaintenanceBar.Adornee = target.Parent.PrimaryPart and target.Parent.PrimaryPart or nil
                                    LocalPlayer.PlayerGui.ShowMaintenanceBar.Enabled = target.Parent.CanShowStatus.Value

                                    --create into showConnection event  click/touch on target
                                    if mobile then
                                        RemoteEvent.OpenCreatureMenu:FireServer(lastTarget, nil, nil)
                                    else
                                        showConnection = UserInputService.InputBegan:Connect(function(key,IsTyping)
                                            if not IsTyping then
                                                if key.UserInputType == Enum.UserInputType.MouseButton1 or key.UserInputType == Enum.UserInputType.Touch then
                                                    --send event show InterfaceUI of target
                                                    --RemoteEvent.OpenCreatureMenu:FireServer(lastTarget, nil, creatureData)
                                                    RemoteEvent.OpenCreatureMenu:FireServer(lastTarget, nil, nil)
                                                end
                                            end
                                        end)
                                    end
                                else
                                    Disable()
                                end
                            else
                                --if not successful check if it's creature of player, we check if it's a creature
                                if target.Parent:FindFirstChild("CreatureID") then
                                    --if we found CreatureID, it's a creature and not belong to localplayer
                                    lastTarget = target.Parent and target.Parent or nil

                                    --Here we check if we can interact or not with model creature
                                    if not lastTarget:GetAttribute("CanInteractWith") then
                                        Disable()
                                        return
                                    end

                                    --so we try to check player of creature with split name of creature who contain the name of player and get this instance
                                    local otherPlayerName = lastTarget.Name:split("_")[2]
                                    local otherPlayer
                                    for _, plr in pairs(game.Players:GetPlayers()) do
                                        if plr.Name == otherPlayerName then
                                            otherPlayer = plr
                                            break
                                        end
                                    end

                                    --if we found the other player
                                    if otherPlayer then
                                        --we can get data of is creature
                                        creatureData = RemoteFunction.GetDataOfPlayer:InvokeServer(otherPlayer, "CreaturesCollection."..lastTarget.CreatureID.Value)
                                        if creatureData then
                                            --mouse.Icon = "rbxasset://SystemCursors/PointingHand"
                                            --and make the click/touch event in showOtherConnection to call a Open InteractionUI for other creature by passing the datacreature parameter
                                            if mobile then
                                                if game.PlaceId ~= EnvironmentModule.GetPlaceId("FashionShow") then
                                                    --not my creature so open for other with data reference
                                                    RemoteEvent.OpenCreatureMenu:FireServer(lastTarget, nil, creatureData)
                                                end
                                            else
                                                showOtherConnection = UserInputService.InputBegan:Connect(function(key,IsTyping)
                                                    if not IsTyping then
                                                        if key.UserInputType == Enum.UserInputType.MouseButton1 or key.UserInputType == Enum.UserInputType.Touch then
                                                            --not my creature so open for other with data reference
                                                            if game.PlaceId ~= EnvironmentModule.GetPlaceId("FashionShow") then
                                                                RemoteEvent.OpenCreatureMenu:FireServer(lastTarget, nil, creatureData)
                                                            end
                                                        end
                                                    end
                                                end)
                                            end
                                        else
                                            Disable()
                                        end
                                    else
                                        Disable()
                                    end
                                else
                                    Disable()
                                end
                            end
                        end
                    else
                        Disable()
                    end
                else
                    Disable()
                end
            else
                Disable()
            end
        end
    end

    if UserInputService.KeyboardEnabled then
        connect = UserInputService.InputChanged:Connect(function(input, gameProcessedEvent)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                if not gameProcessedEvent then
                    MouseDetectHorse()
                end
            end
        end)
    else
        connect = UserInputService.TouchEnded:Connect(function(input, gameProcessedEvent)
            --check if gameprocess is false, so only touch if we don't touch a UI
            if not gameProcessedEvent then
                MouseDetectHorse(true)
            end
        end)
    end
end

InteractionEvent.OnClientEvent:Connect(function(initBar, typeMaintenance, target, progress, goal, originProgress, creatureID)
    if creatureID then
        local currentHorse = workspace.CreaturesFolder:FindFirstChild("Creature_" .. LocalPlayer.Name)
        if currentHorse and currentHorse.CreatureID.Value ~= creatureID then
            return
        end
    end

    local gui = CreatureInteractionGui:FindFirstChild("Main") and CreatureInteractionGui or LocalPlayer.PlayerGui:FindFirstChild("InteractionUI")
    if not gui then
        return
    end

    if not gui:FindFirstChild("Main") then
        return
    end

    local progressBar = gui.Main:FindFirstChild(typeMaintenance)
    if not progressBar then
        return
    end
    local valueIncrement = progress/goal
    local oneOverProgress
    if valueIncrement == 0 then
        --can't do 1/0, just make oneOverProgress = 0
        oneOverProgress = 0
    else
        oneOverProgress = 1/valueIncrement
    end

    progressBar.Clipping.Top.Size = UDim2.new(oneOverProgress, 0, 1, 0) -- set Top size to {1/progress, 0, 1, 0}
    
    if originProgress or originProgress == 0 then
        local originValue = originProgress/goal
        progressBar.Clipping.Size = UDim2.new(originValue, 0, 1, 0)
        progressBar.Info.Text = typeMaintenance .. " : " .. math.round(originProgress)
        local count = 0
        while progressBar.Clipping.Size.X.Scale < valueIncrement do
            progressBar.Clipping.Size += UDim2.new(ProgressBarSpeed, 0, 0, 0)
            progressBar.Info.Text = typeMaintenance .. " : " .. originProgress + count
            if typeMaintenance == "Fed" then
                progressBar.Info.Text = progressBar.Info.Text
            end
            if progressBar.Clipping.Size.X.Scale <= 0.3 then
                progressBar.Clipping.Top.ImageColor3 = Color3.fromRGB(255, 61, 64)
            elseif progressBar.Clipping.Size.X.Scale > 0.3 and progressBar.Clipping.Size.X.Scale < 0.7 then
                progressBar.Clipping.Top.ImageColor3 = Color3.fromRGB(255, 136, 17)
            else
                progressBar.Clipping.Top.ImageColor3 = Color3.fromRGB(139, 234, 30)
            end

            count += math.round(1 * ProgressBarSpeed *100)
            task.wait()
        end
    end
    progressBar.Clipping.Size = UDim2.new(valueIncrement, 0, 1, 0) -- set Clipping size to {progress, 0, 1, 0}
    progressBar.Info.Text = typeMaintenance .. " : " .. math.round(progress)
    if typeMaintenance == "Fed" then
        progressBar.Info.Text = progressBar.Info.Text
    end
end)

HorseEvents.ShowHealthBar.OnClientEvent:Connect(HealthBehavior)

InteractionUI:InitQuickShowMaintenanceStatus()

return InteractionUI