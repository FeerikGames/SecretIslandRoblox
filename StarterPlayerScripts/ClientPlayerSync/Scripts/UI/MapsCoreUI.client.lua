local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))

local TeleportService = game:GetService("TeleportService")

--RequireModule
local ToolsModule = require("ToolsModule")
local UIProviderModule = require("UIProviderModule")
local WalkSpeedModule = require("WalkSpeedModule")
local EnvironmentModule = require("EnvironmentModule")

--Remotes
local PositionningEvent = ReplicatedStorage.PositionningEvent
local remotesEvent = ReplicatedStorage.RemoteEvent
local remoteFunctions = ReplicatedStorage.RemoteFunction.MapsManagerModule

local player = game.Players.LocalPlayer

--UI references
local AllButtonsMainMenusGui = UIProviderModule:GetUI("AllButtonsMainMenusGui")
local MapsGui = UIProviderModule:GetUI("MapsGui")
local Background = MapsGui:WaitForChild("Background")
local ShowUi = AllButtonsMainMenusGui.SubMenu.MapsGuiBtn
local MyMapsBtn = Background.MyMapsBtn
local PublicMapsBtn = Background.PublicMapsBtn
local AdminMapBtn = Background.AdminMapBtn

local PopupUI = MapsGui.Template.Popup
local PublicItem = MapsGui.Template.PublicItem
local Item = MapsGui.Template.Item
local ItemPlayer = MapsGui.Template.ItemPlayer

local MyMaps = Background.MyMaps
local ListMapsBtn = MyMaps.ListMaps
local ListVersionSaveMap = MyMaps.ListVersionSaveMap
local SaveBtn = MyMaps.SaveBtn
local OpenBtn = MyMaps.OpenBtn

local PublicMaps = Background.PublicMaps
local JoinBtn = PublicMaps.JoinBtn
local RefreshBtn = PublicMaps.RefreshBtn

local AdminMap = Background.AdminMap
local EmptyCheckID = "rbxassetid://6401772806"
local CheckedId = "rbxassetid://6401773001"

--when server starting set up the name server
local NameServer, IsPublicServer, IsAutorisedPositionningServer = remoteFunctions.GetInfosServer:InvokeServer()
MapsGui:WaitForChild("NameServer").Title.Text = NameServer
AdminMap.PositionningOption.CheckBox:SetAttribute("Check", IsAutorisedPositionningServer)
AdminMap.PublicOption.CheckBox:SetAttribute("Check", IsPublicServer)

--Buffer to object placed in server client side
local positionningObjects = {}

--[[
	This method allow to change color of button give in parameter and remove selected color
	to other button of list where the button is selected.
	It's a visual feedback function.
]]
function HighlightButton(list, btn)
	for _, b in pairs(list:GetChildren()) do
		if b:IsA("TextButton") then
			if b == btn then
				btn.BackgroundColor3 = Color3.fromRGB(170, 255, 0)
			else
				b.BackgroundColor3 = Color3.fromRGB(255, 231, 175)
			end
		end
	end
end

--[[
	This method allow to reset the attributes values of frame MyMaps where we found the buttons selected for
	save or open/load maps
]]
function ResetValueDestination()
	MyMaps:SetAttribute("DestinationName", "")
	MyMaps:SetAttribute("DestinationID", "")
	MyMaps:SetAttribute("DestinationSlotName", "")
end

