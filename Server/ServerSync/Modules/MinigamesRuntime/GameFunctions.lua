local MinigameFunctions = {}

MinigameFunctions.ActivePlayers = {}
MinigameFunctions.MinigameExemption = {"Balloons"}

function MinigameFunctions:CanPlay(Player, MinigameName)
    local IsExempt = table.find(self.MinigameExemption, MinigameName)
    if IsExempt then
        print("MinigamesLog: Player has JOINED EXEMPT minigame - " .. MinigameName)
        return true
    end

    local UserId = Player.UserId
    if self.ActivePlayers[UserId] then
        if self.ActivePlayers[UserId] == MinigameName then
            self.ActivePlayers[UserId] = nil
            print("MinigamesLog: Player has LEFT minigame - " .. MinigameName)
            return true
        end
        print("MinigamesLog: Player attempted to LEAVE WRONG minigame - " .. MinigameName)
        return false
    else
        self.ActivePlayers[UserId] = MinigameName
        print("MinigamesLog: Player has JOINED minigame - " .. MinigameName)
        return true
    end
end

function MinigameFunctions:GetObjectCount(Folder, Exempt)
    local Total = 0
    for _, Object in pairs(Folder) do
        if Object == Exempt then
            continue
        end

        Total += 1
    end
    return Total
end

function MinigameFunctions:GetRandomPosition(YOffset)
    local Offset = math.random(-50, 50)
    return Vector3.new(Offset, YOffset or Offset, Offset)
end

return MinigameFunctions