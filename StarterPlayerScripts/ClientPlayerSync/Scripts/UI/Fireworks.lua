--!strict

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui

local FireworksGui = PlayerGui:FindFirstChild("Fireworks") or Instance.new("ScreenGui", PlayerGui)
FireworksGui.Name = "Fireworks"
FireworksGui.IgnoreGuiInset = true
FireworksGui.ResetOnSpawn = false
FireworksGui.DisplayOrder = 5

local Random = Random.new()

export type Fireworks = {
	new:(UDim2?)->(ObjectClass),
	CreateFireworks:(UDim2)->({}),
	CreateSound:()->(Sound),
	GetRandomPositionOnScreen:(UDim2?)->(UDim2)
}

export type ObjectClass = {

}

local Fireworks = {}

Fireworks.Settings = {
	EmitCount = 25,
	Distance = 0.7,
	Sounds = {10066947742},
}

local Settings = Fireworks.Settings

function Fireworks.CreateSound()
	local Sound = Instance.new("Sound")
	Sound.SoundId = "rbxassetid://" .. Settings.Sounds[math.random(#Settings.Sounds)]
	Sound.Parent = SoundService
	Sound.Volume = 0.1
	return Sound
end

function Fireworks.CreateFireworks(Position)
	local Particles = {}
	for i = 1, Settings.EmitCount do
		local Frame = Instance.new("ImageLabel")
        Frame.Image = "rbxassetid://13460462375"
        Frame.BackgroundTransparency = 1
		Frame.Name = "Firework"
		Frame.Position = Position
		Frame.Size = UDim2.fromOffset(35,35)
		Frame.Visible = false
		Frame.Parent = FireworksGui
		table.insert(Particles, Frame)
	end
	return Particles
end

function Fireworks.GetRandomPositionOnScreen(Position)
	if Position then
		local X, Y = Position.X.Scale, Position.Y.Scale
		return UDim2.fromScale(X + Random:NextNumber(-Settings.Distance,Settings.Distance), Y + Random:NextNumber(-Settings.Distance,Settings.Distance))
	else
		return UDim2.fromScale(Random:NextNumber(0.25,0.75), Random:NextNumber(0.25,0.75))
	end
end

function Fireworks.new(Position) : ObjectClass
	local Firework = {}

	local StartPosition = Position or Fireworks.GetRandomPositionOnScreen()
	local Particles = Fireworks.CreateFireworks(StartPosition)

	local Sound = Fireworks.CreateSound()
	Sound:Play()

	for _, Particle in pairs(Particles) do
		Particle.Visible = true
        local RotData: number = Particle.Rotation
		local Tween = TweenService:Create(
			Particle,
			TweenInfo.new(1.5),
			{
                Position = Fireworks.GetRandomPositionOnScreen(Particle.Position),
                Rotation = RotData + Random:NextNumber(-100,100),
                ImageTransparency = 2}
		)
		Tween:Play()
		Tween.Completed:Connect(function()
			Particle:Destroy()
		end)
	end

	local Firework:ObjectClass = Firework
	return Firework
end

local Fireworks:Fireworks = Fireworks
return Fireworks