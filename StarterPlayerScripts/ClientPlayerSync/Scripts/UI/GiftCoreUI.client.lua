local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))

--Require
local UIProviderModule = require("UIProviderModule")
local ToolsModule = require("ToolsModule")
local PlayerDataModule = require("ReplicatedPlayerData")
local UIAnimationModule = require("UIAnimationModule")
local SoundControllerModule = require("SoundControllerModule")

--UI
local AllButtonsMainMenusGui = UIProviderModule:GetUI("AllButtonsMainMenusGui")
local GiftTradeGui:ScreenGui = UIProviderModule:GetUI("GiftTradeGui")
local Background:Frame = GiftTradeGui.GiftBackground

-- Remotes
local RemoteEvent = ReplicatedStorage.RemoteEvent

--[[
    Function to create visual item with template for List select item to send in the gift
    and make the behavior of click item to show is selected and clean other select item.
]]
local function MakeItemToSendTemplate(id, obj)
    local clone = GiftTradeGui.Template.ItemToSendTemplate:Clone()
    clone.Name = id
    clone:SetAttribute("TextHover", obj.DisplayName)
    clone.ItemType.Text = obj.Type
    clone.ItemImg.Image = obj.ImageID
    clone.Parent = Background.ItemToSend.List
    clone.Visible = true

    clone.Button.Activated:Connect(function()
        warn("click", clone.Name)
        clone.ValidFrame.Visible = true
        for _, child in pairs(Background.ItemToSend.List:GetChildren()) do
            if child:IsA("Frame") then
                if clone ~= child then
                    child.ValidFrame.Visible = false
                end
            end
        end
    end)
end

function MakeCategoriesButtons()
    for _, button in pairs(Background.ItemToSend.ButtonsList:GetChildren()) do
        if button:IsA("TextButton") then
            button.Activated:Connect(function()
                if button.Name == "Genes" or button.Name == "Sparks" then
                    local result = PlayerDataModule.LocalData.GenesCollection
                    if result then
                        ToolsModule.DepopulateTypeOfItemFrom("Frame", Background.ItemToSend.List)
                        for id, gene in pairs(result) do
                            if button.Name == "Sparks" and gene.Type == "Effect" then
                                MakeItemToSendTemplate(id, gene)
                            end
                            if button.Name == "Genes" and gene.Type ~= "Effect" then
                                MakeItemToSendTemplate(id, gene)
                            end
                        end
                    end
                else
                    local result = PlayerDataModule.LocalData.Inventory
                    if result then
                        ToolsModule.DepopulateTypeOfItemFrom("Frame", Background.ItemToSend.List)
                        for id, obj in pairs(result) do
                            local clone = GiftTradeGui.Template.ItemToSendTemplate:Clone()
                            clone.Name = id
                            --clone:SetAttribute("TextHover", obj.DisplayName)
                            clone.ItemType.Text = ""
                            clone.ItemImg.Image = obj.ImageID
                            clone.Parent = Background.ItemToSend.List
                        end
                    end
                end
            end)
        end
    end
end

Background.SendBtn.Activated:Connect(function()
    -- Temporary fake send data just close ui
    Background.Visible = false

    local co
    co = UIProviderModule:GetUI("PopupAlertGui").ChildAdded:Connect(function(child)
        UIAnimationModule.ParticleExplosionUI(GiftTradeGui.Template.StarsParticle, child)
        co:Disconnect()
    end)

    RemoteEvent.ShowPopupAlert:FireServer(
        "",
        "GIFT SENT!",
        ToolsModule.AlertPriority.Annoucement,
        nil,
        ToolsModule.AlertTypeButton.OK
    )
end)

-- Event for visibility of UI
Background:GetPropertyChangedSignal("Visible"):Connect(function()
	if Background.Visible then
		ToolsModule.EnableOtherUI(false, {"GiftTradeGui"})
	else
		ToolsModule.EnableOtherUI(true, {"GiftTradeGui"})
	end
end)

MakeCategoriesButtons()

-- Make by default completion of List itemToSend on Genes
local result = PlayerDataModule.LocalData.GenesCollection
if result then
    ToolsModule.DepopulateTypeOfItemFrom("Frame", Background.ItemToSend.List)
    for id, gene in pairs(result) do
        if gene.Type ~= "Effect" then
            MakeItemToSendTemplate(id, gene)
        end
    end
end