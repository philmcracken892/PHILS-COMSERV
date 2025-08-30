local RSGCore = exports['rsg-core']:GetCoreObject()

-- State variables
local isSentenced = false
local communityServiceFinished = false
local actionsRemaining = 0
local availableActions = {}
local disable_actions = false
local particleHandles = {}
local onlinePlayers = {}
local playersInService = {}
local lastInteractionTime = 0
local textScale = 0.35
local textFont = 6
local spriteName = "feeds"
local spriteDict = "toast_bg"
-- Constants
local PARTICLE_DICT = "scr_net_target_races"
local PARTICLE_NAME = "scr_net_target_fire_ring_mp"
local MAX_ACTIONS = 5
local INTERACTION_DISTANCE = 1.5
local PARTICLE_RENDER_DISTANCE = 150.0
local ESCAPE_CHECK_INTERVAL = 2000
local WORK_DURATION = 10000
local J_KEY = 0xF3830D8E

-- Cached functions for performance
local PlayerPedId = PlayerPedId
local GetEntityCoords = GetEntityCoords
local vector3 = vector3

local function DrawText3D(x, y, z, text, r, g, b)
    local onScreen, _x, _y = GetScreenCoordFromWorldCoord(x, y, z)
    if not onScreen then return end
    local factor = (string.len(text)) / 160
    SetTextScale(textScale, textScale)
    SetTextFontForCurrentCommand(textFont)
    SetTextColor(255, 255, 255, 255)
    SetTextCentre(1)
    DrawSprite(spriteName, spriteDict, _x, _y + 0.0150, (0.015 + factor), 0.032, 0.1, 0, 0, 0, 190, 0)
    DisplayText(CreateVarString(10, "LITERAL_STRING", text), _x, _y)
end

local function StartCommunityServiceWork()
    local ped = PlayerPedId()
    local dict = "amb_work@world_human_hammer@wall@male_a@trans"
    local anim = "base_trans_base"
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Citizen.Wait(100)
    end
    local hammer = CreateObject(`p_hammer01x`, GetEntityCoords(ped), true, true, true)
    AttachEntityToEntity(hammer, ped, GetEntityBoneIndexByName(ped, "PH_R_Hand"), 0.02, 0.04, -0.06, 180.0, 180.0, 0.0, true, true, false, true, 1, true)
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, 1, 0, true, 0, false, 0, false)
    if exports.ox_lib:progressBar({
        duration = WORK_DURATION,
        label = '🔨 Performing Community Service...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
            mouse = false
        },
        anim = {
            dict = dict,
            clip = anim
        },
    }) then
        ClearPedTasks(ped)
        DeleteEntity(hammer)
        return true
    else
        ClearPedTasks(ped)
        DeleteEntity(hammer)
        TriggerEvent('ox_lib:notify', {
            title = 'Community Service',
            description = 'Work cancelled',
            type = 'error'
        })
        return false
    end
end

local function LoadParticleAsset()
    if HasNamedPtfxAssetLoaded(PARTICLE_DICT) then
        return true
    end
    RequestNamedPtfxAsset(PARTICLE_DICT)
    local timeout = GetGameTimer() + 3000
    while not HasNamedPtfxAssetLoaded(PARTICLE_DICT) and GetGameTimer() < timeout do
        Wait(0)
    end
    return HasNamedPtfxAssetLoaded(PARTICLE_DICT)
end

local function CreateParticleEffect(coords)
    if not coords or not LoadParticleAsset() then 
        return nil 
    end
    UseParticleFxAsset(PARTICLE_DICT)
    return StartParticleFxLoopedAtCoord(PARTICLE_NAME, coords.x, coords.y, coords.z + 0.2, 0.0, 0.0, 0.0, 0.5, false, false, false, false)
end

local function ClearAllParticles()
    for i = #particleHandles, 1, -1 do
        local handle = particleHandles[i]
        if DoesParticleFxLoopedExist(handle) then
            StopParticleFxLooped(handle, false)
        end
        particleHandles[i] = nil
    end
