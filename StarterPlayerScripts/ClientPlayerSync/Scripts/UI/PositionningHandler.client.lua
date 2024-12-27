local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))

local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local PhysicsService = game:GetService("PhysicsService")
local player = game:GetService("Players").LocalPlayer

--Require
local UIProviderModule = require("UIProviderModule")
local LocalBuildingModule = require("LocalBuildingModule")
local ToolsModule = require("ToolsModule")
local GameDataModule = require("GameDataModule")
local EnvironmentModule = require("EnvironmentModule")

--Filters
local ObjectsFilters = {"Nature","Decoration","RaceObject", "Primitive", "Wall", "Scripted", "Lighting"}

local remoteFunctions = ReplicatedStorage.RemoteFunction
local RF_GetRaces = remoteFunctions.GetRaces
local RF_SetRace = remoteFunctions.SetRace


local GetRemoteEvent = require("GetRemoteEvent")
local RaceDataEvent
--Don"t setup race function if its competition parade server
if game.PlaceId ~= EnvironmentModule.GetPlaceId("FashionShow") then
	RaceDataEvent = GetRemoteEvent("RaceDataEvent")
end

local PositionningEvent = ReplicatedStorage.PositionningEvent
local PositionningObjectEvent = PositionningEvent:WaitForChild("PositionningObject")
local PositionningObjects = ReplicatedStorage:WaitForChild("PositionningObjects")
local positionning
local remoteFunctions = ReplicatedStorage.RemoteFunction
local RemoteEvent = ReplicatedStorage.RemoteEvent

--UI
local PositionningGui = UIProviderModule:GetUI("PositionningGui")
local BuildToolBoxUI = PositionningGui:WaitForChild("BuildToolBox")
local Background = PositionningGui:WaitForChild("Background")
local ListObjectsUI = Background.PositionningObjects
local ToolBarUI = PositionningGui.ToolBar
local Template = PositionningGui.Template
local lastVisibleBackround = false

--Character:Wait() not work because he not found Character.. so wait Character not nil to load script
repeat task.wait() until player.Character
local HumanoidRootPart = player.Character:WaitForChild("HumanoidRootPart")

local mouse = player:GetMouse()

local yBuildingOffset = 2.5
local maxPlacingDistance = 200

local rKeyIsPressed = false
local placingObject = false
local yOrientation=0
local zOrientation=0
local goodTOPlace = false
local renderSteppedConnexion
local placedObject
local clientObject
local lastHit

local PositionningObjectsList = PositionningObjects:GetChildren()
local indexSelector = 1
local objSelector = PositionningObjectsList[1]

local isActiveBuildingTool = false
local partBuildingTool = nil
--[[ local handlesList = {
	BuildToolBoxUI.HandlesPos.Name,
	BuildToolBoxUI.HandlesSize.Name,
	BuildToolBoxUI.ArcHandles.Name
} ]]
local currentHandleSelected = PositionningGui:WaitForChild("HandlesPos")
local nextHandleSelected = 1
local surfaceSelectionHandle = BuildToolBoxUI:WaitForChild("SurfaceSelection")
local selectionBoxPreview = BuildToolBoxUI:WaitForChild("SelectionBox")

--for save if player can place object or not and improve speed of placement to not check every moment where player need place or get object
local PlayerCanPlace = false

local AxisPositioningMultipliers = {
	[Enum.NormalId.Top] = Vector3.new(0, 1, 0);
	[Enum.NormalId.Bottom] = Vector3.new(0, -1, 0);
	[Enum.NormalId.Front] = Vector3.new(0, 0, -1);
	[Enum.NormalId.Back] = Vector3.new(0, 0, 1);
	[Enum.NormalId.Left] = Vector3.new(-1, 0, 0);
	[Enum.NormalId.Right] = Vector3.new(1, 0, 0);
}

function RotateY(actionName, userInputState, input)
	if (userInputState == Enum.UserInputState.Begin) then
		yOrientation = yOrientation + 45
	end
end

function RotateZ(actionName, userInputState, input)
	if (userInputState == Enum.UserInputState.Begin) then
		zOrientation = zOrientation + 45
	end
end

function DisableHandles()
	LocalBuildingModule.DisableActifHandles()
	isActiveBuildingTool = false
end

function FreeModellerOwnerBuildingTool()
	LocalBuildingModule.SetAnchorHandlesAdornee(LocalBuildingModule.GetAnchoredOption())
	DisableHandles()
	if partBuildingTool then
		PositionningEvent.ModellerObject:InvokeServer(partBuildingTool, true)
	end
	partBuildingTool = nil
	UnbindPlayerActionBuildingTool()
end

--[[
	This little local function allow to return the normal id
	with the normal vector given in parameter.
]]
local function normalIdFromVector(part, vector)
	local epsilon = 0.001
	for _, normalId in pairs(Enum.NormalId:GetEnumItems()) do
		if part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(normalId)):Dot(vector) > 1 - epsilon then
			--print("FACE IS",normalId)
			return normalId
		end
	end
end

--[[
	This local function allow to check if face object are same size depending of normalID give in parameter
	and return result
]]
local function CheckSameSizeOnAxis(obj1, obj2, face)
	if face == Enum.NormalId.Front or face == Enum.NormalId.Back then
		if obj1.Size.X == obj2.Size.X and obj1.Size.Y == obj2.Size.Y then
			return true
		else
			return false
		end
	elseif face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
		if obj1.Size.X == obj2.Size.X and obj1.Size.Z == obj2.Size.Z then
			return true
		else
			return false
		end
	else
		if obj1.Size.Y == obj2.Size.Y and obj1.Size.Y == obj2.Size.Y then
			return true
		else
			return false
		end
	end
end

