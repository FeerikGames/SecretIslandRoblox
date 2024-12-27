local LocalBuildingModule = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))

local PositionningEvent = ReplicatedStorage.PositionningEvent
local ToolsModule = require("ToolsModule")
local UIProviderModule = require("UIProviderModule")

local gridSize = 1
local gridActivated = true
local alreadyAnchoredOption = true
local duplicatorActivated = false
local duplicated = false
local actifHandles = {}
local increment = 5
local steps = 0.1

local MaxSize = 50
local MinSize = 1

local originalCf, originalSize, originalRot
local connexionDrag, connexionDown, connexionUp

local lastMoveCFrame = true

--[[
	This method init a handles selected in parameters to the part selected. Only can have one
	handles active and this script is the manager of it. So check if handle already exist and remove it
	properly for init the new handle need by player.
]]
function LocalBuildingModule.InitActifHandles(part)
	--check if already a handles actif and disable it to init the new handles
	--[[ if actifHandles then
		LocalBuildingModule.DisableActifHandles()
	end ]]
	
	for _, handle in pairs(UIProviderModule:GetUI("PositionningGui"):GetChildren()) do
		if handle:IsA("PartAdornment") then
			local connections = {}
			
			handle.Adornee = part

			if handle.Adornee:IsA("Model") then
				for _, obj in pairs(handle.Adornee:GetDescendants()) do
					if obj:IsA("BasePart") then
						obj.CollisionGroup = "PlacingObject"
					end
				end
			else
				handle.Adornee.CollisionGroup = "PlacingObject"
			end
			
			if handle.className == "ArcHandles" then
				local connexionDrag = handle.MouseDrag:Connect(function(...)
					onArcHandlesDrag(handle, ...)
				end)
				local connexionDown = handle.MouseButton1Down:Connect(function(...)
					onArcHandlesDown(handle, ...)
				end)
				table.insert(connections, connexionDrag)
				table.insert(connections, connexionDown)

			elseif handle.className == "Handles" then
				local connexionDrag = handle.MouseDrag:Connect(function(...)
					onHandlesDrag(handle, ...)
				end)
				local connexionDown = handle.MouseButton1Down:Connect(function(...)
					onHandlesDown(handle, ...)
				end)
				connexionUp = handle.MouseButton1Up:Connect(function(...)
					onHandlesUp(handle, ...)
				end)
				table.insert(connections, connexionDrag)
				table.insert(connections, connexionDown)
			end

			actifHandles[handle.Name] = connections
		end
	end
end

--[[
	This method allow to disable handle active and reset event connexion binding on it.
]]
function LocalBuildingModule.DisableActifHandles()
	for _, handle in pairs(UIProviderModule:GetUI("PositionningGui"):GetChildren()) do
		if handle:IsA("PartAdornment") then
			if not handle.Adornee then
				return
			end
			if handle.Adornee:IsA("Model") then
				for _, obj in pairs(handle.Adornee:GetDescendants()) do
					if obj:IsA("BasePart") then
						obj.CollisionGroup = "Default"
					end
				end
			else
				handle.Adornee.CollisionGroup = "Default"
			end
		
			for handleName, connections in pairs(actifHandles) do
				if handleName == handle.Name then
					for _, co in pairs(connections) do
						co:Disconnect()
					end
					break
				end
			end
			
			handle.Adornee = nil

			actifHandles[handle.Name] = nil
		end
	end
end

function LocalBuildingModule.SetAnchorHandlesAdornee(isActive)
	for _, handle in pairs(UIProviderModule:GetUI("PositionningGui"):GetChildren()) do
		if handle:IsA("PartAdornment") then
			if not handle.Adornee then
				return
			end
			if not alreadyAnchoredOption then
				handle.Adornee.Anchored = isActive
			else
				handle.Adornee.Anchored = true
			end
			SendAdorneeDataToServer(handle)
			break
		end
	end
end

