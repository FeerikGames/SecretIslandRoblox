local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

--Require
local ToolsModule = require("ToolsModule")
local UIProviderModule = require("UIProviderModule")
local WalkSpeedModule = require("WalkSpeedModule")

--UI
local AllButtonsMainMenusGui = UIProviderModule:GetUI("AllButtonsMainMenusGui")
local ClubsGui = UIProviderModule:GetUI("ClubsGui")
local Background = ClubsGui:WaitForChild("Background")
local ClubFrame = Background:WaitForChild("Club")
local AllClubsFrame = Background:WaitForChild("AllClubs")
local ClubFrameBtn = Background.ClubMembersListBtn
local AllClubsFrameBtn = Background.AllClubsBtn
local KickPopupFrame = Background.KickPopup

local ShowUi = AllButtonsMainMenusGui.SubMenu.ClubsGuiBtn

local ClubItem = ClubsGui.Template.ClubItem
local MemberClubItem = ClubsGui.Template.MemberClubItem

local Player = game.Players.LocalPlayer
local PlayerIsOwner = false
local RuleCreateClub = false

local RefreshUiInProgress = false

local CurrentDescClub;

--For Text Filter Clubsbook
local ObjectHolder = AllClubsFrame.ClubsList
local Objects = {['Frame'] = true, ['TextLabel'] = true, ['ImageButton'] = true, ['ImageLabel'] = true}
local Type = 1

--Events
local RemoteFunction = ReplicatedStorage:FindFirstChild("RemoteFunction")
local RE_TeleportToPrivatePlace = ReplicatedStorage.RemoteEvent.TeleportToPrivatePlace
local RE_ClubUpdatedRefreshPlayersUI = ReplicatedStorage.RemoteEvent.ClubUpdatedRefreshPlayersUI
local RE_RequestToJoinClub = ReplicatedStorage.RemoteEvent.RequestToJoinClub

--Set Visibility of ui for modify description of club - only by owner's club
local function SetDescSaveBtn(isActif)
	ClubFrame.Infos.SaveDescBtn.Visible = isActif
	ClubFrame.Infos.CancelDescBtn.Visible = isActif
	ClubFrame.Infos.SaveDescBtn.Active = isActif
	ClubFrame.Infos.CancelDescBtn.Active = isActif
end

--Set visibility of ui for show player club
local function SetVisibilityUIClub(visibility)
	ClubFrame.Infos.Visible = visibility
	ClubFrame.MembersList.Visible = visibility
	ClubFrame.MembersListTitles.Visible = visibility
	ClubFrame.CreateClub.Visible = not visibility
	ClubFrame.CreateClub.Active = not visibility
end