--[[Allow to select the next handle in the table of handles available to use
function SelectNextHandles()
	local value
	--check the next item
	nextHandleSelected, value = next(handlesList, nextHandleSelected)
	--if nil it's the end of table, so reset to the first item
	if not nextHandleSelected then
		nextHandleSelected, value = next(handlesList)
	end
	--get the next item and init value for use
	currentHandleSelected = script.Parent:FindFirstChild(value)
end]]

--This little method allow to make certain change recursive on all childs of model when placing object
function RecursiveChangeChildren(objectToChangeChild, isValid)
	for _, obj in pairs(objectToChangeChild:GetChildren()) do
		if obj:IsA("Part") or obj:IsA("MeshPart") then
			obj.Transparency = 0.5
			--obj.CanCollide = false
			if isValid then
				obj.BrickColor = BrickColor.new("Bright green")
			else
				obj.BrickColor = BrickColor.new("Crimson")
			end
		else
			RecursiveChangeChildren(obj, isValid)
		end
	end
end

--[[
	This little function return the half size of clientObject selected for placement. Check if it a model
	or a primary part to get the good half size to make a properly placement calcule when try to
	calculate CFrame Position
]]
function GetHalfSizeYModel(model)
	if model then
		if model:IsA("Model") then
			model = model.PrimaryPart
		end
		
		--[[ if model.Orientation.Z ~= 0 and model.Orientation.Z ~= -180 and model.Orientation.Z ~= 180 then
			if model.Size.Z >= model.Size.Y then
				if model.Size.Z < model.Size.X then
					return math.floor(model.Size.Z)+IsEven(model, "Z")
				else
					return math.floor(model.Size.X/2)+IsEven(model, "X")
				end
			end
		end
		
		return math.floor(model.Size.Y/2)+IsEven(model, "Y") ]]

		return model.Size.Y/2
	end
end

--[[
	This little function allow to check if size of object is Even or not to set properly the cframe pos
	taking into account the size of the object.
]]
function IsEven(model, axis)
	if model:IsA("Model") then
		model = model.PrimaryPart
	end
	if model.Size[axis]%2 == 0 then
		return 0
	else
		return 0.5
	end
end

--[[
	Calcule CFrame position rotation where are the object.
	This method implement multiple calcule of CFrame depending if grid activated or if it's a snapped
	object.
	Snapped object can only the same between the hit object and clientObject positionning
]]
function CalculateCFramePosition(position, hit, normal)
	if hit or position then
		local gridActivated, gridSize = LocalBuildingModule.GetGrid()
		local newAnglesCFrame = CFrame.fromEulerAnglesYXZ(
			0,
			math.rad(yOrientation),
			math.rad(zOrientation)
		)
		
		--check if grid is activate or not for determine the position vector object
		local vectorPos
		if gridActivated then
			vectorPos = Vector3.new(
				math.floor(position.X / gridSize) * gridSize + IsEven(clientObject, "X"),
				position.Y + GetHalfSizeYModel(clientObject)--[[math.floor(GetHalfSizeYModel(clientObject)) + IsEven(clientObject, "Y")]],
				math.floor(position.Z / gridSize) * gridSize + IsEven(clientObject, "Z")
			)
		else
			vectorPos = Vector3.new(
				position.X,
				position.Y + GetHalfSizeYModel(clientObject) --[[math.floor(GetHalfSizeYModel(clientObject))+ IsEven(clientObject, "Y")]],
				position.Z
			)
		end

		-- Check if clientObject player want place is a model and if target is model
		local isModel = clientObject:IsA("Model")
		local targetIsModel = hit.Parent ~= workspace and hit.Parent:IsA("Model")
		local target = targetIsModel and hit.Parent or hit
		hit = targetIsModel and target.PrimaryPart or target

		-- Use function to return the normal id from the normal vector give by raycast
		local normalId = normalIdFromVector(hit, normal)

		-- if we check snapping objects
		-- else we use the classic positionning with ground
		if target:GetAttribute("ObjectType") and target.Name == clientObject.Name and CheckSameSizeOnAxis(hit, isModel and clientObject.PrimaryPart or clientObject, normalId) then
			--pcall here to ignore error of arithmetic (when we have complex mesh part)
			pcall(function()
				--Make a cframe snaped who take the hit object ref to calculate this cframe position
				if clientObject:IsA("Model") then
					clientObject:SetPrimaryPartCFrame(hit.CFrame + hit.CFrame:VectorToWorldSpace(hit.Size*AxisPositioningMultipliers[normalId]))
				else
					clientObject.CFrame = hit.CFrame + hit.CFrame:VectorToWorldSpace(hit.Size*AxisPositioningMultipliers[normalId])
				end
			end)

			if normalId then
				--it's a snapping object so we use surface selection for show were is the snapping surface
				surfaceSelectionHandle.TargetSurface = normalId
				surfaceSelectionHandle.Adornee = hit
			end

			--WARN ! This commented part are make in pause for snapping all objects, look here if need to improve snapping between all objects type
			-- If objects are different we make a snapping (IN PROGRESS) for differents parts
			-- pcall here to ignore error of arithmetic (when we have complex mesh part)
			--[[ pcall(function()
				local sizeOnAxisClient = ToolsModule.GetSizeObjectOnGoodAxis(isModel and clientObject.PrimaryPart or clientObject, normalId)
				local offset = AxisPositioningMultipliers[normalId] * (sizeOnAxisClient/2)
				local fitX = 1--math.floor(clientObject.Size.X/2)
				local fitY = 1--math.floor(clientObject.Size.Y/2)
				local fitZ = 1--math.floor(clientObject.Size.Z/2)

				local newPos
				if normalId == Enum.NormalId.Front or normalId == Enum.NormalId.Back then
					newPos = Vector3.new(
						math.floor(position.X / fitX) * fitX + IsEven(clientObject, "X"),
						math.floor(position.Y / fitY) * fitY + IsEven(clientObject, "Y"),
						position.Z
					)
				elseif normalId == Enum.NormalId.Top or normalId == Enum.NormalId.Bottom then
					newPos = Vector3.new(
						math.floor(position.X / fitX) * fitX + IsEven(clientObject, "X"),
						position.Y,
						math.floor(position.Z / fitZ) * fitZ + IsEven(clientObject, "Z")
					)
				else
					newPos = Vector3.new(
						position.X,
						math.floor(position.Y / fitY) * fitY + IsEven(clientObject, "Y"),
						math.floor(position.Z / fitZ) * fitZ + IsEven(clientObject, "Z")
					)
				end
	
				-- Make a cframe snaped who take the hit object ref to calculate this cframe position
				if clientObject:IsA("Model") then
					--clientObject:PivotTo(hit.CFrame + hit.CFrame:VectorToWorldSpace(hit.Size*AxisPositioningMultipliers[normalId]))
					clientObject:PivotTo(CFrame.new(newPos) * CFrame.new(offset) * hit.CFrame.Rotation)
				else
					--clientObject.CFrame = CFrame.new(newPos) * hit.CFrame.Rotation * clientObject.CFrame:ToWorldSpace(CFrame.new(offset))
					clientObject.CFrame = CFrame.new(newPos) * hit.CFrame.Rotation
					clientObject.CFrame = clientObject.CFrame:ToWorldSpace(CFrame.new(offset))
				end
			end)
			
			if normalId then
				-- Get the opposite NormalId
				local oppositeNormalId = Enum.NormalId[ToolsModule.OppositeNormalIdString(normalId.Name)]

				-- It's a snapping object so we use surface selection for show were is the snapping surface
				surfaceSelectionHandle.TargetSurface = oppositeNormalId
				surfaceSelectionHandle.Adornee = isModel and clientObject.PrimaryPart or clientObject
			end ]]
		else
			-- Make a cframe with position vector calculate before
			if isModel then
				clientObject:SetPrimaryPartCFrame(CFrame.new(vectorPos) * newAnglesCFrame)
			else
				clientObject.CFrame = CFrame.new(vectorPos) * newAnglesCFrame
			end

			surfaceSelectionHandle.Adornee = nil
		end
	else
		surfaceSelectionHandle.Adornee = nil
	end