end

RegisterNetEvent("comserv:client:prisonclothes") -- prison outfit event
AddEventHandler("comserv:client:prisonclothes", function()
    local ped = PlayerPedId() -- Replace cache.ped with PlayerPedId()
    
    -- Remove all clothing items
    RemoveShopItemFromPedByCategory(ped, 0x9925C067, true, true, true)
    RemoveShopItemFromPedByCategory(ped, 0x485EE834, true, true, true)
    RemoveShopItemFromPedByCategory(ped, 0x18729F39, true, true, true)
    RemoveShopItemFromPedByCategory(ped, 0x3107499B, true, true, true)
    RemoveShopItemFromPedByCategory(ped, 0x3C1A74CD, true, true, true)
    RemoveShopItemFromPedByCategory(ped, 0x3F1F01E5, true, true, true)
    RemoveShopItemFromPedByCategory(ped, 0x3F7F3587, true, true, true)
    RemoveShopItemFromPedByCategory(ped, 0x49C89D9B, true, true, true)
    RemoveShopItemFromPedByCategory(ped, 0x4A73515C, true, true, true)
    RemoveShopItemFromPedByCategory(ped, 0x514ADCEA, true, true, true)
    RemoveShopItemFromPedByCategory(ped, 0x5FC29285, true, true, true)
    RemoveShopItemFromPedByCategory(ped, 0x79D7DF96, true, true, true)
    RemoveShopItemFromPedByCategory(ped, 0x7A96FACA, true, true, true)
    RemoveShopItemFromPedByCategory(ped, 0x877A2CF7, true, true, true)
    RemoveShopItemFromPedByCategory(ped, 0x9B2C8B89, true, true, true)
    RemoveShopItemFromPedByCategory(ped, 0xA6D134C6, true, true, true)
    RemoveShopItemFromPedByCategory(ped, 0xE06D30CE, true, true, true)
    RemoveShopItemFromPedByCategory(ped, 0x662AC34,  true, true, true)
    RemoveShopItemFromPedByCategory(ped, 0xAF14310B, true, true, true)
    RemoveShopItemFromPedByCategory(ped, 0x72E6EF74, true, true, true)
    RemoveShopItemFromPedByCategory(ped, 0xEABE0032, true, true, true)
    RemoveShopItemFromPedByCategory(ped, 0x2026C46D, true, true, true)
    RemoveShopItemFromPedByCategory(ped, 0xB6B6122D, true, true, true)
    RemoveShopItemFromPedByCategory(ped, 0xB9E2FA01, true, true, true)

    -- Apply prison clothes based on gender
    if IsPedMale(ped) then
        ApplyShopItemToPed(ped, 0x5BA76CCF, true, true, true) -- Male prison outfit
        ApplyShopItemToPed(ped, 0x216612F0, true, true, true)
        ApplyShopItemToPed(ped, 0x1CCEE58D, true, true, true)
    else
        ApplyShopItemToPed(ped, 0x6AB27695, true, true, true) -- Female prison outfit
        ApplyShopItemToPed(ped, 0x75BC0CF5, true, true, true)
        ApplyShopItemToPed(ped, 0x14683CDF, true, true, true)
    end
    
    -- Remove all weapons
    RemoveAllPedWeapons(ped, true, true)
    
    -- Notify player
    TriggerEvent('ox_lib:notify', {
        title = 'Community Service',
        description = 'Prison clothes applied',
        type = 'inform'
    })
end)



local function ShowDurationMenu(targetId, targetName)
    local input = exports.ox_lib:inputDialog('Community Service Duration', {
        {
            type = 'number',
            label = 'Number of Actions',
            description = 'Enter the number of community service actions (1-50)',
            required = true,
            min = 1,
            max = 50
        }
    })
    if not input or not input[1] then return end
    local actions = tonumber(input[1])
    if not actions or actions < 1 or actions > 50 then
        TriggerEvent('ox_lib:notify', {
            title = 'Error',
            description = 'Invalid number of actions',
            type = 'error'
        })
        return
    end
    TriggerServerEvent('rsg-communityservice:server:sendToCommunityService', targetId, actions)
    TriggerEvent('ox_lib:notify', {
        title = 'Community Service',
        description = targetName .. ' has been sentenced to ' .. actions .. ' action(s)',
        type = 'success'
    })
