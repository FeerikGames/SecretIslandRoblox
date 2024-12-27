local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))

--Require
local UIProviderModule = require("UIProviderModule")

local ShowPopupRemoteEvent = ReplicatedStorage.RemoteEvent.ShowPopupAlert

--UI
local PopupAlertGui = UIProviderModule:GetUI("PopupAlertGui")

local destroyPopupCaller = ReplicatedStorage.RemoteFunction:WaitForChild("DestroyPopupCaller")

--[[ PopupAlertGui.ChildAdded:Connect(function(child)
	if not script.Parent.Parent:IsA("ScreenGui") then
		local clone = script:Clone()
		clone.Parent = child
	end
end) ]]

local function ButtonActivated(func, params, obj)
	if func then
		if typeof(func) == "Instance" and func:IsA("RemoteFunction") then
			local remoteFunc = func
			func = function(...)
				print("POPUP FUNC CALLLLLLLLED")
				obj.Visible = false
				return remoteFunc:InvokeServer(...)
			end
		end

		func(table.unpack(params))
		destroyPopupCaller:InvokeServer(obj)
	end
end

ShowPopupRemoteEvent.OnClientEvent:Connect(function(func1, params1, func2, params2, obj)
	coroutine.wrap(function()
		--print("SHOW POPUP CALLED")
		if obj then
			if obj:FindFirstChild("Button1") then
				obj.Button1.Activated:Connect(function()
					--if not have a function make a default behavior to destroy popup
					if not func1 then
						obj:Destroy()
					else
						ButtonActivated(func1, params1, obj)
					end
				end)
			end
			
			if obj:FindFirstChild("Button2") then
				obj.Button2.Activated:Connect(function()
					--if not have a function make a default behavior to destroy popup
					if not func2 then
						obj:Destroy()
					else
						ButtonActivated(func2, params2, obj)
					end
				end)
			end
		end
	end)()
end)

--[[ ShowPopupRemoteEvent.OnClientEvent:Connect(function(func, params, objID)
	if script.Parent.Parent:IsA("ScreenGui") then
		print("SHOW POPUP CALLED")
		local Parent = script.Parent
		if Parent.Name == objID then
			Parent.Button1.Activated:Connect(function()
				Parent:Destroy()
			end)

			Parent.Button2.Activated:Connect(function()
				ButtonActivated(func, params)
			end)
		end
	end
end) ]]