end

function RayCastMouseHit()
	-- Build a "RaycastParams" object
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {clientObject, player.Character}
	raycastParams.IgnoreWater = true
	--Make in Collision Groups Editor the IgnorePlacementObjects and add object you want to ignore with "+"
	raycastParams.CollisionGroup = "IgnorePlacementObjects"

	-- Cast the ray
	local mouseRay = mouse.UnitRay
	local raycastResult = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 1000, raycastParams)
	-- Interpret the result
	if raycastResult then
		return raycastResult.Instance, raycastResult.Position, raycastResult.Normal
	end
end

-- Handles construction of actual Brick when user is satisfied with placement/rotation
function PlaceObjectSelected(actionName, userInputState, input)
	local part
	if (userInputState == Enum.UserInputState.Begin) then
		if placingObject ==  true then
			if goodTOPlace == true then
				if actionName ~= "duplicator" then
					if renderSteppedConnexion then
						renderSteppedConnexion:Disconnect()
					end
					UnbindPlayerAction()
				end
				
				local hit, position, normal = RayCastMouseHit()
				CalculateCFramePosition(position, hit, normal)
				if actionName == "duplicator" then
					BuildToolBoxUI.Duplicator.PanelLight.ImageColor3 = Color3.fromRGB(0,255,0)
					if clientObject.Name == "Start" then
						return
					end
				end
				if clientObject:IsA("Model") then
					placedObject, part = PositionningObjectEvent:InvokeServer(
						clientObject.Name,
						clientObject.PrimaryPart.CFrame,
						clientObject.PrimaryPart.Size,
						LocalBuildingModule.GetAnchoredOption(),
						false
					)
				else
					placedObject, part = PositionningObjectEvent:InvokeServer(
						clientObject.Name,
						clientObject.CFrame,
						clientObject.Size,
						LocalBuildingModule.GetAnchoredOption(),
						false,
						clientObject:GetAttribute("RaceCreator"),
						clientObject:GetAttribute("RaceLink")
					)
				end

				if placedObject == true and part and actionName ~= "duplicator" then
					surfaceSelectionHandle.Adornee = nil
					placingObject = false
					clientObject:Destroy()
					task.wait(0.05)
					if lastVisibleBackround then
						Background.Visible = true
					end
					BuildToolBoxUI.Catch.PanelLight.ImageColor3 = Color3.fromRGB(255, 241, 208)
				elseif not placedObject and actionName ~= "duplicator" then
					surfaceSelectionHandle.Adornee = nil
					placingObject = false
					clientObject:Destroy()
					task.wait(0.05)
					if lastVisibleBackround then
						Background.Visible = true
					end
					BuildToolBoxUI.Catch.PanelLight.ImageColor3 = Color3.fromRGB(255, 241, 208)
				elseif placedObject and actionName == "duplicator" then
					BuildToolBoxUI.Duplicator.PanelLight.ImageColor3 =  Color3.fromRGB(255, 241, 208)
				end
			end
		end
	end
end