--This method allow to setup and populate ui of club if player have a club
local function CheckPlayerHaveClubUI()
	ToolsModule.DepopulateTypeOfItemFrom("Frame", ClubFrame:WaitForChild("MembersList"))
	local result = RemoteFunction:WaitForChild("GetValueOf"):InvokeServer("Club")
	--Check if player have club
	if result ~= "" then
		local club = RemoteFunction.Club:WaitForChild("GetClubData"):InvokeServer(result)
		if club then
			--This check allow to verify if player are kick from club during disconnected or not.
			local playerAreAlawayInClub = false
			for plrId, value in pairs(club.ListOfMembers) do
				if tostring(Player.UserId) == plrId then
					--Founded in list of members so player have club
					print("Player are in club")
					playerAreAlawayInClub = true
					break
				end
			end
			
			--if player don't have club, so if playerAreAlawayInClub are not passed true
			if not playerAreAlawayInClub then
				print("Player no longer have club")
				--Remove club data of player because he have not a club (quit, kick or banned)
				RemoteFunction:WaitForChild("SetValueOf"):InvokeServer("Club", "")
				SetVisibilityUIClub(false)
				return
			end

			--Set visibility of ui for show player club
			SetVisibilityUIClub(true)
			
			--Populate UI with club data
			ClubFrame.Infos.ClubID.Value = result
			ClubFrame.Infos.ClubImage.Image = club.ClubImage
			ClubFrame.Infos.ClubName.Text = club.ClubName
			ClubFrame.Infos.ClubDescription.Text = club.ClubDescription

			for index, value in pairs(club.ListOfMembers) do
				local item = MemberClubItem:Clone()
				item.Visible = true
				item.Name = index
				item.MemberName.Text = value.PlayerName
				item.MemberRanking.Text = value.Ranking
				item.MemberReputation.Text = value.Reputation
				item.NbHorses.Text = value.NbHorses
				item.OwnerClub.Visible = value.Owner
				item.AdminClub.Visible = value.Admin

				if tostring(Player.UserId) == index then
					item.LeaveClubBtn.Visible = true
					item.LayoutOrder = 0
				end	
				
				--Check if player is owner
				if Player.UserId == club.Owner then
					PlayerIsOwner = true
					if tostring(Player.UserId) == index then
						item.GiveOwnerBtn.Visible = false
					else
						item.GiveOwnerBtn.Visible = true
						if value.Admin then
							item.GiveAdminBtn.Visible = false
							item.RemoveAdminBtn.Visible = true
						else
							item.GiveAdminBtn.Visible = true
						end
					end
					item.LeaveClubBtn.Visible = true
					ClubFrame.Infos.ClubDescription.TextEditable = true
				else
					PlayerIsOwner = false
				end
				
				--check if player is admin
				if club.ListOfMembers[tostring(Player.UserId)].Admin then
					if index ~= tostring(club.Owner) then
						item.LeaveClubBtn.Visible = true
					end
				end

				item.LeaveClubBtn.Activated:Connect(function()
					KickPopupFrame.KickBtn.KickTxt.Text = "Kick"
					KickPopupFrame.KickBtn.Active = true

					if index == tostring(club.Owner) then
						print("Owner can't leave is club ! Give owner to another player before to leave club !")
					else
						--only for owner or admin and don't do that if it's owner or admin himself
						if Player.UserId == club.Owner or club.ListOfMembers[tostring(Player.UserId)].Admin and index ~= tostring(Player.UserId) then
							local connect
							KickPopupFrame.Visible = true
							connect = KickPopupFrame.KickBtn.Activated:Connect(function()
								KickPopupFrame.KickBtn.KickTxt.Text = "Waiting..."
								KickPopupFrame.KickBtn.Active = false
								connect:Disconnect()
								
								--reset value of time choose for ban (to avoid changing the default value)
								local res = RemoteFunction.Club:WaitForChild("RemoveClubMember"):InvokeServer(
									index,
									result,
									KickPopupFrame.BanField.BanValue.Value,
									KickPopupFrame.DropDown.SelectedOption.Value
								)
								KickPopupFrame.BanField.Text = ""
								KickPopupFrame.BanField.BanValue.Value = 0
								KickPopupFrame.Visible = false
							end)
						else
							--last parameter is ban value, make 0 for let the player just leave andn il because no day minutes or seconds is selected
							local res = RemoteFunction.Club:WaitForChild("RemoveClubMember"):InvokeServer(index, result, 0, nil)
						end
					end
				end)
				
				item.GiveOwnerBtn.Activated:Connect(function()
					if Player.UserId == club.Owner then
						RemoteFunction.Club:WaitForChild("ChangeOwnerOfClub"):InvokeServer(result, tonumber(index), tostring(Player.UserId))
					end
				end)
				
				item.GiveAdminBtn.Activated:Connect(function()
					if Player.UserId == club.Owner then
						item.AdminClub.Visible = true
						RemoteFunction.Club:WaitForChild("ChangeAdminOfClub"):InvokeServer(result, index, true)
					end
				end)
				
				item.RemoveAdminBtn.Activated:Connect(function()
					if Player.UserId == club.Owner then
						item.AdminClub.Visible = false
						RemoteFunction.Club:WaitForChild("ChangeAdminOfClub"):InvokeServer(result, index, false)
					end
				end)
			
				item.Parent = ClubFrame.MembersList
			end		
		end
	else
		--Set visibility of ui for show player club
		SetVisibilityUIClub(false)
		ClubFrame.Infos.ClubID.Value = ""
	end
end

--This function populate UI List Of Clubs for show all club exist in game and a button to send request to join club
local function CheckClubsBookUI()
	ToolsModule.DepopulateTypeOfItemFrom("Frame", AllClubsFrame.ClubsList)
	local clubs = RemoteFunction.Club:WaitForChild("GetAllClubs"):InvokeServer()
	for index, value in pairs(clubs) do
		local item = ClubItem:Clone()
		item.Visible = true
		item.Name = index
		item.ClubName.Text = value.ClubName
		item.ClubImage.Image = value.ClubImage
		item.ClubMembers.Text = value.NbMembers
		item.ClubHorses.Text = value.NbHorses
		
		--Check if player have already a club and if true, hide the join club button for all other club
		if ClubFrame.Infos.ClubID.Value ~= "" then
			item.JoinClubBtn.Visible = false
		end
		
		item.JoinClubBtn.Activated:Connect(function()
			--Call event to send request to owner of club player want to join
			RE_RequestToJoinClub:FireServer(value.ClubName)
			item.JoinClubBtn.Visible = false
		end)
		
		item.Parent = AllClubsFrame.ClubsList
	end
