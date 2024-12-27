local AdvertisingSystemModule = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

--Require Modules
local GameDataModule = require("GameDataModule")

--Remote Function
local RemoteFuncFolder = ReplicatedStorage.SharedSync.RemoteFunction

--Setup variables datastore of game
local DataStoreService = game:GetService("DataStoreService")
local AdvertisingDatastore = DataStoreService:GetDataStore(GameDataModule.DatastoreVariables.GameSystem.AdvertisingSystem.Name..GameDataModule.DatastoreVariables.GameSystem.AdvertisingSystem.Version)

local AdvertisingDataSession = {}

function AdvertisingSystemModule.SetupDataSession()
    local listSuccess, pages = pcall(function()
        return AdvertisingDatastore:ListKeysAsync()
    end)
    if listSuccess then
        coroutine.wrap(function()
            pcall(function()
                while true do
                    local items = pages:GetCurrentPage()
                    for _, v in ipairs(items) do
                        local value = AdvertisingDatastore:GetAsync(v.KeyName)
                        if value then
                            --print("Key: ", v.KeyName, "Value: ", value)
                            AdvertisingDataSession[v.KeyName] = value
                        end
                    end
                    if pages.IsFinished then
                        return
                    end
                    pages:AdvanceToNextPageAsync()
                end
            end)
        end)()
    end
end

--[[
    Load Advertising data from Datastore
]]
function AdvertisingSystemModule.LoadAdvertisingData(itemID)
    if itemID ~= "" then
        local data
        local success, err = pcall(function()
            data = AdvertisingDatastore:GetAsync(itemID)
        end)

        if not success then
            data = AdvertisingSystemModule.LoadAdvertisingData(itemID)
        end
        return data
    end
end

--[[
    Save Advertising data into Datastore
]]
function AdvertisingSystemModule.SaveAdvertisingItem(itemID, itemDatas)
    if itemID ~= "" then
        local data = itemDatas

        local success, err = pcall(function()
            AdvertisingDatastore:SetAsync(itemID, data)
        end)

        if not success then
            AdvertisingSystemModule.SaveAdvertisingItem(itemID)
        else
            print("DATA ADVERTISING ITEM SAVE")
            return true
        end
    end
end

local function GetDateFormat()
    local Date = DateTime.now():ToIsoDate()
    Date = string.gsub(Date,"%-", "_")
    Date = string.gsub(Date,"[%s%p%a]+", "_" )
    Date = Date:split("_")
    local ActualDateNumber = tonumber(Date[1]..Date[2]..Date[3])
    return ActualDateNumber
end

local function SetupFramePanelAdvertising()
    local exist = game.Workspace:FindFirstChild("AdvertisingBillboard")
    if exist then
        local Panel = exist.Panel
        --infinite loop to create and check auto switch advertising on panel
        coroutine.wrap(function()
            local tableAdvertising = {}
            while true do
                if #tableAdvertising ~= 1 then
                    tableAdvertising = {}
                end
                
                local publish = 0
                for ID, datas in pairs(AdvertisingDataSession) do
                    if datas["PublishedItem"] then
                        --check date available
                        local actuDate = GetDateFormat()
                        if (datas["DateEndAvailable"] >= actuDate and datas["DateStartAvailable"] <= actuDate) or datas["DateEndAvailable"] == 0 or datas["DateStartAvailable"] == 0 then
                            publish+=1
                            --check if advertising already created
                            local exist = Panel.FrontSurfaceGui:FindFirstChild(ID)
                            local clone
                            if not exist then
                                clone = Panel.FrontSurfaceGui.Template.FrameTemplate:Clone()
                            else
                                clone = exist
                            end
                            
                            --create or update info on frame advertise
                            clone.Name = ID
                            clone.Title.Text = datas["TitleContent"]
                            clone.AdvertisingText.Text = datas["BodyContent"]
                            
                            for imgID, imgData in pairs(datas["Images"]) do
                                --create new images
                                local img = Instance.new("ImageLabel")
                                img.Size = UDim2.fromScale(imgID and imgData.SizeX or 1, imgID and imgData.SizeY or 1)
                                img.Position = UDim2.fromScale(imgID and imgData.PosX or 0, imgID and imgData.PosY or 0)
                                img.Image = imgID and imgData.ImgID or ""
                                img.ZIndex = imgID and imgData.Zindex or 1
                                img.ScaleType = imgData["ScaleType"] and imgData.ScaleType or Enum.ScaleType.Fit
                                img.BackgroundTransparency = 1
                                img.Parent = clone
                            end

                            clone.Parent = Panel.FrontSurfaceGui

                            -- Make the same in the back panel
                            if Panel.BackSurfaceGui:FindFirstChildWhichIsA("Frame") then
                                Panel.BackSurfaceGui:FindFirstChildWhichIsA("Frame"):Destroy()
                            end
                            local cloneBack = clone:Clone()
                            cloneBack.Parent = Panel.BackSurfaceGui

                            --here we check if have 1 element and it's only, break and do nothing because it's alone advertising
                            if #tableAdvertising == 1 then
                                if tableAdvertising[1][4] == ID then
                                    break
                                end
                            end
                            
                            table.insert(tableAdvertising, {clone, datas["DisplayTime"], datas["PublishedItem"], ID})
                        else
                            datas["PublishedItem"] = false
                        end
                    end
                end

                --if on the last tick we don't have pass on any advertise, so we are empty publish advertise so reset table
                if publish == 0 then
                    for _, data in ipairs(tableAdvertising) do
                        data[1].Visible = false
                    end
                    tableAdvertising = {}
                end

                if #tableAdvertising >= 1 then
                    for _, data in ipairs(tableAdvertising) do
                        if data[3] then
                            data[1].Visible = true
                            task.wait(data[2]==0 and 1 or data[2])
                            if #tableAdvertising ~= 1 then
                                data[1].Visible = false
                            end
                        end
                    end
                end
                
                task.wait()
            end
        end)()
    end
end

RemoteFuncFolder.AdvertisingSystem.SaveAdvertisingItemData.OnServerInvoke = function(player, itemID, itemDatas)
    --make a verification of integrity of type data in serverr side before to save it the StockItemsDataSession
    --all data send are a string, but some date need to be a number so check it here
    for index, value in pairs(itemDatas) do
        if index == "DateEndAvailable" or index == "DateStartAvailable" or index == "DisplayTime" then
            if typeof(value) ~= "number" then
                if value == "" then
                    itemDatas[index] = 0
                else
                    itemDatas[index] = tonumber(value)
                end
            end
        end
    end

    --filtering text shwoed to player
    --[[ itemDatas["TitleContent"] = FilteringTextModule.FilteringFromServer(player, itemDatas["TitleContent"])
    itemDatas["BodyContent"] = FilteringTextModule.FilteringFromServer(player, itemDatas["BodyContent"]) ]]

    AdvertisingDataSession[itemID] = itemDatas
    print("ADVERTISING DATA SESSION", AdvertisingDataSession)
    AdvertisingSystemModule.SaveAdvertisingItem(itemID, itemDatas)
end

RemoteFuncFolder.AdvertisingSystem.GetAdvertisingData.OnServerInvoke = function()
    return AdvertisingDataSession
end

AdvertisingSystemModule.SetupDataSession()
SetupFramePanelAdvertising()

return AdvertisingSystemModule