local PopupAlertManager = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

--Remote
local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local BindableEvent = ReplicatedStorage.SharedSync.BindableEvent

--Require
local ToolsModule = require("ToolsModule")
local DataManagerModule = require("DataManagerModule")

local ShowPopupBindableEvent = BindableEvent.ShowPopupAlert
local ShowPopupRemoteEvent = RemoteEvent.ShowPopupAlert
local RE_DestroyPopup = RemoteEvent.DestroyPopup

local destroyPopupCaller = Instance.new("RemoteFunction", ReplicatedStorage.SharedSync.RemoteFunction)
destroyPopupCaller.Name = "DestroyPopupCaller"

--[[
	This method allow to encapsulate the function who need to execute on client when click on button into
	remote function, sended into remote event to catch the future remote function return to execute the function
	passed in parameter
]]
local function encapsuleFunction(ownerPlayer, func)
	print("ENCAPSULE FUNCTION CALLED")
	if not func then
		func = ownerPlayer
		ownerPlayer = nil
	end

	local remoteFunc = Instance.new("RemoteFunction")
	remoteFunc.OnServerInvoke = function(player, ...)
		print("CALLED")
		if ownerPlayer and player ~= ownerPlayer then
			error("You are not the owner of this remote.")
		end
		destroyPopupCaller.OnServerInvoke = function(player, obj)
			remoteFunc:Destroy()
			obj:Destroy()
		end
		return func(player, ...)
	end

	remoteFunc.Parent = workspace
	return remoteFunc
end

--[[
	This method allow to setup the data of template UI for alert item or popup depending on priority level.
	After populate data and place correctly the UI, we send a remote event to activate popup created.
]]
local function ShowPopUpAlert(player, title, message, priority, button1, button2, method1, params1, method2, params2, TextParams)
	--print("POPUP ALERT SHOWED")
	local PlayerGui = player:WaitForChild("PlayerGui"):WaitForChild("StarterGuiSync")
	local PopupAlertGui = PlayerGui:WaitForChild("PopupAlertGui")
	local PopupTemplateUI = PopupAlertGui.Template.PopupTemplate
	local ItemAlertTemplateUI = PopupAlertGui.Template.ItemAlertTemplate
	
	local cloneTemplateUI
	--Determine if we show intrusive popup or create item into alert feed
	if priority == ToolsModule.AlertPriority.Annoucement or priority == ToolsModule.AlertPriority.AdminMessage then
		cloneTemplateUI = PopupTemplateUI:Clone()
		cloneTemplateUI.Parent = PopupAlertGui
	else
		local childAlertFeed = PopupAlertGui.AlertFeed.ScrollingFrame:GetChildren()
		--here we check if feed alert not have already 99 child, if yes, return and not adding more alert feed
		if #childAlertFeed > 100 then
			return
		end
		for _, item in pairs(childAlertFeed) do
			if item:IsA("Frame") then
				if item.Message.Text == message and item.Title.Text == title then
					--already exist so stop creating popup
					--print("Popup already exist, abort popup creation")
					return
				end
			end
		end
		
		cloneTemplateUI = ItemAlertTemplateUI:Clone()
		cloneTemplateUI.Parent = PopupAlertGui.AlertFeed.ScrollingFrame
	end
	
	cloneTemplateUI.Visible = true
	cloneTemplateUI.ZIndex = priority
	cloneTemplateUI.LayoutOrder = ToolsModule.AlertPriority.AdminMessage - priority
	cloneTemplateUI.Title.Text = title
	cloneTemplateUI.Message.Text = message
	if TextParams then
		cloneTemplateUI.Title.TextColor3 = TextParams.TitleColor
		cloneTemplateUI.Message.TextColor3 = TextParams.MessageColor
	end
	cloneTemplateUI.Name = DataManagerModule.GenerateUniqueID()
	
	if button1 then
		cloneTemplateUI.Button1.Button1Txt.Text = button1
	else
		cloneTemplateUI.Button1.Visible = false
	end
	
	if button2 then
		cloneTemplateUI.Button2.Button2Txt.Text = button2
	else
		cloneTemplateUI.Button2.Visible = false
	end
	if method1 and not method2 then
		ShowPopupRemoteEvent:FireClient(player, encapsuleFunction(player, method1), params1, nil, nil, cloneTemplateUI)
	elseif method2 and not method1 then
		ShowPopupRemoteEvent:FireClient(player,  nil, nil, encapsuleFunction(player, method2), params2, cloneTemplateUI)
	elseif method1 and method2 then
		ShowPopupRemoteEvent:FireClient(player,  encapsuleFunction(player, method1), params1, encapsuleFunction(player, method2), params2, cloneTemplateUI)
	else
		ShowPopupRemoteEvent:FireClient(player, nil, nil, nil, nil, cloneTemplateUI)
	end
end

--Events listeners
ShowPopupBindableEvent.Event:Connect(ShowPopUpAlert)
ShowPopupRemoteEvent.OnServerEvent:Connect(ShowPopUpAlert)
RE_DestroyPopup.OnServerEvent:Connect(function(player, popup)
	local PlayerGui = player:WaitForChild("PlayerGui"):WaitForChild("StarterGuiSync")
	local PopupAlertGui = PlayerGui:WaitForChild("PopupAlertGui")
	local item = PopupAlertGui.AlertFeed.ScrollingFrame:FindFirstChild(popup.Name)
	if item then
		item:Destroy()
	end
end)

return PopupAlertManager
