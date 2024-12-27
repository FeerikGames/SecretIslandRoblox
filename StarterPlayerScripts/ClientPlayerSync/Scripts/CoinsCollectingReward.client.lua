local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local PlayerDataModule = require("ReplicatedPlayerData")
local UIProviderModule = require("UIProviderModule")
local ToolsModule = require("ToolsModule")
local GameDataModule = require("GameDataModule")
local SoundControllerModule = require("SoundControllerModule")
local EnvironmentModule = require("EnvironmentModule")

local Assets = ReplicatedStorage.SharedSync.Assets
local Player = game.Players.LocalPlayer

local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local RemoteFunction = ReplicatedStorage.SharedSync.RemoteFunction

local HorseEvents = ReplicatedStorage.SharedSync.HorseEvents

--If not principal place and farm place we don't launch this system
if game.PlaceId ~= EnvironmentModule.GetPlaceId("MainPlace") and game.PlaceId ~= EnvironmentModule.GetPlaceId("MyFarm") then
    return
end

--Define limit of spawn type obj per day
local CollectingLimits = {
    
}

--Define actual spawn session objects to check limit
local SessionSpawned = {
    
}

local Collectables = Assets.Collectables:GetChildren()
local SpawnBy = 100
local SpawnByForOtherSpawn = 2
local LimitOfSpawnedCollectables = 500
local NbActualCollectablesSpawned = 0
local ResetTime = nil

local CollectingFolder = Instance.new("Folder", workspace)
CollectingFolder.Name = "CollectingFolder"
local CollectingSpawnsFolder = workspace:FindFirstChild("CollectingSpawns") or Instance.new("Folder", workspace)
CollectingSpawnsFolder.Name = "CollectingSpawns"
local CollectingFieldsSpawnsFolder = workspace:FindFirstChild("CollectingFieldsSpawns")
local CrystalFieldSpawnsFolder = workspace:WaitForChild("CollectingCrystalsSpawns")

local magnetizeBonus = RemoteFunction.CheckPlayerHasGamepass:InvokeServer(GameDataModule.Gamepasses.MagnetizeX2.ProductID) and 2 or 1
local limitCollectableBonus = RemoteFunction.CheckPlayerHasGamepass:InvokeServer(GameDataModule.Gamepasses.DailyLimitCollectablesX2.ProductID) and 2 or 1

--[[
    This function allow to animate rotating and floating collectible object in world when spawn with TweenService
]]
local function SetRotationAndFloating(obj)
    local tweenInfo = TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, false)
    local goal = {
        Orientation = Vector3.new(0,360,0)
    }
    local tween = TweenService:Create(obj, tweenInfo, goal)
    tween:Play()
end

--[[
    Little function for launch detection event when obj give in parameter touch the ground terrain we anchor object
]]
local function TouchGround(obj:Part)
    local coTouch
    coTouch = obj.Touched:Connect(function(otherPart)
        if otherPart == workspace.Terrain then
            coTouch:Disconnect()
            obj.Anchored = true
            obj.AssemblyLinearVelocity = Vector3.new()
            obj.AssemblyAngularVelocity = Vector3.new()
            obj.Rotation = Vector3.new()
        end
    end)
end

local function SetShakeExplosion(obj, callback)
    local duration = 0.025
    local totalTime = 0

    -- Définir les limites de la position de la part
    local limit = 0.15
    local origin = obj.Position

    for _, particle in pairs(obj:GetChildren()) do
        if particle:IsA("ParticleEmitter") then
            particle.Enabled = true
        end
    end

    -- Boucle infinie pour animer la part
    while totalTime < 0.5 do
        local random = Random.new()
        local tween = TweenService:Create(obj, TweenInfo.new(duration), {
            Position = obj.Position + Vector3.new(random:NextNumber(-limit, limit), random:NextNumber(-limit, limit), random:NextNumber(-limit, limit))
        })
        
        tween:Play()

        tween.Completed:Connect(function(playbackState)
            if playbackState == Enum.PlaybackState.Completed then
                obj.Position = origin
                totalTime += duration
            end
        end)
        
        tween.Completed:Wait()
    end

    for _, particle in pairs(obj:GetChildren()) do
        if particle:IsA("ParticleEmitter") then
            particle:Destroy()
        end
    end

    callback()
