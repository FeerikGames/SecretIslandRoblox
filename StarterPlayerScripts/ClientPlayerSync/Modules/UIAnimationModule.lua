local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

-- Require
local UIProviderModule = require("UIProviderModule")
local GameDataModule = require("GameDataModule")
local ToolsModule = require("ToolsModule")
local SoundControllerModule = require("SoundControllerModule")

-- Remotes
local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent

--Animation Parameters :

local IconFeedBackAnimationScale = 6
local IconFeedBackAnimationRotation = 360

local FeedBackScreenGui = UIProviderModule:GetUI("FeedBackScreenGui")
--Creature On Fire Screen Feedback
local OnFireFeedback = FeedBackScreenGui:WaitForChild("OnFireFeedback")
local OnFireTween1
local OnFireTween2

--Creature On Frozen Screen Feedback
local OnFrozenFeedback = FeedBackScreenGui:WaitForChild("OnFrozenFeedback")
local OnFrozenTween

local UIAnimationModule = {}

local UIDebounceTimer = {}

function UIAnimationModule.InitTweenParamIconFeedBackAnimation(Img)
    local tweenInfo = TweenInfo.new(0.3,Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0, true, 0)
	local BaseRotation = Img.Rotation
	local BaseSize = Img.Size
	local Goal = {}
	Goal.Rotation = Img.Rotation + IconFeedBackAnimationRotation
	Goal.Size = UDim2.fromScale(Img.Size.X.Scale * IconFeedBackAnimationScale, Img.Size.Y.Scale * IconFeedBackAnimationScale)
	local ecusTween = TweenService:Create(Img, tweenInfo, Goal)
	ecusTween.Completed:Connect(function(playbackState)
		Img.Rotation = BaseRotation
		Img.Size = BaseSize
	end)
	return ecusTween
end

function UIAnimationModule.InitTweenParamBarAnimation(Bar, endValue, maxValue)
	local tweenInfo = TweenInfo.new(0.1,Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0, true, 0)
	local Goal = {}
	Goal.Size = UDim2.fromScale(endValue/maxValue, Bar.Size.Y.Scale)
	local barTween = TweenService:Create(Bar, tweenInfo, Goal)
	barTween.Completed:Connect(function(playbackState)
		Bar.Size = UDim2.fromScale(endValue/maxValue, Bar.Size.Y.Scale)
	end)
	return barTween
end

function UIAnimationModule.StartTextNumberIncrementAnimation(textObject, OldValue, NewValue, durationInFrame)
    for i = durationInFrame, 1, -1 do
		textObject.Text = ToolsModule.DotNumber(math.round(OldValue + ((NewValue - OldValue) / i)))
		task.wait()
	end
end

function UIAnimationModule.BouncyCurrencyBarFeedback(Frame:Frame)
	local ratio = 1.12
    local tweenInfo = TweenInfo.new(0.3,Enum.EasingStyle.Bounce, Enum.EasingDirection.Out, 0, true, 0)
	local BaseSize = Frame.Size
	local Goal = {}
	Goal.Size = UDim2.fromScale(Frame.Size.X.Scale * ratio, Frame.Size.Y.Scale * ratio)
	local tween = TweenService:Create(Frame, tweenInfo, Goal)
	tween.Completed:Connect(function(playbackState)
		if playbackState == Enum.PlaybackState.Completed then
			Frame.Size = BaseSize
		end
	end)
	return tween
end