--[[
	At the starting of client side we initialize list button for all Custom Map who exist in game
	and setup data for the next action Open/Load or Save Maps.
]]
for _, btn in pairs(ListMapsBtn:GetChildren()) do
	if not btn:IsA("UIListLayout") then
		--When button of this list is selected
		btn.Activated:Connect(function()
			--change color of button selected
			HighlightButton(ListMapsBtn, btn)
			--Reset value of MyMaps attributes
			ResetValueDestination()
			--Ask server side to get the list of maps in datastore for this player
			positionningObjects = PositionningEvent:WaitForChild("DatastorePositionning"):InvokeServer(false, false, btn.Name)
			--Init the list of map versions slots saved
			ToolsModule.DepopulateTypeOfItemFrom("TextButton", ListVersionSaveMap)
			if positionningObjects then
				--for all maps we create a button for all slot save with mapId and name of slot
				for index, maps in pairs(positionningObjects) do
					if index == btn.Name then
						for i, objs in pairs(maps) do
							local clone = Item:Clone()
							clone.Visible = true
							clone.Name = i
							clone.Text = i
							clone.Parent = ListVersionSaveMap
							--when this button clone is selected, we setup attributes of MyMaps data
							--to prepare the save or open maps action and change color of btn selected
							clone.Activated:Connect(function()
								MyMaps:SetAttribute("DestinationName", btn.Text)
								MyMaps:SetAttribute("DestinationID", btn.Name)
								MyMaps:SetAttribute("DestinationSlotName", clone.Name)
								HighlightButton(ListVersionSaveMap, clone)
							end)
						end
					end
				end
			end
		end)
	end
end

--[[
	This method is call for update the button and data of public list server call
	when server side receive a new public server information.
]]
function UpdatePublicServersList(listOfServerOpen)
	ToolsModule.DepopulateTypeOfItemFrom("TextButton", PublicMaps.ListMaps)
	--check if list defaut are given in parameter and init if false
	if not listOfServerOpen then
		listOfServerOpen = remoteFunctions.GetPublicServers:InvokeServer()
	end
	--For all server in list we make a button who set PublicMaps attributes used by Join button for join public server
	for i, v in pairs(listOfServerOpen) do
		for playerId, placeId in pairs(v) do
			local clone = PublicItem:Clone()
			clone.Visible = true
			clone.Name = i
			clone.Text = game.Players:GetNameFromUserIdAsync(playerId).." Server's"
			clone.Parent = PublicMaps.ListMaps
			clone.Activated:Connect(function()
				--set attributes id of map destination server and placeId of destination server
				--to allow on click join button we use this value for Teleport player
				PublicMaps:SetAttribute("DestinationID", i)
				PublicMaps:SetAttribute("DestinationPlaceId", placeId)
				HighlightButton(PublicMaps.ListMaps, clone)
			end)
		end
	end
end

--[[
	This method allow to client side said at the server to make a save of the object placed in the actual map.
	The invoked method on server side is DatastorePositionning, who make a save with dictionnary of all
	object in the server, save CFrame position and make a datastore sync. After this, method return success
	value for allow to client side show the good UI.
]]
function SaveMap()
	local success = false
	--client side check if important value are not empty to save properly
	if MyMaps:GetAttribute("DestinationID") ~= "" and MyMaps:GetAttribute("DestinationSlotName") ~= "" then
		success = PositionningEvent:WaitForChild("DatastorePositionning"):InvokeServer(true, true, MyMaps:GetAttribute("DestinationID"), MyMaps:GetAttribute("DestinationSlotName"))
		ResetValueDestination()
		HighlightButton(ListVersionSaveMap, nil)
	end
	
	return success
end

--[[
	This method allow players to open a world from UI or load data of slot if the actual map
	corresponding with the slot data asked by the player.
	If player is the owner and he want to load data of slot corresponding with the actual map, player can
	ask server to LoadMap.
	If player is the owner and he want to load data of slot NOT corresponding with the actual map, player
	can't ask server to LoadMap, but he can ask server to Teleport the Player in the map choosen with the
	data slot choosen !
	And if player are not owner, he can't LoadMap and can only need to server a Teleport request with data
	selected in UI (set in attribute of MyMaps).
]]
function OpenMap(owner)
	local success = false
	if MyMaps:GetAttribute("DestinationID") ~= "" and MyMaps:GetAttribute("DestinationSlotName") ~= "" then
		if player.UserId == owner and  tostring(game.PlaceId) == MyMaps:GetAttribute("DestinationID") then
			--Owner and map is same as slot data needed
			PositionningEvent.LoadMap:FireServer(MyMaps:GetAttribute("DestinationID"), MyMaps:GetAttribute("DestinationSlotName"))
		else
			--Owner but map not same as slot data or just not a owner so teleport
			remotesEvent.TeleportToMap:FireServer(MyMaps:GetAttribute("DestinationID"), MyMaps:GetAttribute("DestinationSlotName"), owner)
		end
		ResetValueDestination()
		HighlightButton(ListVersionSaveMap, nil)
		success = true
	end
	return success
