local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerService = game:GetService("Players")

local AmbianceParticules = {}

--references

local AmbianceParticulesFolder = ReplicatedStorage.SharedSync.Assets.AmbianceParticules

local particules = {
    VolcanoArea = AmbianceParticulesFolder.Volcano,
    MountainArea = AmbianceParticulesFolder.Snow,
    FireDamageArea = AmbianceParticulesFolder.Volcano,
}

local localPlayer = PlayerService.LocalPlayer
local ParticulesSpawned


function AmbianceParticules:CleanParticules()
    if ParticulesSpawned then
        ParticulesSpawned:Destroy()
        ParticulesSpawned = nil
    end
end

function AmbianceParticules:ActivateAmbianceParticulesFolder(Type)
    AmbianceParticules:CleanParticules()
    if Type == "Default" then
        return
    end
    local Attachment = localPlayer.Character.PrimaryPart:FindFirstChild("ParticulesAttachment")
    if not Attachment then
        Attachment = Instance.new("Attachment", localPlayer.Character.PrimaryPart)
        Attachment.Name = "ParticulesAttachment"
    end
    local ambianceParticules = particules[Type]:Clone()
    ambianceParticules.Position = localPlayer.Character.PrimaryPart.Position
    ambianceParticules.Anchored = false
    ambianceParticules.Parent = localPlayer.Character
    ambianceParticules.AlignPosition.Attachment1 = Attachment
    ambianceParticules.AlignOrientation.Attachment1 = Attachment
    ParticulesSpawned = ambianceParticules
end

return AmbianceParticules