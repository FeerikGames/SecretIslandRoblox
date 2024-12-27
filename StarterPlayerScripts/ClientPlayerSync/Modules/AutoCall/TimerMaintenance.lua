local PlayerService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local Player = PlayerService.LocalPlayer

local TimerMaintenance = {}
local TimerRemoteEvent = ReplicatedStorage.RemoteEvent.TimerMaintenance

local function LaunchTimer(MAINTENANCE_INTERVAL)
	while wait(MAINTENANCE_INTERVAL) do
		print("CHECK MAINTENANCE HORSES")
		TimerRemoteEvent:FireServer()
	end
end

TimerRemoteEvent.OnClientEvent:Connect(LaunchTimer)

return TimerMaintenance