end

--Initialize the visibility of club frame by default
local function InitVisibility()
	RefreshUI()
	ClubFrame.Visible = true
	AllClubsFrame.Visible = false
end

--[[
	This function allow to filter list of all club based on value of Text input.
	Set the visibility and the order layout for display what the player want.
]]
function TextFilter(Text)
	for i,v in pairs(ObjectHolder:GetChildren()) do
		if Objects[v.ClassName] then
			if string.match(string.lower(v.Name), Text) then
				if Type == 1 then
					v.Visible = true
				end
				v.LayoutOrder = 1
			else
				if Type == 1 then
					v.Visible = false
				end
				v.LayoutOrder = 0
			end
		end
	end
end

ClubFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	ClubFrame.CreateClubFrame.Visible = false
	if not ClubFrame.Visible then
		--CheckPlayerHaveClubUI()
	end
end)

AllClubsFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	if not AllClubsFrame.Visible then
		--CheckClubsBookUI()
	end
end)

Background:GetPropertyChangedSignal("Visible"):Connect(function()
	ClubFrame.Visible = Background.Visible
	AllClubsFrame.Visible = not Background.Visible
	WalkSpeedModule.SetControlsPlayerAndCreature(not Background.Visible)
	ToolsModule.EnableOtherUI(not Background.Visible, {"ClubsGui"})
end)

ClubFrame.CreateClub.Activated:Connect(function()
	ClubFrame.CreateClubFrame.Visible = true
	ClubFrame.Infos.Visible = false
end)

--[[
	This event listen input value Text of club name for check format and length of name when a new character
	is added or remove by player. Allow to check if it's valid format name and force to upper and
	automatically remove special characters for standardize Names of clubs.
]]
ClubFrame.CreateClubFrame.ClubName:GetPropertyChangedSignal('Text'):Connect(function()
	local form = ClubFrame.CreateClubFrame
	local alertName = form.ClubNameAlert
	local CurrentText = form.ClubName.Text
	
	--remove special characters
	CurrentText = CurrentText:gsub("[^%w%s_]+", "")
	--force text to upper
	CurrentText = string.upper(CurrentText)
	form.ClubName.Text = CurrentText
	print(CurrentText)
	
	--Check if length respect rule of minimum and set alert text for feedback player
	if string.len(form.ClubName.Text) < 3 then
		alertName.Text = "The name of club need minimum 3 characters !"
		RuleCreateClub = false
	else
		alertName.Text = ""
		RuleCreateClub = true
	end
end)

--[[
	This event listener is launch when create button of form to make a club is clicked.
	It take all value information of form, name and desc of club and verify on click, if rules for format
	is respected. If not, feedback player with message why not work.
	If okay, this event call a remote function to create new club and check return result of function
	to check status of creation club.
]]
ClubFrame.CreateClubFrame.CreateBtn.Activated:Connect(function()
	local form = ClubFrame.CreateClubFrame
	local name = form.ClubName
	local desc = form.ClubDesc
	local alertName = form.ClubNameAlert
	local alertDesc = form.ClubDescAlert
	local btnCreate = form.CreateBtn
	
	if string.len(desc.Text) > 199 then
		alertDesc.Text = "The maximum length of description is 200 characters !"
		RuleCreateClub = false
	end
	
	if RuleCreateClub then
		btnCreate.CreateTxt.Text = "Waiting ..."
		btnCreate.Active = false
		
		--Call remote function to create new club
		local result = RemoteFunction.Club:WaitForChild("CreateNewClub"):InvokeServer("", name.Text, desc.Text)
		--Check return result of function create
		if result == "MODERATED" then
			--If result is moderate, the create club fail because the name of club are filtered by Roblox
			btnCreate.CreateTxt.Text = "Create"
			btnCreate.Active = true
			alertName.Text = "This name is not appropriate..."
		elseif result == "ERROR" then
			--If result is error, it's for any other fail can't processed during create club on name value
			btnCreate.CreateTxt.Text = "Create"
			btnCreate.Active = true
			alertName.Text = "Error during creation, try again."
		elseif result == nil then
			--if result is nil, name of club are already used, name of club is unique
			btnCreate.CreateTxt.Text = "Create"
			btnCreate.Active = true
			alertName.Text = "The name of club already exist..."
		elseif result == false then
			--if result is false, it's because player who create club are already in club.
			--This case should normally never be reached, but we check in case.
			btnCreate.CreateTxt.Text = "Create"
			btnCreate.Active = true
			alertName.Text = "You are already in a club..."
		elseif result == true then
			--If result is true, create club is successful, so reset ui player to display ui of club
			--and hide the ui creation club
			print(name.Text)
			name.Text = ""
			desc.Text = ""
			alertName.Text = ""
			alertDesc.Text = ""
			form.Visible = false
			btnCreate.CreateTxt.Text = "Create"
			btnCreate.Active = true
			ClubFrame.Infos.Visible = true
		end
	end
end)

