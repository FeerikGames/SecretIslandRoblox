local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))

-- Require Module
local PlayerDataModule = require("ReplicatedPlayerData")
local ToolsModule = require("ToolsModule")
local GameDataModule = require("GameDataModule")
local SoundControllerModule = require("SoundControllerModule")
local UIProviderModule = require("UIProviderModule")

-- Remotes
local RemoteFunction:Folder = ReplicatedStorage.RemoteFunction
local RemoteEvent:Folder = ReplicatedStorage.RemoteEvent

-- UI
local AllButtonsMainMenusGui:ScreenGui = UIProviderModule:GetUI("AllButtonsMainMenusGui")
local WorldTeleportationGui:ScreenGui = UIProviderModule:GetUI("WorldTeleportationGui")
local Background:Frame = WorldTeleportationGui.Background
local AreasFrame:Frame = Background.AreasFrame
local SpawnFrame:Frame = Background.SpawnFrame
local ShowUI:ImageButton = AllButtonsMainMenusGui.TeleportGuiBtn

local Player = game.Players.LocalPlayer

local LocalTeleport:table = game.Workspace:WaitForChild("LocalTeleport"):GetChildren()

-- Default init function visibility behavior of Backgroud
local function VisibilityBackground()
    if Background.Visible then
		ToolsModule.EnableOtherUI(false, {"WorldTeleportationGui"})
	else
		ToolsModule.EnableOtherUI(true, {"WorldTeleportationGui"})
	end
end

--[[ 
    Setup behavior of spawn button clicked to check if player have unlock it or if need to pay it for unlock
]]
local function SpawnButtonBehavior(area:Part, spawn:Part, unlocked:boolean)
    if unlocked then
        -- Check Local attribute of area, if true, it's local teleport else it's teleport place behavior
        if spawn:GetAttribute("Local") then
            -- Teleport player to the spawn selected CFrame
            Player.Character:PivotTo(spawn.CFrame + Vector3.new(0,5,0))
            Background.Visible = false
        else
            RemoteEvent.TeleportEvent:FireServer(true, area.Name, spawn.Name)
        end
    else
        RemoteFunction:WaitForChild("PurchaseWorldTeleport"):InvokeServer(area.Name, spawn.Name)
    end
end

--[[
    Setup behavior of Area main button for prepare spawn button list link to the area selected by player
]]
local function AreaButtonBehavior(area:Folder)
    ToolsModule.DepopulateTypeOfItemFrom("Frame", SpawnFrame.ItemsList)

    SpawnFrame.Title.Text = "- "..area:GetAttribute("DisplayName").." Spawns -"

    -- Setup spawn children of Area when area button are selected
    for _, spawn:Part in pairs(area:GetChildren()) do
        local spawnBtn:Frame = WorldTeleportationGui.Template.Item:Clone()
        spawnBtn.Title.Text = spawn:GetAttribute("DisplayName")
        spawnBtn.LayoutOrder = spawn:GetAttribute("DisplayOrder")
        
        -- If found spawn name in player data teleport unlocked table it's a unlocked part
        local unlocked = table.find(PlayerDataModule.LocalData.WorldTeleportUnlocked, spawn.Name)
        if not unlocked then
            spawnBtn.Locked.Visible = true
            spawnBtn.ImageButton.BackgroundColor3 = Color3.fromRGB(60, 255, 0)
        end

        spawnBtn.Parent = SpawnFrame.ItemsList
        spawnBtn.Visible = true

        spawnBtn.ImageButton.Activated:Connect(function()
            SpawnButtonBehavior(area, spawn, unlocked)
        end)
    end

    -- Setup some fake button for populate content list
    for i=10, 1, -1 do
        local clone:Frame = WorldTeleportationGui.Template.ItemFake:Clone()
        clone.LayoutOrder = 999
        clone.Parent = SpawnFrame.ItemsList
        clone.Visible = true
    end
end

-- Function for init data UI with areas main button and when click on area button it setup the list of spawn link to this area
local function InitDataUI()
    -- Check data gamepass teleport for player
    RemoteFunction:WaitForChild("SetGamepassTeleport"):InvokeServer()
    if RemoteFunction.CheckPlayerHasGamepass:InvokeServer(GameDataModule.Gamepasses.AllTeleportation.ProductID) then
        SpawnFrame.UnlockAllFrame.Visible = false
    end
    SpawnFrame.UnlockAllFrame.BuyPassBtn.Text = "\u{E002}"..GameDataModule.Gamepasses.AllTeleportation.Price

    -- If not exist data teleport local in actual place we don't show button teleport and not setup UI datas
    if #LocalTeleport <= 0 then
        ShowUI.Visible = false
        return
    end
    
    local smallOrder
    for _, area:Folder in pairs(LocalTeleport) do
        -- Setup button list of Area
        local areaBtn:Frame = WorldTeleportationGui.Template.AreaItem:Clone()
        areaBtn.Title.Text = area:GetAttribute("DisplayName")
        areaBtn.ImageButton.Image = area:GetAttribute("ImageDisplay")
        areaBtn.LayoutOrder = area:GetAttribute("DisplayOrder")
        areaBtn.Parent = AreasFrame.ItemsList
        areaBtn.Visible = true

        -- found the first element ordered and show it by default
        if not smallOrder then
            smallOrder = area
        else
            if areaBtn.LayoutOrder < smallOrder:GetAttribute("DisplayOrder") then
                smallOrder = area
            end
        end
        
        areaBtn.ImageButton.Activated:Connect(function()
            AreaButtonBehavior(area)
        end)
    end

    if smallOrder then
        AreaButtonBehavior(smallOrder)
    end
end

-- Little functon button for show or hide UI
ShowUI.Activated:Connect(function()
    Background.Visible = not Background.Visible
    VisibilityBackground()
end)

Background:GetPropertyChangedSignal("Visible"):Connect(VisibilityBackground)

-- Event receive by serve when purchase teleport spawn are make to update gui teleport
RemoteEvent:WaitForChild("ValidPurchaseWorldTeleport").OnClientEvent:Connect(function(area)
    AreaButtonBehavior(area)
end)

SpawnFrame.UnlockAllFrame.BuyPassBtn.Activated:Connect(function()
    game:GetService("MarketplaceService"):PromptGamePassPurchase(Player, GameDataModule.Gamepasses.AllTeleportation.ProductID)
end)

InitDataUI()