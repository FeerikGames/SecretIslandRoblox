--// Awesom3_Eric
--// 7/22/2022 @ 1:47AM
--// UIStrokeAdjuster



--[[== CONFIGURATIONS ==]]--

-- Paste the following code into the command bar and change the Studio_Viewport_Size to the values in the output bar:
-- print(workspace.CurrentCamera.ViewportSize)
local Studio_Viewport_Size = Vector2.new(1920, 1080)

-- Set to false to manually tag BillboardGuis and ScreenGuis yourself
-- Set to true to automatically tag BillboardGuis and ScreenGuis recursively in PlayerGui
local Auto_Tag = true

-- Change if you want lol
local Billboard_Tag = "Billboard"
local Screen_Gui_Tag = "ScreenGui"
local Screen_Stroke_Tag = "ScreenStroke"
local Default_Billboard_Distance = 10 -- Estimated distance if "Distance" attribute of BillboardGui is not set









--[[== CODE ==]]--

--|| Initialization ||--

-- Services
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

-- Player
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui", 100)

-- Variables
local camera = workspace.CurrentCamera





--|| Utility Functions ||--

-- Returns average resolution of Vector2
local function average(vector: Vector2): number
	return (vector.X + vector.Y) / 2
end

-- Returns ratio of current viewport size to studio viewport size
local function getScreenRatio(): number
	return average(camera.ViewportSize)/average(Studio_Viewport_Size)
end

-- Recursively tags instance with tag based on objectType
-- Listens for added instances
local function tagRecursive(instance: Instance, objectType: string, tag: string)
	if instance:IsA(objectType) then
		CollectionService:AddTag(instance, tag)
	end
	for _, child in instance:GetChildren() do
		tagRecursive(child, objectType, tag)
	end
	instance.ChildAdded:Connect(function(child)
		tagRecursive(child, objectType, tag)
	end)
end

-- Returns position of part or model (for relative BillboardGui position)
local function getInstancePosition(instance: Instance): Vector3
	if instance:IsA("Part") then
		return instance.Position
	elseif instance:IsA("Model") then
		local cf, size = instance:GetBoundingBox()
		return cf.Position
	end
	return Vector3.new(0, 0, 0)
end





--|| ScreenGui Updating ||--

local ScreenStrokes = {}

-- Recurisvely tags UIStrokes in ScreenGui
CollectionService:GetInstanceAddedSignal(Screen_Gui_Tag):Connect(function(screenGui: ScreenGui)
	tagRecursive(screenGui, "UIStroke", Screen_Stroke_Tag)
end)

-- Indexes UIStroke in ScreenStrokes to update
CollectionService:GetInstanceAddedSignal(Screen_Stroke_Tag):Connect(function(uiStroke: UIStroke)
	ScreenStrokes[uiStroke] = uiStroke.Thickness
	uiStroke.Thickness *= getScreenRatio()
end)

-- Updates UIStroke thickness in ScreenStrokes in Heartbeat
RunService.Heartbeat:Connect(function()
	for uiStroke, originalThickness in ScreenStrokes do
		if not uiStroke.Parent then
			ScreenStrokes[uiStroke] = nil
		else
			uiStroke.Thickness = originalThickness * getScreenRatio()
		end
	end
end)





--|| BillboardGui Updating ||--

-- Initializes thickness update on BillboardGui's UIStrokes
CollectionService:GetInstanceAddedSignal(Billboard_Tag):Connect(function(billboardGui: BillboardGui)
	-- Index BillboardGui's UIStrokes recursively
	local BillboardStrokes = {}
	local function getUiStrokeFromInstance(instance: Instance)
		if instance:IsA("UIStroke") then
			BillboardStrokes[instance] = instance.Thickness
		end
		for _, uiStroke in instance:GetChildren() do
			getUiStrokeFromInstance(uiStroke)
		end
		instance.ChildAdded:Connect(getUiStrokeFromInstance)
	end
	getUiStrokeFromInstance(billboardGui)
	
	-- Update UIStrokes
	local update; update = RunService.Heartbeat:Connect(function()
		-- Disconnect if BillboardGui is deleted
		if not billboardGui.Parent then
			update:Disconnect()
		else
		-- Update
			local adornee = billboardGui.Adornee
			local origin = adornee and getInstancePosition(adornee) or getInstancePosition(billboardGui.Parent)
			local magnitude = (workspace.CurrentCamera.CFrame.Position - origin).Magnitude
			local distanceRatio = ((billboardGui:GetAttribute("Distance") or Default_Billboard_Distance)/magnitude)
			for stroke, originalThickness in BillboardStrokes do
				if not stroke.Parent then
					BillboardStrokes[stroke] = nil
				else
					stroke.Thickness = originalThickness * distanceRatio * getScreenRatio()
				end
			end
		end
	end)
end)



-- Automatically tag ScreenGuis and BillboardGuis in PlayerGui if Auto_Tag == true
if Auto_Tag then
	tagRecursive(PlayerGui, "ScreenGui", Screen_Gui_Tag)
	tagRecursive(PlayerGui, "BillboardGui", Billboard_Tag)
end






--|| Module Functions ||--
local UIStrokeAdjuster = {}

function UIStrokeAdjuster:TagScreenGui(screenGui: ScreenGui)
	if screenGui:IsA(screenGui) then
		CollectionService:AddTag(screenGui, Screen_Stroke_Tag)
	end
end

function UIStrokeAdjuster:TagBillboardGui(billboardGui: BillboardGui)
	if billboardGui:IsA(billboardGui) then
		CollectionService:AddTag(billboardGui, Billboard_Tag)
	end
end

return UIStrokeAdjuster