end

local function ShowPlayerMenu()
    if #onlinePlayers == 0 then return end
    local options = {}
    for i = 1, #onlinePlayers do
        local player = onlinePlayers[i]
        options[i] = {
            title = player.name,
            description = 'ID: ' .. player.id,
            onSelect = function()
                ShowDurationMenu(player.id, player.name)
            end
        }
    end
    exports.ox_lib:registerContext({
        id = 'community_service_players',
        title = 'Select for Service',
        options = options
    })
    exports.ox_lib:showContext('community_service_players')
end

local function ShowEndServiceMenu()
    local options = {}
    if #playersInService > 0 then
        for i = 1, #playersInService do
            local player = playersInService[i]
            options[i] = {
                title = player.name,
                description = 'Actions Remaining: ' .. player.actionsRemaining,
                onSelect = function()
                    local alert = exports.ox_lib:alertDialog({
                        header = 'End Community Service',
                        content = 'Are you sure you want to end community service for ' .. player.name .. '?',
                        centered = true,
                        cancel = true
                    })
                    if alert == 'confirm' then
                        TriggerServerEvent('rsg-communityservice:server:finishCommunityService', player.id)
                    end
                end
            }
        end
    else
        options[1] = {
            title = 'No Players in Community Service',
            description = 'There are currently no players serving community service',
            disabled = true
        }
    end
    exports.ox_lib:registerContext({
        id = 'end_community_service',
        title = 'End Community Service',
        options = options
    })
    exports.ox_lib:showContext('end_community_service')
end

local function IsActionAtCoords(coords, actionList)
    for i = 1, #actionList do
        local action = actionList[i]
        if action.coords.x == coords.x and action.coords.y == coords.y and action.coords.z == coords.z then
            return true
        end
    end
    return false
end

local function RemoveActionFromTable(targetAction)
    for i = #availableActions, 1, -1 do
        local action = availableActions[i]
        if action.coords.x == targetAction.coords.x and 
           action.coords.y == targetAction.coords.y and 
           action.coords.z == targetAction.coords.z then
            table.remove(availableActions, i)
            break
        end
    end
end

