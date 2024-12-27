local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local controls = require(game:GetService("Players").LocalPlayer.PlayerScripts.PlayerModule):GetControls()
local CameraController = require(game:GetService("StarterPlayer").StarterPlayerScripts.ClientPlayerSync.Modules:WaitForChild("CameraController"))

local RemoteFunction = ReplicatedStorage:FindFirstChild("RemoteFunction")
local RemoteEvent = ReplicatedStorage.RemoteEvent

local Player = game.Players.LocalPlayer

-- RequireModule
local UIProviderModule = require("UIProviderModule")
local PlayerDataModule = require("ReplicatedPlayerData")
local ToolsModule = require("ToolsModule")
local CreaturesTalentsModule = require("CreaturesTalentsModule")
local GameDataModule = require("GameDataModule")
local SoundControllerModule = require("SoundControllerModule")
local UIAnimationModule = require("UIAnimationModule")

-- UI
local TalentsGeneratorGui = UIProviderModule:GetUI("TalentsGeneratorGui")
local HorsesCollectionGui = UIProviderModule:GetUI("HorsesCollectionGui")
local Background = TalentsGeneratorGui:WaitForChild("Background")
local CreaturesListUI = HorsesCollectionGui:WaitForChild("CreaturesListForBreedingBack"):WaitForChild("CreaturesListForBreeding")
local InfosFrame = Background:WaitForChild("InfosFrame")
local TalentGenerationFrame = InfosFrame.TalentGenerationFrame
local UpgradeTalentFrame = InfosFrame.UpgradeTalentFrame


local CreatureIDSelected
local CreatureUISelected
local TalentIDSelected
local debouceValidButton = true
local debounceAnimation = true

local TalentsButtonConnection = {}

local function AnimationWaiting()
    if Background.AnimeBackground:FindFirstChildWhichIsA("ViewportFrame") then
        Background.AnimeBackground:FindFirstChildWhichIsA("ViewportFrame"):Destroy()
        Background.AnimeBackground.Sparkle.Size = UDim2.fromScale(0,0)
        Background.AnimeBackground.Sparkle.Rotation = 0
        Background.AnimeBackground.Sparkle.ImageTransparency = 0.2
    end

    local ViewportFrame = CreatureUISelected:FindFirstChildWhichIsA("ViewportFrame"):Clone()
    ViewportFrame.Parent = Background.AnimeBackground
    ViewportFrame.Size = UDim2.fromScale(0.8,0.8)
    ViewportFrame.Camera:Destroy()
    Background.AnimeBackground.Visible = true

    local CreatureModel = ViewportFrame.WorldModel:FindFirstChildWhichIsA("Model")

    local camera = Instance.new("Camera")
    local target = CreatureModel.PrimaryPart
    ViewportFrame.CurrentCamera = camera
    camera.Parent = ViewportFrame
    camera.CameraType = Enum.CameraType.Scriptable
    camera.MaxAxisFieldOfView = 50
    local zOffset = 15
    local cameraOffset = Vector3.new(0, 1, zOffset)
    camera.Focus = target.CFrame
    local rotatedCFrame = CFrame.Angles(0, math.rad(-145), 0)
    rotatedCFrame = CFrame.new(target.Position) * rotatedCFrame
    camera.CFrame = rotatedCFrame:ToWorldSpace(CFrame.new(cameraOffset))

    Background.AnimeBackground.Sparkle.Visible = true

    local tRot = TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, false)
    local goalRot = {
        Rotation = 360
    }
    local rotationTween = TweenService:Create(Background.AnimeBackground.Sparkle, tRot, goalRot)
    rotationTween:Play()

    local tSize = TweenInfo.new(1.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false)
    local goalSize = {
        Size = UDim2.fromScale(2,2)
    }
    local sizeTween = TweenService:Create(Background.AnimeBackground.Sparkle, tSize, goalSize)
    sizeTween:Play()
    SoundControllerModule:CreateSound("WaitingGenerator")
    debounceAnimation = false
    sizeTween.Completed:Connect(function(playbackState)
        if playbackState == Enum.PlaybackState.Completed then
            rotationTween:Cancel()
            local fadeInfo = TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false)
            local fade = TweenService:Create(Background.AnimeBackground.Sparkle, fadeInfo, {
                ImageTransparency = 1
            })
            fade:Play()
            fade.Completed:Connect(function(playbackState)
                if playbackState == Enum.PlaybackState.Completed then
                    debounceAnimation = true
                end
            end)
        end
    end)