end

--[[
    This function allow to animate little jump dropable collectible object in world when spawn
]]
local function SetLittleJumpRandom(obj:Part)
    while obj do
        task.wait(math.random(3,6))
        local random = math.random(1, 100)
        if random <= 30 then
            obj.Anchored = false
            obj:ApplyImpulse(Vector3.new(0,1000,0))
            TouchGround(obj)
        end
    end
end

--[[
    Here we set up the behavior of object for play can get it and if player get it.
    Object work only if player are on creature mounted and allow to increment value of collectible getting.
    We update the number of type object player have collect to check daily collectable objects player can get.
]]

local function SetBehaviorObject(obj, specificValue)
    local runCo

    runCo = RunService.Heartbeat:Connect(function(deltaTime)
        if Player.Character and Player.Character.PrimaryPart then
            local creature = game.Workspace.CreaturesFolder:FindFirstChild("Creature_"..Player.Name)
            if creature then
                creature:WaitForChild("HumanoidRootPart")
                local SizeRatio = creature.PrimaryPart:GetAttribute("SizeRatio")
                local multiply =  SizeRatio > 1 and SizeRatio or 1
                if (obj.Position - Player.Character.PrimaryPart.Position).Magnitude < (35 * multiply * magnetizeBonus) then
                    -- Check if limit are reach if yes we disable behavior of drop and can't collected by player
                    if PlayerDataModule.LocalData.CollectableLimit[obj:GetAttribute("ParentName")] then
                        if PlayerDataModule.LocalData.CollectableLimit[obj:GetAttribute("ParentName")] >= CollectingLimits[obj:GetAttribute("ParentName")] then
                            return
                        end
                    end

                    if creature.Seat.Rider.Value then
                        runCo:Disconnect()

                        if string.match(obj:GetAttribute("CollectingType"), "Crystal") then
                            -- Check if race of creature match with drop crystal to know if he can win xp or just loot crystal
                            if string.match(obj:GetAttribute("CollectingType"), PlayerDataModule.LocalData.CreaturesCollection[creature.CreatureID.Value].Race) then
                                -- If player win exp for creature we don't give loot crystal because is consume for give exp ifn ot we give crystal currency to player
                                if not RemoteFunction.CreatureEvolution.GiveExpToCreature:InvokeServer(creature.CreatureID.Value, specificValue or obj:GetAttribute("CollectingValue")) then
                                    -- Loot crystal for currency crystals
                                    RemoteFunction.IncrementValueOf:InvokeServer("Crystals."..obj:GetAttribute("CollectingType"), specificValue or obj:GetAttribute("CollectingValue"))
                                end
                            end

                            -- Make update limit of collectable parent of drop (only for crystal collectable)
                            local parentName = obj:GetAttribute("ParentName")
                            local data = PlayerDataModule.LocalData.CollectableLimit
                            data[parentName] += 1
                            RemoteFunction.SetValueOf:InvokeServer("CollectableLimit", data)

                            -- If limit are reach by player we sned event to create popup alert by server to say player limit reach and give possibility to buy gamepass extra limit
                            if data[parentName] >= CollectingLimits[parentName] then
                                RemoteEvent.CallPopupDailyLimit:FireServer(CollectingLimits[parentName], parentName)
                            end
                        else
                            RemoteFunction.IncrementValueOf:InvokeServer(obj:GetAttribute("CollectingType"), specificValue or obj:GetAttribute("CollectingValue"))
                        end

                        ToolsModule.MagnetizedObject(Player, obj)
                        SoundControllerModule:CreateSound("CoinCollect2")
                        obj:Destroy()
                    end
                end
            end
        end
    end)

    return runCo
end

