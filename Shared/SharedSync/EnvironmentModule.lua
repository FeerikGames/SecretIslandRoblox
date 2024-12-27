export type EnvironmentModule = {

}

type Place = {
    id:number,
    name:string
}

type Environment = {
    name:string,
    places:{},
    indexedPlacesByName:{[string] : Place},
    variablesByName:{[string] : any}
}

type EnvironmentsMap = {
    [string] : Environment
}

local EnvironmentModule:EnvironmentModule = {}

local environments:EnvironmentsMap = {}
local indexedEnvironmentsNamesByPlaceId = {}

 function GetOrCreateEnvironment(environmentName:string)
    local environment:Environment = environments[environmentName]

    if environment == nil then
        environment = {
            name=environmentName,
            places={},
            indexedPlacesByName={},
            variablesByName={}
        }

        environments[environmentName]  = environment
    end

    return environment
end

function EnvironmentModule.RegisterPlace(environmentName:string, placeId:number, placeName:string)
    local environment:Environment = GetOrCreateEnvironment(environmentName)

    environment.places[placeId] = {
        id=placeId,
        name=placeName
    }

    environment.indexedPlacesByName[placeName] = placeId
    indexedEnvironmentsNamesByPlaceId[placeId] = environmentName
end

function EnvironmentModule.RegisterVariable(environmentName:string, variableName:string, value:any)
    local environment:Environment = GetOrCreateEnvironment(environmentName)

    environment.variablesByName[variableName] = value
end

function EnvironmentModule.GetCurrentEnvironmentName()
    local currentEnvName = indexedEnvironmentsNamesByPlaceId[game.placeId]

    if currentEnvName == nil then
        error("Environment not found for placeId : "..tostring(game.placeId))
    end

    return currentEnvName
end

function EnvironmentModule.GetPlaceId(placeName:string)
    local currentEnvName = EnvironmentModule.GetCurrentEnvironmentName()
    local environment:Environment = environments[currentEnvName]
      
    local placeId:number? = environment.indexedPlacesByName[placeName]

    if placeId == nil then
        error("Place ["..placeName.."] not in environment ["..currentEnvName.."]")
    end

    return placeId
end

function EnvironmentModule.GetVariable(variableName:string)
    local currentEnvName = EnvironmentModule.GetCurrentEnvironmentName()
    local environment:Environment = environments[currentEnvName]

    local variableValue = environment.variablesByName[variableName]

    if variableValue == nil then
        error("Variable ["..variableName.."] not in environment ["..currentEnvName.."]")
    end

    return variableValue
end

-- Register places ID for Development project side
EnvironmentModule.RegisterPlace("dev", 7537675424, "MainPlace")
EnvironmentModule.RegisterPlace("dev", 7543992206, "MyFarm")
EnvironmentModule.RegisterPlace("dev", 9161951766, "FashionShow")
EnvironmentModule.RegisterPlace("dev", 7543980049, "MapA")
EnvironmentModule.RegisterPlace("dev", 7543986248, "MapB")
EnvironmentModule.RegisterPlace("dev", 9739461447, "ClubMap")

-- Register places ID for Production project side
EnvironmentModule.RegisterPlace("production", 14175038413, "MainPlace")
EnvironmentModule.RegisterPlace("production", 14175048964, "MyFarm")
EnvironmentModule.RegisterPlace("production", 14175056888, "FashionShow")
EnvironmentModule.RegisterPlace("production", 14175129133, "MapA")
EnvironmentModule.RegisterPlace("production", 14175133800, "MapB")
EnvironmentModule.RegisterPlace("production", 14175123548, "ClubMap")

return EnvironmentModule