local HorseAnimator = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local HorseAnimationEvent = ReplicatedStorage.SharedSync.HorseEvents:WaitForChild("HorseAnimationEvent")

local function TerminateConnections(ConnectionTable)
	for _,Connection in pairs(ConnectionTable) do
		Connection:Disconnect()
		print("TERMINATED")
	end
end

--[[
	This function allow to Load Animation found in Folder give in parameter into the Table give in parameter. This method are recursive and search if found
	heriarchy in folder
]]
local function LoadAnimations(Animator,Folder,Table)
	for _,AnimationObject in pairs(Folder:GetChildren()) do
		if AnimationObject:IsA("Animation") then
			Table[AnimationObject.Name] = Animator:LoadAnimation(AnimationObject)
			if AnimationObject:FindFirstChild("PlaybackMultiplier") then
				Table[AnimationObject.Name]:SetAttribute("PlaybackMultiplier",AnimationObject.PlaybackMultiplier.Value)
			end
		else
			Table[AnimationObject.Name] = {}
			LoadAnimations(Animator, AnimationObject, Table[AnimationObject.Name])
		end
	end
end

--[[
	This function allow to find a animation with the name of animation into a table of animation give in parameters.
	Return a AnimationTrack object we can use to play or stop animation.
]]
local function FindAnimationByName(Name,animations,_target)
	for AnimationName,Animation in pairs(_target or animations) do --check here for stop anim
		if typeof(Animation) == "Instance" then
			if AnimationName == Name then
				return Animation
			end
		else
			local Result = FindAnimationByName(Name,nil,Animation)
			if Result then
				return Result
			end
		end
	end
end

--This cache allow to client to store the others creatures and their animation and status animation to make it update by server
local CreaturesCache = {}

local function MakeHumanoidAnimator(CreatureObject)
	print("MAKING NEW ANIMATOR")
	local AnimatorTable = CreatureObject.Animator
	AnimatorTable.AnimationConnections = {}
	local Character = CreatureObject.Instance
	local Humanoid = Character.Humanoid

	
	function AnimatorTable:Play(AnimationName,IsExternal)
		local anim = typeof(AnimationName) == "Instance" and AnimationName.Name or AnimationName
		local AnimationTarget = FindAnimationByName(anim,AnimatorTable.Animations)
		if AnimationTarget then
			AnimationTarget:Play()
			if RunService:IsClient() and not IsExternal then
				HorseAnimationEvent:FireServer("AnimationState",CreatureObject.ID,anim,true)
			end
		else
			warn("Animation not found!",AnimationName)
		end
	end
	function AnimatorTable:Stop(AnimationName,IsExternal)
		local anim = typeof(AnimationName) == "Instance" and AnimationName.Name or AnimationName
		local AnimationTarget = FindAnimationByName(anim,AnimatorTable.Animations)
		if AnimationTarget then
			AnimationTarget:Stop()
			if RunService:IsClient() and not IsExternal then
				HorseAnimationEvent:FireServer("AnimationState",CreatureObject.ID,anim,false)
			end
		else
			warn("Animation not found!",AnimationName)
		end
	end
	function AnimatorTable:SetMovementAnimation(AnimationName,IsExternal)
		local anim = typeof(AnimationName) == "Instance" and AnimationName.Name or AnimationName
		local AnimationTarget = FindAnimationByName(anim,AnimatorTable.Animations)
		if AnimationTarget then
			if AnimatorTable.CurrentMovementAnimation then
				AnimatorTable.CurrentMovementAnimation:Stop()
			end
			AnimatorTable.CurrentMovementAnimation = AnimationTarget
			if RunService:IsClient() and not IsExternal then
				HorseAnimationEvent:FireServer("UpdateMovementAnimation",CreatureObject.ID,anim, false)
			end
		else
			warn("Animation not found!",AnimationName)
		end
	end

	AnimatorTable:Play("Idle")
	AnimatorTable:SetMovementAnimation("Gallop") -- eee?
	
	local LastSlopeAngle = 0
	local LastHipOffset = 0
	AnimatorTable.AnimationConnections.Walking = RunService.Heartbeat:Connect(function()
		if Character.Parent and  CreatureObject.Instance.PrimaryPart then
			local RootPart = CreatureObject.Instance.PrimaryPart
			CreatureObject.Speed = Vector3.new(RootPart.AssemblyLinearVelocity.X,0,RootPart.AssemblyLinearVelocity.Z).Magnitude
			-- Walkspeed
			if AnimatorTable.CurrentMovementAnimation then
				if CreatureObject.Speed > 0.5 then
					local DefaultSpeed = 14
					if AnimatorTable.CurrentMovementAnimation.IsPlaying == true then
						local BaseSpeed = AnimatorTable.CurrentMovementAnimation:GetAttribute("PlaybackMultiplier") or 1
						AnimatorTable.CurrentMovementAnimation:AdjustSpeed(BaseSpeed * (CreatureObject.Speed/DefaultSpeed) / RootPart:GetAttribute("SizeRatio"))
						--print("TEST SPEED ANIMATION MINE", AnimatorTable.CurrentMovementAnimation, AnimatorTable.CurrentMovementAnimation.Speed)
					else
						AnimatorTable:Play(AnimatorTable.CurrentMovementAnimation)
						--AnimatorTable.CurrentMovementAnimation:Play()
						--Horse.Animations.Idle:Stop()
					end
				else
					if AnimatorTable.CurrentMovementAnimation.IsPlaying then
						AnimatorTable:Stop(AnimatorTable.CurrentMovementAnimation)
					end
					--AnimatorTable.CurrentMovementAnimation:Stop()
					--Horse.Animations.Idle:Play()
				end
			end
			---
		else
			TerminateConnections(AnimatorTable.AnimationConnections)
		end
	end)
	AnimatorTable.AnimationConnections.Jumping = Humanoid.Jumping:Connect(function() -- May do a more custom implementation of this
		AnimatorTable:Play("DefaultJump")
	end)