--[[
	This is listener of value text of input filter text of list of club
	when text is modified use TextFilter() for update ui dynamic list of clubs
]]
AllClubsFrame.Infos.SearchField:GetPropertyChangedSignal('Text'):Connect(function()
	local CurrentText = AllClubsFrame.Infos.SearchField.Text

	if CurrentText == "" then
		for i,v in pairs(ObjectHolder:GetChildren()) do
			if Objects[v.ClassName] then
				v.Visible = true
			end
		end
	else
		TextFilter(string.lower(CurrentText))
	end
end)

KickPopupFrame.BanField:GetPropertyChangedSignal("Text"):Connect(function()
	KickPopupFrame.BanField.Text = KickPopupFrame.BanField.Text:gsub('%D+', '');
	KickPopupFrame.BanField.BanValue.Value = tonumber(KickPopupFrame.BanField.Text)
end)

ClubFrameBtn.Activated:Connect(function()
	ClubFrame.Visible = true
	AllClubsFrame.Visible = false
	ClubFrameBtn.BackgroundTransparency = 0
	AllClubsFrameBtn.BackgroundTransparency = 0.4
end)

AllClubsFrameBtn.Activated:Connect(function()
	AllClubsFrame.Visible = true
	ClubFrame.Visible = false
	AllClubsFrameBtn.BackgroundTransparency = 0
	ClubFrameBtn.BackgroundTransparency = 0.4
end)

ShowUi.Activated:Connect(function()
	Background.Visible = not Background.Visible
	if Background.Visible then
		InitVisibility()
	end
end)


--[[
	On club UI, when button Join Private Server of club is clicked we get the code of private
	server for club, and call event to teleport player are clicked on button to the server club.
]]
ClubFrame.Infos.JoinClubPrivateServer.Activated:Connect(function()
	local result = RemoteFunction:WaitForChild("GetValueOf"):InvokeServer("Club")
	--Check if player have club
	if result ~= "" then
		local club = RemoteFunction.Club:WaitForChild("GetClubData"):InvokeServer(result)
		if club then
			print("Teleport player to private server Club")
			RE_TeleportToPrivatePlace:FireServer(club.CodePrivateServer)
		end
	end
end)

--//Action can do it on club only for owner of club !
ClubFrame.Infos.ClubDescription.Focused:Connect(function()
	if PlayerIsOwner then
		if ClubFrame.Infos.ClubDescription.IsFocused then
			CurrentDescClub = ClubFrame.Infos.ClubDescription.Text
			SetDescSaveBtn(true)
		end
	end
end)

ClubFrame.Infos.SaveDescBtn.Activated:Connect(function()
	if PlayerIsOwner then
		local desc = ClubFrame.Infos.ClubDescription
		if string.len(desc.Text) < 201 then
			if desc.Text ~= CurrentDescClub then
				RemoteFunction.Club:WaitForChild("ChangeDescOfClub"):InvokeServer(ClubFrame.Infos.ClubID.Value, desc.Text)
				print("SAVE DESC")
			end
		else
			print("Description need to be < at 200 characters !")
		end
		SetDescSaveBtn(false)
	end
end)

ClubFrame.Infos.CancelDescBtn.Activated:Connect(function()
	if PlayerIsOwner then
		ClubFrame.Infos.ClubDescription.Text = CurrentDescClub
		SetDescSaveBtn(false)
	end
end)
--//

function RefreshUI()
	if not RefreshUiInProgress then
		RefreshUiInProgress = true
		print("UI CLUB REFRESHED")
		CheckPlayerHaveClubUI()
		CheckClubsBookUI()
		RefreshUiInProgress = false
	end
end

RE_ClubUpdatedRefreshPlayersUI.OnClientEvent:Connect(RefreshUI)

RefreshUI()