end

--[[
	This is a event when button UI Save in MyMaps is clicked.
	Event hide UI and make a popup action validation to the player for check if player is agree
	with action to save data in slot of the map selected.
]]
SaveBtn.Activated:Connect(function()
	--Hide UI for only show popup
	Background.Visible = false
	--make clone of ui popup for setup
	local clonePopup = PopupUI:Clone()
	clonePopup.Visible = true
	clonePopup.TextContent.Text = "Are you sure you want to save to "..MyMaps:GetAttribute("DestinationName").."/"..MyMaps:GetAttribute("DestinationSlotName").."?"
	
	--set action to NO button to reset values attributes,
	--remove button selected color and destroy popup created
	clonePopup.NoBtn.Activated:Connect(function()
		ResetValueDestination()
		HighlightButton(ListVersionSaveMap, nil)
		clonePopup:Destroy()
	end)
	
	--Set action to YES button to call the SaveMap() method and display properly
	--the result success or not of save, and destroy the popup when is down
	clonePopup.YesBtn.Activated:Connect(function()
		clonePopup.NoBtn.Visible = false
		clonePopup.YesBtn.Visible = false
		clonePopup.TextContent.Text = MyMaps:GetAttribute("DestinationName").."/"..MyMaps:GetAttribute("DestinationSlotName").." is Saving ..."
		local isSuccess = SaveMap()
		if isSuccess == true then
			clonePopup.TextContent.Text = "Successful saving"
			clonePopup.TextContent.TextColor3 = Color3.fromRGB(170, 255, 0)
			task.wait(2)
		else
			if isSuccess ~= false then
				clonePopup.TextContent.Text = isSuccess
			else
				clonePopup.TextContent.Text = "Saving failed !"
			end
			clonePopup.TextContent.TextColor3 = Color3.fromRGB(255, 0, 0)
			task.wait(3)
		end
		clonePopup:Destroy()
	end)
	clonePopup.Parent = MapsGui
end)

--[[
	This event check when player click on OpenButton in MyMaps frame. This button have two behavior :
	- Loading map data from server
	- Teleport player to the destination map corresponding with selection in UI.
	And the method make a populate a PopupUI to verify if player is okay with the action needed by him.
]]
OpenBtn.Activated:Connect(function()
	Background.Visible = false
	
	--get owner of server to check if load or teleport player
	local owner = remoteFunctions.GetOwnerServer:InvokeServer()
	--Instanciate a copy of popupUI
	local clonePopup = PopupUI:Clone()
	clonePopup.Visible = true
	
	--Check if owner and map destination ID slot selected by player is the same id of actual map server.
	if player.UserId == owner and  tostring(game.PlaceId) == MyMaps:GetAttribute("DestinationID") then
		clonePopup.TextContent.Text = "Are you sure you want to load "..MyMaps:GetAttribute("DestinationName").."/"..MyMaps:GetAttribute("DestinationSlotName").."?"
	else
		clonePopup.TextContent.Text = "Do you want to teleport to "..MyMaps:GetAttribute("DestinationName").."/"..MyMaps:GetAttribute("DestinationSlotName").."?"
	end
	
	--init behavior if No button is clicked
	--destroy popup and reset value and ui
	clonePopup.NoBtn.Activated:Connect(function()
		ResetValueDestination()
		HighlightButton(ListVersionSaveMap, nil)
		clonePopup:Destroy()
	end)
	
	--init behavior if yes button is clicked
	--show popup and launch OpenMap() method
	clonePopup.YesBtn.Activated:Connect(function()
		clonePopup.NoBtn.Visible = false
		clonePopup.YesBtn.Visible = false
		if player.UserId == owner and  tostring(game.PlaceId) == MyMaps:GetAttribute("DestinationID") then
			clonePopup.TextContent.Text = "Loading..."
		else
			clonePopup.TextContent.Text = ""
		end
		local success = OpenMap(owner)
		if success then
			clonePopup.TextContent.Text = "Map is loaded"
			clonePopup.TextContent.TextColor3 = Color3.fromRGB(170, 255, 0)
		else
			clonePopup.TextContent.Text = "Failed load!"
			clonePopup.TextContent.TextColor3 = Color3.fromRGB(255, 0, 0)
		end
		wait(2)
		clonePopup:Destroy()
	end)
	clonePopup.Parent = MapsGui
end)

