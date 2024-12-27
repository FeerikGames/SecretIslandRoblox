local DataManagerModule = {}

local HttpService = game:GetService("HttpService")

local DataTypes = {
	number = "NumberValue", --TODO check how make a diff with Int and Number (pblm create by farms value progress and wetness)
	boolean = "BoolValue",
	string = "StringValue"
};

function DataManagerModule.GenerateUniqueID()
	return HttpService:GenerateGUID(true)
end

function DataManagerModule.GetLengthOfDictionnary(dico)
	local nbElement = {}
	for key, _ in pairs(dico) do
		table.insert(nbElement, key)
	end

	return #nbElement
end

--[[
	This method allow to clone a dictionary
]]
function DataManagerModule.CopyTable(original)
	local copy = {}
	for key, value in pairs(original) do
		copy[key] = value
	end
	return copy
end

--[[
	This method allow to convert color3 into table with 3 int
]]
function DataManagerModule.convertColor3ForSaveData(color)
	return {r = color.r, g = color.g, b = color.b}
end

--[[
	This method convert a table of 3 int in the datastore to new Color3
]]
function DataManagerModule.loadColorFromDataStore(t)
	return Color3.new(t.r, t.g, t.b)
end

--[[
	This is a recursive method to convert data from dictionary into folder and data value.
	Method check if folder and value already exist and if yes, replace value of exist object,
	if not, create object and set value
]]
function DataManagerModule.convertDictionaryToFolders(dataDictionary, parentFolder)
	for index, value in pairs(dataDictionary) do
		local indexExist = parentFolder:FindFirstChild(index)
		if not indexExist then
			if index:match("Color") then
				local color = Instance.new("Color3Value")
				color.Name = index
				color.Value = DataManagerModule.loadColorFromDataStore(value)
				color.Parent = parentFolder

			elseif (DataTypes[typeof(value)]) then
				if index == "Sparks" then
					local data_data = Instance.new("NumberValue")
					data_data.Name = index
					data_data.Value = value
					data_data.Parent = parentFolder
				else
					local data_data = Instance.new(DataTypes[typeof(value)])
					data_data.Name = index
					data_data.Value = value
					data_data.Parent = parentFolder
				end

			elseif typeof(value) == "table" then
				local folder = Instance.new("Folder", parentFolder)
				folder.Name = index
				DataManagerModule.convertDictionaryToFolders(value, folder)
			end
		else
			if index:match("Color") then
				indexExist.Value = DataManagerModule.loadColorFromDataStore(value)

			elseif (DataTypes[typeof(value)]) then
				indexExist.Value = value
			elseif typeof(value) == "table" then
				DataManagerModule.convertDictionaryToFolders(value, indexExist)
			end
		end
	end
end

--[[
	This is a recursive method to convert folders and data value into dictionary
]]
function DataManagerModule.convertDataToDictionary(dataValueFolder, dataTable)
	for index_data, dataFolder in pairs(dataValueFolder:GetChildren()) do
		if dataFolder:IsA("Folder") then
			local dataTypeTable = {}
			dataTable[dataFolder.Name] = dataTypeTable
			DataManagerModule.convertDataToDictionary(dataFolder, dataTypeTable)
		elseif dataFolder:IsA("Color3Value") then
			dataTable[dataFolder.Name] = DataManagerModule.convertColor3ForSaveData(dataFolder.Value)
		else
			if not dataFolder:IsA("BasePart") and not dataFolder:IsA("Model") and not dataFolder:IsA("Decal") then
				dataTable[dataFolder.Name] = dataFolder.Value
			end
		end
	end
end

--[[
	This is a recursive method to convert folders and data value into dictionary depending of the number of data need
	Make for Client UI who need nb horses to display into horsesCollection UI. It's use for a system pages with index and next or previous value to show
	This function return the size of datafolder to say at the client what is the max value to not make error out of table.
]]
function DataManagerModule.convertNbDataToDictionary(dataCreaturesCollection, dataToReturn, nbValue, index, filterChoose)

	local dataFiltered = {}
	--if filters are selected we filter horse data to make a datafiltered as datafolder who use for page system. Allow to return datafiltered directly to adapte page system with filter system existing
	if filterChoose then
		if DataManagerModule.GetLengthOfDictionnary(filterChoose) > 0 then
			for index, dataCreature in pairs(dataCreaturesCollection) do
				local filterIsOk = true
				--check data corresponding filter or not
				for filterName, filterData in pairs(filterChoose) do
					if tostring(dataCreature[filterName].Value) ~= filterData then
						filterIsOk = false
					end
				end
				if filterIsOk then
					--adding data if coreresponding all filter selected by player
					dataFiltered[index] = dataCreature
				end
			end
		end
	end

	--were we chose if we use the data filtered or the data folder to get horses datas
	local dataSelected = (filterChoose and DataManagerModule.GetLengthOfDictionnary(filterChoose) > 0) and dataFiltered or dataCreaturesCollection
	local i=index and index or 1
	
	for _, dataCreature in ipairs(dataSelected) do
		dataToReturn[_] = dataCreature
		if i == nbValue then
			break
		else
			i+=1
		end
	end

	return DataManagerModule.GetLengthOfDictionnary(dataSelected)
end

function DataManagerModule.RecursiveCopy(dataTable)
	local tableCopy = {}
	for index, value in pairs(dataTable) do
		if type(value) == "table" then
			value = DataManagerModule.RecursiveCopy(value)
		end
		tableCopy[index] = value
	end

	return tableCopy
end

return DataManagerModule
