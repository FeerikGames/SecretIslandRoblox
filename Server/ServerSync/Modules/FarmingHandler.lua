-- Stratiz 2021
local FarmingHandler = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local Assets = ReplicatedStorage:WaitForChild("SharedSync"):WaitForChild("Assets").FarmingAssets
local GetRemoteEvent = require("GetRemoteEvent")
local GetRemoteFunction = require("GetRemoteFunction")
local SpatialUtils = require("SpatialUtils")
local UtilFunctions = require("UtilFunctions")
local PlayerDataModule = require("PlayerDataModule")
local ToolsModule = require("ToolsModule")
local TeleportModule = require("TeleportModule")
local EnvironmentModule = require("EnvironmentModule")

local FarmingFunction = GetRemoteFunction("FarmingFunction")

local FarmFolder = workspace:FindFirstChild("FarmingFolder") or Instance.new("Folder",workspace)
FarmFolder.Name = "FarmingFolder"
local FarmLandsFolder = FarmFolder:FindFirstChild("Land") or Instance.new("Folder",workspace)
FarmLandsFolder.Name = "Land"
local ActiveFarmsFolder = FarmFolder:FindFirstChild("Farms") or Instance.new("Folder",workspace)
ActiveFarmsFolder.Name = "Farms"

local GetOwnerServer = ReplicatedStorage.SharedSync.BindableFunction:WaitForChild("GetOwnerServer")
local ShowPopupBindableEvent = ReplicatedStorage.SharedSync.BindableEvent.ShowPopupAlert

local FarmData = {}

--[[
	Listen Event when player disconnect to the game.
]]
function playerRemoved(player)
    if game.PlaceId == EnvironmentModule.GetPlaceId("MyFarm") then
        --Save data farm only if player removed is the owner of farm. Care because if we not check this when a player disconnect from other player farm we replace their data farm.
        if player.UserId == GetOwnerServer:Invoke() then
            local Farms = PlayerDataModule:Get(player, "Farms")
            --print("FARM DATA BEFORE CLOSE",FarmData)
            for farmInstance, farmData in pairs(FarmData) do
                --print("SIMULATE SAVE", farmID, farmData)
                local data = {}
                for blockID, blockData in pairs(farmData) do
                    data[tostring(blockID)] = {
                        CurrentPlant = blockData.CurrentPlant and true or false,
                        Type = "Plant",
                        FarmSize = tostring(farmInstance.PrimaryPart.Size),
                        ID = blockData.ID,
                        Progress = blockData.BlockInstance:GetAttribute("Progress"),
                        GrowTime = blockData.GrowTime,
                        Wetness = blockData.Wetness,
                        StartTick = blockData.StartTick,
                        LastGrowTick = blockData.LastGrowTick,
                        Weeds = blockData.Weeds
                    }
                end

                Farms[tostring(farmInstance:GetPrimaryPartCFrame())] = data
            end
            print("DATA FARMING SAVE", Farms)
            PlayerDataModule:Set(player, Farms, "Farms")

            --Teleport other players to the public maps
            local players = {}
            for _, plr in pairs(game.Players:GetPlayers()) do
                if plr ~= player then
                    table.insert(players,plr)
                    if plr and not plr:GetAttribute("Teleporting") then
                        plr:SetAttribute("Teleporting", true)
                    end
                end
            end
            if #players >= 1 then
                print("TELEPORT ALL PLAYERS")
                -- Teleport the player to public server (true = private, false = not private server)
                TeleportModule.teleportWithRetry(EnvironmentModule.GetPlaceId("MainPlace"), players, false)
            end
        end
    end
end

--// Makes default farm block
local function MakeFarmBlock()
    local Part = Instance.new("Part")
    Part.Color = Color3.new(0.266666, 0.188235, 0.086274)
    Part.Material = Enum.Material.Pebble
    Part.Anchored = true
    Part.Size = Vector3.new(5,1,5)
    return Part
end

local function MakePlantModel()
    local PlantModel = Assets.Models.Plant:Clone()
    PlantModel.PrimaryPart.Transparency = 1
    return PlantModel
end
--// Updates size of crops
local DefaultCropSize = Vector3.new(3.579, 4, 3.921)
local function SetCropPercent(CropInstance,Alpha,Liveness)
    local AdjustedAlpha = 0.5 + (Alpha * 0.5)
    local PlantPart = CropInstance.Grass
    if Alpha <= 1 then
        local OldSize = PlantPart.Size
        PlantPart.Size = DefaultCropSize * AdjustedAlpha
        PlantPart.CFrame = PlantPart.CFrame * CFrame.new(0,PlantPart.Size.Y - OldSize.Y,0)  * CFrame.Angles(0,math.rad(0.5) * (Liveness or 1),0)
    else
        PlantPart.Color = UtilFunctions.LerpColor(Color3.fromRGB(91, 117, 79),Color3.fromRGB(75, 48, 15),math.clamp(Alpha-1,0,1))
    end