end

local function SuccessAnimation(success:boolean, newTalent)
    Background.AnimeBackground.Sparkle.Visible = false

    if success then
        SoundControllerModule:CreateSound("ExplosionBonus")
        local img = Instance.new("ImageLabel")
        img.AnchorPoint = Vector2.new(0.5,0)
        img.Size = UDim2.fromScale(0.05,0.05)
        img.ScaleType = Enum.ScaleType.Fit
        img.BackgroundTransparency = 1
        img.Image = "rbxassetid://6583628103"

        UIAnimationModule.AnimateNbImageRandomUP(Background.AnimeBackground, img, 100)
        
        task.wait(1.5)
        img:Destroy()

        local talentName, talentDesc
        for id, value in pairs(newTalent) do
            talentName = CreaturesTalentsModule.TalentsTable[id].Name
            talentDesc = CreaturesTalentsModule.TalentsTable[id].Desc:format(value,"%")
            break
        end

        RemoteEvent.ShowPopupAlert:FireServer("New Talent !",
            talentName.." : "..talentDesc,
            ToolsModule.AlertPriority.Annoucement,
            nil,
            ToolsModule.AlertTypeButton.OK
        )
    else
        SoundControllerModule:CreateSound("FailSound")
        RemoteEvent.ShowPopupAlert:FireServer("Fail...",
            "You didn't get any new talent.",
            ToolsModule.AlertPriority.Annoucement,
            nil,
            ToolsModule.AlertTypeButton.OK
        )
    end

    Background.AnimeBackground.Visible = false
end

