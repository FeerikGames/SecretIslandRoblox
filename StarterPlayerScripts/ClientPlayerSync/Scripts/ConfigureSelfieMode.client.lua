local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SelfieMode = require(ReplicatedStorage:WaitForChild("SelfieMode"))

--[[SelfieMode.closeSelfieMode()
SelfieMode.openSelfieMode()
SelfieMode.isSelfieModeOpen()]]

SelfieMode.configure({
	disableCharacterMovement = true
})

SelfieMode.actionActivated:Connect(function(action)
	print(action.name, "activated")
end)

SelfieMode.actionDeactivated:Connect(function(action)
	print(action.name, "deactivated")
end)
