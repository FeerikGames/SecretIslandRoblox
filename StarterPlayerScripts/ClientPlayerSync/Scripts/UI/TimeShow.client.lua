local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))

local UIProviderModule = require("UIProviderModule")

local TimeGui = UIProviderModule:GetUI("TimeGui")
local mainFrame = TimeGui:WaitForChild("Frame")
local timeLabel = mainFrame:WaitForChild("Time")

while wait() do
	local seconds = os.date("*t")["sec"]
	local minutes = os.date("*t")["min"]
	local hours = os.date("*t")["hour"]

	if tonumber(seconds)<= 9 then
		seconds = "0".. seconds
	end
	if tonumber(minutes) <= 9 then
		minutes = "0"..minutes
	end
	if tonumber(hours)<= 9 then
		hours = "0"..hours
	end

	timeLabel.Text = hours..":"..minutes..":"..seconds
end