--[[
    Function to setup behavior of Collectable object who make little dropable object magnetized
    All collectables objects are setup in Folder Collectables from ReplicatedStorage Assets and contains all particles animation
    and a Folder setup for droppable objects.
]]
local function SetBehaviorCollectableObject(object)
    local runCo
    runCo = RunService.Heartbeat:Connect(function(deltaTime)
        if Player.Character and Player.Character.PrimaryPart then
            local creature = game.Workspace.CreaturesFolder:FindFirstChild("Creature_"..Player.Name)
            if creature then
                creature:WaitForChild("HumanoidRootPart")

                -- Check if limit are reach and don't make spawn drop if limit are reach for the object spawned
                if PlayerDataModule.LocalData.CollectableLimit[object.Name] >= CollectingLimits[object.Name] then
                    return
                end

                if not creature:FindFirstChild("CollectablesDetector") then
                    return
                end

                local parts = workspace:GetPartsInPart(object) --(object.Position - Player.Character.PrimaryPart.Position).Magnitude < math.floor(60 + Player.Character.PrimaryPart.AssemblyLinearVelocity.Magnitude)
                if table.find(parts, creature.CollectablesDetector) then
                    -- Check if creature type can collect this object
                    local CanCollect = object:GetAttribute("CanCollect")
                    if CanCollect ~= "All" then
                        if PlayerDataModule.LocalData.CreaturesCollection[creature.CreatureID.Value].Race ~= CanCollect then
                            return
                        end
                    end

                    if creature.Seat.Rider.Value then
                        runCo:Disconnect()

                        task.spawn(function()
                            SetShakeExplosion(object, function()
                                object.Transparency = 1
                                object.explose.particle:Emit(100)
                                object.explose.Stars:Emit(150)
                                SoundControllerModule:CreateSound("ExplosionDrop", object)
                                SoundControllerModule:CreateSound("Drop", object)

                                local amout = not RemoteFunction.CheckPlayerHasGamepass:InvokeServer(GameDataModule.Gamepasses.VIP.ProductID) and object:GetAttribute("Amount") or object:GetAttribute("Amount") * 2

                                task.spawn(function()
                                    DropCollectables(object.CFrame, object.Name, ReplicatedStorage.SharedSync.Assets.Drops.DropCollectable, object.Drops:GetChildren(), amout)
                                end)

                                -- Check luck to have a drop bonus
                                local bonusWin = math.random(1,100)
                                if bonusWin <= 30 then
                                    -- Win bonus drop
                                    object.BillboardGui.Enabled = true

                                    for _, v in pairs(object.Bonus:GetChildren()) do
                                        if v:IsA("ParticleEmitter") then
                                            v.Parent = object
                                            v:Emit(100)
                                        end
                                    end

                                    SoundControllerModule:CreateSound("ExplosionBonus", object)

                                    DropCollectables(object.CFrame, object.Name, ReplicatedStorage.SharedSync.Assets.Drops.DropCollectable, object.Drops:GetChildren(), amout/1.2, true)
                                    
                                    object.BillboardGui.Enabled = false
                                    for _, v in pairs(object:GetChildren()) do
                                        if v:IsA("ParticleEmitter") then
                                            v:Destroy()
                                        end
                                    end
                                end

                                task.wait(2)
                                object:Destroy()
                            end)
                        end)

                        -- Update limit of collectables object here only if not a crystal because for crystal limit are make on drop and not collectable
                        if not string.match(object.Name, "Crystal") then
                            local data = PlayerDataModule.LocalData.CollectableLimit
                            data[object.Name] += 1
                            RemoteFunction.SetValueOf:InvokeServer("CollectableLimit", data)
                        end
                        
                        NbActualCollectablesSpawned -= 1
                    end
                end
            end
        end
    end)
end

--Allow to check if we can spawn object at position give in parameter. Used by SelectRandomPosition()
local function checkValidSpawningPosition(position, size, blacklist)
    local isValidPosition = true
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = blacklist
    local overlappedParts = workspace:GetPartBoundsInRadius(position, size.Magnitude + 30, overlapParams)
    if #overlappedParts > 0 then
        for _, part in pairs(overlappedParts) do
            if part.CollisionGroup == "DroppingCollectable" then
                isValidPosition = false
                break
            end
        end
    end

    return isValidPosition
end