function LocalBuildingModule.SetGrid(isActive, size)
	gridActivated = isActive
	if size then
		gridSize = size
	end
end

function LocalBuildingModule.GetGrid()
	return gridActivated, gridSize
end

function LocalBuildingModule.SetAnchoredOption(isActive)
	alreadyAnchoredOption = isActive
end

function LocalBuildingModule.GetAnchoredOption()
	return alreadyAnchoredOption
end

--[[
	This function allow to set status of Duplicator tool of Building mode.
	The duplication of object work only with the handles movement and we change color of it to indicate to the player if he use
	movement handle tool or duplicator tool.
]]
function LocalBuildingModule.SetDuplicator(value:boolean)
	for _, handle in pairs(UIProviderModule:GetUI("PositionningGui"):GetChildren()) do
		if handle:IsA("PartAdornment") then
			if handle.Adornee then
				if handle.className == "Handles" then
					if handle.Style == Enum.HandlesStyle.Movement then
						handle.Color3 = value and Color3.fromRGB(255,255,0) or Color3.fromRGB(13, 105, 172)
						duplicatorActivated = value
						return
					end
				end
			end
		end
	end
end

function LocalBuildingModule.GetDuplicator()
	return duplicatorActivated
end

function round(number)
	return math.floor((number / increment) + 0.5) * increment
end

function AngleFromAxis(axis, r)
	local relativeAngle = math.rad(round(math.deg(r)))

	return axis == Enum.Axis.X and {relativeAngle, 0, 0} 
		or axis == Enum.Axis.Y and {0, relativeAngle, 0} 
		or axis == Enum.Axis.Z and {0, 0, relativeAngle}
end

local AxisSizeMultipliers = {
	[Enum.NormalId.Top] = Vector3.new(0, 1, 0);
	[Enum.NormalId.Bottom] = Vector3.new(0, 1, 0);
	[Enum.NormalId.Front] = Vector3.new(0, 0, 1);
	[Enum.NormalId.Back] = Vector3.new(0, 0, 1);
	[Enum.NormalId.Left] = Vector3.new(1, 0, 0);
	[Enum.NormalId.Right] = Vector3.new(1, 0, 0);
}

local AxisPositioningMultipliers = {
	[Enum.NormalId.Top] = Vector3.new(0, 1, 0);
	[Enum.NormalId.Bottom] = Vector3.new(0, -1, 0);
	[Enum.NormalId.Front] = Vector3.new(0, 0, -1);
	[Enum.NormalId.Back] = Vector3.new(0, 0, 1);
	[Enum.NormalId.Left] = Vector3.new(-1, 0, 0);
	[Enum.NormalId.Right] = Vector3.new(1, 0, 0);
}

--Send to server the data of object to synchro object size and cframe to server for all player
function SendAdorneeDataToServer(handle)
	if handle.Adornee.Parent:IsA("Model") and handle.Adornee.Parent:GetAttribute("playerNeeded") == nil then
		PositionningEvent.UpdatePositionningObject:FireServer(
			handle.Adornee.Parent,
			handle.Adornee.Parent.PrimaryPart.Size,
			handle.Adornee.Parent:GetPrimaryPartCFrame(),
			handle.Adornee.Parent.PrimaryPart.Anchored
		)
	else
		PositionningEvent.UpdatePositionningObject:FireServer(
			handle.Adornee,
			handle.Adornee.Size,
			handle.Adornee.CFrame,
			handle.Adornee.Anchored
		)
	end
end

