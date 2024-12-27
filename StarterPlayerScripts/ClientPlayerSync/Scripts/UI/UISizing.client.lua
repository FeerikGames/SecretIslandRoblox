local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))

local StarterGui = game:GetService("StarterGui")
local Player = game.Players.LocalPlayer

--RequireModule
local ToolsModule = require("ToolsModule")
local UIProviderModule = require("UIProviderModule")

--UI
local Uis = UIProviderModule:GetAllUI()


local CloseUiButtons = {}

local camera = workspace.CurrentCamera

local CloseUiButtonRatioSize = 0.03

local function GetAllCloseUiButtons()
    for _, Ui in pairs(Uis) do
        for i, UiObject in pairs(Ui:GetDescendants()) do
            if UiObject.Name == "CloseUI" then
                table.insert(CloseUiButtons, UiObject)
            end
        end
    end
    print(CloseUiButtons)
end

local function SetCloseUiButtonSize()
    local screenSize = camera.ViewportSize
    local buttonsSize = screenSize.X * 0.03

    print(buttonsSize)

    for index, button in pairs(CloseUiButtons) do
        button.Size = UDim2.fromOffset(buttonsSize, buttonsSize)
    end

end


task.wait(3)
GetAllCloseUiButtons()

SetCloseUiButtonSize()