-- Clean list of cost value
local function ClearCostUI(ShowCostFrame)
	for _, child in pairs(ShowCostFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

-- Little function for reset UI when leave system
local function ResetDataUI()
    InfosFrame.PanelButtons.TalentGenerationBtn.Hover.Visible = false
    InfosFrame.PanelButtons.TalentUpgradeBtn.Hover.Visible = true

    TalentGenerationFrame.Visible = true
    UpgradeTalentFrame.Visible = false
    TalentGenerationFrame.SuccessPrctText.Visible = false
    TalentGenerationFrame.ActionsButtons.Visible = false

    for _, talentFrame in pairs(TalentGenerationFrame.Talents:GetChildren()) do
        if talentFrame:IsA("Frame") then
            talentFrame.Visible = false
        end
    end
    for _, talentFrame in pairs(UpgradeTalentFrame.Talents:GetChildren()) do
        if talentFrame:IsA("Frame") then
            talentFrame.Visible = false
        end
    end

    CreatureIDSelected = nil
    CreatureUISelected = nil
    TalentIDSelected = nil

    ClearCostUI(TalentGenerationFrame.ShowCostFrame)
    ClearCostUI(UpgradeTalentFrame.ShowCostFrame)
end

-- Auto setup UI Cost depending of Cost list give in parameter and the UI need to setup
local function MakeCostUI(CostsList, CostFrame)
    local canPayout = true
    for costType, value in pairs(CostsList) do
        local ui = TalentsGeneratorGui.Template.CostItem:Clone()
        ui.Name = costType.."Cost"
        ui.Parent = CostFrame
        ui.Icon.Image = GameDataModule.DropCollectablesWithBorders[costType]

        local playerActualValue
        if string.match(costType, "Crystal") then
            playerActualValue = PlayerDataModule.LocalData.Crystals[costType]
        else
            playerActualValue = PlayerDataModule.LocalData[costType]
        end

        ui.ValueTxt.Text = ToolsModule.DotNumber(tostring(playerActualValue)).." / "..ToolsModule.DotNumber(tostring(value))
        if value <= playerActualValue then
            ui.ValueTxt.TextColor3 = Color3.fromRGB(0, 255, 0)
        else
            ui.ValueTxt.TextColor3 = Color3.fromRGB(255, 0, 0)
            canPayout = false
        end

        ui.Visible = true
    end

    CostFrame.Parent.ActionsButtons.ValidBtn.Active = canPayout
end

local function PopulateInfoUI(CreatureSelected)
    -- Setup existed talent of creature in UIs preview
    local creatureTalent = CreatureSelected.Talents
    local nbTalent = ToolsModule.LengthOfDic(creatureTalent)

    -- Reset talents button connection (only for upgrade talent)
    for _, v in pairs(TalentsButtonConnection) do
        v:Disconnect()
    end

    -- Reset UIs talents list
    for _, talentFrame in pairs(TalentGenerationFrame.Talents:GetChildren()) do
        if talentFrame:IsA("Frame") then
            talentFrame.Visible = false
        end
    end
    for _, talentFrame in pairs(UpgradeTalentFrame.Talents:GetChildren()) do
        if talentFrame:IsA("Frame") then
            talentFrame.UIStroke.Enabled = false
            talentFrame.Visible = false
        end
    end

    if nbTalent == 0 then
        UpgradeTalentFrame.TalentDesc.Text = "NO TALENTS"
        UpgradeTalentFrame.ActionsButtons.Visible = false
    else
        UpgradeTalentFrame.TalentDesc.Text = "Select a talent you want to try to upgrade..."
        UpgradeTalentFrame.ActionsButtons.Visible = true
    end

    -- Setup UIs for talents creature
    local i = 1
    for id, value in pairs(creatureTalent) do
        local talentFrame = TalentGenerationFrame.Talents["Talent"..i]
        talentFrame.Title.Text = CreaturesTalentsModule.TalentsTable[id].Name
        talentFrame:SetAttribute("TextHover", CreaturesTalentsModule.TalentsTable[id].Desc:format(value,"%"))
        talentFrame.Visible = true

        local talentFrame = UpgradeTalentFrame.Talents["Talent"..i]
        talentFrame.Title.Text = CreaturesTalentsModule.TalentsTable[id].Name
        talentFrame:SetAttribute("TextHover", CreaturesTalentsModule.TalentsTable[id].Desc:format(value,"%"))
        talentFrame.Visible = true

        -- Setup button behavior of talent selected (only for Upgrade talent)
        local co = talentFrame.Btn.Activated:Connect(function()
            -- Setup visual talent selected
            talentFrame.UIStroke.Enabled = true
            for _, v in pairs(UpgradeTalentFrame.Talents:GetChildren()) do
                if v:IsA("Frame") then
                    if v ~= talentFrame then
                        v.UIStroke.Enabled = false
                    end
                end
            end

            TalentIDSelected = id

            -- Adding description of talent selected
            UpgradeTalentFrame.TalentDesc.Text = CreaturesTalentsModule.TalentsTable[id].Desc:format(value,"%")

            -- Clear cost ui
            ClearCostUI(UpgradeTalentFrame.ShowCostFrame)
            -- Make cost UI for Upgrade talent
            MakeCostUI(CreaturesTalentsModule.TalentsTable[id].UpgradeCost, UpgradeTalentFrame.ShowCostFrame)
        end)

        -- Adding connection event to temp table for reset when creature selected change
        table.insert(TalentsButtonConnection, co)

        i+=1
    end

    -- Lock valid buttons actives validates by default
    TalentGenerationFrame.ActionsButtons.ValidBtn.Active = false
    UpgradeTalentFrame.ActionsButtons.ValidBtn.Active = false

    -- Get and show Success rate (only for generation)
    local rateSuccess = GameDataModule.TalentsGeneratorLuckSuccess[nbTalent+1]
    TalentGenerationFrame.SuccessPrctText.Text = tostring(rateSuccess).." %"

    -- Show next talent frame feedback for understand we can unlock maybe another talent (only for generation)
    if nbTalent < 4 then
        local previewFrame = TalentGenerationFrame.Talents["Talent"..nbTalent+1]
        previewFrame.Title.Text = "???"
        previewFrame:SetAttribute("TextHover", "Success rate to win this slot talent : "..rateSuccess.." %")
        previewFrame.Visible = true
    end

    -- Show cost of try to generate new talent (only for generation)
    ClearCostUI(TalentGenerationFrame.ShowCostFrame)
    ClearCostUI(UpgradeTalentFrame.ShowCostFrame)
    -- Check if creature have not reach maximum talents
    if nbTalent > 4 then
        TalentGenerationFrame.SuccessPrctText.Text = "Max talent reached !"
        TalentGenerationFrame.ActionsButtons.Visible = false
        return
    end

    MakeCostUI(GameDataModule.TalentsGeneratorCost[nbTalent+1], TalentGenerationFrame.ShowCostFrame)
end

--[[
	This function allow to setup UI of all creatures list and set behavior of click for init
    the generator talent ui
]]
local function ShowCreatureUI()
	CreaturesListUI.Populate.Value = false
	CreaturesListUI.Populate.Value = true
	task.wait(.1)
	for _, creature in pairs(CreaturesListUI:GetChildren()) do
		if creature:IsA("Frame") then
			creature.Visible = true

            -- Setup behavior when player select animals
            creature.ItemImgBtn.Activated:Connect(function()
                if CreatureUISelected then
                    CreatureUISelected.ItemName.UIStroke.Enabled = false
                    CreatureUISelected.ItemName.TextColor3 = Color3.fromRGB(0,0,0)
                end

                CreatureUISelected = creature
                CreatureIDSelected = creature:FindFirstChildWhichIsA("ViewportFrame").Name
                CreatureUISelected.ItemName.UIStroke.Enabled = true
                CreatureUISelected.ItemName.TextColor3 = Color3.fromRGB(0,255,0)
                
                TalentGenerationFrame.SuccessPrctText.Visible = true
                TalentGenerationFrame.ActionsButtons.Visible = true

                PopulateInfoUI(PlayerDataModule.LocalData.CreaturesCollection[CreatureIDSelected])
            end)
		end
	end

    -- Setup UI of list for Talents Generator System
    CreaturesListUI.Parent.Position = UDim2.fromScale(0.35,0.5)
    CreaturesListUI.Parent.Size = UDim2.fromScale(0.5,0.6)
    CreaturesListUI.Position = UDim2.fromScale(0.5,0.5)
    CreaturesListUI.Size = UDim2.fromScale(0.9,0.9)
    CreaturesListUI.UIGridLayout.CellSize = UDim2.fromScale(0.2,0.2)
    CreaturesListUI.UIGridLayout.FillDirectionMaxCells = 0
    CreaturesListUI.Parent.SelectedCharacteristicsUI.Visible = false

    CreaturesListUI.Parent.Visible = true
end

Background.LeaveBtn.Activated:Connect(function()
    local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom

	controls:Enable()
	Background.Visible = false
    HorsesCollectionGui.CreaturesListForBreedingBack.Visible = false
	ToolsModule.EnableOtherUI(true, {"TalentsGeneratorGui", "HorsesCollectionGui"})
    ResetDataUI()
end)

TalentGenerationFrame.ActionsButtons.ValidBtn.Activated:Connect(function()
    if not debouceValidButton then
        return
    end

    if CreatureIDSelected then
        debouceValidButton = false

        -- Send to server try to generate new talent for creature selected
        RemoteEvent.TalentsGeneratorSystem.TryGenerateNewTalentCreature:FireServer(CreatureIDSelected)

        -- Play waiting animation
        AnimationWaiting()
    else
        warn("NO ANIMALS SELECTED")
    end
end)

UpgradeTalentFrame.ActionsButtons.ValidBtn.Activated:Connect(function()
    if not debouceValidButton then
        return
    end
    if CreatureIDSelected and TalentIDSelected then
        debouceValidButton = false
        RemoteEvent.TalentsGeneratorSystem.UpgradeTalentCreature:FireServer(CreatureIDSelected, TalentIDSelected)
    end
end)

RemoteEvent.TalentsGeneratorSystem.UpgradeTalentCreature.OnClientEvent:Connect(function(talentID, newValue, lastValue)
    SoundControllerModule:CreateSound("FailSound")
    local text = newValue >= lastValue and "<font color=\"rgb(0,255,0)\">"..newValue.."</font>" or "<font color=\"rgb(255,0,0)\">"..newValue.."</font>"
    RemoteEvent.ShowPopupAlert:FireServer("Talent Updated !",
        CreaturesTalentsModule.TalentsTable[talentID].Name.." :\n"..CreaturesTalentsModule.TalentsTable[talentID].Desc:format(text,"%"),
        ToolsModule.AlertPriority.Annoucement,
        nil,
        ToolsModule.AlertTypeButton.OK
    )
    
    PopulateInfoUI(PlayerDataModule.LocalData.CreaturesCollection[CreatureIDSelected])

    debouceValidButton = true
end)

RemoteEvent.TalentsGeneratorSystem.TryGenerateNewTalentCreature.OnClientEvent:Connect(function(isSuccess:boolean, newTalent)
    repeat
        task.wait(0.1)
    until debounceAnimation
    
    -- Receive result of try to generate new talent for creature selected
    if isSuccess then
        -- Play success animation
        SuccessAnimation(true, newTalent)
    else
        -- Play not success animation
        SuccessAnimation(false)
    end

    -- Show new data on UI Generator
    PopulateInfoUI(PlayerDataModule.LocalData.CreaturesCollection[CreatureIDSelected])

    debouceValidButton = true
end)

-- Panel button to show generation talent
InfosFrame.PanelButtons.TalentGenerationBtn.Activated:Connect(function()
    TalentIDSelected = nil
    TalentGenerationFrame.Visible = true
    UpgradeTalentFrame.Visible = false

    InfosFrame.PanelButtons.TalentGenerationBtn.Hover.Visible = false
    InfosFrame.PanelButtons.TalentUpgradeBtn.Hover.Visible = true
end)

-- Panel button to show upgrade talent
InfosFrame.PanelButtons.TalentUpgradeBtn.Activated:Connect(function()
    TalentIDSelected = nil
    TalentGenerationFrame.Visible = false
    UpgradeTalentFrame.Visible = true

    InfosFrame.PanelButtons.TalentGenerationBtn.Hover.Visible = true
    InfosFrame.PanelButtons.TalentUpgradeBtn.Hover.Visible = false
end)

RemoteEvent.TalentsGeneratorSystem.ActivateSystem.OnClientEvent:Connect(function()
    --Check if player have enter in auction house with creature summoned, if yes deload it because we can have conflict UI with event on creatures
	local exist = workspace:WaitForChild("CreaturesFolder"):FindFirstChild("Creature_"..Player.Name)
	if exist then
		--Dismount and Deload Creature from world
		RemoteFunction.InvokHorsePlayer:InvokeServer(exist.CreatureID.Value, true)
	end
    
    CameraController.SetEnabled(false)

    controls:Disable()
	ToolsModule.EnableOtherUI(false, {"TalentsGeneratorGui", "HorsesCollectionGui"})
    HorsesCollectionGui.CreaturesListForBreedingBack.Visible = true
    Background.Visible = true
	TalentGenerationFrame.Visible = true
    UpgradeTalentFrame.Visible = false

    ShowCreatureUI()
end)