--[[
	Join button allow to teleport player to a public server selected in the Public ListMap.
	We check the mapId destination and the placeId destination are correctly selected and we make
	a friend teleportation allow player to join a existing reserved server !
]]
JoinBtn.Activated:Connect(function()
	if PublicMaps:GetAttribute("DestinationID") ~= "" and PublicMaps:GetAttribute("DestinationPlaceId") ~= "" then
		remotesEvent.FriendInvitToPrivateServer:FireServer(PublicMaps:GetAttribute("DestinationID"), PublicMaps:GetAttribute("DestinationPlaceId"))
		HighlightButton(PublicMaps.ListMaps, nil)
	end
end)

--[[
	This allow to make a refresh of public list map. We call the event server to need server make
	refresh of list. A timer is launch to avoid spamm of request and bloque the messagingService.
]]
RefreshBtn.Activated:Connect(function()
	if RefreshBtn:GetAttribute("Timer") == 0 then
		remotesEvent.RefreshPublicServersUI:FireServer()
		task.spawn(function()
			RefreshBtn:SetAttribute("Timer", 60)
			RefreshBtn.Active = false
			RefreshBtn.BackgroundColor3 = Color3.fromRGB(155, 155, 155)
			RefreshBtn.AutoButtonColor = false
			while RefreshBtn:GetAttribute("Timer") > 0 do
				RefreshBtn:SetAttribute("Timer", RefreshBtn:GetAttribute("Timer")-1)
				RefreshBtn.RefreshTxt.Text = "Next Refresh :"..tostring(RefreshBtn:GetAttribute("Timer")).." s"
				task.wait(1)
			end
			RefreshBtn.Active = true
			RefreshBtn.RefreshTxt.Text = "Refresh"
			RefreshBtn.AutoButtonColor = true
			RefreshBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		end)
	end
end)

ShowUi.Activated:Connect(function()
	MapsGui.Background.Visible = not MapsGui.Background.Visible
end)


MyMapsBtn.Activated:Connect(function()
	MyMaps.Visible = true
	PublicMaps.Visible = false
	AdminMap.Visible = false
	AdminMapBtn.BackgroundTransparency = 0.4
	PublicMapsBtn.BackgroundTransparency = 0.4
	MyMapsBtn.BackgroundTransparency = 0
end)

PublicMapsBtn.Activated:Connect(function()
	MyMaps.Visible = false
	PublicMaps.Visible = true
	AdminMap.Visible = false
	AdminMapBtn.BackgroundTransparency = 0.4
	PublicMapsBtn.BackgroundTransparency = 0
	MyMapsBtn.BackgroundTransparency = 0.4
end)

AdminMapBtn.Activated:Connect(function()
	MyMaps.Visible = false
	PublicMaps.Visible = false
	AdminMap.Visible = true
	AdminMapBtn.BackgroundTransparency = 0
	PublicMapsBtn.BackgroundTransparency = 0.4
	MyMapsBtn.BackgroundTransparency = 0.4
end)

Background:GetPropertyChangedSignal("Visible"):Connect(function()
    WalkSpeedModule.SetControlsPlayerAndCreature(not Background.Visible)
	ToolsModule.EnableOtherUI(not Background.Visible, {"MapsGui"})
end)

remotesEvent.RefreshPublicServersUI.OnClientEvent:Connect(UpdatePublicServersList)

--////// ADMIN PART \\\\\\
local function InitCheckBehavior(img)
	local check = img:GetAttribute("Check")
	check = not check
	img:SetAttribute("Check", check)
	if check then
		img.Image = CheckedId
	else
		img.Image = EmptyCheckID
	end
end

