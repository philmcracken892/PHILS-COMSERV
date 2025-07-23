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
local WORK_DURATION = 10000 -- Updated to match hammer animation duration
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
    SetTextColor(255, 255, 255, 255) -- White
    SetTextCentre(1)
    
    DrawSprite(spriteName, spriteDict, _x, _y + 0.0150, (0.015 + factor), 0.032, 0.1, 0, 0, 0, 190, 0)
    DisplayText(CreateVarString(10, "LITERAL_STRING", text), _x, _y)
end

-- Community Service Work Animation Function
local function StartCommunityServiceWork()
    local ped = PlayerPedId()
    
    -- Animation dictionary and name for hammer work
    local dict = "amb_work@world_human_hammer@wall@male_a@trans"
    local anim = "base_trans_base"
    
    -- Request animation dictionary
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Citizen.Wait(100)
    end
    
    -- Create and attach hammer prop
    local hammer = CreateObject(`p_hammer01x`, GetEntityCoords(ped), true, true, true)
    AttachEntityToEntity(hammer, ped, GetEntityBoneIndexByName(ped, "PH_R_Hand"), 0.02, 0.04, -0.06, 180.0, 180.0, 0.0, true, true, false, true, 1, true)
    
    -- Start the animation
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, 1, 0, true, 0, false, 0, false)
    
    -- Use progress bar with the animation
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
    }) then -- Completed
        ClearPedTasks(ped)
        DeleteEntity(hammer) -- Clean up the hammer prop
        return true
    else -- Cancelled
        ClearPedTasks(ped)
        DeleteEntity(hammer) -- Clean up the hammer prop
        TriggerEvent('ox_lib:notify', {
            title = 'Community Service',
            description = 'Work cancelled',
            type = 'error'
        })
        return false
    end
end

-- Particle system optimization
local function LoadParticleAsset()
    if HasNamedPtfxAssetLoaded(PARTICLE_DICT) then
        return true
    end
    
    RequestNamedPtfxAsset(PARTICLE_DICT)
    local timeout = GetGameTimer() + 3000 -- 3 second timeout
    
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
    return StartParticleFxLoopedAtCoord(PARTICLE_NAME,
        coords.x, coords.y, coords.z + 0.2, 
        0.0, 0.0, 0.0, 
        0.5, false, false, false, false)
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

-- Menu functions
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
        title = 'Select Player for Community Service',
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

-- Core service functions
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
        
        -- Check if action already exists or is the excluded action
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

-- Notification system
local lastActionsCount = -1
local lastHelpNotification = 0
local HELP_NOTIFICATION_COOLDOWN = 3000 -- 3 seconds between help notifications

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

-- Event handlers
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
    lastActionsCount = -1 -- Reset notification tracking
    ClearAllParticles()
end)

RegisterNetEvent('rsg-communityservice:client:inCommunityService', function(actions_remaining)
    if isSentenced then return end
    
    local playerPed = PlayerPedId()
    actionsRemaining = actions_remaining
    lastActionsCount = -1 -- Reset notification tracking
    PopulateActionTable()
    SetEntityCoords(playerPed, Config.ServiceLocation.x, Config.ServiceLocation.y, Config.ServiceLocation.z)
    isSentenced = true
    communityServiceFinished = false
    
    -- Escape detection loop
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
            sleep = 500 -- default when in service
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
                    sleep = 1 -- tighter loop when near interaction

                    -- Show 3D DrawText hint
                    DrawText3D(actionCoords.x, actionCoords.y, actionCoords.z + 1.0, "[J] Start Community Service Task")

                    -- Listen for key press
                    if IsControlJustReleased(0, J_KEY) and (GetGameTimer() - lastInteractionTime > 1000) and not disable_actions then
                        lastInteractionTime = GetGameTimer()
                        disable_actions = true

                        -- Start the hammer work animation
                        local workCompleted = StartCommunityServiceWork()
                        
                        if workCompleted then
                            -- Do the work action
                            local currentAction = availableActions[i]
                            RemoveActionFromTable(currentAction)
                            PopulateActionTable(currentAction)

                            TriggerServerEvent('rsg-communityservice:server:completeService')
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
                        break -- exit loop after successful action
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

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        ClearAllParticles()
    end
end)
