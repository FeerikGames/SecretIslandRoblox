local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))

--Require
local UIProviderModule = require("UIProviderModule")

local PopupAlertGui = UIProviderModule:GetUI("PopupAlertGui")
local Parent = PopupAlertGui.AlertFeed
local ScrollingFrame = Parent.ScrollingFrame
local DeleteAllBtn = Parent.DeleteAllBtn
local NbAlert = Parent.NbAlert

local RE_DestroyPopup = ReplicatedStorage.RemoteEvent.DestroyPopup

ScrollingFrame.ChildAdded:Connect(function(child)
	NbAlert.Value += 1
end)

ScrollingFrame.ChildRemoved:Connect(function(child)
	NbAlert.Value -= 1

	if NbAlert.Value <= 0 then
		NbAlert.Value = 0
	end
	
	RE_DestroyPopup:FireServer(child)
end)

DeleteAllBtn.Activated:Connect(function()
	for _, obj in pairs(ScrollingFrame:GetChildren()) do
		if obj:IsA("Frame") then
			obj:Destroy()
		end
	end
end)

--init
local nbChild = ScrollingFrame:GetChildren()
NbAlert.Value = #nbChild - 1 --because gridlayout in child