function SeeRaycast(result, rayOrigin, name)
	if result then
		local distance = (rayOrigin - result.Position).Magnitude
		--[[ local exist = workspace:FindFirstChild("RaycastViewer"..name)
		if exist then
			exist:Destroy()
		end ]]
		local p = Instance.new("Part",workspace)
		p.Name = "RaycastViewer"..name
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.BrickColor = BrickColor.Red()
		p.Size = Vector3.new(0.5, 0.5, distance)
		p.CFrame = CFrame.lookAt(rayOrigin, result.Position)*CFrame.new(0, 0, -distance/2)
        
        task.wait(0.5)
        p:Destroy()
	end
end

local radius = 2000 --radius of field action of spawn obj in map
local FieldSpawn = RemoteFunction.GetCollectableFieldSpawn:InvokeServer()
local OtherFieldsSpawn = CollectingFieldsSpawnsFolder:GetChildren()
table.remove(OtherFieldsSpawn, table.find(OtherFieldsSpawn,FieldSpawn))

--[[
    Use Raycast to take random position on map in radius give before. This allow to setup random position without conflict position with other object or material of map
    for object spawned.
]]
local function SelectRandomPosition(obj, spawn)
    local tryPos = 0
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Include
    raycastParams.IgnoreWater = true
    raycastParams.FilterDescendantsInstances = {workspace.Terrain}
    
    local position
    local validPosition = false
    while validPosition == false do
        -- Calcule local pos of box with size of it
        local localPos = Vector3.new(math.random(-spawn.Size.X/2,spawn.Size.X/2),spawn.Size.Y/2,math.random(-spawn.Size.Z/2,spawn.Size.Z/2))--Vector3.new(math.random(-radius,radius),150,math.random(-radius,radius))
        -- Calcule worldOffset with only rotation matrix of Cframe for transform vector
        local worldOffset = spawn.CFrame:VectorToWorldSpace(localPos) -- Same as : spawn.CFrame.Rotation * localPos or spawn.CFrame.Rotation:PointToWorldSpace(localPos)
        -- Apply offset relative to world position of box to take rotation of object and good start raycast origin
        local rayOrigin = spawn.CFrame.Position + worldOffset
        
        local raycastResult = workspace:Raycast(rayOrigin, Vector3.new(0,-spawn.Size.Y,0)*10, raycastParams)--workspace:Raycast(rayOrigin, Vector3.new(0,-radius,0), raycastParams)
        --[[ task.spawn(function()
            SeeRaycast(raycastResult, rayOrigin, "Test")
        end) ]]
        if raycastResult --[[ and raycastResult.Material ~= Enum.Material.Water ]] then
            position = raycastResult.Position + obj.Size * Vector3.new(0,0.5,0)
            validPosition = checkValidSpawningPosition(position, obj.Size, {workspace.Terrain})
            if validPosition then
                obj:PivotTo(CFrame.new(position) * CFrame.Angles(0,math.rad(math.random(0,360)),0))
            else
                -- Increment try search valid position, if 100 try are make and not found we cancel search
                tryPos += 1
                if tryPos > 20 then
                    break
                end
            end
        end
        task.wait()
    end

    return validPosition
end

--[[
    Select a random collectable object we want to spawn calculate by Weight with dynamic setup depending of
    setup collectable object in folder Collectables
]]
local function GetRandomCollectable()
    --return Assets.Collectables.GroundCrystal10
    local OrderedTable = {}
    local TotalWeight = 0
    for _, obj in pairs(Collectables) do
        TotalWeight += obj:GetAttribute("Weight")
        OrderedTable[obj.Name] = obj:GetAttribute("Weight")
    end
    
    local Chance = math.random(1, TotalWeight)
	local Counter = 0
	for Name, Weight in pairs(OrderedTable) do
		Counter = Counter + Weight
		if Chance <= Counter then
			for _, obj in pairs(Collectables) do
                if obj.Name == Name then
                    return obj
                end
            end
		end
	end
end