local function InitPlayersPermitsList()
	ToolsModule.DepopulateTypeOfItemFrom("Frame", AdminMap.PlayersPermitsList)
	local AuthorisedPositionningPlayers = remoteFunctions.GetAuthorisedPositionningPlayers:InvokeServer()
	local players = game.Players:GetPlayers()
	for _, plr in pairs(players) do
		if plr ~= player then
			local cloneItem = ItemPlayer:Clone()
			cloneItem.Visible = true
			cloneItem.Name = plr.Name
			cloneItem.PlayerName.Text = plr.Name
			cloneItem.PlayerIcon.Image = game.Players:GetUserThumbnailAsync(
				plr.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size420x420
			)
			
			--if player are already in the authorised list, we make a good status of ui information
			if table.find(AuthorisedPositionningPlayers, plr.UserId) then
				cloneItem.CanPlaceObjects:SetAttribute("Check", true)
				cloneItem.CanPlaceObjects.Image = CheckedId
			end
			
			cloneItem.KickBtn.Activated:Connect(function()
				remotesEvent.KickPlayer:FireServer(plr)
			end)
			
			cloneItem.CanPlaceObjects.Activated:Connect(function()
				InitCheckBehavior(cloneItem.CanPlaceObjects)
				remotesEvent.ChangeAutorisedPositionningServerAdmin:FireServer(cloneItem.CanPlaceObjects:GetAttribute("Check"), plr)
			end)

			cloneItem.Parent = AdminMap.PlayersPermitsList
		end		
	end
end

game.Players.ChildAdded:Connect(InitPlayersPermitsList)
game.Players.ChildRemoved:Connect(InitPlayersPermitsList)

AdminMap.PublicOption.CheckBox.Activated:Connect(function()
	InitCheckBehavior(AdminMap.PublicOption.CheckBox)
	remotesEvent.ChangeVisibilityServerAdmin:FireServer(AdminMap.PublicOption.CheckBox:GetAttribute("Check"))
end)
AdminMap.PublicOption.CheckBox:GetAttributeChangedSignal("Check"):Connect(function()
	local img = AdminMap.PublicOption.CheckBox
	local check = img:GetAttribute("Check")
	if check then
		img.Image = CheckedId
	else
		img.Image = EmptyCheckID
	end
end)

AdminMap.PositionningOption.CheckBox.Activated:Connect(function()
	InitCheckBehavior(AdminMap.PositionningOption.CheckBox)
	local check = AdminMap.PositionningOption.CheckBox:GetAttribute("Check")
	remotesEvent.ChangeAutorisedPositionningServerAdmin:FireServer(AdminMap.PositionningOption.CheckBox:GetAttribute("Check"))
	if check then
		AdminMap.PlayersPermitsList.Visible = false
		AdminMap.ShowPlayersManagementOption.DropBtn.Text = "v"
		AdminMap.ShowPlayersManagementOption.DropBtn:SetAttribute("isShow", false)
		AdminMap.ShowPlayersManagementOption.Visible = false
	else
		AdminMap.ShowPlayersManagementOption.Visible = true
	end
	InitPlayersPermitsList()
end)
AdminMap.PositionningOption.CheckBox:GetAttributeChangedSignal("Check"):Connect(function()
	local img = AdminMap.PositionningOption.CheckBox
	local check = img:GetAttribute("Check")
	if check then
		img.Image = CheckedId
	else
		img.Image = EmptyCheckID
	end
end)

--This event catch when button drop is clicked for show or hide the list of players permits
AdminMap.ShowPlayersManagementOption.DropBtn.Activated:Connect(function()
	local btn = AdminMap.ShowPlayersManagementOption.DropBtn
	if not btn:GetAttribute("isShow") then
		btn:SetAttribute("isShow", true)
		AdminMap.PlayersPermitsList.Visible = true
		btn.Text = "^"
	else
		btn:SetAttribute("isShow", false)
		AdminMap.PlayersPermitsList.Visible = false
		btn.Text = "v"
	end
end)

InitPlayersPermitsList()
--////// ------------ \\\\\\

-- Read teleport data
local teleportData = TeleportService:GetLocalPlayerTeleportData()
if teleportData then
	local players = game.Players:GetChildren()
	if #players > 1 then
		--player are already on the map, map exist so not load after teleport for not destroy other player
		--creation or placing objects
	else
		PositionningEvent.LoadMap:FireServer(teleportData.mapId, teleportData.mapName)
	end
end