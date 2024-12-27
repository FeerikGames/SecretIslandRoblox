local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))
local TweenService = game:GetService("TweenService")

--Require
local UIProviderModule = require("UIProviderModule")

--UI
local AllButtonsMainMenusGui = UIProviderModule:GetUI("AllButtonsMainMenusGui")
local SubMenu = AllButtonsMainMenusGui:WaitForChild("SubMenu")
local CloseBtn = AllButtonsMainMenusGui:WaitForChild("CloseBtn")

local infoToogleMenu = TweenInfo.new(.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.In)
local tweenOpenToogleMenu = TweenService:Create(SubMenu, infoToogleMenu, {Visible = true})
local tweenCloseToogleMenu = TweenService:Create(SubMenu, infoToogleMenu, {Visible = false})
local debounce = false

local function AnimationToogle()
    if not SubMenu.Visible then
        if debounce then return end
        debounce = true
        AllButtonsMainMenusGui.ToogleBtn.Visible = false
        tweenOpenToogleMenu:Play()
        tweenOpenToogleMenu.Completed:Wait()
        CloseBtn.Visible = true
        debounce = false
    else
        if debounce then return end
        debounce = true
        CloseBtn.Visible = false
        SubMenu.Visible = false
        AllButtonsMainMenusGui.ToogleBtn.Visible = true
        debounce = false
    end
end

AllButtonsMainMenusGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    if not AllButtonsMainMenusGui.Enabled then
        CloseBtn.Visible = false
        SubMenu.Visible = false
        AllButtonsMainMenusGui.ToogleBtn.Visible = true
    end
end)

CloseBtn.Activated:Connect(function()
    CloseBtn.Visible = false
    SubMenu.Visible = false
    AllButtonsMainMenusGui.ToogleBtn.Visible = true
end)

for _, child in pairs(SubMenu:GetChildren()) do
    if child:IsA("Button") then
        child.Activated:Connect(AnimationToogle)
    end
end

AllButtonsMainMenusGui.ToogleBtn.Activated:Connect(AnimationToogle)