function DropCollectables(originCFrame:CFrame, parentName:string, objectDrop, dropsInfo:table, totalAmount:number, isBonus:boolean)
    local function InstantiateDrops(amount, dropName, dropConfig)
        for i = 0, amount do
            task.spawn(function()
                local clone:Part = objectDrop:Clone()
                clone.Name = "Drop"..i
                clone.CFrame  = originCFrame
                clone.Parent = workspace
                clone.BillboardGui.Icon.Image = GameDataModule.DropCollectables[dropName]
                clone.Trail.Enabled = isBonus
    
                -- Visual config
                if dropConfig:FindFirstChild("ImageColor") then
                    clone.BillboardGui.Brightness = dropConfig.Brightness.Value
                    clone.BillboardGui.Sparkle.ImageTransparency = dropConfig.ImageTransparency.Value
                    clone.BillboardGui.Sparkle.ImageColor3 = dropConfig.ImageColor.Value
                end
    
                clone:SetAttribute("CollectingType", dropName)
                clone:SetAttribute("CollectingValue", dropConfig.QuantityForOne.Value)
                clone:SetAttribute("ParentName", parentName)
        
                local randomX = {math.random(-8,-5), math.random(5,8)}
                local randomZ = {math.random(-8,-5), math.random(5,8)}
        
                local velocity = Vector3.new(randomX[math.random(1,2)], math.random(30,80), randomZ[math.random(1,2)])
                clone:ApplyImpulse(velocity * 25)
        
                task.spawn(function()
                    SetLittleJumpRandom(clone)
                end)
    
                task.wait(Random.new():NextNumber(0.5, 0.9))
    
                local co = SetBehaviorObject(clone)
    
                TouchGround(clone)
                
                if isBonus then
                    SoundControllerModule:CreateSound("DropBonus", clone)
                    task.wait(0.05)
                end
    
    
                task.spawn(function()
                    task.wait(30)
                    if clone then
                        co:Disconnect()
                        clone:Destroy()
                    end
                end)
            end)
        end
    end

    for _, drop in pairs(dropsInfo) do
        InstantiateDrops(math.floor(totalAmount*(drop.value/100)), drop.Name, drop)
    end
end

repeat
    task.wait(1)
until PlayerDataModule.LocalData

-- Setup table of limitation for Collectables
for _, obj in pairs(Collectables) do
    CollectingLimits[obj.Name] = obj:GetAttribute("LimitParDay") * limitCollectableBonus
    SessionSpawned[obj.Name] = 0
end

