local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local Assets = ReplicatedStorage.SharedSync.Assets

local UIProviderModule = require("UIProviderModule")

local player = game.Players.LocalPlayer
local Humanoid = player.Character.Humanoid

local StaminaPlayerUI = Assets.ShowMaintenanceBar:Clone()
StaminaPlayerUI.Name = "StaminaPlayerUI"
StaminaPlayerUI.Enabled = true
StaminaPlayerUI.Adornee = player.Character.HumanoidRootPart
StaminaPlayerUI.Parent = player.PlayerGui
StaminaPlayerUI.ExtentsOffsetWorldSpace = Vector3.new(0,3,0)
StaminaPlayerUI.ProgressBar.Size = UDim2.fromScale(0.9,0.07)
StaminaPlayerUI.ProgressBar.Goal.Value = Humanoid.MaxHealth
StaminaPlayerUI.ProgressBar.Progress.Value = Humanoid.Health
StaminaPlayerUI.ProgressBar.Info.Text = StaminaPlayerUI.ProgressBar.Progress.Value.." / "..StaminaPlayerUI.ProgressBar.Goal.Value

local function ProgressBarAnimation(progressBar, progress, goal)
    local valueIncrement = progress/goal
    local oneOverProgress
    if valueIncrement == 0 then
        --can't do 1/0, just make oneOverProgress = 0
        oneOverProgress = 0
    else
        oneOverProgress = 1/valueIncrement
    end

    --here we setup the color of progress bar depending of pourcent of empty
    if valueIncrement <= 0.3 then
        progressBar.Clipping.Top.ImageColor3 = Color3.fromRGB(255, 0, 0)
    elseif valueIncrement > 0.3 and valueIncrement < 0.7 then
        progressBar.Clipping.Top.ImageColor3 = Color3.fromRGB(222, 200, 0)
    else
        progressBar.Clipping.Top.ImageColor3 = Color3.fromRGB(0, 222, 0)
    end

    progressBar.Clipping.Size = UDim2.new(valueIncrement, 0, 1, 0) -- set Clipping size to {progress, 0, 1, 0}
    progressBar.Clipping.Top.Size = UDim2.new(oneOverProgress, 0, 1, 0) -- set Top size to {1/progress, 0, 1, 0}
end

while true do
    if Humanoid.Health == Humanoid.MaxHealth then
        StaminaPlayerUI.ProgressBar.Visible = false
    else
        StaminaPlayerUI.ProgressBar.Visible = true
    end
    StaminaPlayerUI.ProgressBar.Goal.Value = Humanoid.MaxHealth
    StaminaPlayerUI.ProgressBar.Progress.Value = Humanoid.Health
	StaminaPlayerUI.ProgressBar.Info.Text = StaminaPlayerUI.ProgressBar.Progress.Value.." / "..StaminaPlayerUI.ProgressBar.Goal.Value
    ProgressBarAnimation(StaminaPlayerUI.ProgressBar, StaminaPlayerUI.ProgressBar.Progress.Value, StaminaPlayerUI.ProgressBar.Goal.Value)
	Humanoid.HealthChanged:Wait()
end