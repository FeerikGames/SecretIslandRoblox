local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))

-- Requires
local GameDataModule = require("GameDataModule")
local EnvironmentModule = require("EnvironmentModule")

--Remote
local RemoteFunction = ReplicatedStorage.RemoteFunction
local BindableFunction = ReplicatedStorage.BindableFunction

local LocalPlayer = Players.LocalPlayer

local ToolsModule = {
	AlertPriority = {
		Low = 0,
		Standard = 1,
		High = 2,
		ExtremlyHigh = 3,
		Annoucement = 4,
		AdminMessage = 5
	},
	AlertTypeButton = {
		SeeCreature = "See Creature",
		OK = "Ok",
		YES = "Yes",
		NO = "No",
		VALID = "VALIDATE",
		LOCK = "LOCK"
	},
	CurrencyType = {
		Robux = 0,
		Ecus = 1,
		Feez = 2
	},
	RarityColor = {
		Common = Color3.fromRGB(0, 162, 255),
		Uncommon =Color3.fromRGB(153, 0, 255),
		Rare =Color3.fromRGB(81, 255, 0),
		UltraRare =Color3.fromRGB(255, 17, 0),
		Legendary =Color3.fromRGB(255, 251, 0),
	},
	CantUseInventoryServerIDList = {
		EnvironmentModule.GetPlaceId("MapA"),
		EnvironmentModule.GetPlaceId("MapB"),
		EnvironmentModule.GetPlaceId("ClubMap")
	},
	Abbreviations = {"K","M","B","T","Qd","Qn","Sx","Sp","O","N"}
}

--[[
	Method allow destroy component located in UI for reset data ui with the type given
]]
function ToolsModule.DepopulateTypeOfItemFrom(typeOfItem, location)
	for _, v in pairs(location:GetChildren()) do
		if v:IsA(typeOfItem) then
			v:Destroy()
		end
	end
end

function ToolsModule.AbbreviateNumber(number)
	local abbreviationIndex = math.floor(math.log(number,1000))
	local abbreviation = ToolsModule.Abbreviations[abbreviationIndex]

	local IsMobile = LocalPlayer.PlayerGui:FindFirstChild("TouchGui")

	if abbreviation and IsMobile then
		local shortNum = number/(1000^abbreviationIndex)
		local intNum = math.floor(shortNum)
		local str = intNum .. abbreviation
		if intNum < shortNum then
			str = str .. "+"
		end
		return str
	else
		return tostring(ToolsModule.DotNumber(number))
	end
end

function ToolsModule.DotNumber(value)
	local t
	while true do
		value, t = string.gsub(value, "^(-?%d+)(%d%d%d)", "%1,%2")
		if t==0 then
			break
		end
	end
	return value
end

local function WeldPair(x, y, ToObject)
	local weld = Instance.new("Weld")
	weld.Part0 = x
	weld.Part1 = y
	if ToObject then
		weld.C1 = y.CFrame:toObjectSpace(x.CFrame)
	end
	weld.Parent = y
	return weld
end

function ToolsModule.WeldModelToPrimary(Model)
	if Model.PrimaryPart then
		for _,Part in ipairs(Model:GetDescendants()) do
			if Part:IsA("BasePart") and Part ~= Model.PrimaryPart then
				--check if found a weld already exist destroy it to replace by new
				for i, child in pairs(Part:GetChildren()) do
					if child:IsA("Weld") then
						child:Destroy()
					end
				end
				WeldPair(Model.PrimaryPart,Part,true)
				Part.Anchored = false
			end
		end
	else
		error("Cannot weld model, model has no primary part")    
	end
end

--[[

]]
function ToolsModule.ScaleModel(model, dis)
	local PrimaryPart = model.PrimaryPart
	local PrimaryPartCFrame = model:GetPrimaryPartCFrame()

	local MaxSize = 50
	local MinSize = 1

	--scale first ref part and check max size reach
	local scale = 1+(dis/60)
	local newSize = PrimaryPart.Size*scale

	--check if not rach max or min size of model to resize all objects of model
	if (newSize.X < MaxSize and newSize.X > MinSize) and (newSize.Y < MaxSize and newSize.Y > MinSize) and (newSize.Z < MaxSize and newSize.Z > MinSize) then
		PrimaryPart.Size = newSize
		local distance = (PrimaryPart.Position - PrimaryPartCFrame.p)
		local rotation = (PrimaryPart.CFrame - PrimaryPart.Position)
		PrimaryPart.CFrame = (CFrame.new(PrimaryPartCFrame.p + distance*scale) * rotation)

		--Scale BaseParts
		for _,object in pairs(model:GetDescendants()) do
			if object:IsA('BasePart') and object ~= PrimaryPart then
				local scale = 1+(dis/60)
				object.Size = object.Size*scale
				local distance = (object.Position - PrimaryPartCFrame.p)
				local rotation = (object.CFrame - object.Position)
				object.CFrame = (CFrame.new(PrimaryPartCFrame.p + distance*scale) * rotation)
			end
		end
	end
