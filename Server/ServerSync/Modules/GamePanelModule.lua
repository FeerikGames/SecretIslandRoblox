local GamePanelModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerService = game:GetService("Players")

local Assets = ReplicatedStorage:WaitForChild("SharedSync"):WaitForChild("Assets")

-- make a panel at the CFrame position and orientation and set the Title and Message of it
function GamePanelModule:MakePanelInfo(PanelCFrame, Parent, Title, Message)
	local raceInfoModel = Assets.RaceInfoPanel

	local Panel = raceInfoModel:Clone()
	Panel.Name = "PanelInfo"
	Panel.Parent = Parent

	Panel:PivotTo(PanelCFrame)

	Panel.Panel.Gui.Title.Text = Title
	Panel.Panel.Gui.message.Text = Message
	return Panel
end

-- Changes the panel's CFrame, Title and Message
function GamePanelModule:ChangePanelInfo(panelModel, PanelCFrame, Title, Message)
	local Panel = panelModel

	Panel:PivotTo(PanelCFrame)

	Panel.Panel.Gui.Title.Text = Title
	Panel.Panel.Gui.message.Text = Message
end

-- Give the panel sizes
function GamePanelModule:GetPanelSizes()
    local raceInfoModel = Assets.RaceInfoPanel
    return raceInfoModel.Panel.Size, raceInfoModel.pole.Size
end


-- Fills the passed panel with players data 
-- players is a dictionnary that needs : a "Player" value (dictionnary) with "name" and "userId" in it; a "Placement" int (it will display and set layoutorder); and an "Info" value like the Timing;
function GamePanelModule:fillPanelInfo(panelModel, players)
	if not players then
		return
	end
    local Gui = panelModel.Panel.Gui
	for _, playerItem in pairs(Gui.Participants:GetChildren()) do
		if playerItem:IsA("Frame") then
			playerItem:Destroy()
		end
	end
	for userId, data in pairs(players) do
        local playerIcon, isReady
        if data.Player.userId then
            playerIcon, isReady = PlayerService:GetUserThumbnailAsync(data.Player.userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size352x352)
        end

		local playerItem = Gui.Template.startItem:Clone()
		playerItem.Parent = Gui.Participants
		playerItem.Name = data.Player.name
		playerItem.playerName.Text = data.Player.name
		playerItem.playerIcon.Image = playerIcon
		playerItem.placement.Text = data.Placement
		playerItem.LayoutOrder = data.Placement
		playerItem.info.Text = data.Info
		playerItem.Visible = true
	end
end



return GamePanelModule