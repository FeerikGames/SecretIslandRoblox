local collectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")


--references
local CloudsMountain = workspace:FindFirstChild("Clouds Mountain")
local rotations = collectionService:GetTagged("RotationTween")

local function CreateModelHandler(type, rotated)
    local Handler = Instance.new("Part", workspace)
    Handler.Name = type .. ":" .. rotated.Name
    Handler.Position = Vector3.new(0,-100,0)
    Handler.Size = Vector3.new(1,1,1)
    Handler.Anchored = true
    Handler.CanCollide = false
    Handler.CanTouch = false
    Handler.CanQuery = false
    Handler.Transparency = 1
    return Handler
end

local function RotateModel(tween, model, Looker)
    task.spawn(function()
        while task.wait(0.2) do
            if model.PrimaryPart ~= nil then
                break
            end
        end
        local primaryPart = model.PrimaryPart
        local isFinished = false
        tween.Completed:Connect(function()
            isFinished = true
        end)
        while task.wait() do
            model:PivotTo(Looker.CFrame.Rotation + primaryPart.CFrame.Position)
            if isFinished then
                break
            end
        end
    end)
end

local function InitRotationTweens()
    for _, rotated in pairs(rotations) do
        local tweenTime = rotated:GetAttribute("Time")
        local orientation = rotated:GetAttribute("Orientation")
        local loop = rotated:GetAttribute("Loop")
        local reverse = rotated:GetAttribute("Reverse")

        local tweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, loop and -1 or 1, reverse)
        local goal = {
            Orientation = orientation
        }

        local rotationTween
        if rotated:IsA("Model") then
            local looker = CreateModelHandler("Rotation", rotated)
            rotationTween = TweenService:Create(looker, tweenInfo, goal)
            RotateModel(rotationTween, rotated, looker)
        else
            rotationTween = TweenService:Create(rotated, tweenInfo, goal)
        end

        rotationTween:Play()
    end
end

collectionService:GetInstanceAddedSignal("RotationTween"):Connect(function(rotated)
    local tweenTime = rotated:GetAttribute("Time")
    local orientation = rotated:GetAttribute("Orientation")
    local loop = rotated:GetAttribute("Loop")
    local reverse = rotated:GetAttribute("Reverse")

    local tweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, loop and -1 or 1, reverse)
    local goal = {
        Orientation = orientation
    }

    local rotationTween
    if rotated:IsA("Model") then
        local looker = CreateModelHandler("Rotation", rotated)
        rotationTween = TweenService:Create(looker, tweenInfo, goal)
        RotateModel(rotationTween, rotated, looker)
    else
        rotationTween = TweenService:Create(rotated, tweenInfo, goal)
    end

    rotationTween:Play()
end)

task.wait(2)
InitRotationTweens()