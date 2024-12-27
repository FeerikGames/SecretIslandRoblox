local Player = game.Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui"):WaitForChild("StarterGuiSync")
local controls = require(game:GetService("Players").LocalPlayer.PlayerScripts.PlayerModule):GetControls()

--local BreedingGui = PlayerGui:WaitForChild("BreedingGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")

local function DisableTrackingInSystem()
	local existTrackCrystal = workspace:FindFirstChild("CrystalTracking")
	if existTrackCrystal then
		existTrackCrystal:Destroy()
	end
end

Player.Character:WaitForChild("HumanoidRootPart").Touched:Connect(function(hit)
	if not Player:GetAttribute("AreInActivity") then
		if hit.Name == "BreedingField" then
			DisableTrackingInSystem()
			ReplicatedStorage.RemoteEvent.ActivateFusionSystem:FireServer(Player)
		elseif hit.Name == "AuctionHouseField" then
			DisableTrackingInSystem()
			ReplicatedStorage.RemoteEvent.AuctionHouse.ChangeCameraPlayer:FireServer()
		elseif hit.Name == "TalentGeneratorSystemField" then
			DisableTrackingInSystem()
			ReplicatedStorage.RemoteEvent.TalentsGeneratorSystem.ActivateSystem:FireServer()
		elseif hit:GetAttribute("LocalTeleport") then
			local isActive = hit:GetAttribute("LocalTeleport")
			if isActive then
				controls:Disable()
				for _, target in pairs(hit.Parent:GetChildren()) do
					local isGate = target:GetAttribute("IsGate")
					if isGate and target ~= hit then
						Player.Character.PrimaryPart.CFrame = target.CFrame * CFrame.new(Vector3.new(0,0,-5))
					end
				end
				controls:Enable()
			end
		end
	end
end)