function CatchObject(actionName, userInputState, input)
	--check if player can place object or not
	if not PlayerCanPlace or isActiveBuildingTool then
		return
	end
	if userInputState == Enum.UserInputState.Begin then
		if placingObject or actionName ~= "catch" then
			return
		end
		BindPlayerAction()
		local hit, position = RayCastMouseHit()
		if not hit or (HumanoidRootPart.Position - hit.Position).Magnitude >= maxPlacingDistance then
			return
		end
		local exist = FoundItem(hit)
		if not exist then
			warn("Can't catch nothing")
			UnbindPlayerAction()
			return
		end
		local hitter = nil
		if hit:GetAttribute("Modeller") then
			hitter = hit
		elseif hit.Parent:GetAttribute("Modeller") then
			hitter = hit.Parent
		end
		if not hitter then
			warn("Can't catch nothing")
			UnbindPlayerAction()
			return
		end
		
		if hitter:GetAttribute("Modeller") then
			if hitter:GetAttribute("Modeller") ~= 0 then
				if hitter:GetAttribute("Modeller") ~= player.UserId then
					warn("One player are already modify this object")
					UnbindPlayerAction()
					return
				end
			end
		end

		--If player not owner, other player can't interact with inventory object type
		if player.UserId ~= remoteFunctions.MapsManagerModule.GetOwnerServer:InvokeServer() then
			if hitter:GetAttribute("Modeller") and hitter:GetAttribute("ObjectType") and hitter:GetAttribute("StockQuantity") then
				UnbindPlayerAction()
				return
			elseif hitter:GetAttribute("Modeller") and not hitter:GetAttribute("ObjectType") then
				UnbindPlayerAction()
				return
			end
		end
		
		--For race system, if player try catch a start object and its not the owner, it's not autorized, so return
		if hit.Name == "Start" then
			warn("You can't catch a Start Race Object !")
			UnbindPlayerAction()
			return
		end

		if hit.Name == exist.Name then
			DisableHandles()
			handleBrickButtonPressed(hit.Name, hit)
			PositionningObjectEvent:InvokeServer(nil, nil, nil, nil, hit)--this call is for destroy hit object
		elseif hit.Parent.Name == exist.Name then
			DisableHandles()
			handleBrickButtonPressed(hit.Parent.Name, hit.Parent)
			PositionningObjectEvent:InvokeServer(nil, nil, nil, nil, hit.Parent)--this call is for destroy hit object
		end

	--When wheel is scrolled catch event and chekc its selector actio name called
	elseif userInputState == Enum.UserInputState.Change then
		if actionName == "selector" then
			--if the object selected by player is RaceObject not continue fcuntion and don't make a scroll
			if clientObject:GetAttribute("ObjectType") == "RaceObject" then
				return
			end
			local scrollDir = input.Position.Z > 0 and "UP" or "DOWN"

			--Make the authorized list of object in scroll list (remove the race object)
			local listObject = PositionningObjectsList
			for _, obj in pairs(listObject) do
				if obj:GetAttribute("ObjectType") == "RaceObject" then
					table.remove(listObject, _)
				end
			end

			--for boucle selector
			--indexSelector = (indexSelector >= #PositionningObjectsList) and 1 or (indexSelector + 1)
			
			--check if up or down for up or down the number selector object of list
			if scrollDir == "UP" then
				if indexSelector ~= 1 then
					indexSelector -= 1
				end
			else
				if indexSelector < #listObject  then
					indexSelector += 1
				end
			end
			
			--define the object selected whith scroll wheel by indexSelector of list object
			objSelector = listObject[indexSelector]
			
			--check actual client object selected is not the same as obj scroll selected
			if clientObject.Name ~= objSelector.Name then
				--make all for disable and destroy the actual object previous by the new selected obj
				DisableHandles()
				placingObject = false
				clientObject:Destroy()
				if renderSteppedConnexion then
					renderSteppedConnexion:Disconnect()
				end
				
				--launch the function to show the new obj preview selected in scroll
				handleBrickButtonPressed(objSelector.Name, objSelector)
			end
		end
	end
end

function CancelPositionning(actionName, userInputState, input)
	if (userInputState == Enum.UserInputState.Begin) then
		print("CANCEL")
		placingObject = false
		if clientObject then
			clientObject:Destroy()
		end
		--Background.Visible = true
		BuildToolBoxUI.Catch.PanelLight.ImageColor3 = Color3.fromRGB(255, 241, 208)
		if renderSteppedConnexion then
			renderSteppedConnexion:Disconnect()
		end
		UnbindPlayerAction()
	end
end

function SetGridButton(actionName, userInputState, input)
	if (userInputState == Enum.UserInputState.Begin) then
		if actionName == "setGrid" then
			LocalBuildingModule.SetGrid(not LocalBuildingModule.GetGrid())
			if LocalBuildingModule.GetGrid() then
				BuildToolBoxUI.Grid.PanelLight.ImageColor3 = Color3.fromRGB(0, 255, 0)
			else
				BuildToolBoxUI.Grid.PanelLight.ImageColor3 = Color3.fromRGB(255, 0, 0)
			end
		end
	end
end

function SetAnchorButton(actionName, userInputState, input)
	if (userInputState == Enum.UserInputState.Begin) then
		if actionName == "setAnchor" then
			LocalBuildingModule.SetAnchoredOption(not LocalBuildingModule.GetAnchoredOption())
			if LocalBuildingModule.GetAnchoredOption() then
				BuildToolBoxUI.Anchored.PanelLight.ImageColor3 = Color3.fromRGB(0, 255, 0)
			else
				BuildToolBoxUI.Anchored.PanelLight.ImageColor3 = Color3.fromRGB(255, 0, 0)
			end
		end
	end
end

--[[
	This method is binding on call N Key and E,R,T Key.
	If it's N Key with actionName : "activeBuildingTool", the method check if activate or disable
	the building tool handles on the object hit by player mouse.
	For E,R,T Key it's for the selected handle by player. Key have a action name who as same name of
	handles choosen. If E is pressed this function is call with actionName = "HandlesPos" and set the new
	object to HandlesPos.
]]
function BuildingTool(actionName, userInputState, input)
	--check if player can place object or not
	if not PlayerCanPlace or placingObject then
		return
	end
	Background.Visible = false
	local isSet = false
	local lastPart
	if not (userInputState == Enum.UserInputState.Begin) then
		return
	end
	if actionName == "activeBuildingTool" then
		--if code arrived here, return not called, so no authorized hit object for
		--activated building tool, check if buidling tool is active for disable it
		if isActiveBuildingTool then
			BuildToolBoxUI.BuildTool.PanelLight.ImageColor3 = Color3.fromRGB(255, 241, 208)
			if partBuildingTool.Name == "Checkpoint" then
				PositionningEvent.EnableBeam:FireServer(partBuildingTool, false)
				SetCheckpointUI(partBuildingTool, false)
			elseif partBuildingTool.Name == "Start" then
				SetStartRaceUI(partBuildingTool, false)
			end
			--Send to server can free the modeller owner of object
			FreeModellerOwnerBuildingTool()
		end

		local hit, position = RayCastMouseHit()
		if hit and (HumanoidRootPart.Position - hit.Position).Magnitude < maxPlacingDistance then
			local exist = FoundItem(hit)
			if exist then
				if hit.Name == exist.Name then
					if partBuildingTool ~= hit then
						lastPart = partBuildingTool
						partBuildingTool = hit
						isSet = true
					end
				elseif hit.Parent.Name == exist.Name then
					if partBuildingTool ~= hit.Parent.PrimaryPart then
						lastPart = partBuildingTool
						partBuildingTool = hit.Parent.PrimaryPart
						isSet = true
					end
				end

				if hit:GetAttribute("Modeller") then						
					if hit:GetAttribute("Modeller") ~= 0 then
						if hit:GetAttribute("Modeller") ~= player.UserId then
							warn("One player are already modify this object")
							return
						end
					end
				end

				--If player not owner, other player can't interact with inventory object type
				if player.UserId ~= remoteFunctions.MapsManagerModule.GetOwnerServer:InvokeServer() then
					if hit:GetAttribute("Modeller") and hit:GetAttribute("ObjectType") and hit:GetAttribute("StockQuantity") then
						return
					elseif hit:GetAttribute("Modeller") and not hit:GetAttribute("ObjectType") then
						return
					end
				end
				
				if isSet then
					--if here, obj can changed, activate building tool on hit target and return for stop function
					--Send to server reserve the modeller owner of object
					PositionningEvent.ModellerObject:InvokeServer(partBuildingTool, false)
					PositionningEvent.ModellerObject:InvokeServer(lastPart, true)
					LocalBuildingModule.InitActifHandles(partBuildingTool)
					LocalBuildingModule.SetAnchorHandlesAdornee(true)
					isActiveBuildingTool = true
					BindPlayerActionBuildingTool()
					BuildToolBoxUI.BuildTool.PanelLight.ImageColor3 = Color3.fromRGB(0,255,0)

					if partBuildingTool.Name == "Checkpoint" then
						PositionningEvent.EnableBeam:FireServer(partBuildingTool, true)
						SetCheckpointUI(partBuildingTool, true)
						SetStartRaceUI(partBuildingTool, false)
					elseif partBuildingTool.Name == "Start" then
						SetStartRaceUI(partBuildingTool, true)
						SetCheckpointUI(partBuildingTool, false)
					end

					return
				elseif hit == partBuildingTool and isActiveBuildingTool then
					--break
				end
			end
		end
	else
		if isActiveBuildingTool then
			LocalBuildingModule.InitActifHandles(partBuildingTool)
			LocalBuildingModule.SetAnchorHandlesAdornee(true)
		end
	end
end

-- Handles rendering the temporary Brick during placement
function handleRenderStepped()
	local hit, position, normal = RayCastMouseHit()
	if clientObject:IsA("Model") then
		if hit and (HumanoidRootPart.Position - clientObject.PrimaryPart.Position).Magnitude < maxPlacingDistance --[[ and not workspace:ArePartsTouchingOthers({clientObject.PrimaryPart}) ]] then
			goodTOPlace = true
			RecursiveChangeChildren(clientObject, goodTOPlace)
			lastHit = hit
		else
			goodTOPlace = false
			RecursiveChangeChildren(clientObject, goodTOPlace)
		end
	else
		if hit and (HumanoidRootPart.Position - clientObject.Position).Magnitude < maxPlacingDistance --[[ and not workspace:ArePartsTouchingOthers({clientObject}) ]] then
			goodTOPlace = true
			lastHit = hit
			clientObject.Transparency = 0.5
			clientObject.BrickColor = BrickColor.new("Bright green")
		else
			goodTOPlace = false
			clientObject.Transparency = 0.5
			clientObject.BrickColor = BrickColor.new("Crimson")
		end
	end
	
	--Calcule CFrame position rotation where are the object
	CalculateCFramePosition(position, hit, normal)
end

--[[
	Handles constructing the temporary placement brick when the create button is pressed.
	If hit parameter is exist, the method as not call by user interface for create a primitive
	object, but is called by the Catch function for move a existing object place in the map.
]]
function handleBrickButtonPressed(ObjectName, hit)
	Background.Visible = false
	BuildToolBoxUI.Catch.PanelLight.ImageColor3 = Color3.fromRGB(0,255,0)
	yOrientation = 0
	zOrientation = 0
	local startingCFrame = CFrame.new(0, -2, -15)
	
	if placingObject == false then
		placingObject = true
		
		for index, v in pairs(PositionningObjectsList) do
			if v.Name == ObjectName then
				indexSelector = index
			end
		end
		
		if not hit then
			local exist = PositionningObjects:FindFirstChild(ObjectName)
			clientObject = exist:Clone()
		else
			clientObject = hit:Clone()
		end
		
		if clientObject:IsA("Model") then
			RecursiveChangeChildren(clientObject, true)
			ToolsModule.WeldModelToPrimary(clientObject)
			clientObject:SetPrimaryPartCFrame(HumanoidRootPart.CFrame:ToWorldSpace(startingCFrame))
		else
			clientObject.Transparency = 0.5
			--clientObject.CanCollide = false
			clientObject.Anchored = true
			clientObject.CFrame = HumanoidRootPart.CFrame:ToWorldSpace(startingCFrame)
		end

		clientObject.Parent = game.Workspace

		if clientObject:IsA("Model") then
			for _, obj in pairs(clientObject:GetDescendants()) do
				if obj:IsA("BasePart") then
					obj.CollisionGroup = "PlacingObject"
				end
			end
		else
			clientObject.CollisionGroup = "PlacingObject"
		end

		renderSteppedConnexion = RunService.RenderStepped:Connect(handleRenderStepped)
	end
end

--This method allow to active on listen all action of player for positionning object
function BindPlayerAction()
	InitToolBarUI("PositionningToolBarItemsTemplate")
	ToolBarUI.Visible = true
	ContextActionService:BindAction("place", PlaceObjectSelected, false, Enum.UserInputType.MouseButton1)
	ContextActionService:BindAction("duplicator", PlaceObjectSelected, false, Enum.UserInputType.MouseButton3)
	--ContextActionService:BindAction("selector", CatchObject, false, Enum.UserInputType.MouseWheel)
	ContextActionService:BindAction("rotateY", RotateY, false, Enum.KeyCode.R)
	ContextActionService:BindAction("rotateZ", RotateZ, false, Enum.KeyCode.T)
	ContextActionService:BindAction("cancelPos", CancelPositionning, false, Enum.KeyCode.C)
end

function BindPlayerActionBuildingTool()
	ContextActionService:BindAction("setDuplicator", function()
		LocalBuildingModule.SetDuplicator(not LocalBuildingModule.GetDuplicator())
		BuildToolBoxUI.Duplicator.PanelLight.ImageColor3 = BuildToolBoxUI.Duplicator.PanelLight.ImageColor3 == Color3.fromRGB(255, 241, 208) and Color3.fromRGB(0,255,0) or Color3.fromRGB(255, 241, 208)
	end, false, Enum.KeyCode.Q)
end

--This method unbind all action listening for postionningobject action player
--Allow to not block usage of action, as mouse click event is blocked for other roblox object !
--Unbind is important !
function UnbindPlayerAction()
	ToolBarUI.Visible = false
	ContextActionService:UnbindAction("place")
	ContextActionService:UnbindAction("duplicator")
	--ContextActionService:UnbindAction("selector")
	--ContextActionService:UnbindAction("catch")
	ContextActionService:UnbindAction("rotateY")
	ContextActionService:UnbindAction("rotateZ")
	ContextActionService:UnbindAction("cancelPos")
end

function UnbindPlayerActionBuildingTool()
	ToolBarUI.Visible = false
	ContextActionService:UnbindAction("HandlesPos")
	ContextActionService:UnbindAction("HandlesSize")
	ContextActionService:UnbindAction("ArcHandles")
	ContextActionService:UnbindAction("setDuplicator")
end


--////////////////// INTERFACE \\\\\\\\\\\\\\\\\\

--[[ 
	This RunService Hearthbeat function allow to client side to check every frame if player target with mouse a object who can interact with him.
	If we found a interactable positionning object we adornee a selection box to the target objet to give feedback visual to player for see what
	object can active Positionning or Building Tool.
]]
RunService.Heartbeat:Connect(function(deltaTime)
	--check if player can place object or not
	if PlayerCanPlace then
		if not placingObject then
			local hit, position = RayCastMouseHit()
			if hit and (HumanoidRootPart.Position - hit.Position).Magnitude < maxPlacingDistance then
				local hitter = nil
				if hit:GetAttribute("Modeller") then
					hitter = hit
				elseif hit.Parent:GetAttribute("Modeller") then
					hitter = hit.Parent
				end

				if hitter and partBuildingTool ~= hitter then
					-- Object can modify are found
					selectionBoxPreview.Adornee = hitter
				else
					selectionBoxPreview.Adornee = nil
				end
			else
				selectionBoxPreview.Adornee = nil
			end
		else
			selectionBoxPreview.Adornee = nil
		end
	end
end)

function InitStartRaceUI()
	local ui = Template:FindFirstChild("StartRaceUI"):Clone()
	ui.Background.DeleteBtn.Activated:Connect(function()
		ui.Background.Visible = false
		ui.ConfirmDelete.Visible = true
		ui.TxtRace.Text = "Confirm Delete ?"
		ui.TxtRace.TextColor3 = Color3.fromRGB(255, 0, 0)
	end)

	ui.ConfirmDelete.YesBtn.Activated:Connect(function()
		if ui.Adornee then
			--check player are owner race or owner map to delete
			if player.UserId == ui.Adornee:GetAttribute("RaceCreator") or player.UserId == remoteFunctions.MapsManagerModule.GetOwnerServer:InvokeServer() then
				BuildToolBoxUI.Visible = false
				--Send to server can free the modeller owner of object
				FreeModellerOwnerBuildingTool()
				DisableHandles()
				print("Delete Race")
				PositionningEvent.DeleteRace:InvokeServer(ui.Adornee.Parent)
				ui.Background.Visible = true
				ui.ConfirmDelete.Visible = false
				ui.TxtRace.Text = ""
				ui.TxtRace.TextColor3 = Color3.fromRGB(0, 0, 0)
			end
		end
	end)

	ui.ConfirmDelete.NoBtn.Activated:Connect(function()
		ui.Background.Visible = true
		ui.ConfirmDelete.Visible = false
		ui.TxtRace.Text = ui.Adornee:GetAttribute("RaceLink")
		ui.TxtRace.TextColor3 = Color3.fromRGB(0, 0, 0)
	end)
	
	ui.PlayersNeeded.Add.Activated:Connect(function()
		local races = RF_GetRaces:InvokeServer()
		local raceName = tostring(ui.Adornee:GetAttribute("RaceLink"))
		races[raceName].playerNeeded += 1
		ui.PlayersNeeded.playerNeeded.Text = races[raceName].playerNeeded
		RF_SetRace:InvokeServer(raceName, races[raceName])
	end)

	ui.PlayersNeeded.Substract.Activated:Connect(function()
		local races = RF_GetRaces:InvokeServer()
		local raceName = ui.Adornee:GetAttribute("RaceLink")
		races[raceName].playerNeeded -= 1
		if races[raceName].playerNeeded < 1 then
			races[raceName].playerNeeded = 1
		end
		ui.PlayersNeeded.playerNeeded.Text = races[raceName].playerNeeded
		RF_SetRace:InvokeServer(raceName, races[raceName])
	end)

	ui.Parent = PositionningGui
end

function SetStartRaceUI(model, isSet)
	local ui = PositionningGui:FindFirstChild("StartRaceUI")
	if ui then
		if isSet then
			if player.UserId == model:GetAttribute("RaceCreator") or player.UserId == remoteFunctions.MapsManagerModule.GetOwnerServer:InvokeServer() then
				ui.Adornee = model
				ui.TxtRace.Text = model:GetAttribute("RaceLink")
				ui.Enabled = true
				print("RACE Ui , ",  ui.PlayersNeeded)
				ui.PlayersNeeded.Visible = true
			end
		else
			ui.Adornee = nil
			ui.Enabled = false
		end
	end	
end

--[[
	This function allow to init the checkpoint interface changing number of the checkpoint when
	player click on "-" or "+" increment or decrease number value and send it to the server for
	update it.
	This ui are place into PositionningGui and set the object who attached with
	adornee value.
]]
function InitCheckpointUI()
	local ui = Template:FindFirstChild("SelectNumberCheckpointUI"):Clone()
	ui.Background["-"].Activated:Connect(function()
		local nb = tonumber(ui.Background.TxtNumber.Text)
		if nb - 1 > 0 then
			nb -= 1
		end
		ui.Background.TxtNumber.Text = tostring(nb)
		if ui.Adornee then
			PositionningEvent.UpdateCheckpointNumber:InvokeServer(ui.Adornee, nb)
		end
	end)
	ui.Background["+"].Activated:Connect(function()
		local nb = tonumber(ui.Background.TxtNumber.Text)
		nb += 1
		ui.Background.TxtNumber.Text = tostring(nb)
		if ui.Adornee then			
			PositionningEvent.UpdateCheckpointNumber:InvokeServer(ui.Adornee, nb)
		end
	end)

	ui.RaceLink.Next.Activated:Connect(function()
		if ui.Adornee then
			local userID = PositionningEvent.UpdateCheckpointRaceLink:InvokeServer(ui.Adornee, true)		
			ui.RaceLink.OwnerName.Text = ui.Adornee:GetAttribute("RaceLink")
			ui.Background.TxtNumber.Text = ui.Adornee:GetAttribute("NumberCheckpoint")
		end
	end)
	ui.RaceLink.Previous.Activated:Connect(function()
		local userID = PositionningEvent.UpdateCheckpointRaceLink:InvokeServer(ui.Adornee, false)		
		ui.RaceLink.OwnerName.Text = ui.Adornee:GetAttribute("RaceLink")
		ui.Background.TxtNumber.Text = ui.Adornee:GetAttribute("NumberCheckpoint")
	end)

	ui.Parent = PositionningGui
end

--[[
	This function allow to show or not show the UI for set checkpoint number
	on the attached model given in parameter.
]]
function SetCheckpointUI(model, isSet)
	local ui = PositionningGui:FindFirstChild("SelectNumberCheckpointUI")
	if ui then
		if isSet then			
			ui.Adornee = model
			ui.Background.TxtNumber.Text = model:GetAttribute("NumberCheckpoint")
			ui.RaceLink.OwnerName.Text = model:GetAttribute("RaceLink")
			ui.Enabled = true
		else
			ui.Adornee = nil
			ui.Enabled = false
		end
	end	
end

--[[
	This function allow to setup behavior of buttons in toolbar to make their function when button is pressed on mobile and can't use key keyboard
]]
function InitToolBarUI(typeOfInit)
	ToolsModule.DepopulateTypeOfItemFrom("ImageButton", ToolBarUI)
	for _, v in pairs(Template[typeOfInit]:GetChildren()) do
		local c = v:Clone()
		c.Visible = true
		c.Parent = ToolBarUI
		c.Activated:Connect(function()
			if c.Name == "RotateZ" then
				RotateZ("rotateZ",Enum.UserInputState.Begin)
			elseif c.Name == "RotateY" then
				RotateY("rotateY", Enum.UserInputState.Begin)
			elseif c.Name == "Grid" then
				SetGridButton("setGrid",Enum.UserInputState.Begin)
			elseif c.Name == "Anchored" then
				SetAnchorButton("setAnchor",Enum.UserInputState.Begin)
			elseif c.Name == "Cancel" then
				CancelPositionning("cancelPos",Enum.UserInputState.Begin)
			end
		end)
	end
end

--[[
	This function allow to return true of false for say if localplayer can positionning object or not. We check if server are a private server, if player are
	owner of map or if server authorisation are true or false or specific player authorisation are given to localplayer
]]
function PlayerIsAutorisedToPositionning()
	local ServerName, IsPublicServer, IsAutorisedPositionningServer, PrivateServerId = remoteFunctions.MapsManagerModule.GetInfosServer:InvokeServer()
	if PrivateServerId == "" then
		return false
	end
	if player.UserId ~= remoteFunctions.MapsManagerModule.GetOwnerServer:InvokeServer() then
		if not IsAutorisedPositionningServer then
			if table.find(remoteFunctions.MapsManagerModule.GetAuthorisedPositionningPlayers:InvokeServer(), player.UserId) then
				return true
			else
				return false
			end
		else
			return true
		end
	else
		return true
	end
end

if not RunService:IsStudio() then
	PlayerCanPlace = PlayerIsAutorisedToPositionning()
else
	-- Check player can place if is studio only in map with positionning object activated
	PlayerCanPlace = (game.PlaceId ~= EnvironmentModule.GetPlaceId("MainPlace") and game.PlaceId ~= EnvironmentModule.GetPlaceId("FashionShow")) and true or false
end

--Create all buttons of categorie positioning object
for _, categorie in pairs(ObjectsFilters) do
	local clone = Template.BtnTemplate:Clone()
	clone.Visible = true
	clone.Parent = Background.ListFiltersObjects
	clone.Name = categorie
	clone.Title.Text = categorie

	clone.Activated:Connect(function()
		for _, obj in pairs(ListObjectsUI:GetChildren()) do
			if obj:IsA("TextButton") or obj:IsA("Frame") then
				if obj:GetAttribute("ObjectType") == categorie then
					obj.Visible = true
				else
					obj.Visible = false
				end
			end
		end

		Background.CategorieTitle.Text = categorie
		Background.CategorieTitle.Visible = true
		Background.ListFiltersObjects.Visible = false
		Background.BackBtn.Visible = true
		ListObjectsUI.Visible = true
	end)
end

--Backbutton to return list of object to list of button categorie objects
Background.BackBtn.Activated:Connect(function()
	Background.CategorieTitle.Visible = false
	Background.ListFiltersObjects.Visible = true
	Background.BackBtn.Visible = false
	ListObjectsUI.Visible = false
end)

--Create all image for All existing PositionningObject in replicatedstorage
for _, objectRef in pairs(ReplicatedStorage.PositionningObjects:GetChildren()) do
	local clone = Template.ItemTemplate:Clone()
	local viewport = clone.ViewportFrame
	local object = objectRef:Clone()
	object.Parent = viewport

	clone.Visible = true
	clone.Name = objectRef.Name
	clone:SetAttribute("ObjectType", objectRef:GetAttribute("ObjectType"))

	local price = objectRef:GetAttribute("Price")
	if price then
		clone.EcusFrame.ValueTxt.Text = ToolsModule.DotNumber(tostring(price))
		clone.EcusFrame.IconImg.Image = GameDataModule.DropCollectables[objectRef:GetAttribute("CurrencyType")]
	else
		clone.EcusFrame.Visible = false
	end

	clone.Parent = ListObjectsUI

	-- Check if object is a model & Calculate the object's size
	local target
	local objectSize

	if object:IsA("Model") then
		target = object.PrimaryPart
		objectSize = object:GetExtentsSize()
	else
		target = object
		objectSize = object.Size
	end

	local viewportCamera = Instance.new("Camera")
	viewport.CurrentCamera = viewportCamera
	viewportCamera.Parent = viewport

	viewportCamera.Focus = target.CFrame
	local rotatedCFrame = CFrame.Angles(1, 5, 1)
	rotatedCFrame = CFrame.new(target.Position) * rotatedCFrame
	viewportCamera.CFrame = rotatedCFrame:ToWorldSpace(CFrame.new(Vector3.new(objectSize.X/1.2, objectSize.Y/1.2, objectSize.Z/1.2)))
	viewportCamera.CFrame = CFrame.new(viewportCamera.CFrame.Position, target.Position)
end

-- Iterate over all Buttons in the ListObjectsUI and attach a click listener
for _, item in pairs(ListObjectsUI:GetChildren()) do
	if item:IsA("Frame") then
		item.ItemImgBtn.Activated:Connect(function()
			if PlayerCanPlace then
				handleBrickButtonPressed(item.Name)
				BindPlayerAction()
			end
		end)
	end
end

function FoundItem(hit)
	local exist = ListObjectsUI:FindFirstChild(hit.Name)
	if not exist then
		exist = ListObjectsUI:FindFirstChild(hit.Parent.Name)
	end
	print("EXIST IS", exist)
	return exist
end

InitCheckpointUI()
InitStartRaceUI()
PositionningGui.PositionningGuiBtn.Activated:Connect(function()
	Background.Visible = not Background.Visible
	lastVisibleBackround = Background.Visible
end)

ContextActionService:BindAction("catch", CatchObject, false, Enum.KeyCode.F)
ContextActionService:BindAction("activeBuildingTool", BuildingTool, false, Enum.KeyCode.N)
ContextActionService:BindAction("setAnchor", SetAnchorButton, false, Enum.KeyCode.H)
ContextActionService:BindAction("setGrid", SetGridButton, false, Enum.KeyCode.G)

if RaceDataEvent then
	RaceDataEvent.OnClientEvent:Connect(function(Reason,Data)
		if Reason == "RaceStart" then
			SetCheckpointUI(nil, false)
			SetStartRaceUI(nil, false)
			FreeModellerOwnerBuildingTool()
		end
	end)
end

--Listen event send by server when player owner have change autorisation of positionning in server.
RemoteEvent.ChangeAutorisedPositionningServerAdmin.OnClientEvent:Connect(function(isAutorised)
	--affect only player not are owner
	if player.UserId ~= remoteFunctions.MapsManagerModule.GetOwnerServer:InvokeServer() then
		--if autorisation begin false we remove properly autorisation and action in progress of player
		if not isAutorised then
			print("Player have lose autorised placement")
			placingObject = false
			if clientObject then
				clientObject:Destroy()
			end

			BuildToolBoxUI.Visible = false
			if renderSteppedConnexion then
				renderSteppedConnexion:Disconnect()
			end

			UnbindPlayerAction()
			DisableHandles()
			UnbindPlayerActionBuildingTool()
		end

		--update info of autorisation for action Catch and BuildTool
		PlayerCanPlace = isAutorised
	end
end)

--We need to listen server when he update object modified because if duplication of object is make we need to know who is the latest objet player modify if he change BuildingTool
PositionningEvent.UpdatePartBuildingTool.OnClientInvoke = function(newObject)
	partBuildingTool = newObject:IsA("Model") and newObject.PrimaryPart or newObject
end