--[[
    This function allow to select a random collectable and make check of limitation to spawn it or not
    Check timer of reset data collectable
]]
local function CreateAndSpawnRandomCollectableAtSpawn(spawn)
    local obj = GetRandomCollectable()

    if PlayerDataModule.LocalData.CollectableLimit then
        --check if we can spawn it or not
        if PlayerDataModule.LocalData.CollectableLimit[obj.Name] then
            if PlayerDataModule.LocalData.CollectableLimit[obj.Name] < CollectingLimits[obj.Name] and SessionSpawned[obj.Name] < CollectingLimits[obj.Name] then
                -- Create and instatiate collectable object
                local clone = obj:Clone()

                -- Check if object is a Crystal (it's specific collectable type object with specific spawns)
                if string.match(obj.Name, "Crystal") then
                    -- Select random spawn from crystal spawn
                    local CrystalSpawns = CrystalFieldSpawnsFolder:GetChildren()
                    local GoodCrystalSpawns = {}

                    -- Get only spawn of same crystal object
                    for _, spawn in pairs(CrystalSpawns) do
                        if string.match(obj.Name, spawn.Name) then
                            table.insert(GoodCrystalSpawns, spawn)
                        end
                    end
                    
                    -- Check if min 1 spawn exist else make default random spawn pos
                    if #GoodCrystalSpawns > 0 then
                        -- If found valid position make it, if not, destroy object and cancel spawning to make another
                        local crystalField = GoodCrystalSpawns[math.random(1, #GoodCrystalSpawns)]
                        --warn("Test Choose Crystal Field", crystalField)
                        local result = SelectRandomPosition(clone, crystalField)
                        --warn("After Choose", result)
                        if not result then
                            clone:Destroy()
                            return
                        end
                    else
                        SelectRandomPosition(clone, spawn)
                    end
                else
                    SelectRandomPosition(clone, spawn)
                end

                clone.Parent = CollectingFolder
                SetBehaviorCollectableObject(clone)

                if SessionSpawned[obj.Name] == 0 then
                    SessionSpawned[obj.Name] = PlayerDataModule.LocalData.CollectableLimit[obj.Name] + 1
                else
                    SessionSpawned[obj.Name] += 1
                end

                NbActualCollectablesSpawned += 1
                
                return
            end
        end

        --check if limit are reach if time to reset data is coming
        local ActualTime = os.time()
        local diffTime = os.difftime(ActualTime, ResetTime or PlayerDataModule.LocalData.LastDateConnexion)
        if diffTime > 3600 then
            diffTime = diffTime/3600
            if diffTime >= 24 then
                --24 hours have passed so we can reset limitation colleting
                --print("TEST RESET COLLECTING LIMIT")
                ResetTime = os.time()
                local data = PlayerDataModule.LocalData.CollectableLimit
                for _, t in pairs(Collectables) do
                    if data[t.Name] then
                        SessionSpawned[t.Name] -= data[t.Name]
                    end

                    data[t.Name] = 0
                end
                RemoteFunction.SetValueOf:InvokeServer("CollectableLimit", data)

                print("test reset data collectables", data)
            end
        end
    end
end

--[[
    Here we setup all collectable object with spawn are defined in game manually
]]
task.spawn(function()
    for _, spawn in pairs(CollectingSpawnsFolder:GetDescendants()) do
        if spawn:IsA("BasePart") then
            -- Check prct of luck to try spawn it or not
            local prct = spawn:GetAttribute("PrctLuckSpawn")

            -- If random number coresponding to prct luck of spawn make collectable, create collectable.
            if math.random(1, 100) <= prct then
                local collectableName = spawn:GetAttribute("CollectableName")
                if spawn.isEmpty.Value then
                    local clone:BasePart
                    for _, obj in pairs(Collectables) do
                        if obj.Name == collectableName then
                            clone = obj:Clone()
                            break
                        end
                    end
        
                    if clone then
                        clone:SetAttribute("Amount", spawn:GetAttribute("CollectableAmount"))
                        spawn.isEmpty.Value = false
                        clone.Parent = CollectingFolder
                        clone:PivotTo(spawn.CFrame + Vector3.new(0,3,0))
        
                        SetBehaviorCollectableObject(clone)
                        
                        clone.Destroying:Connect(function()
                            spawn.isEmpty.Value = true
                        end)
                    end
                end
            end
        end
    end
end)

--Here we setup continusly random collectable objects with random position on map and check limit of spawn quantity and per day to spawn or not the object random selected
task.spawn(function()
    while true do
        if NbActualCollectablesSpawned < LimitOfSpawnedCollectables then
            -- Principal big field selected by server to spawn lot of collectables
            for i=0, SpawnBy do
                CreateAndSpawnRandomCollectableAtSpawn(FieldSpawn)
            end
    
            -- Secondary other field to spawn a few collectables objects
            for _, otherSpawn in pairs(OtherFieldsSpawn) do
                for i=0, SpawnByForOtherSpawn do
                    CreateAndSpawnRandomCollectableAtSpawn(otherSpawn)
                end
            end
        end
        task.wait(1)
    end
end)

-- Try to make a listener event send by server PushObject for reward players who destroy rocks in game
RemoteEvent:WaitForChild("RockExplode").OnClientEvent:Connect(function(originCFrame:CFrame, parentName:string, objectDrop, dropsInfo:table, totalAmount:number, isBonus:boolean)
    task.spawn(function()
        DropCollectables(originCFrame, parentName, objectDrop, dropsInfo, totalAmount, isBonus)
    end)
end)

-- Remote Event GamePassPromptPurchaseFinished listen, event send by server when pruchase Gamepass are make and return if purchase Success and what PAss ID are buy by player
RemoteEvent:WaitForChild("GamePassPromptPurchaseFinished").OnClientEvent:Connect(function(purchasedPassID, purchaseSuccess)
    if purchaseSuccess then
        if purchasedPassID == GameDataModule.Gamepasses.MagnetizeX2.ProductID then
            magnetizeBonus = 2
        elseif purchasedPassID == GameDataModule.Gamepasses.DailyLimitCollectablesX2.ProductID then
            limitCollectableBonus = 2
            for _, obj in pairs(Collectables) do
                CollectingLimits[obj.Name] = obj:GetAttribute("LimitParDay") * limitCollectableBonus
            end
        end
    end
end)