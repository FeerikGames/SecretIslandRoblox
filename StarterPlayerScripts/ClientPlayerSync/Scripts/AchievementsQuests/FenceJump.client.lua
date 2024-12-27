local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerService = game:GetService("Players")

local RE_SpawnDrop = ReplicatedStorage.SharedSync.RemoteEvent.SpawnDrop

local fencesFolder = workspace.Fences
local rewardParticle1 = ReplicatedStorage.SharedSync.Assets.Quests.RewardParticle1
local rewardParticle2 = ReplicatedStorage.SharedSync.Assets.Quests.RewardParticle2
local rewardParticle3 = ReplicatedStorage.SharedSync.Assets.Quests.RewardParticle3

local localPlayer = PlayerService.LocalPlayer

local maxWaitTime = 1
local rewardNumber = 10
local CoolDown = 10

local TouchedConnections1 = {}
local TouchedConnections2 = {}
local TouchedConnections3 = {}
local fencePlayerTouched = {}


local function InstanciateParticle(particlePos)
    local posMod = {Vector3.new(1,0,0),Vector3.new(-1,0,0),Vector3.new(0,0,1),Vector3.new(0,0,-1)}
	for _, pos in pairs(posMod) do
		local particlePart = Instance.new("Part", workspace.Achievements)
		particlePart.Position = particlePos.Position + pos * 5
		particlePart.Size = Vector3.new(1,1,1)
		particlePart.Anchored = true
		particlePart.CanCollide = false
		particlePart.CanTouch = false
		particlePart.CanQuery = false
		particlePart.Transparency = 1
		local rewardEffect1 = rewardParticle1:Clone()
		local rewardEffect2 = rewardParticle2:Clone()
		local rewardEffect3 = rewardParticle3:Clone()
		rewardEffect1.Parent = particlePart
		rewardEffect2.Parent = particlePart
		rewardEffect3.Parent = particlePart
		delay(0.3, function()
			rewardEffect1.Enabled = false
			rewardEffect2.Enabled = false
			rewardEffect3.Enabled = false
			delay(10, function()
				particlePart:Destroy()
			end)
		end)
	end
end

local function Init()
    for _, fence in pairs(fencesFolder:GetChildren()) do

		local detection1 = ReplicatedStorage.SharedSync.Assets.Detection1:Clone()
		detection1.Parent = fence
		detection1.Position = fence.Position + Vector3.new(0, fence.Size.Y/2 + detection1.Size.Y/2,0)
		detection1.Orientation = fence.Orientation
		local detection2 = ReplicatedStorage.SharedSync.Assets.Detection2:Clone()
		detection2.Parent = fence
		detection2.Position = fence.Position - Vector3.new(0, fence.Size.Y/3,0)

		
        TouchedConnections1[_] =  fence.Detection1.Touched:Connect(function(touchedPart)
			if fence:GetAttribute("debounce") then
				return
			end
            local modelTouched = touchedPart:FindFirstAncestorWhichIsA("Model")
			local horse = false
			if modelTouched.Parent == workspace.CreaturesFolder then
				horse = true
			end

            if modelTouched and horse then
                fencePlayerTouched[modelTouched.Name] = {
                    touchedTime = tick(),
                    fenceTouched = fence
                }
				delay(maxWaitTime, function()
					fencePlayerTouched[modelTouched.Name] = nil
				end)
            end
        end)
        TouchedConnections2[_] =  fence.Detection2.Touched:Connect(function(touchedPart)
            local modelTouched = touchedPart:FindFirstAncestorWhichIsA("Model")
            local horse = false
			if modelTouched.Parent == workspace.CreaturesFolder then
				horse = true
			end
            if modelTouched and horse then
                if fencePlayerTouched[modelTouched.Name] then
                    fencePlayerTouched[modelTouched.Name] = nil
					--CoolDown
					fence:SetAttribute("debounce", true)
					local fenceTexture = fence.TextureID
					fence.TextureID = ""
					local fenceColor = fence.Color
					fence.Color = Color3.fromRGB(177, 177, 177)
					delay(CoolDown, function()
						fence:SetAttribute("debounce", nil)
						fence.TextureID = fenceTexture
						fence.Color = fenceColor
					end)
					

					--Reward
                    InstanciateParticle(fence.Detection1)
					local Drops = ReplicatedStorage.SharedSync.Assets.Drops:GetChildren()
					for i=1, math.random(rewardNumber/2, rewardNumber) do
						local rand = math.random(0,100)
						local spawning
						if rand < 45 then
							spawning = Drops[3].Name
						elseif rand < 75 then
							spawning = Drops[2].Name
						else
							spawning = Drops[1].Name
						end
						
						RE_SpawnDrop:FireServer(spawning,1, modelTouched.PrimaryPart.Position,"Ground")
						wait(0.02)
					end
                end
            end
        end)
		TouchedConnections3[_] =  fence.Touched:Connect(function(touchedPart)
            local modelTouched = touchedPart:FindFirstAncestorWhichIsA("Model")
			local horse = false
			if modelTouched.Parent == workspace.CreaturesFolder then
				horse = true
			end

            if modelTouched and horse and touchedPart.Name ~= "Mane_Tail_Body" then
				fencePlayerTouched[modelTouched.Name] = nil
            end
        end)
    end
end



Init()