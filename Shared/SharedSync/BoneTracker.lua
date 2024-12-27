-- Stratiz 9/29/2021
-- Built to solve the issue of being unable to get bone positions

local BoneTracker = {}

local RunService = game:GetService("RunService")

local Debug = false
local DebugDebris = nil
local function MakeDebugPart()
	if Debug then
		if not DebugDebris then
			DebugDebris = Instance.new("Folder")
			DebugDebris.Name = "_BoneTrackDebugDebris"
			DebugDebris.Parent = workspace
		end
		local Part = Instance.new("Part")
		Part.Shape = Enum.PartType.Ball 
		Part.Anchored = true
		Part.CanCollide = false
		Part.Size = Vector3.new(0.5,0.5,0.5)
		Part.Transparency = 0.4
		Part.Parent = DebugDebris
		return Part
	end
end

local BoneTables = {}

--[[BoneTracker.Bones = setmetatable({},{
	__index = function(Table,Index)
		local TargetTable = BoneTables[Index]

	end
})]]

function BoneTracker:TrackBones(Model)
	local BoneRoot = Model
	if not Model:IsA("Bone") then
		BoneRoot = Model:FindFirstChildOfClass("Bone",true)
	end
	if BoneRoot then
		print("Tracking bones.")
		BoneTables[Model] = {
			[BoneRoot.Name] = {
				Bone = BoneRoot,
				CFrame = CFrame.new(0,0,0),
				ChildBones = {},
				DebugPart = MakeDebugPart()
			}
		}
		local BoneTable = BoneTables[Model]
		local function AddBone(BoneData)
			for _,NextBone in pairs(BoneData.Bone:GetChildren()) do
				if NextBone:IsA("Bone") then
					BoneData.ChildBones[NextBone.Name] = {
						Bone = NextBone,
						CFrame = NextBone.CFrame,
						ChildBones = {},
						DebugPart = MakeDebugPart()
					}
					AddBone(BoneData.ChildBones[NextBone.Name])
				end
			end
		end
		AddBone(BoneTable[BoneRoot.Name])
		
		local function UpdateBoneData(BoneData,CurrentCFrameTotal)
			local Offset = BoneData.Bone.Transform
			--if BoneData.Bone:IsA("Motor6D")
			local NewCFrame = CurrentCFrameTotal * BoneData.Bone.CFrame * Offset
			BoneData.CFrame = NewCFrame
			if BoneData.DebugPart then
				BoneData.DebugPart.CFrame = NewCFrame + Vector3.new(0,10,0)
			end
			for _,NextBoneData in pairs(BoneData.ChildBones) do
				UpdateBoneData(NextBoneData,NewCFrame)
			end
		end
		
		local TrackerConnection = nil
		TrackerConnection = RunService.PreAnimation:Connect(function()
			if not BoneTable[BoneRoot.Name].Bone.Parent then
				TrackerConnection:Disconnect()
				return
			end
			local RootPartCFrame = BoneTable[BoneRoot.Name].Bone.Parent.CFrame --* BoneTable[BoneRoot.Name].Bone.CFrame:Inverse()
			--.profilebegin("Bone Tracking (50 Players)")
			--for i=1,50 do
			UpdateBoneData(BoneTable[BoneRoot.Name],RootPartCFrame  )--(RootPartCFrame + (RootPartCFrame.Position - BoneTable[BoneRoot.Name].Bone.WorldPosition)) * BoneTable[BoneRoot.Name].Bone.CFrame:Inverse())-- + Vector3.new(0,10,0)) --RootPartCFrame:PointToObjectSpace(BoneTable[BoneRoot.Name].Bone.WorldPosition)
			--end
			--debug.profileend()
		end)
			-- Here is where the code to be profiled should be
		return BoneTable
	end
end

return BoneTracker