end

--// Makes farm plot from a base part as reference
local function MakeFarmFromRootPart(FarmRoot)
    local Farm = Instance.new("Model",ActiveFarmsFolder)
    Farm.Name = FarmRoot.Name
    FarmRoot.Parent = Farm
    Farm.PrimaryPart = FarmRoot
    if FarmRoot.Size.X % 5 ~= 0 or FarmRoot.Size.Z % 5 ~= 0 then
        --warn("Farm Block is not in increments of 5 studs!")
    end
    FarmData[Farm] = {}
    local CurrentIndex = 0
    for x=1,math.floor(FarmRoot.Size.X/5) do
        for y=1,math.floor(FarmRoot.Size.Z/5) do
            CurrentIndex += 1
            local Block = MakeFarmBlock()
            Block.Name = CurrentIndex
            Block:SetAttribute("ID",CurrentIndex)
            Block:SetAttribute("InUse",false)
            if CurrentIndex % 2 == 0 then
                --Block.Color = Color3.new(0.411764, 0.294117, 0.133333)
            end
            Block.Parent = Farm
            Block.CFrame = FarmRoot.CFrame * CFrame.new(2.5 + (-FarmRoot.Size.X/2 + (5 * (x-1))),0,2.5 + (-FarmRoot.Size.Z/2 + (5 * (y-1))))
            table.insert(FarmData[Farm],{
                Progress = 0,
                StartTick = tick(),
                GrowTime = 5,
                CurrentPlant = nil,
                BlockInstance = Block,
                PlantInstance = nil,
                HarvestAward = 10
            })
        end
    end
    FarmRoot:ClearAllChildren()
    FarmRoot.Transparency = 1
    local PlantHolder = Instance.new("Folder",Farm)
    PlantHolder.Name = "PlantHolder"
    -- Make Border
    local Directions = {
        {
            Vector = Vector3.new(0,0,0.5),
            Size = Vector3.new(1,1.3,0)
        },
        {
            Vector = Vector3.new(0,0,-0.5),
            Size = Vector3.new(1,1.3,0)
        },
        {
            Vector = Vector3.new(0.5,0,0),
            Size = Vector3.new(0,1.3,1)
        },
        {
            Vector = Vector3.new(-0.5,0,0),
            Size = Vector3.new(0,1.3,1)
        }
    }
    for _,DirectionData in ipairs(Directions) do
        local Part = Instance.new("Part")
        Part.Anchored = true
        Part.Parent = FarmFolder
        Part.CFrame = FarmRoot.CFrame * CFrame.new(FarmRoot.Size * DirectionData.Vector)
        Part.Size = (FarmRoot.Size * DirectionData.Size) + Vector3.new(1,0, 1)
        Part.TopSurface = Enum.SurfaceType.Smooth
        Part.Material = Enum.Material.Wood
        Part.Color = Color3.fromRGB(160, 95, 53)
    end

    return Farm
end

local function IncrementPlayerHarvestData(player, value)
    PlayerDataModule:Increment(player, value, "TotalHarvests")
    print("Total Harvests player :", PlayerDataModule:Get(player, "TotalHarvests"))
end

