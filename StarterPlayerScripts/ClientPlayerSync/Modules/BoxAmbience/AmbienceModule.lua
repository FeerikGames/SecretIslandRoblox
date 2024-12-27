local Tween = game:GetService("TweenService")

local AmbienceModule = {}
AmbienceModule.__index = AmbienceModule

function AmbienceModule.new(Presets)
	local self = setmetatable({}, AmbienceModule)
	
	self.Presets = Presets
	
	return self
end

function AmbienceModule:ChangeAmbience(Zone)
	if self.AtmosphereTween then
		if self._AtmosphereTweenCompleted then
			self._AtmosphereTweenCompleted:Disconnect()
		end
		
		self.AtmosphereTween:Pause()
		self.AtmosphereTween:Destroy()
	end
	
	if self.ColorCorrectionTween then
		if self._ColorCorrectionCompleted then
			self._ColorCorrectionCompleted:Disconnect()
		end
		
		self.ColorCorrectionTween:Pause()
		self.ColorCorrectionTween:Destroy()
	end

    if self.LightningSettingTween then
        if self._LightningSettingCompleted then
			self._LightningSettingCompleted:Disconnect()
		end
		
		self.LightningSettingTween:Pause()
		self.LightningSettingTween:Destroy()
    end
	
	if self.Presets:FindFirstChild(Zone) then
		local NewPreset = self.Presets:FindFirstChild(Zone)
		
		for _, v in pairs(game.Lighting:GetChildren()) do
			if v.Name ~= "Presets" and v.Name ~="Atmosphere" and v.Name ~= "ColorCorrection" then
				v:Destroy()
			end
		end

		for _, v in pairs(NewPreset:GetChildren()) do
			if v.Name ~= "Atmosphere" and v.Name ~= "ColorCorrection" then
				local Copy = v:Clone()
				Copy.Parent = game.Lighting
			end
		end
		
		local AtmosphereTweenInfo = TweenInfo.new(.75)
		self.AtmosphereTween = Tween:Create(game.Lighting.Atmosphere, AtmosphereTweenInfo,
		{
			Color = NewPreset.Atmosphere.Color, Decay = NewPreset.Atmosphere.Decay,
			Glare = NewPreset.Atmosphere.Glare, Haze = NewPreset.Atmosphere.Haze,
			Density = NewPreset.Atmosphere.Density, Offset = NewPreset.Atmosphere.Offset
		})
		
		self.ColorCorrectionTween = Tween:Create(game.Lighting.ColorCorrection, AtmosphereTweenInfo,
		{
			TintColor = NewPreset.ColorCorrection.TintColor,
			 Saturation = NewPreset.ColorCorrection.Saturation,
			Contrast = NewPreset.ColorCorrection.Contrast, Brightness = NewPreset.ColorCorrection.Brightness
		})

		self.LightningSettingTween = Tween:Create(game.Lighting, AtmosphereTweenInfo,
		{
			Ambient = NewPreset.LightingSettings.Ambient.Value,
			Brightness = NewPreset.LightingSettings.Brightness.Value,
			OutdoorAmbient = NewPreset.LightingSettings.OutdoorAmbient.Value,
			GeographicLatitude = NewPreset.LightingSettings.GeographicLatitude.Value,
			ShadowSoftness = NewPreset.LightingSettings.ShadowSoftness.Value,
			EnvironmentDiffuseScale = NewPreset.LightingSettings.EnvironmentDiffuseScale.Value,
			ColorShift_Top = NewPreset.LightingSettings.ColorShift_Top.Value,
			EnvironmentSpecularScale = NewPreset.LightingSettings.EnvironmentSpecularScale.Value,
			ColorShift_Bottom = NewPreset.LightingSettings.ColorShift_Bottom.Value,
			GlobalShadows = NewPreset.LightingSettings.GlobalShadows.Value,
			ClockTime = NewPreset.LightingSettings.ClockTime.Value,
			ExposureCompensation = NewPreset.LightingSettings.ExposureCompensation.Value,
		})

		self._AtmosphereTweenCompleted = self.AtmosphereTween.Completed:Connect(function(PBS)
			if PBS == Enum.PlaybackState.Completed then
				self.AtmosphereTween:Destroy()
				self._AtmosphereTweenCompleted:Disconnect()
			end
		end)
		
		self ._ColorCorrectionCompleted = self.ColorCorrectionTween.Completed:Connect(function(PBS)
			if PBS == Enum.PlaybackState.Completed then
				self.ColorCorrectionTween:Destroy()
				self._ColorCorrectionCompleted:Disconnect()
			end
		end)

        self ._LightningSettingCompleted = self.LightningSettingTween.Completed:Connect(function(PBS)
			if PBS == Enum.PlaybackState.Completed then
				self.LightningSettingTween:Destroy()
				self._LightningSettingCompleted:Disconnect()
			end
		end)
		
		self.AtmosphereTween:Play()
		self.ColorCorrectionTween:Play()
        self.LightningSettingTween:Play()
	end
end

function AmbienceModule:Destroy()
	if self._AtmosphereTweenCompleted then
		self._AtmosphereTweenCompleted:Disconnect()
	end
	
	if self.AtmosphereTween then
		self._AtmosphereTween:Destroy()
	end
	
	if self._ColorCorrectionCompleted then
		self._ColorCorrectionCompleted:Disconnect()
	end
	
	if self.ColorCorrectionTween then
		self.ColorCorrectionTween:Destroy()
	end

    if self._LightningSettingCompleted then
		self._LightningSettingCompleted:Disconnect()
	end
	
	if self.LightningSettingTween then
		self.LightningSettingTween:Destroy()
	end
	
	self = nil
	return nil
end

return AmbienceModule