end


function HorseAnimator:Bind(CreatureObject)
	local Humanoid = CreatureObject.Instance:WaitForChild("Humanoid",3)
	if Humanoid then
		print("Binding Animator")
		local Animator = Humanoid:WaitForChild("Animator")
		if Animator then
			if CreatureObject["Animator"] and CreatureObject["Animator"].Unbind then
				
				CreatureObject.Animator:Unbind()
			end
			CreatureObject.Animator = {}
			CreatureObject.Animator.Animations = {}
			
			LoadAnimations(Animator, ReplicatedStorage.SharedSync:WaitForChild("Assets").Animations[CreatureObject.CreatureType], CreatureObject.Animator.Animations)
			--
			MakeHumanoidAnimator(CreatureObject)
			---
			function CreatureObject.Animator:Unbind()
				print("Unbind Animator")
				TerminateConnections(CreatureObject.Animator.AnimationConnections)
			end

			return CreatureObject
		end
	else
		warn("Failed to bind horse, model has no humanoid.")
	end
end

if RunService:IsClient() then
	--[[
		Client event receive by server send by local player have update their animations.
		Here we check if CreatureID receive exist or not and if exist we check if is already stock in CreaturesCache with animations data, if not we make it.
		After we check the Reason of event receive to make the correct update animation and update cache data of animations CreatureID given.

		This is allow to a client to send by server to other clients their actuel animation play and this make the replication animation.
	]]
	HorseAnimationEvent.OnClientEvent:Connect(function(Reason,CreatureID,AnimationName,State)
		local creatures = workspace:WaitForChild("CreaturesFolder"):GetChildren()
		local TargetData
		for _, child in pairs(creatures) do
			if child.CreatureID.Value == CreatureID then
				TargetData = child
			end
		end

		if TargetData then
			local animator = TargetData.Humanoid:WaitForChild("Animator")

			if not CreaturesCache[CreatureID] then
				local animations = {}
				LoadAnimations(animator, ReplicatedStorage.SharedSync:WaitForChild("Assets").Animations[TargetData:GetAttribute("CreatureType")], animations)
				local data = {
					CreatureObject = TargetData,
					Animations = animations,
					CurrentMovementAnimation = FindAnimationByName(AnimationName,animations),
					AnimationConnections = nil
				}
				CreaturesCache[CreatureID] = data
				--Allow client to know speed other client to sync the animation speed
				CreaturesCache[CreatureID].AnimationConnections = RunService.Heartbeat:Connect(function()
					if TargetData and TargetData.Parent and TargetData:FindFirstChild("Humanoid") then
						if TargetData.Humanoid then
							local RootPart = TargetData.PrimaryPart
							local CreatureSpeed = Vector3.new(RootPart.AssemblyLinearVelocity.X,0,RootPart.AssemblyLinearVelocity.Z).Magnitude
							if CreaturesCache[CreatureID].CurrentMovementAnimation then
								if CreatureSpeed > 0.5 then
									if CreaturesCache[CreatureID].CurrentMovementAnimation.IsPlaying == true then
										local BaseSpeed = CreaturesCache[CreatureID].CurrentMovementAnimation:GetAttribute("PlaybackMultiplier") or 1
										CreaturesCache[CreatureID].CurrentMovementAnimation:AdjustSpeed(BaseSpeed * (CreatureSpeed/14) / RootPart:GetAttribute("SizeRatio"))
										--print("test animation adjust ratio", RootPart:GetAttribute("SizeRatio"))
									end
								end
							end
						end
					else
						CreaturesCache[CreatureID].AnimationConnections:Disconnect()
						CreaturesCache[CreatureID] = nil
					end
				end)
			end
			
			if Reason == "UpdateMovementAnimation" then
				if animator then
					local track = FindAnimationByName(AnimationName,CreaturesCache[CreatureID].Animations)
					if CreaturesCache[CreatureID].CurrentMovementAnimation then
						CreaturesCache[CreatureID].CurrentMovementAnimation:Stop()
					end

					CreaturesCache[CreatureID].CurrentMovementAnimation = track
				end

			elseif Reason == "AnimationState" then
				if animator then
					local track = FindAnimationByName(AnimationName,CreaturesCache[CreatureID].Animations)
					if track then
						if State == true then
							track:Play()
						else
							track:Stop()
						end
					end
				end
			end
		end
	end)
else
	--If is Server behavior we make a event to send all other players a event update animation of this local player anim update
	HorseAnimationEvent.OnServerEvent:Connect(function(Player,...)
		for _,TargetPlayer in ipairs(Players:GetPlayers()) do
			if TargetPlayer ~= Player then
				HorseAnimationEvent:FireClient(TargetPlayer,...)
			end
		end
	end)
end

return HorseAnimator