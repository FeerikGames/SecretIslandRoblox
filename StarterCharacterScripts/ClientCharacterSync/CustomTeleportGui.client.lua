local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local Players = game:GetService("Players")
local controls = require(game:GetService("Players").LocalPlayer.PlayerScripts.PlayerModule):GetControls()
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- Get remote event created by the teleport module
local teleportEvent = ReplicatedStorage.RemoteEvent:WaitForChild("TeleportEvent")

local TipsData = {
	"rbxassetid://11235006492///Level Up to a FIRE SUPRA to get into the Volcano!",
	"rbxassetid://11234271928///Level Up to an ICE SUPRA to go to the top of the mountain!",
	"rbxassetid://11234217077///You can teleport directly to your friends!",
	"rbxassetid://11234217077///Look for the horse shaped cloud in the sky to find Coins and more!",
	"rbxassetid://11234217077///Level Up to a WATER SUPRA to explore the waters!",
	"rbxassetid://11234217077///Level Up to a LIGHT SUPRA to explore the tunnels!",
	"rbxassetid://11234217077///A GROUNG SUPRA can push heavy rocks!",
	"rbxassetid://11234217077///Explore faster by becoming a GIANT SUPRA!",
}

local LoadingScreen = ReplicatedFirst:FindFirstChild("LoadingScreen"):Clone()
LoadingScreen.Enabled = false
LoadingScreen.Parent = PlayerGui

local Frame = LoadingScreen:WaitForChild("Frame")
local BackgroundTips = Frame:WaitForChild("BackgroundTips")

local TipsImg = BackgroundTips:WaitForChild("Img")
local TipsText = BackgroundTips:WaitForChild("Tips")
local BlackScreen = BackgroundTips:WaitForChild("BlackScreen")
local loadingRing = BackgroundTips:WaitForChild("Loading")

local function SelectRandomTips()
	local selectedRandomTips = TipsData[math.random(1,#TipsData)]
	TipsText.Text = string.split(selectedRandomTips, "///")[2]
	TipsImg.Image = string.split(selectedRandomTips, "///")[1]
end

-- Set the teleport GUI in preparation for teleport
TeleportService:SetTeleportGui(LoadingScreen)

teleportEvent.OnClientEvent:Connect(function(playersTable, enable)
	local tweenInfoTips = TweenInfo.new(2, Enum.EasingStyle.Linear)
	local tweenTips = TweenService:Create(BlackScreen, tweenInfoTips, {BackgroundTransparency = 1})
	tweenTips:Play()

	local tweenInfo = TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1)
	local tween = TweenService:Create(loadingRing, tweenInfo, {Rotation = 360})
	tween:Play()

	--allow to change tips all 5s until background are not invisible
	task.spawn(function()
		repeat
			SelectRandomTips()
			task.wait(10)
		until not BackgroundTips.Visible
	end)

	-- Enable or disable teleport GUI for valid players
	if table.find(playersTable, player) then
		if enable then
			LoadingScreen.Enabled = true
		else
			BackgroundTips.Visible = false
			LoadingScreen:Destroy()
		end
		controls:Disable()
	end
end)