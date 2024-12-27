local SocialService = game:GetService("SocialService")
local HttpService = game:GetService("HttpService")
local Player = game.Players.LocalPlayer
local FriendInvocationStones = workspace:WaitForChild("FriendInvocationStones", 5)

-- Function to check whether the player can send an invite
local function canSendGameInvite(sendingPlayer)
	local success, canSend = pcall(function()
		return SocialService:CanSendGameInviteAsync(sendingPlayer)
	end)
	return success and canSend
end

--setup behavior of all summoned friends stone if folder as founded
if FriendInvocationStones then
    for _, portal in pairs(FriendInvocationStones:GetChildren()) do
        portal.Summon.ProximityPrompt.Triggered:Connect(function()
            --we check if player can send invitation (exemple if server have free slots)
            local canInvite = canSendGameInvite(Player)
            if canInvite then
                local success, errorMessage = pcall(function()
                    --setup data of joining game used on server side
                    local data = {
                        senderUserID = Player.UserId,
                        spawnLocation = {portal.SpawnPart.CFrame.Position.X,portal.SpawnPart.CFrame.Position.Y,portal.SpawnPart.CFrame.Position.Z}
                    }
        
                    --prepare invit option with attribute founded on portal for specific teleportation
                    local ExperienceInvitOptions = Instance.new("ExperienceInviteOptions")
                    ExperienceInvitOptions.LaunchData = HttpService:JSONEncode(data)
                    ExperienceInvitOptions.PromptMessage = portal:GetAttribute("PromptMessage")
                    ExperienceInvitOptions.InviteMessageId = portal:GetAttribute("InviteMessageId")
        
                    --open prompt on invitation players with options created
                    SocialService:PromptGameInvite(Player, ExperienceInvitOptions)
                end)
            end
        end)
    end
end