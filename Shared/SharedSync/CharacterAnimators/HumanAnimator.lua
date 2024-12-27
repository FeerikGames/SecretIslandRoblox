local HumanAnimator = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local AnimationsFolder = ReplicatedStorage.SharedSync:WaitForChild("Assets").Animations.Human

local HorseEvents = ReplicatedStorage.SharedSync.HorseEvents

local function Lerp(v0, v1, t)
	return v0 + t * (v1 - v0)
end

function IsCharacterHorse(Character)
	if Character and not Character:FindFirstChild("LeftHand") and Character:FindFirstChild("RootPart") then
		return true
	end
	return false
end

--[[
	This function allow to return if player are on his creature summoned.
]]
local function CheckIfMountedCreature()
	local exist = workspace.CreaturesFolder:FindFirstChild("Creature_"..game.Players.LocalPlayer.Name)
	if exist then
		exist:WaitForChild("Seat")
		if exist.Seat:FindFirstChild("Rider") then
			if exist.Seat.Rider.Value then
				return true
			end
		end
	end

	return false
end

local function GetCreatureInvoked()
	local exist = workspace.CreaturesFolder:FindFirstChild("Creature_"..game.Players.LocalPlayer.Name)
	if exist then
		return exist
	end

	return false
end

local function MakeHumanoidAnimator(Human)
	Human.AnimationConnections = {}
	local Character = Human.Instance
	local Humanoid = Character.Humanoid
	
	Human.Animations.Idle:Play()
	Human.CurrentMovementAnimation = Human.Animations.Walk
	
	local LastSlopeAngle = 0
	local LastHipOffset = 0
	Human.AnimationConnections.Walking = RunService.Heartbeat:Connect(function()

		local RootPart = Human.Instance.PrimaryPart
		Human.Speed = Vector3.new(RootPart.AssemblyLinearVelocity.X,0,RootPart.AssemblyLinearVelocity.Z).Magnitude
		-- Walkspeed
		if Human.CurrentMovementAnimation then
			if Human.Speed > 0.5 then
				local DefaultSpeed = 16
				if Human.CurrentMovementAnimation.IsPlaying == true then
					-- Check if Playerback attribute exist and apply speed multiplcator to current animation to sync player anim speed with creature anim speed
					local BaseSpeed = Human.CurrentMovementAnimation:GetAttribute("PlaybackMultiplier") or 1
					Human.CurrentMovementAnimation:AdjustSpeed(BaseSpeed * (Human.Speed/DefaultSpeed))
				else
					if not CheckIfMountedCreature() then
						Human.CurrentMovementAnimation = Human.Animations.Walk
					end
					Human.CurrentMovementAnimation:Play()
					--Horse.Animations.Idle:Stop()
				end
			else
				if Human.CurrentMovementAnimation.IsPlaying then
					Human.CurrentMovementAnimation:Stop()

					if CheckIfMountedCreature() then
						Human.Animations.Idle:Stop()
						Human.Animations["IdleOnMount"..GetCreatureInvoked():GetAttribute("CreatureType")]:Play()
					else
						Human.Animations.Idle:Play()
						if GetCreatureInvoked() then
							Human.Animations["IdleOnMount"..GetCreatureInvoked():GetAttribute("CreatureType")]:Stop()
						end
					end
				end
				--Horse.Animations.Idle:Play()
			end
		end
		---

	end)
	Human.AnimationConnections.Jumping = Humanoid.Jumping:Connect(function() -- May do a more custom implementation of this
		Human.Animations.Jump:Play()
		task.wait(0.1)
		if Humanoid:GetState() == Enum.HumanoidStateType.Freefall then
			Human.Animations.Falling:Play()
		end
	end)
	Human.AnimationConnections.Falling = Humanoid.FreeFalling:Connect(function(State)
		if State == false then
			Human.Animations.Falling:Stop()
			Human.Animations.Jump:Stop()
		end
	end)

	--[[
		This event allow to know and change animation of player when he are on his creature to play good animation style
	]]
	Human.AnimationConnections.ChangeStyle = HorseEvents.CreatureChangeStyle.OnClientEvent:Connect(function(style)
		if CheckIfMountedCreature() then
			if style == "Walk" then
				Human.CurrentMovementAnimation:Stop()
				Human.CurrentMovementAnimation = Human.Animations["WalkOnMount"..GetCreatureInvoked():GetAttribute("CreatureType")]
				
			elseif style == "Gallop" then
				Human.CurrentMovementAnimation:Stop()
				Human.CurrentMovementAnimation = Human.Animations["RunOnMount"..GetCreatureInvoked():GetAttribute("CreatureType")]

			elseif style == "Mount" then
				Human.CurrentMovementAnimation:Stop()
				Human.CurrentMovementAnimation = Human.Animations["RunOnMount"..GetCreatureInvoked():GetAttribute("CreatureType")]
				Human.Animations.Idle:Stop()
				Human.Animations["IdleOnMount"..GetCreatureInvoked():GetAttribute("CreatureType")]:Play()
			end
			if Human.Speed > 0.5 then
				Human.CurrentMovementAnimation:Play()
			end
		end
	end)
end


function HumanAnimator:Bind(Character)
	if not IsCharacterHorse(Character) then
		local Humanoid = Character:WaitForChild("Humanoid",3)
		if Humanoid then
			repeat
				task.wait()
			until Character:IsDescendantOf(workspace)
			print("Binding human")
			local Animator = Humanoid:WaitForChild("Animator")
			if Animator then
				local Human = {Instance = Character,Animations = {},Type = "Human"}
				-- Load animations
				local function LoadAnimations(Folder,Table)
					for _,AnimationObject in pairs(Folder:GetDescendants()) do
						if AnimationObject:IsA("Animation") then
							-- Save Loadanimation result in table animations human for player
							Table[AnimationObject.Name] = Animator:LoadAnimation(AnimationObject)

							-- Check if animation save have a child PlaybackMultiplier and set attribute if yes to use it later
							if AnimationObject:FindFirstChild("PlaybackMultiplier") then
								Table[AnimationObject.Name]:SetAttribute("PlaybackMultiplier",AnimationObject.PlaybackMultiplier.Value)
							end
						end
					end
				end
				LoadAnimations(AnimationsFolder,Human.Animations)
				--
				MakeHumanoidAnimator(Human)
				return Human
			end
		else
			warn("Failed to bind horse, model has no humanoid.")
		end
	end
end

return HumanAnimator