--[[
	Calculate new CFrame object for only change face size selected and not the both
	If Duplicator is activated, when we drag object handle, function make a clone of first moved object and setup automatically the new cframe
	of clone depending of last cframe and size of object duplicated.
]]
local function SetNewCFrameHandlesDrag(handle, face, distance)
	if not duplicatorActivated then
		if handle.Adornee.Parent:IsA("Model") then
			if gridActivated and handle.Style == Enum.HandlesStyle.Movement then
				handle.Adornee.Parent:SetPrimaryPartCFrame(originalCf * (CFrame.new() + (AxisPositioningMultipliers[face] * distance)))
			else
				handle.Adornee.Parent:SetPrimaryPartCFrame(originalCf * (CFrame.new() + (AxisPositioningMultipliers[face] * distance/2)))
			end
		else
			--try to check if colliding another object can't move
			--[[ if workspace:ArePartsTouchingOthers({actifHandles.Adornee}) and lastMoveCFrame then
				print("TOUCHED")
				actifHandles.Adornee.CFrame = lastMoveCFrame
				lastMoveCFrame = nil
			else
				print("MOVED")
				lastMoveCFrame = actifHandles.Adornee.CFrame
				if gridActivated and actifHandles.Style == Enum.HandlesStyle.Movement then				
					actifHandles.Adornee.CFrame = originalCf * (CFrame.new() + (AxisPositioningMultipliers[face] * distance))
				else
					actifHandles.Adornee.CFrame = originalCf * (CFrame.new() + (AxisPositioningMultipliers[face] * distance) / 2)
				end
			end ]]

			lastMoveCFrame = handle.Adornee.CFrame
			if gridActivated and handle.Style == Enum.HandlesStyle.Movement then
				handle.Adornee.CFrame = originalCf * (CFrame.new() + (AxisPositioningMultipliers[face] * distance))
			else
				handle.Adornee.CFrame = originalCf * (CFrame.new() + (AxisPositioningMultipliers[face] * distance) / 2)
			end
		end
	else
		--check not already duplicated to prevent multiple clone objects
		if duplicated then
			return
		end
		duplicated = true

		local isModel = handle.Adornee.Parent:IsA("Model")
		local sizeOnAxis, placedObject, clone

		--Call server to make a clone duplication of object selected by player (same behavior when player click to place positionning object but here we not destroy origine)
		if isModel then
			placedObject, clone = PositionningEvent.PositionningObject:InvokeServer(
				handle.Adornee.Parent.Name,
				handle.Adornee.Parent.PrimaryPart.CFrame,
				handle.Adornee.Parent.PrimaryPart.Size,
				LocalBuildingModule.GetAnchoredOption(),
				false
			)
		else
			placedObject, clone = PositionningEvent.PositionningObject:InvokeServer(
				handle.Adornee.Name,
				handle.Adornee.CFrame,
				handle.Adornee.Size,
				LocalBuildingModule.GetAnchoredOption(),
				false,
				handle.Adornee:GetAttribute("RaceCreator"),
				handle.Adornee:GetAttribute("RaceLink")
			)
		end

		--local clone = isModel and actifHandles.Adornee.Parent:Clone() or actifHandles.Adornee:Clone()
		if placedObject then
			if isModel then
				clone.Parent = handle.Adornee.Parent.Parent
			else
				clone.Parent = handle.Adornee.Parent
			end
	
			--reset collision of actif handle going to replace by clone
			if isModel then
				for _, obj in pairs(handle.Adornee.Parent:GetDescendants()) do
					if obj:IsA("BasePart") then
						obj.CollisionGroup = "Default"
					end
				end
			else
				handle.Adornee.CollisionGroup = "Default"
			end

			--change Modeller assignement attribute of origine object
			PositionningEvent.ModellerObject:InvokeServer(isModel and handle.Adornee.Parent or handle.Adornee, true)
	
			--assign to handles the cloned object
			for _, h in pairs(UIProviderModule:GetUI("PositionningGui"):GetChildren()) do
				if h:IsA("PartAdornment") then
					h.Adornee = isModel and clone.PrimaryPart or clone
				end
			end

			--change Modeller assignement attribute of origine object
			PositionningEvent.ModellerObject:InvokeServer(handle.Adornee, false)

			-- allow to found the good size depending of face pull by player for cframe calculation
			if face == Enum.NormalId.Left or face == Enum.NormalId.Right then
				-- axe horizontal
				if isModel then
					local orientation, size = handle.Adornee.Parent:GetBoundingBox()
					sizeOnAxis = size.X
				else
					sizeOnAxis = handle.Adornee.Size.X
				end
			elseif face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
				-- axe vertical
				if isModel then
					local orientation, size = handle.Adornee.Parent:GetBoundingBox()
					sizeOnAxis = size.Y
				else
					sizeOnAxis = handle.Adornee.Size.Y
				end
			else
				-- axe perpendiculaire
				if isModel then
					local orientation, size = handle.Adornee.Parent:GetBoundingBox()
					sizeOnAxis = size.Z
				else
					sizeOnAxis = handle.Adornee.Size.Z
				end
			end
	
			--create new cframe of duplicated object depending of axes and size of last object from duplication
			lastMoveCFrame = handle.Adornee.CFrame
			if isModel then
				handle.Adornee.Parent:SetPrimaryPartCFrame(originalCf * (CFrame.new() + (AxisPositioningMultipliers[face] * sizeOnAxis)))
			else
				handle.Adornee.CFrame = originalCf * (CFrame.new() + (AxisPositioningMultipliers[face] * sizeOnAxis))
			end
		end
	end
