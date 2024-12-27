local ClientFarmHandler = {}
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local Assets = ReplicatedStorage:WaitForChild("SharedSync"):WaitForChild("Assets").FarmingAssets
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local FarmFolder = workspace:WaitForChild("FarmingFolder")
local FarmLandsFolder = FarmFolder:FindFirstChild("Land")
local ActiveFarmsFolder = FarmFolder:FindFirstChild("Farms")


local GetRemoteEvent = require("GetRemoteEvent")
local GetRemoteFunction = require("GetRemoteFunction")
local UtilFunctions = require("UtilFunctions")
local InputController = require("InputController")

local FarmingFunction = GetRemoteFunction("FarmingFunction")



local FarmPlaceTweenInfo = TweenInfo.new(0.5,Enum.EasingStyle.Quint,Enum.EasingDirection.Out)

ClientFarmHandler.Enabled = false

local LandSelector = Instance.new("Part")
LandSelector.Anchored = true
LandSelector.CanCollide = false
LandSelector.TopSurface = Enum.SurfaceType.Smooth

local Connections = {}
local CurrentModels = {}
local ModelTarget 

local function UpdateTargetModel(TargetName)
    if ModelTarget ~= TargetName then
        for ModelName,Model in pairs(CurrentModels) do
            if ModelName ~= TargetName then
                Model.Parent = nil
            else
                Model.Parent = workspace
                Mouse.TargetFilter = Model
            end
        end
        ModelTarget = TargetName
        if TargetName == "MakeLand" then
            LandSelector.Parent = FarmFolder
        else
            LandSelector.Parent = nil
        end
        return true
    end
end

function ClientFarmHandler:Init()
    RunService.Heartbeat:Connect(function(deltaTime)
        --??
    end)
    --[[ task.spawn(function()
        task.wait(5)
        print("SIMUALTE LOAD DATA FARMING")
        UpdateTargetModel("Plant")
        local TargetFarm = ActiveFarmsFolder:FindFirstChild("Farm1")
        for count = 1, 10, 1 do
            FarmingFunction:InvokeServer("LoadData",{
                Type = ModelTarget,
                Farm = TargetFarm,
                ID = count,
                Progress = 0.5,
                GrowTime = 10,
                Wetness = 1,
                StartTick = tick(),
                LastGrowTick = tick(),
                Weeds = false
            })
        end
    end) ]]
    task.spawn(function()
        task.wait(1)
        print("LOAD DATA FARMING")
        FarmingFunction:InvokeServer("LoadData")
    end)
end

function ClientFarmHandler:SetMode(ModeName)
    if self.Enabled then
        UpdateTargetModel(ModeName)
    end
end