function FarmingHandler:Init()
    print("FARMING INIT")
    for _,FarmPart in pairs(ActiveFarmsFolder:GetChildren()) do
        MakeFarmFromRootPart(FarmPart)
    end
    task.spawn(function()
        while task.wait() do
            for Farm,Blocks in pairs(FarmData) do
                for ID,Block in pairs(Blocks) do
                    if Block.CurrentPlant then
                        if not Block.Weeds then
                            Block.Progress += ((tick() - Block.LastGrowTick)/Block.GrowTime) * Block.Wetness
                        end
                        Block.LastGrowTick = tick()
                        SetCropPercent(Block.PlantInstance,Block.Progress,Block.Weeds == true and 0 or Block.Wetness)
                        Block.BlockInstance:SetAttribute("Progress",Block.Progress)
                        Block.Wetness = math.clamp(Block.Wetness - math.random(1,100)/100000,0,1)
                        Block.BlockInstance.Color = UtilFunctions.LerpColor(Color3.fromRGB(172, 104, 65),Color3.fromRGB(62, 37, 23),Block.Wetness)
                        --
                        if math.random(15000) == 1 then
                            Block.Weeds = true
                            Block.PlantInstance.Weeds.Transparency = 0
                        end
                    end
                end
            end
        end
    end)

    FarmingFunction.OnServerInvoke = function(Player,Reason,Data) 
        if Reason == "Action" then
            if Data.Farm then
                local FoundBlock 
                for _,Block in ipairs(Data.Farm:GetChildren()) do
                    if Block:GetAttribute("ID") == Data.ID then
                        FoundBlock = Block
                        break
                    end
                end
                if FoundBlock then
                    if Data.Type == "Plant" then
                        if FoundBlock:GetAttribute("InUse") == false then
                            local result = PlayerDataModule:Decrement(Player, 50, "Ecus")
                            if not result then
                                --if error with payout, it's because player don't have money so we make a popup who redirect player on the Purchase Ecus
                                ShowPopupBindableEvent:Fire(
                                    Player,
                                    "Fail Payout",
                                    "You don't have enough Ecus ...",
                                    ToolsModule.AlertPriority.Annoucement,
                                    nil,
                                    ToolsModule.AlertTypeButton.OK,
                                    nil,
                                    nil,
                                    ToolsModule.OpenEcusGui,
                                    {Player}
                                )
                                
                                return
                            end

                            local PlantModel = MakePlantModel()
                            PlantModel:PivotTo(FoundBlock.CFrame)
                            PlantModel.Parent = Data.Farm.PlantHolder
                            FoundBlock:SetAttribute("InUse",true)

                            --
                            FarmData[Data.Farm][Data.ID].CurrentPlant = "PLANT_ID?"
                            FarmData[Data.Farm][Data.ID].Progress = 0
                            FarmData[Data.Farm][Data.ID].GrowTime = 60
                            FarmData[Data.Farm][Data.ID].Wetness = math.random()
                            FarmData[Data.Farm][Data.ID].StartTick = tick()
                            FarmData[Data.Farm][Data.ID].LastGrowTick = tick()
                            FarmData[Data.Farm][Data.ID].PlantInstance = PlantModel
                            FarmData[Data.Farm][Data.ID].Weeds = false
                        else
                            warn("Block is in use by another crop")
                        end
                    elseif Data.Type == "Harvest" then
                        if FarmData[Data.Farm][Data.ID] and FarmData[Data.Farm][Data.ID].CurrentPlant then
                            FarmData[Data.Farm][Data.ID].PlantInstance:Destroy()
                            FarmData[Data.Farm][Data.ID].CurrentPlant = nil
                            FoundBlock:SetAttribute("InUse",false)

                            print("Progress harvest", FarmData[Data.Farm][Data.ID].Progress)
                            local HarvestProgress = FarmData[Data.Farm][Data.ID].Progress
                            local HarvestReward = FarmData[Data.Farm][Data.ID].HarvestAward

                            local resultHarvest = 0
                            if FarmData[Data.Farm][Data.ID].Progress <= 1 then
                                resultHarvest = math.floor(HarvestReward * HarvestProgress)
                                print("Harvest reward for player is", resultHarvest)
                            else
                                resultHarvest = math.floor(HarvestReward - ((HarvestReward * HarvestProgress) - HarvestReward))
                                print("Harvest reward for player is", resultHarvest)
                            end
                            if resultHarvest > 0 then                                
                                game.ReplicatedStorage.SharedCustom.RemoteEvent.AnimateHarvestReward:FireClient(Player, resultHarvest)
                                IncrementPlayerHarvestData(Player, resultHarvest)
                            end
                        end
                    elseif Data.Type == "Water" then
                        if FarmData[Data.Farm][Data.ID] and FarmData[Data.Farm][Data.ID].CurrentPlant then
                            FarmData[Data.Farm][Data.ID].Wetness = 1
                        end
                    elseif Data.Type == "Rake" then
                        if FarmData[Data.Farm][Data.ID] and FarmData[Data.Farm][Data.ID].CurrentPlant then
                            FarmData[Data.Farm][Data.ID].Weeds = false
                            FarmData[Data.Farm][Data.ID].PlantInstance.Weeds.Transparency = 1
                        end
                    end
                    print("FARM DATA", FarmData)
                else
                    warn("Invalid farm Block ID")
                end
            end
        elseif Reason == "MakeLand" then
            local FoundLand
            for _,Land in ipairs(FarmLandsFolder:GetChildren()) do
                if SpatialUtils.IsPositionInPart(Data.StartCFrame.Position,Land) and SpatialUtils.IsPositionInPart(Data.EndCFrame.Position,Land) then
                    FoundLand = Land
                end
            end
            if FoundLand then
                local RootPart = Instance.new("Part")
                RootPart.CFrame = CFrame.new((Data.StartCFrame.Position+Data.EndCFrame.Position)/2)
                RootPart.Size = Vector3.new(
                    math.abs(Data.StartCFrame.Position.X-Data.EndCFrame.Position.X)+5,
                    1,
                    math.abs(Data.StartCFrame.Position.Z-Data.EndCFrame.Position.Z)+5
                )
                RootPart.Anchored = true
                RootPart.CanCollide = false
                RootPart.Parent = FarmFolder

                MakeFarmFromRootPart(RootPart)
            else
                warn("No land found")
            end
        elseif Reason == "LoadData" then
            if Player.UserId == GetOwnerServer:Invoke() then
                local PlayerFarmsData = PlayerDataModule:Get(Player, "Farms")
                --print("Player Farms Data",PlayerFarmsData)
                for farmID, dataFarm in pairs(PlayerFarmsData) do
                    if typeof(dataFarm) == "table" then
                        local TargetFarm
                        for _, model in pairs(ActiveFarmsFolder:GetChildren()) do
                            if model:GetPrimaryPartCFrame() == ToolsModule.ConvertStringToCFrame(farmID) then
                                TargetFarm = model
                                break
                            end
                        end
                        
                        if not TargetFarm then
                            local RootPart = Instance.new("Part")
                            RootPart.CFrame = ToolsModule.ConvertStringToCFrame(farmID)
                            RootPart.Size = ToolsModule.ConvertStringToVector3(dataFarm["1"].FarmSize)
                            RootPart.Anchored = true
                            RootPart.CanCollide = false
                            RootPart.Parent = FarmFolder

                            TargetFarm = MakeFarmFromRootPart(RootPart)
                        end

                        if TargetFarm then
                            for blockID, data in pairs(dataFarm) do
                                if data.CurrentPlant then
                                    local FoundBlock = TargetFarm:FindFirstChild(blockID)
                                    if FoundBlock then
                                        if data.Type == "Plant" then
                                            if FoundBlock:GetAttribute("InUse") == false then
                                                local PlantModel = MakePlantModel()
                                                PlantModel:PivotTo(FoundBlock.CFrame)
                                                PlantModel.Parent = TargetFarm.PlantHolder
                                                FoundBlock:SetAttribute("InUse",true)
                                                --
                                                local timePassed = math.abs(tick() - data.LastGrowTick)
                                                FarmData[TargetFarm][tonumber(blockID)].Progress = data.Progress
                                                FarmData[TargetFarm][tonumber(blockID)].GrowTime = data.GrowTime
                                                FarmData[TargetFarm][tonumber(blockID)].Wetness = math.clamp(data.Wetness - (timePassed/10000),0,1)
                                                FarmData[TargetFarm][tonumber(blockID)].StartTick = data.StartTick
                                                FarmData[TargetFarm][tonumber(blockID)].LastGrowTick = data.LastGrowTick
                                                FarmData[TargetFarm][tonumber(blockID)].PlantInstance = PlantModel
                                                FarmData[TargetFarm][tonumber(blockID)].Weeds = data.Weeds

                                                if data.Weeds then
                                                    FarmData[TargetFarm][tonumber(blockID)].PlantInstance.Weeds.Transparency = 0
                                                else
                                                    --if time passed are so long, this plant have automatically a weeds
                                                    --make a random with time passed to check if offline weed have spawn
                                                    --if time passed are more longer, more weeds spawn are bigger
                                                    local randomValueWeeds = 1000/(math.floor(timePassed)/100)
                                                    if randomValueWeeds < 1 then
                                                        randomValueWeeds = 1
                                                    end

                                                    if math.random(randomValueWeeds) == 1 then
                                                        FarmData[TargetFarm][tonumber(blockID)].Weeds = true
                                                        FarmData[TargetFarm][tonumber(blockID)].PlantInstance.Weeds.Transparency = 0
                                                        FarmData[TargetFarm][tonumber(blockID)].Progress = data.Progress + ((math.random(data.LastGrowTick, tick()) - data.LastGrowTick)/data.GrowTime) * FarmData[TargetFarm][tonumber(blockID)].Wetness
                                                        --print("PROGRESS OFF IS", FarmData[TargetFarm][tonumber(blockID)].Progress)
                                                    end
                                                end

                                                --When it's set, the plant start to work with spawn function who reduce with random value the life of plant
                                                FarmData[TargetFarm][tonumber(blockID)].CurrentPlant = data.CurrentPlant
                                            else
                                                warn("Block is in use by another crop")
                                            end
                                        end
                                    else
                                        warn("Invalid farm Block ID")
                                    end
                                end
                            end
                        end
                    end
                end
                --print("FarmData AFTER LOAD PLAYER DATA", FarmData)
            end
        end
    end

    ReplicatedStorage.SharedSync.RemoteEvent.UIFarmOpen.OnServerEvent:Connect(function(player, isOpen)
        ReplicatedStorage.SharedSync.RemoteEvent.UIFarmOpen:FireClient(player, isOpen)
    end)
end

game.Players.PlayerRemoving:Connect(playerRemoved)

return FarmingHandler