local function PopulateActionTable(excludeAction)
    ClearAllParticles()
    while #availableActions < MAX_ACTIONS do
        local randomAction = Config.ServiceLocations[math.random(1, #Config.ServiceLocations)]
        if not IsActionAtCoords(randomAction.coords, availableActions) and 
           (not excludeAction or not IsActionAtCoords(randomAction.coords, {excludeAction})) then
            availableActions[#availableActions + 1] = randomAction
        end
    end
end

local function RenderActionParticles()
    ClearAllParticles()
    local playerCoords = GetEntityCoords(PlayerPedId())
    for i = 1, #availableActions do
        local coords = availableActions[i].coords
        if #(playerCoords - coords) < PARTICLE_RENDER_DISTANCE then
            local handle = CreateParticleEffect(coords)
            if handle then
                particleHandles[#particleHandles + 1] = handle
            end
        end
    end
end

local lastActionsCount = -1
local lastHelpNotification = 0
local HELP_NOTIFICATION_COOLDOWN = 3000

local function ShowActionsRemaining(count)
    if count ~= lastActionsCount then
        lastActionsCount = count
        TriggerEvent('ox_lib:notify', {
            title = 'Community Service',
            description = 'Actions Remaining: ' .. count,
            type = 'inform',
            position = 'top-right',
            duration = 5000
        })
    end
end

RegisterNetEvent('rsg-communityservice:client:openPlayerMenu', function()
    TriggerServerEvent('rsg-communityservice:server:getOnlinePlayers')
end)

RegisterNetEvent('rsg-communityservice:client:openEndServiceMenu', function()
    TriggerServerEvent('rsg-communityservice:server:getPlayersInService')
end)

RegisterNetEvent('rsg-communityservice:client:receiveOnlinePlayers', function(players)
    onlinePlayers = players
    ShowPlayerMenu()
end)

RegisterNetEvent('rsg-communityservice:client:receivePlayersInService', function(players)
    playersInService = players
    ShowEndServiceMenu()
end)

RegisterNetEvent('rsg-communityservice:client:finishCommunityService', function()
    communityServiceFinished = true
    isSentenced = false
    actionsRemaining = 0
    lastActionsCount = -1
    ClearAllParticles()
    
end)

RegisterNetEvent('rsg-communityservice:client:inCommunityService', function(actions_remaining)
    if isSentenced then return end
    local playerPed = PlayerPedId()
    actionsRemaining = actions_remaining
    lastActionsCount = -1
    PopulateActionTable()
    SetEntityCoords(playerPed, Config.ServiceLocation.x, Config.ServiceLocation.y, Config.ServiceLocation.z)
    isSentenced = true
    communityServiceFinished = false
    CreateThread(function()
        while actionsRemaining > 0 and not communityServiceFinished do
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            if IsPedInAnyVehicle(ped, false) then
                ClearPedTasksImmediately(ped)
            end
            if #(coords - Config.ServiceLocation) > 100 then
                SetEntityCoords(ped, Config.ServiceLocation.x, Config.ServiceLocation.y, Config.ServiceLocation.z)
                TriggerServerEvent('rsg-communityservice:server:extendService')
                actionsRemaining = actionsRemaining + Config.ServiceExtensionOnEscape
                TriggerEvent('ox_lib:notify', {
                    title = 'Community Service',
                    description = 'Escape Attempted! ' .. Config.ServiceExtensionOnEscape .. ' more actions added!',
                    type = 'error',
                    position = 'center',
                    duration = 4000
                })
            end
            Wait(ESCAPE_CHECK_INTERVAL)
        end
        isSentenced = false
        ClearAllParticles()
		
       
    end)
end)

CreateThread(function()
    local lastInteractionTime = 0
    while true do
        local sleep = 1000
        if actionsRemaining > 0 and isSentenced then
            sleep = 500
            ShowActionsRemaining(actionsRemaining)
            RenderActionParticles()
            local ped = PlayerPedId()
            local pCoords = GetEntityCoords(ped)
            local nearAction = false
            for i = 1, #availableActions do
                local actionCoords = availableActions[i].coords
                local dist = #(pCoords - actionCoords)
                if dist < INTERACTION_DISTANCE then
                    nearAction = true
                    sleep = 1
                    DrawText3D(actionCoords.x, actionCoords.y, actionCoords.z + 1.0, "[J] Start Community Service Task")
                    if IsControlJustReleased(0, J_KEY) and (GetGameTimer() - lastInteractionTime > 1000) and not disable_actions then
                        lastInteractionTime = GetGameTimer()
                        disable_actions = true
                        local workCompleted = StartCommunityServiceWork()
                        if workCompleted then
                            local currentAction = availableActions[i]
                            RemoveActionFromTable(currentAction)
                            PopulateActionTable(currentAction)
                            TriggerServerEvent('rsg-communityservice:server:completeService')
							ExecuteCommand('loadskin')
                            actionsRemaining = actionsRemaining - 1
                            TriggerEvent('ox_lib:notify', {
                                title = 'Community Service',
                                description = 'Task completed! ' .. actionsRemaining .. ' remaining',
                                type = 'success',
                                position = 'top-right',
                                duration = 2000
                            })
                        end
                        disable_actions = false
                        break
                    end
                end
            end
            if not nearAction then
                sleep = 500
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        ClearAllParticles()
        if isSentenced then
            ExecuteCommand('loadskin')
        end
    end
end)