function ClientFarmHandler:Enable()
    self.Enabled = true
    InputController:SetInputMap("Farming")
    for _,FarmingModel in ipairs(Assets.Models:GetChildren()) do
        CurrentModels[FarmingModel.Name] = FarmingModel:Clone()
        CurrentModels[FarmingModel.Name].Parent = FarmFolder
        CurrentModels[FarmingModel.Name].PrimaryPart.Transparency = 1
    end

    -- Overlap params for farm collision detection
    local NewFarmOverlapParams = OverlapParams.new()
    NewFarmOverlapParams.FilterType = Enum.RaycastFilterType.Whitelist
    local InstanceTable = {}
    for _,Farm in ipairs(ActiveFarmsFolder:GetChildren()) do
        table.insert(InstanceTable,Farm.PrimaryPart)
    end
    NewFarmOverlapParams.FilterDescendantsInstances = InstanceTable
    Connections.NewFarm = ActiveFarmsFolder.ChildAdded:Connect(function(NewFarm)
        table.insert(InstanceTable,NewFarm.PrimaryPart)
        NewFarmOverlapParams.FilterDescendantsInstances = InstanceTable
    end)

    local TargetID = 1
    local ModelTargetCFrame = CFrame.new()
    local TargetFarm
    local TargetLand
    local LandPlacementStart
    local LandPlacementSize = Vector3.new(5,1,5)

    local function CanPlaceFarm()
        local CheckCFrame = LandPlacementStart and CFrame.new((LandPlacementStart.Position + ModelTargetCFrame.Position)/2) or CFrame.new(ModelTargetCFrame.Position)
        if #workspace:GetPartBoundsInBox(CheckCFrame,LandPlacementSize,NewFarmOverlapParams) == 0 then
            return true
        end
        return false
    end

    Connections.Placement = RunService.Heartbeat:Connect(function(deltaTime)
        if Mouse.Hit and CurrentModels.Plant and ModelTarget then
            if ModelTarget ~= "MakeLand" then -- Edit plants mode
                TargetLand = nil
                local InRange = false
                for _,Farm in pairs(ActiveFarmsFolder:GetChildren()) do
                    if Farm.PrimaryPart then
                        local RelativePosition = Farm.PrimaryPart.CFrame:PointToObjectSpace(Mouse.Hit.Position)
                        local Size = Farm.PrimaryPart.Size
                        if math.abs(RelativePosition.X) <= Size.X/2 and RelativePosition.Y <= Size.Y + 5 and math.abs(RelativePosition.Z) <= Size.Z/2 then
                            TargetFarm = Farm
                            InRange = true
                        end
                    end
                end
                if TargetFarm and InRange then
                    local XIsOdd,YIsOdd = math.floor(TargetFarm.PrimaryPart.Size.X/5) % 2 == 1, math.floor(TargetFarm.PrimaryPart.Size.Z/5) % 2 == 1

                    local RelativePosition = TargetFarm.PrimaryPart.CFrame:PointToObjectSpace(Mouse.Hit.Position)
                    local XIndex = math.floor((RelativePosition.X + (XIsOdd and 2.5 or 0)) / 5)
                    local YIndex = math.floor((RelativePosition.Z + (YIsOdd and 2.5 or 0)) / 5)
                    
                    local XOffset = math.floor((TargetFarm.PrimaryPart.Size.X/2)/5)
                    local YOffset = math.floor((TargetFarm.PrimaryPart.Size.Z/2)/5)

                    local DesiredTargetID = ((XIndex + XOffset) * math.floor(TargetFarm.PrimaryPart.Size.Z/5)) + (YIndex + YOffset) + 1

                    local CanPlace = false
                    local TargetBlock
                    for _,Block in ipairs(TargetFarm:GetChildren()) do
                        if Block:GetAttribute("ID") == DesiredTargetID then
                            TargetBlock = Block
                            if Block:GetAttribute("InUse") == false then
                                CanPlace = true
                                break
                            end
                        end
                    end
                    
                    if CanPlace and ModelTarget == "Plant" or TargetBlock then    
                        ModelTargetCFrame = (TargetFarm.PrimaryPart.CFrame * CFrame.new((XIsOdd and 0 or 2.5) + XIndex * 5,0,(YIsOdd and 0 or 2.5) + YIndex * 5))
                    end
                    if TargetID ~= DesiredTargetID then
                        if CurrentModels[ModelTarget].PrimaryPart:FindFirstChild("ProgressBar") and TargetBlock then
                            local Progress = TargetBlock:GetAttribute("Progress") or 0 --error
                            if Progress <= 1 then
                                CurrentModels[ModelTarget].PrimaryPart.ProgressBar.Frame.Fill.Size = UDim2.new(0,0,1,0)
                                CurrentModels[ModelTarget].PrimaryPart.ProgressBar.Frame.Fill.BackgroundColor3 = Color3.fromRGB(85, 170, 255)
                                CurrentModels[ModelTarget].PrimaryPart.ProgressBar.Frame.Fill:TweenSize(UDim2.new(Progress,0,1,0),"Out","Quint",0.5,true)
                            else
                                CurrentModels[ModelTarget].PrimaryPart.ProgressBar.Frame.Fill.BackgroundColor3 = UtilFunctions.LerpColor(Color3.fromRGB(85, 255, 127),Color3.fromRGB(224, 26, 0),math.clamp(Progress-1,0,1))
                                CurrentModels[ModelTarget].PrimaryPart.ProgressBar.Frame.Fill:TweenSize(UDim2.new(1,0,1,0),"Out","Quint",0.5,true)
                            end
                        end
                    end
                    TargetID = DesiredTargetID
                end
            else --// make farm mode
                TargetFarm = nil
                local InRange = false
                
                for _,Land in pairs(FarmLandsFolder:GetChildren()) do
                    
                    local RelativePosition = Land.CFrame:PointToObjectSpace(Mouse.Hit.Position)
                    local Size = Land.Size
                    if math.abs(RelativePosition.X) <= Size.X/2 and RelativePosition.Y <= Size.Y + 5 and math.abs(RelativePosition.Z) <= Size.Z/2 then
                        TargetLand = Land
                        InRange = true
                    end
                end
                if TargetLand and InRange then
                    local RelativePosition = TargetLand.CFrame:PointToObjectSpace(Mouse.Hit.Position)
                    local XIndex = math.floor(RelativePosition.X / 5)
                    local YIndex = math.floor(RelativePosition.Z / 5)
                    
                    local OldModelTarget = ModelTargetCFrame
                    ModelTargetCFrame = (TargetLand.CFrame * CFrame.new(2.5 + XIndex * 5,0,2.5 + YIndex * 5))
                    if OldModelTarget ~= ModelTargetCFrame and CurrentModels[ModelTarget] then
                        if CanPlaceFarm() == true then
                            LandSelector.Color = Color3.fromRGB(23, 248, 98)
                        else
                            LandSelector.Color = Color3.fromRGB(250, 48, 48)
                        end
                    end
                    if LandPlacementStart then
                        LandPlacementSize = Vector3.new(
                            math.abs(LandPlacementStart.Position.X-ModelTargetCFrame.Position.X)+5,
                            1,
                            math.abs(LandPlacementStart.Position.Z-ModelTargetCFrame.Position.Z)+5
                        )
                        LandSelector.Size = UtilFunctions.Lerp(LandSelector.Size,LandPlacementSize,0.2)
                        LandSelector.CFrame = LandSelector.CFrame:Lerp(CFrame.new((LandPlacementStart.Position + ModelTargetCFrame.Position)/2),0.2)
                    else
                        LandPlacementSize = Vector3.new(5,1,5)
                        LandSelector.Size = LandPlacementSize
                        LandSelector.CFrame = LandSelector.CFrame:Lerp(ModelTargetCFrame,0.2)
                    end
                end
            end
        end
        if CurrentModels[ModelTarget] then
            CurrentModels[ModelTarget]:PivotTo(CurrentModels[ModelTarget].PrimaryPart.CFrame:Lerp(ModelTargetCFrame,0.2))
        end
    end)
    local Debounce = false
    Connections.Place = InputController.Inputs.Farming.Place.Activated:Connect(function()
        if TargetFarm then
            print("Farming!",TargetID)
            FarmingFunction:InvokeServer("Action",{Type = ModelTarget,Farm = TargetFarm,ID = TargetID})
        elseif TargetLand then
            if Debounce == false then
                Debounce = true
                if not LandPlacementStart then
                    LandPlacementStart = ModelTargetCFrame
                else
                    print("Made land")
                    if CanPlaceFarm() then
                        FarmingFunction:InvokeServer("MakeLand",{StartCFrame = LandPlacementStart, EndCFrame = ModelTargetCFrame})
                    else
                        warn("already a farm there")
                    end
                    local TweenPart = LandSelector:Clone()
                    TweenPart.Parent = workspace
                    TweenService:Create(TweenPart,FarmPlaceTweenInfo,{Size = TweenPart.Size * 1.2,Transparency = 1}):Play()
                    LandPlacementStart = nil
                    LandPlacementSize = Vector3.new(5,1,5)
                    task.wait(0.5)
                    TweenPart:Destroy()
                end
                Debounce = false
            end
        end
    end)
end

function ClientFarmHandler:Disable()
    self.Enabled = false
    for _,Connection in pairs(Connections) do
        Connection:Disconnect()
    end
    for _,Model in pairs(CurrentModels) do
        Model:Destroy()
    end
    ModelTarget = nil
end

return ClientFarmHandler