--[[
	This function allow to make animation of currency like Ecus Feez show on screen UI player with little animation and
	cumulation of collecting currency (stay show max 1second if player continue to collect currency, the timer is reset)
]]
function UIAnimationModule.FeedbackCurrencyDrop(currencyType, oldAmount, newAmount)
	if not UIDebounceTimer[currencyType] then
		local info = TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0)

		local frame = FeedBackScreenGui.Template.AnimateCurrencyUI:Clone()
		frame.Name = currencyType
		frame.Parent = FeedBackScreenGui
		frame.Icon.Image = GameDataModule.DropCollectablesWithBorders[currencyType]
		frame.IconBorder.Image = GameDataModule.DropCollectablesWithBorders[currencyType]
		frame.Title:SetAttribute("Value", 0 + (newAmount-oldAmount))
		frame.Title.Text = ToolsModule.DotNumber(frame.Title:GetAttribute("Value"))

		frame.Position = UDim2.fromScale(0.5+Random.new():NextNumber(-0.15,0.15), 0.55 + Random.new():NextNumber(-0.1,0.05))
		frame.Visible = true

		UIDebounceTimer[currencyType] = {
			Timer = os.time(),
			UI = frame
		}

		local goals = {Position = UDim2.fromScale(frame.Position.X.Scale, frame.Position.Y.Scale - Random.new():NextNumber(0,0.2))}
		local tween = TweenService:Create(frame, info, goals)
		tween:Play()

		task.spawn(function()
			while UIDebounceTimer[currencyType] do
				if os.time() - UIDebounceTimer[currencyType].Timer > 2 then
					UIDebounceTimer[currencyType].UI:Destroy()
					UIDebounceTimer[currencyType] = nil
				end
				task.wait()
			end
		end)
	else
		UIDebounceTimer[currencyType].Timer = os.time()
		local val = UIDebounceTimer[currencyType].UI.Title:GetAttribute("Value") + (newAmount-oldAmount)
		UIDebounceTimer[currencyType].UI.Title:SetAttribute("Value", val)
		UIDebounceTimer[currencyType].UI.Title.Text = ToolsModule.DotNumber(UIDebounceTimer[currencyType].UI.Title:GetAttribute("Value"))
	end
end