end

function onArcHandlesDown(handle)
	originalCf = handle.Adornee.CFrame
end

function onArcHandlesDrag(handle, axis, relativeAngle, delta)
	handle.Adornee.CFrame = originalCf * CFrame.Angles(unpack(AngleFromAxis(axis, relativeAngle)))
	SendAdorneeDataToServer(handle)
end

--[[
	This method allow to init save CFrame and initial size of object attached to the handles
	to calculate the change with onHandlesDrag
]]
function onHandlesDown(handle, face)
	duplicated = false
	originalCf = handle.Adornee.CFrame
	originalSize = handle.Adornee.Size
	ToolsModule.SetWeldModelObject(handle.Adornee, false)
end

function onHandlesUp(handle)
	ToolsModule.SetWeldModelObject(handle.Adornee, true)
	lastMoveCFrame = true
end

--[[
	This method use the original CFrame and size and the face dragged and the good axis
	multiplier setup in table Size / Positionning to calculate with distance the new value of size and cframe.
	Important : multiply original CFrame by another CFrame to transform it in space and not add it
]]
function onHandlesDrag(handle, face, distance)
	if handle.Adornee and lastMoveCFrame then
		--convert distance value to a decimal value (before 0.32545454545, after step : 0.3)
		if gridActivated then
			distance = distance - (distance%gridSize)
		else
			distance = distance - (distance%steps)
		end
		
		--Check if it's a model and Resize tool because scaling object are not the same for model or BasePart object
		if handle.Adornee.Parent:IsA("Model") and handle.Style == Enum.HandlesStyle.Resize then
			ToolsModule.ScaleModel(handle.Adornee.Parent, distance)
			
			PositionningEvent.UpdatePositionningObject:FireServer(
				handle.Adornee.Parent,
				handle.Adornee.Parent.PrimaryPart.Size,
				handle.Adornee.Parent:GetPrimaryPartCFrame(),
				handle.Adornee.Parent.PrimaryPart.Anchored,
				distance
			)
		else
			--check to change size only if it's a Resize Handles and not a movement Handles
			if handle.Style == Enum.HandlesStyle.Resize then
				--calculate new size with face choose for multiply distance add to the original size
				local newSize = originalSize + AxisSizeMultipliers[face] * distance

				--check if max or min size is reach and if yes return to do nothing because max or min size reached
				if (newSize.X < MaxSize and newSize.X > MinSize) and (newSize.Y < MaxSize and newSize.Y > MinSize) and (newSize.Z < MaxSize and newSize.Z > MinSize) then
					handle.Adornee.Size = newSize
				else
					SendAdorneeDataToServer(handle)
					return
				end
			end

			SetNewCFrameHandlesDrag(handle, face, distance)
		end
		
		SendAdorneeDataToServer(handle)
	end
end

return LocalBuildingModule
