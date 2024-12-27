local FilteringTextModule = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local TextService = game:GetService("TextService")
local Event = ReplicatedStorage.RemoteEvent.FilterMessage

local function filterMessage(msg, fromUser)
    local result
    local success, err = pcall(function()
        result = TextService:FilterStringAsync(msg, fromUser)
    end)
    if success then
        return result
    end
    return false
end

local function getFilteredMessage(textObj, recipient)
	local result
	local success, err = pcall(function()
		result = textObj:GetChatForUserAsync(recipient)
	end)
	if success then
		return result
	end
	return false
end

local function getFilteredMessageNonChatType(textObj)
	local filteredMessage
	local success, errorMessage = pcall(function()
		filteredMessage = textObj:GetNonChatStringForBroadcastAsync()
	end)
	if success then
		return filteredMessage
	elseif errorMessage then
		print("Error filtering message:", errorMessage)
	end
	return false
end

local function onSendMessage(sender, message, from, type)
	if message ~= "" then
		local filteredMessage = filterMessage(message, sender.UserId)
 
		if filteredMessage then
			for _, player in pairs(game.Players:GetPlayers()) do
				local filteredMessage = type == "Chat" and getFilteredMessage(filteredMessage, player.UserId) or getFilteredMessageNonChatType(filteredMessage)
				Event:FireClient(player, filteredMessage, sender, from)
			end
		end
	end
end

function FilteringTextModule.FilteringFromServer(sender, message)
	if message ~= "" then
		-- Filter the incoming message and send the filtered message
		local messageObject = filterMessage(message, sender.UserId)
		local filteredText = ""
		filteredText = getFilteredMessageNonChatType(messageObject)
		return filteredText
	end
end

Event.OnServerEvent:Connect(onSendMessage)


return FilteringTextModule