--[[
	Function to animate UI screen with feedback of fire area damaged and CrackedLava ground make to player or animals
]]
function UIAnimationModule.OnFireFeedbackUI(value:boolean, FireRace:boolean)
	if value then
		if not OnFireTween1 and not OnFireTween2 then
			local OnFireTweenInfo = TweenInfo.new(
				0.5, -- Time
				Enum.EasingStyle.Linear, -- EasingStyle
				Enum.EasingDirection.Out, -- EasingDirection
				-1, -- RepeatCount (when less than zero the tween will loop indefinitely)
				true, -- Reverses (tween will reverse once reaching it's goal)
				0 -- DelayTime
			)
			OnFireTween1 = TweenService:Create(OnFireFeedback.Img1, OnFireTweenInfo, {ImageTransparency = 0.3})
			OnFireTween2 = TweenService:Create(OnFireFeedback.Img2, OnFireTweenInfo, {ImageTransparency = 0.3})
	
			--Feedback screen when player or creature walk in fire
			if FireRace then
				OnFireFeedback.Visible = false
			else
				OnFireFeedback.Visible = true
			end
	
			OnFireFeedback.Img1.ImageTransparency = 0.9
			OnFireFeedback.Img2.ImageTransparency = 0.9
			OnFireTween1:Play()
			OnFireTween2:Play()
		end
	else
		--StopFeedback screen if player or creature are not in fire
		OnFireFeedback.Visible = false
		if OnFireTween1 then
			OnFireTween1:Cancel()
			OnFireTween1 = nil
		end
		if OnFireTween2 then
			OnFireTween2:Cancel()
			OnFireTween2 = nil
		end
	end
end

--[[
	Function to animate UI screen with feedback of frozen area damaged make to player or animals
]]
function UIAnimationModule.OnFrozenFeedbackUI(value:boolean, IceRace:boolean)
	if value then
		if not OnFrozenTween then
			local OnFrozenTweenInfo = TweenInfo.new(
				0.5, -- Time
				Enum.EasingStyle.Linear, -- EasingStyle
				Enum.EasingDirection.Out, -- EasingDirection
				-1, -- RepeatCount (when less than zero the tween will loop indefinitely)
				true, -- Reverses (tween will reverse once reaching it's goal)
				0 -- DelayTime
			)
			OnFrozenTween = TweenService:Create(OnFrozenFeedback.Img, OnFrozenTweenInfo, {ImageTransparency = 0.4})
	
			-- Feedback screen when player or creature walk in area Mountain Ice
			if IceRace then
				OnFrozenFeedback.Visible = false
			else
				OnFrozenFeedback.Visible = true
			end
	
			OnFrozenFeedback.Img.ImageTransparency = 0
			OnFrozenTween:Play()
		end
	else
		-- StopFeedback screen if player or creature are not in moutain ice
		OnFrozenFeedback.Visible = false
		if OnFrozenTween then
			OnFrozenTween:Cancel()
			OnFrozenTween = nil
		end
	end
end

function UIAnimationModule.AnimateNbImageRandomUP(TargetUI, image, quantity)
	task.spawn(function()
		for i=1, quantity do
			local tweenInfo1 = TweenInfo.new(Random.new():NextNumber(0.5, 1.5), Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0)

			local clone = image:Clone()
			clone.Parent = TargetUI
			clone.Visible = true
			clone.Position = UDim2.fromScale(Random.new():NextNumber(0.2,0.8), Random.new():NextNumber(0.7,1))

			local t1 = TweenService:Create(clone, tweenInfo1, {Position = UDim2.fromScale(clone.Position.X.Scale, clone.Position.Y.Scale - 1)})
			t1:Play()
			t1.Completed:Connect(function()
				clone:Destroy()
			end)
			task.wait(Random.new():NextNumber(0.01, 0.06))
		end
	end)
end

function UIAnimationModule.AnimateFadeInOutTextObjectUI(TargetUI:TextLabel)
	task.spawn(function()
		local tweenInfo1 = TweenInfo.new(1.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0)

		--TargetUI.Position = UDim2.fromScale(0.5, 0.5)
		TargetUI.TextTransparency = 1
		TargetUI.UIStroke.Transparency = 1

		local t1 = TweenService:Create(TargetUI, tweenInfo1, {TextTransparency = 0})
		t1:Play()
		TweenService:Create(TargetUI.UIStroke, tweenInfo1, {Transparency = 0}):Play()

		t1.Completed:Connect(function()
			task.wait(.5)
			TargetUI:Destroy()
		end)
	end)
end

--[[
	This function allow to make a continue feedback animation of ExpProgressBar of animal to show effect when player can evolve it's creature. 
		We have a bouncy animation on progress bar and shine animation continue.
		We can call this function with isStop parameter to true for disable and desactivate animation on progressbar.
]]
local TweenExpProgressBarConnection = {}
function UIAnimationModule.AnimateExpProgressBarFeedback(expProgressBar, isStop)
	-- Check if call is make to disable animation
	if isStop then
		for _, v in pairs(TweenExpProgressBarConnection) do
			v:Cancel()
		end
		expProgressBar.Shine.UIGradient.Offset = Vector2.new(-1.5,0)
		TweenExpProgressBarConnection = {}

		return
	end

	-- Not setup animation if already exist
	if #TweenExpProgressBarConnection ~= 0 then
		return
	end
	
	--image size bounce effect
	local TweenInformationImage = TweenInfo.new(0.3, Enum.EasingStyle.Quint,Enum.EasingDirection.Out,-1,true, 3)
	local GoalImage = {
		Size = UDim2.fromScale(expProgressBar.Size.X.Scale - 0.025, expProgressBar.Size.Y.Scale),
	}
	local TweenImage = TweenService:Create(expProgressBar, TweenInformationImage, GoalImage)
	TweenImage:Play()
	table.insert(TweenExpProgressBarConnection, TweenImage)

	--shiny effect
	expProgressBar.Shine.UIGradient.Offset = Vector2.new(-1.5,0)
	local TweenInformationShine = TweenInfo.new(1, Enum.EasingStyle.Sine,Enum.EasingDirection.Out,-1,false, 1)
	local GoalShine = {
		Offset = Vector2.new(1.5, 0),
	}
	local TweenShine = TweenService:Create(expProgressBar.Shine.UIGradient, TweenInformationShine, GoalShine)
	TweenShine:Play()
	table.insert(TweenExpProgressBarConnection, TweenShine)
end

--[[

]]
function UIAnimationModule.ParticleExplosionUI(imgParticle, gui)
	SoundControllerModule:CreateSound("ReadyToEvolve")
	-- At the same time we make a explosion ui particle
	task.spawn(function()
		-- Tween info about rotation image particle
		local tweenInfo2 = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false, 0)

		-- Make NB particle need behavior of One particle Img
		for i=1, 75 do
			-- Set random of duration tween positionning dstination
			local rPos = Random.new():NextNumber(0.3,1)
			-- Set tween position
			local tweenInfo1 = TweenInfo.new(rPos, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0)

			--set tween transparency of particle depending of random value base on total distance of particle
			local tweenTransparency = TweenInfo.new(Random.new():NextNumber(0.3,1), Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, (rPos - (rPos/math.random(2,4))))
			
			-- Make clone particle and set all default value before launch animation
			local clone = imgParticle:Clone()
			clone.Parent = gui
			clone.Visible = true
			clone.Position = UDim2.fromScale(0.5,0.5)
			local rSize = Random.new():NextNumber(0.2, 0.5)
			clone.Size = UDim2.fromScale(rSize,rSize)

			-- Launch all tween (pos, transparency and rotation) with goal needed for this particle img
			local t1 = TweenService:Create(clone, tweenInfo1, {Position = UDim2.fromScale(Random.new():NextNumber(-0.5,1.5), Random.new():NextNumber(-3,3))})
			local t2 = TweenService:Create(clone, tweenInfo2, {Rotation = 360})
			local t3 = TweenService:Create(clone, tweenTransparency, {ImageTransparency = 1})
			t1:Play()
			t2:Play()
			t3:Play()

			-- Clear when pos twen is reach by particle
			t1.Completed:Connect(function(playbackState)
				if playbackState == Enum.PlaybackState.Completed then
					t1:Cancel()
					t3:Cancel()
					clone:Destroy()
				end
			end)
		end
	end)
end

--[[
	function to launch short animation when animal reach max EXP and are ready to evolve.
		Animation show quickly big the progressbar exp and make a UI particle Explosion stars with sound and launch the
		AnimateExpProgressBarFeedback after finish it.
]]
function UIAnimationModule.ReadyToEvolveAnimation()
	local gui = UIProviderModule:GetUI("CreatureInteractionGui")
	local expProgressBar = gui.ExpProgressBar
	local originSizeBar = expProgressBar.Size

	-- Play sound sparkles to show ready to evolve
	SoundControllerModule:CreateSound("ReadyToEvolve")

	-- Make spawn function to animate quickly bouncy exp progressbar to BIG
	task.spawn(function()
		warn("SET ANIMATION BIG EXP")
		local tween = TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0)
		local t1 = TweenService:Create(expProgressBar, tween, {Size = UDim2.fromScale(0.4,0.2)})
		t1:Play()
		t1.Completed:Connect(function(playbackState)
			if playbackState == Enum.PlaybackState.Completed then
				expProgressBar.Size = originSizeBar
			end
		end)
	end)

	-- At the same time we make a explosion ui particle
	task.spawn(function()
		-- Tween info about rotation image particle
		local tweenInfo2 = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false, 0)

		-- Make NB particle need behavior of One particle Img
		for i=1, 75 do
			-- Set random of duration tween positionning dstination
			local rPos = Random.new():NextNumber(0.3,1)
			-- Set tween position
			local tweenInfo1 = TweenInfo.new(rPos, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0)

			--set tween transparency of particle depending of random value base on total distance of particle
			local tweenTransparency = TweenInfo.new(Random.new():NextNumber(0.3,1), Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, (rPos - (rPos/math.random(2,4))))
			
			-- Make clone particle and set all default value before launch animation
			local clone = gui.Template.StarsParticle:Clone()
			clone.Parent = gui.ExpBackgroundAnimation
			clone.Visible = true
			clone.Position = UDim2.fromScale(0.5,0.5)
			local rSize = Random.new():NextNumber(0.5, 2.5)
			clone.Size = UDim2.fromScale(rSize,rSize)

			-- Launch all tween (pos, transparency and rotation) with goal needed for this particle img
			local t1 = TweenService:Create(clone, tweenInfo1, {Position = UDim2.fromScale(Random.new():NextNumber(-0.5,1.5), Random.new():NextNumber(-3,3))})
			local t2 = TweenService:Create(clone, tweenInfo2, {Rotation = 360})
			local t3 = TweenService:Create(clone, tweenTransparency, {ImageTransparency = 1})
			t1:Play()
			t2:Play()
			t3:Play()

			-- Clear when pos twen is reach by particle
			t1.Completed:Connect(function(playbackState)
				if playbackState == Enum.PlaybackState.Completed then
					t1:Cancel()
					t3:Cancel()
					clone:Destroy()
				end
			end)
		end

		-- Little wait and launch the feedback continusly of ExpProgressbar
		task.wait(0.5)
		UIAnimationModule.AnimateExpProgressBarFeedback(expProgressBar)
	end)
end

-- Remote event for launch animation ready when server have validate animal exp is ready to evolve
RemoteEvent.CreatureEvolution.ReadyToEvolve.OnClientEvent:Connect(UIAnimationModule.ReadyToEvolveAnimation)

return UIAnimationModule