end

--[[
	
]]
function ToolsModule.SetWeldModelObject(model, isEnable)
	if model.Parent:IsA("Model") then
		model=model.Parent
		if not isEnable then
			for _,object in pairs(model:GetDescendants()) do
				if object:IsA('BasePart') then
					for _,weld in pairs(object:GetDescendants()) do
						if weld:IsA('Weld') then
							object.Anchored = true
							weld:Destroy()
						end
					end
				end
			end
		else
			ToolsModule.WeldModelToPrimary(model)
		end
	end
end

--[[
	This function allow to return size of Dictionnary
]]
function ToolsModule.LengthOfDic(Table)
	local counter = 0 
	for _, v in pairs(Table) do
		counter =counter + 1
	end
	return counter
end

function ToolsModule.GetRandomKeyFromDictionnary(dico)
	local keys = {}
	for key, _ in pairs(dico) do
		table.insert(keys, key)
	end

	return keys[math.random(#keys)]
end


function ToolsModule.GetRandomValueFromDictionnary(dico)
	local values = {}
	for _, value in pairs(dico) do
		table.insert(values, value)
	end

	return values[math.random(#values)]
end

--[[
	This function will return a copy of passed table and return it
]]
function ToolsModule.deepCopy(original)
	if type(original) == "table" then
		local copy = {}
		for k, v in pairs(original) do
			if type(v) == "table" then
				v = ToolsModule.deepCopy(v)
			end
			copy[k] = v
		end
		return copy
	end
	return original
end

--[[
	This function allow to transform a string CFrame to a CFrame value.
	Example, it's use to save position of a object save in the datastore.
]]
function ToolsModule.ConvertStringToCFrame(cf)
	local components = {}
	for num in string.gmatch(cf, "[^%s,]+") do
		components[#components+1] = tonumber(num)
	end

	return CFrame.new(unpack(components))
end

--[[
	This function allow to transform a string Vector3 to a Vactor3 value.
	Example, it's use to save size of a object save in the datastore.
]]
function ToolsModule.ConvertStringToVector3(val)
	local components = {}
	for s in string.gmatch(val,"[^,]+") do
		table.insert(components,tonumber(s))
	end

	return Vector3.new(unpack(components))
end

function ToolsModule.MakeRandomColorRGBFormat()
	local color = BrickColor.Random()
	return {r=color.r, g=color.g, b=color.b}
end

--[[
	This allow to client to show or hide ui of game with one function
]]
function ToolsModule.EnableOtherUI(value, uiNotHide)
	--not work for competition parade place because this is a mini game need specific show ui management
	if game.PlaceId == EnvironmentModule.GetPlaceId("FashionShow") then
		return
	end

	-- Specific behavior for PositioningGui visibility
	task.spawn(function()
		-- Get autorisation positionning server for nice setup of PositionningGui
		local _, _, IsAutorisedPositionningServer, PrivateServerId = RemoteFunction.MapsManagerModule.GetInfosServer:InvokeServer()
		local ExistToPlace = table.find(RemoteFunction.MapsManagerModule.GetAuthorisedPositionningPlayers:InvokeServer(), game.Players.LocalPlayer.UserId)
		local IsOwnerServer = RemoteFunction.MapsManagerModule.GetOwnerServer:InvokeServer() == game.Players.LocalPlayer.UserId
		local IsPrivateServer = PrivateServerId ~= ""

		local gui = game.Players.LocalPlayer.PlayerGui.StarterGuiSync:FindFirstChild("PositionningGui")
	
		if gui.Name == "PositionningGui" then
			if IsPrivateServer then
				if IsOwnerServer then
					gui.Enabled = value
				elseif ExistToPlace or IsAutorisedPositionningServer then
					gui.Enabled = value
				end
			end
		end
	end)

	local guis = game.Players.LocalPlayer.PlayerGui:WaitForChild("StarterGuiSync")
	for _, gui in pairs(guis:GetChildren()) do
		if gui:IsA("ScreenGui") and gui.Name ~= "PopupAlertGui" and gui.Name ~= "FeedBackScreenGui" and gui.Name ~= "PlayerInfosGui" and gui.Name ~="PurchaseStoreGui" and gui.Name ~= "PositionningGui" and gui.Name ~= "FirstTimePlayedGui" and gui.Name ~= "MouseHover" and gui.Name ~= "DailyReward" then
			local exist = table.find(uiNotHide, gui.Name)
			if not exist then
				gui.Enabled = value
			end
		end
	end
end

function ToolsModule.EvalNumberSequence(sequence: NumberSequence, time: number)
    -- If time is 0 or 1, return the first or last value respectively
    if time == 0 then
        return sequence.Keypoints[1].Value
    elseif time == 1 then
        return sequence.Keypoints[#sequence.Keypoints].Value
    end

    -- Otherwise, step through each sequential pair of keypoints
    for i = 1, #sequence.Keypoints - 1 do
        local currKeypoint = sequence.Keypoints[i]
        local nextKeypoint = sequence.Keypoints[i + 1]
        if time >= currKeypoint.Time and time < nextKeypoint.Time then
            -- Calculate how far alpha lies between the points
            local alpha = (time - currKeypoint.Time) / (nextKeypoint.Time - currKeypoint.Time)
            -- Return the value between the points using alpha
            return currKeypoint.Value + (nextKeypoint.Value - currKeypoint.Value) * alpha
        end
    end
end

--Allow to rezise mesh link to bones
function ToolsModule.ScaleMesh(scaleVector3, meshPart)
	for _,descendant in pairs(meshPart:GetDescendants()) do
		if descendant:IsA("Bone") then
			local bone = descendant
			--move bone local translation to part space, scale xyz in part space, then move back to bone parent space
			local parentCFrame
			--parent can be either the MeshPart or another Bone
			if (bone.Parent:IsA("Bone")) then 
				parentCFrame = bone.Parent.WorldCFrame
			else
				parentCFrame = bone.Parent.CFrame
			end
			local parentInPartCFrame = meshPart.CFrame:Inverse() * parentCFrame
			--rotation only
			local parentInPartRotationCFrame = parentInPartCFrame - parentInPartCFrame.Position
			local pivotOffsetInPartSpace = parentInPartRotationCFrame * bone.Position 
			local scaledPivotOffsetInPartSpace = pivotOffsetInPartSpace * scaleVector3
			local partToParentRotationCFrame = parentInPartRotationCFrame:inverse()
			bone.Position = partToParentRotationCFrame * scaledPivotOffsetInPartSpace
		elseif descendant:IsA("Attachment") then
			--attachments are always directly parented to the MeshPart
			local attachment = descendant
			attachment.Position = attachment.Position * scaleVector3
		end
	end
	meshPart.Size = meshPart.Size * scaleVector3
end

-- Allow to Resize a model and keep the model proportion based on the WorldPivot.
function ToolsModule.ResizeModel(Model, Size)
	local DistanceTable = {}
	
	for _, part in pairs(Model:GetChildren()) do
		local distanceToPivot = part.Position - Model.WorldPivot.Position
		DistanceTable[part] = distanceToPivot
	end
	for _, part in pairs(Model:GetChildren()) do
		part.Size *= Size
		part.Position = Model.WorldPivot.Position + (DistanceTable[part] * Size)
	end
end

--[[
	Function tool allow to make all players and creature or added players or addeed creature invisible when player client enter in auction house or in
	fusion system. This allow to player don't see other if massivly player are connected.

	Function make a connection to childadded on player character and creature folder to make invisible if change are make during player client are
	in system.
	When leave system restore all visibility of players and creatures.
]]
local connexionInvisiblePlayer = nil
local connexionInvisibleCreature = nil
function ToolsModule.MakeOthersPlayersInvisible(isInvisible)
	if connexionInvisiblePlayer then
		connexionInvisiblePlayer:Disconnect()
	end

	if connexionInvisibleCreature then
		connexionInvisibleCreature:Disconnect()
	end

	local function PlayersInvisible(character, isInvisible)
		print("TEST PLAYER INVISIBLE",isInvisible)
		if character then
			--make humanoid character invisible and check accessory to make it too invisible
			for _, part in pairs(character:GetChildren()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					if isInvisible then
						part.Transparency = 1
					else
						part.Transparency = 0
					end
				end

				if part:IsA("Accessory") then
					if isInvisible then
						part.Handle.Transparency = 1
					else
						part.Handle.Transparency = 0
					end
				end

				if part.Name == "Head" then
					local face = part:FindFirstChild("face")
					if face then
						if isInvisible then
							face.Transparency = 1
						else
							face.Transparency = 0
						end
					end
				end
			end
		end
	end

	local function CreaturesInvisible(creature, isInvisible)
		creature:WaitForChild("CreatureID")
		if creature.CreatureID.Value ~= "" then
			local creatureData = RemoteFunction.GetDataOfPlayer:InvokeServer(game.Players[creature.Name:split("_")[2]], "CreaturesCollection."..creature.CreatureID.Value)
			print("TEST CREATURE DATA", creatureData.CreatureType)
			if creatureData then
				--Make creature invisible and check special part to not make bad transparency
				for _, part in pairs(creature:GetChildren()) do
					if part:IsA("MeshPart") and part.Name ~= "Seat" and part.Name ~= "Slipstream" and part.Name ~= "CollectablesDetector" then
						if isInvisible then
							part.Transparency = 1
						else
							if part.Name:match("Eye") then
								part.Transparency = 0.01
							elseif part.Name:match("Wing") then
								if creatureData.Race == "Celestial" then
									part.Transparency = 0.01
								else
									part.Transparency = 1
								end
							else
								part.Transparency = 0
							end
						end
					end
				end
			end
		end
	end

	for _, character in pairs(workspace.CharacterFolder:GetChildren()) do
		PlayersInvisible(character, isInvisible)
	end

	for _, creature in pairs(workspace.CreaturesFolder:GetChildren()) do
		if creature:IsA("Model") then
			CreaturesInvisible(creature, isInvisible)
		end
	end

	if isInvisible then
		connexionInvisiblePlayer = workspace.CharacterFolder.ChildAdded:Connect(function(child)
			PlayersInvisible(child, true)
		end)
		connexionInvisibleCreature = workspace.CreaturesFolder.ChildAdded:Connect(function(child)
			CreaturesInvisible(child, true)
		end)
	end
end


function ToolsModule.GetTimeDisplay(Time, In)
	local timing
	local Unit
	if In == "Hour" then
		if Time >= 1 then
			timing = Time
			Unit = "Hour"
		elseif Time * 60 <= 2 then
			timing = Time * math.pow(60,2)
			Unit = "Second"
		else
			timing = Time * 60
			Unit = "Minute"
		end
	elseif In == "Minute" then
		if Time >= 60 then
			timing = Time /60
			Unit = "Hour"
		elseif Time > 2 then
			timing = Time
			Unit = "Minute"
		else
			timing = Time * 60
			Unit = "Second"
		end
	elseif In == "Second" then
		if Time / 60 >= 60 then
			timing = Time / math.pow(60,2)
			Unit = "Hour"
		elseif Time > 60 * 2 then
			timing = Time / 60
			Unit = "Minute"
		else
			timing = Time
			Unit = "Second"
		end
	end
	return timing, Unit
end

function ToolsModule.ConvertSecToHour(seconds)
	local hourVal = seconds / 3600
	local hour, min = math.modf(hourVal)
	min *= 60
	local minRound, sec = math.modf(min)
	sec *= 60
	hour = hour <= 10 and ("0"..hour) or hour
	minRound = minRound <= 10 and ("0"..minRound) or minRound
	sec = sec <= 10 and ("0"..math.round(sec)) or math.round(sec)
	return hour, minRound, sec
end

--[[
    This function allow to make animation magnetize object when player passthrought of it
]]
function ToolsModule.MagnetizedObject(player, obj)
    local t = 0
    local currentDelta = RunService.Heartbeat:Wait()
    if obj then
        local StartCFrame = obj.CFrame
        while t < 1 do
            if obj.Parent and player.Character and player.Character.PrimaryPart then
                t += 0.035 * (currentDelta/(1/60))
                obj.CFrame = (StartCFrame:Lerp(player.Character.PrimaryPart.CFrame,TweenService:GetValue(t,Enum.EasingStyle.Quint,Enum.EasingDirection.In)))
                currentDelta = RunService.Heartbeat:Wait()
            else
                break
            end
        end
    end
end

--[[
    This function allow with TweenService to change size of object and active magnetize to anime recovery object by player and destroy it when animation is completed
]]
function ToolsModule.PlayCollectObject(player, obj)
	obj.CanCollide = false
    local tween
    local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false)
    local goal = {
        Size = Vector3.new(0,0,0)
    }

    tween = TweenService:Create(obj, tweenInfo, goal)
    tween:Play()
    ToolsModule.MagnetizedObject(player, obj)

    tween.Completed:Connect(function(playbackState)
        if playbackState == Enum.PlaybackState.Completed then
            obj:Destroy()
        end
    end)
end

--[[
	This method as the same behavior of server when want to evolve creature by race but in client side we have specifique access for show it on the UI and 3D local
	show model. So here we check race and change tail and mane of creature as on the server but for localplayer.

	!!This function need to be launch before apply material, color or other element on the part.!!
]]
function ToolsModule.CheckEvolutionPartCreatureToAttribute(CreatureModel, data)
	local CreaturesModularPartsFolder = ReplicatedStorage.Assets.CreaturesModularParts
	--Check for Race Tail
	local TailEvolve = CreaturesModularPartsFolder[data["CreatureType"]].Tail[data["Race"]]:Clone()
	TailEvolve.Parent = CreatureModel

	CreatureModel.Tail.Motor6D.Parent = TailEvolve
	TailEvolve.Motor6D.Part1 = TailEvolve
	
	CreatureModel.Tail:Destroy()
	TailEvolve.Name = "Tail"

	--Check for Race Mane
	local ManeEvolve = CreaturesModularPartsFolder[data["CreatureType"]].Mane[data["Race"]]:Clone()
	ManeEvolve.Parent = CreatureModel

	CreatureModel.Mane.Motor6D.Parent = ManeEvolve
	ManeEvolve.Motor6D.Part1 = ManeEvolve
	
	CreatureModel.Mane:Destroy()
	ManeEvolve.Name = "Mane"
end

--[[
	This is a function refactor to create a Model of Creature data given. Actually used to show in Viewport in list of Creatures Collection or for show
	the specific creature need by client from breeding or favoris for example.
	The model are clone from creature type found in data of creature and make apply evolution and genes data to model and make it parent viewport if given.
	If Viewport not given, the function return model and set parent where we need to show model creature.
]]
function ToolsModule.MakeCreatureModelForRender(data, AvailableGenesCollection, ViewportFrame)
	local CreatureModel:Model = ReplicatedStorage.Assets.CreaturesModels[data["CreatureType"].."ModelFusion"]:Clone()
	CreatureModel.Name = data["CreatureType"].."Model"
	
	--if viewport its to show in list creatures collection
	if ViewportFrame then
		CreatureModel.Parent = ViewportFrame.WorldModel
		local camera = Instance.new("Camera")
		local target = CreatureModel.PrimaryPart

		local creatureRotate = data["CreatureType"] == "Cat" and 45 or 25

		CreatureModel:PivotTo(target.CFrame*CFrame.Angles(0,math.rad(creatureRotate),0))
		ViewportFrame.CurrentCamera = camera
		camera.Parent = ViewportFrame
		camera.CameraType = Enum.CameraType.Scriptable
		camera.MaxAxisFieldOfView = 50

		local yOffset = data["CreatureType"] == "Cat" and 1.25 or 2
		local zOffset = data["CreatureType"] == "Cat" and -2.5 or -2
		local xOffset = data["CreatureType"] == "Cat" and -7.7 or -6.7

		local cameraOffset = Vector3.new(xOffset,yOffset, zOffset)
		camera.Focus = target.CFrame
		local rotatedCFrame = CFrame.Angles(0, math.rad(-90), 0)
		rotatedCFrame = CFrame.new(target.Position) * rotatedCFrame
		camera.CFrame = CFrame.new(cameraOffset) * rotatedCFrame--rotatedCFrame:ToWorldSpace(CFrame.new(cameraOffset))
	end

	--check here evolution modular parts
	ToolsModule.CheckEvolutionPartCreatureToAttribute(CreatureModel, data)

	-- Check all register accessory on this creature and setup them
	if data["Accessory"] then
		for _, accessoryID in pairs(data.Accessory) do
			ToolsModule.CreateAccessoryClientSide(accessoryID, data.CreatureType, CreatureModel)
		end
	end

	--remove shadow for render model in collections detail
	for _, child in pairs(CreatureModel:GetChildren()) do
		if child:IsA("BasePart") then
			child.CastShadow = false
		end
	end
	
	-- Setup size model depending of is Growth
	if data.Growth == "Baby" then
		--CreatureModel:ScaleTo(0.5)
		for _, child in pairs(CreatureModel:GetChildren()) do
			if child:IsA("BasePart") then
				ToolsModule.ScaleMesh(Vector3.new(0.5,0.5,0.5), child)
			end
		end
		CreatureModel.Tetine.Transparency = 0
	end

	--Check type of gene for display this type and name and if no gene display, juste type of gene emplacement is show
	for geneType, geneID in pairs(data.Genes) do
		local founded = false
		for _, child in pairs(CreatureModel:GetChildren()) do
			if child:IsA("BasePart") then
				if string.lower(child.Name):match(string.lower(geneType)) then
					if AvailableGenesCollection[geneID] then
						child.TextureID = AvailableGenesCollection[geneID]["TextureID"]

						if string.lower(child.Name):match(string.lower("Accessory")) or string.lower(child.Name):match(string.lower("Eye")) then
							child.Transparency = 0.01
						else
							child.Transparency = 0
						end

						--Check if its mesh part if texture gene to apply have a surface appereance or not
						--Make this behavior into spawn function reduce 95% latence of show in UI
						if child:IsA("MeshPart") then
							task.spawn(function()
								local exist = RemoteFunction.SearchSurfaceForFusion:InvokeServer(geneID)
								if exist then
									--if yes destroy the actuel and replace by another
									local t = child:FindFirstChildOfClass("SurfaceAppearance")
									if t then
										t:Destroy()
									end
									local clone = exist:Clone()
									clone.Parent = child
								else
									--if not destroy it
									local t = child:FindFirstChildOfClass("SurfaceAppearance")
									if t then
										t:Destroy()
									end
								end
							end)
						end
						founded = true
					end
				end
			end
		end
		if not founded then
			for _, child in pairs(CreatureModel:GetDescendants()) do
				if child:IsA("Texture") then
					if string.lower(child.Name):match(string.lower(geneType)) then
						if AvailableGenesCollection[geneID] then
							child.Texture = AvailableGenesCollection[geneID]["TextureID"]
							child.Transparency = 0
							founded = true
						end
					end
				end
			end
		end
	end

	if data.Race == "Celestial" then
		CreatureModel["Wing_Left"].Transparency = 0.01
		CreatureModel["Wing_Right"].Transparency = 0.01
		CreatureModel["Wing_Left"].TextureID = data.Genes["Wing"]
		CreatureModel["Wing_Right"].TextureID = data.Genes["Wing"]
	else
		CreatureModel["Wing_Left"].Transparency = 1
		CreatureModel["Wing_Right"].Transparency = 1
	end

	--allow to update color and material of horse part horse
	for _, child in pairs(CreatureModel:GetChildren()) do
		--print("SEE TYPE GENE NAME",string.lower(item.Name))
		if string.lower(child.Name):match("mane") then
			local t = data["ManeColor"]
			child.Color = Color3.new(t.r, t.g, t.b)
			child.Material = data["PartsMaterial"].Mane
		elseif string.lower(child.Name):match("marking") then
			local t = data["Color"]
			child.Color = Color3.new(t.r, t.g, t.b)
			child.Material = data["PartsMaterial"].Marking
		elseif string.lower(child.Name):match("tail") then
			local t = data["TailColor"]
			child.Color = Color3.new(t.r, t.g, t.b)
			child.Material = data["PartsMaterial"].Tail
		elseif string.lower(child.Name):match("socks") then
			local t = data["SocksColor"]
			child.Color = Color3.new(t.r, t.g, t.b)
			child.Material = data["PartsMaterial"].Socks
		end
	end

	return CreatureModel
end

function ToolsModule.GetSizeObjectOnGoodAxis(object, face)
	local isModel = object.Parent ~= workspace and object.Parent:IsA("Model")
	local sizeOnAxis
	-- allow to found the good size depending of face pull by player for cframe calculation
	if face == Enum.NormalId.Left or face == Enum.NormalId.Right then
		-- axe horizontal
		if isModel then
			local orientation, size = object.Parent:GetBoundingBox()
			sizeOnAxis = size.X
		else
			sizeOnAxis = object.Size.X
		end
	elseif face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
		-- axe vertical
		if isModel then
			local orientation, size = object.Parent:GetBoundingBox()
			sizeOnAxis = size.Y
		else
			sizeOnAxis = object.Size.Y
		end
	else
		-- axe perpendiculaire
		if isModel then
			local orientation, size = object.Parent:GetBoundingBox()
			sizeOnAxis = size.Z
		else
			sizeOnAxis = object.Size.Z
		end
	end

	return sizeOnAxis
end

--[[
	This function allow to return opposite face normalID string of face receive
]]
function ToolsModule.OppositeNormalIdString(normalIdString)
    local oppositeDirections = {
        Left = "Right",
        Right = "Left",
        Top = "Bottom",
        Bottom = "Top",
        Back = "Front",
        Front = "Back"
    }
    return oppositeDirections[normalIdString]
end

--[[
	This little function allow to open Ecus Gui purchase
	Used when player try to pruchase and server detect player not have enought golds
]]
function ToolsModule.OpenEcusGui(player)
	local PlayerGui = player:WaitForChild("PlayerGui")
	local PurchaseStoreGui = PlayerGui.StarterGuiSync:WaitForChild("PurchaseStoreGui")
	PurchaseStoreGui.Enabled = true
	PurchaseStoreGui.EcusBackground.Visible = false
	task.wait()
	PurchaseStoreGui.EcusBackground.Visible = true
end

--[[
	Function to generate random animals name with GameData list of animals name we have setup
]]
function ToolsModule.GenerateRandomName()
	local listName = GameDataModule.AnimalsNameList
	local selected = math.random(1, #listName)

	return listName[selected]
end

--[[
	Call only on Server Side to setup the Billboard GUI Ove Head players to show their name and TAG like VIP
]]
function ToolsModule.CreateOverHeadGuiName(player)
	local character = player.Character

	if character.Head:FindFirstChild("NameGUI") then
		character.Head.NameGUI:Destroy()
	end

	local uiName:BillboardGui = ReplicatedStorage.Assets.NameGUI:Clone()
	uiName.Parent = character.Head
	uiName.PlayerToHideFrom = player

	-- Setup showing Name text with Tag (VIP exemple)
	local text
	if player:GetRankInGroup(12349377) >= 128 then
		local tagcolor:Color3 = GameDataModule.TagsData.ADMIN[1].TagColor
		text = "<font color=\"rgb("..math.floor(tagcolor.R*255)..","..math.floor(tagcolor.G*255)..","..math.floor(tagcolor.B*255)..")\"> ["..GameDataModule.TagsData.ADMIN[1].TagText.."] "..player.Name.."</font>"
	
	elseif BindableFunction.CheckPlayerHasGamepass:Invoke(player, GameDataModule.Gamepasses.VIP.ProductID) then
		local tagcolor:Color3 = GameDataModule.TagsData.VIP[1].TagColor
		text = "<font color=\"rgb("..math.floor(tagcolor.R*255)..","..math.floor(tagcolor.G*255)..","..math.floor(tagcolor.B*255)..")\"> ["..GameDataModule.TagsData.VIP[1].TagText.."] "..player.Name.."</font>"
	else
		text = player.Name
	end

	uiName.name.Text = text
end

--[[
	Only Client Side
	This function allow to create the visual accessory to render it in client side for preview animals and link to the animal for match
	with animation.
	If isPreview player can do not have it accessory in this inventory because he want to preview from shop, so is isPreview we need to get the model clone
	from server side.
]]
function ToolsModule.CreateAccessoryClientSide(accessoryID, creatureType, CreatureModel:Model, isPreview:boolean)
	if RunService:IsClient() then
		local inventoryPlayer = game.Players.LocalPlayer.Backpack
		local accessory = inventoryPlayer:FindFirstChild(accessoryID)

		--[[
			If isPreview create accessory is for preview visual model on animal and not setup a accessory equipped on animal by player
			so only server have model so we send function server to ask him clone and put in backpack player
			the model, client clone it and send server clone is ok to destroy on server side.
		]]
		if isPreview then
			local clone = RemoteFunction.CloneAccessoryForPreview:InvokeServer(accessoryID, false)
			if clone then
				accessory = clone:Clone()
				RemoteFunction.CloneAccessoryForPreview:InvokeServer(accessoryID, true)
			end
		end

		if accessory then
			if accessory:FindFirstChild("MultipleAccessory") then
				-- If we found this folder it's special accessory need to be multiple clone of it (example feet accessory need on 4 feet)
				local FolderMultipleAccessory = Instance.new("Folder", CreatureModel)
				FolderMultipleAccessory.Name = accessoryID
	
				for _, part in pairs(accessory.MultipleAccessory:GetChildren()) do
	
					local clone:MeshPart = accessory:Clone()
					clone.Parent = FolderMultipleAccessory
				
					local attachment:Attachment = Instance.new("Attachment", clone)
					local constraint:RigidConstraint = Instance.new("RigidConstraint", clone)
					constraint.Attachment0 = attachment
			
					-- Search bone reference instance
					for _, bone in pairs(CreatureModel.RootPart:GetDescendants()) do
						if bone:IsA("Bone") then
							if bone.Name == part[creatureType].BoneNameRef.Value then
								constraint.Attachment1 = bone
							end
						end
					end
			
					-- Apply reference position, orientation & size
					clone.Size = part[creatureType].Size.Value
					local rotX = math.rad(part[creatureType].Orientation.Value.X)
					local rotY = math.rad(part[creatureType].Orientation.Value.Y)
					local rotZ = math.rad(part[creatureType].Orientation.Value.Z)
					attachment.CFrame = CFrame.new(part[creatureType].Position.Value) * CFrame.fromOrientation(rotX,rotY,rotZ)
					
					-- Check if actual animal have a size effect active or not to apply the good size ratio
					if CreatureModel.PrimaryPart:GetAttribute("SizeEffectActive") then
						local SizeRatio = CreatureModel.PrimaryPart:GetAttribute("SizeRatio")
						ToolsModule.ScaleMesh(Vector3.new(SizeRatio,SizeRatio,SizeRatio), clone)
					else
						local SizeRatio = CreatureModel:GetScale()
						ToolsModule.ScaleMesh(Vector3.new(SizeRatio,SizeRatio,SizeRatio), clone)
					end
				end
			else
				local clone:MeshPart = accessory:Clone()
				clone.Parent = CreatureModel

				local attachment:Attachment = Instance.new("Attachment", clone)
				local constraint:RigidConstraint = Instance.new("RigidConstraint", clone)
				constraint.Attachment0 = attachment
			
				-- Search bone reference instance
				for _, bone in pairs(CreatureModel.RootPart:GetDescendants()) do
					if bone:IsA("Bone") then
						if bone.Name == clone[creatureType].BoneNameRef.Value then
							constraint.Attachment1 = bone
						end
					end
				end
			
				-- Apply reference position, orientation & size
				clone.Size = clone[creatureType].Size.Value
				local rotX = math.rad(clone[creatureType].Orientation.Value.X)
				local rotY = math.rad(clone[creatureType].Orientation.Value.Y)
				local rotZ = math.rad(clone[creatureType].Orientation.Value.Z)
				attachment.CFrame = CFrame.new(clone[creatureType].Position.Value) * CFrame.fromOrientation(rotX,rotY,rotZ)
				
				-- Check if actual animal have a size effect active or not to apply the good size ratio
				if CreatureModel.PrimaryPart:GetAttribute("SizeEffectActive") then
					local SizeRatio = CreatureModel.PrimaryPart:GetAttribute("SizeRatio")
					ToolsModule.ScaleMesh(Vector3.new(SizeRatio,SizeRatio,SizeRatio), clone)
				else
					local SizeRatio = CreatureModel:GetScale()
					ToolsModule.ScaleMesh(Vector3.new(SizeRatio,SizeRatio,SizeRatio), clone)
				end
			end

			if isPreview then
				accessory:Destroy()
			end
		else
			warn("Accessory"..accessoryID.."not found in player inventory!")
		end
	else
		warn("This function can only call on Client Side")
	end
end

return ToolsModule
