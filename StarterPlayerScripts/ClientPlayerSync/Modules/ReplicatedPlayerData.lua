-- Stratiz 2022
local DataReplication = {}

local GetRemoteEvent = _G.require("GetRemoteEvent")
local GetRemoteFunction = _G.require("GetRemoteFunction")

local DataUpdateEvent = GetRemoteEvent("DataUpdateEvent")
local InitDataGet = GetRemoteFunction("DataGetFunction")
DataReplication.LocalData = {}

local Binds = {}
function DataReplication:Changed(Path:string, ToFire:(any, any, string) -> ())
	table.insert(Binds,{Path = Path, ToFire = ToFire})
	--print("TEST SHOW BINDS", Binds)
	return {
		Disconnect = function()
			for index,Bind in pairs(Binds) do
				local StringStart,_ = string.find(Path or "",Bind.Path)
				if Bind.Path == Path or StringStart == 1 then
					table.remove(Binds,index)
					--print("TEST SHOW BINDS AFTER DISCONNECT", Binds)
					return
				end
			end
		end
	}
end

function DataReplication:Init()
	self.LocalData = InitDataGet:InvokeServer()
    print("Client fetched inital player data from server.")
	DataUpdateEvent.OnClientEvent:Connect(function(Path,Value)
		--print("Data updated: "..(Path or "ALL"))
		local Current = self.LocalData
		local OldValue
		local PathKeys = Path and Path:split(".") or {}
		if #PathKeys == 0 then
			Current = Value
		end
		for Index,NextKey in pairs(PathKeys) do
			if type(Current) == "table" then
				if Index >= #PathKeys then
					OldValue = Current[NextKey]
					Current[NextKey] = Value
				elseif Current[NextKey] then
					Current = Current[NextKey]
				else
					warn("Path error | "..Path)
					warn("Data may be out of sync, re-syncing with server...")
					self.LocalData= InitDataGet:InvokeServer()
				end
			else
				warn("Invalid path | "..Path)
			end
		end
		if #PathKeys == 0 then
			self.LocalData= Value
		end
		---
		--print(self.Data)
		-- Changed event
		for _,Bind in pairs(Binds) do
			local StringStart,_ = string.find(Path or "",Bind.Path)
			if Bind.Path == Path or StringStart == 1 then
				Bind.ToFire(OldValue,Value,Path)
			end
		end
	end)
end

return DataReplication