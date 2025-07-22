
local RSGCore = exports['rsg-core']:GetCoreObject()



local CommunityServiceData = {}

-- Command to open player menu (LEOs only)
RSGCore.Commands.Add('comserv', 'Send To Community Service', {}, false, function(source, args)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not Player.PlayerData then
        
        return
    end

    if Player.PlayerData.job.type == "leo" or Player.PlayerData.job.name == "vallaw" then
        TriggerClientEvent('rsg-communityservice:client:openPlayerMenu', source)
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Error',
            description = 'You are not authorized to use this command',
            type = 'error'
        })
    end
end)

-- Command to end someone's sentence
RSGCore.Commands.Add('endcomserv', 'End Community Service', {}, false, function(source, args)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not Player.PlayerData then
        
        return
    end

    if Player.PlayerData.job.type == "leo" or Player.PlayerData.job.name == "vallaw" then
        TriggerClientEvent('rsg-communityservice:client:openEndServiceMenu', source)
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Error',
            description = 'You are not authorized to use this command',
            type = 'error'
        })
    end
end)

-- === Server Events === --

RegisterServerEvent('rsg-communityservice:server:getOnlinePlayers', function()
    local src = source
    local players = {}

    for _, id in pairs(RSGCore.Functions.GetPlayers()) do
        local Player = RSGCore.Functions.GetPlayer(id)
        if Player and Player.PlayerData then
            table.insert(players, {
                id = id,
                name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
                citizenid = Player.PlayerData.citizenid
            })
        end
    end

    TriggerClientEvent('rsg-communityservice:client:receiveOnlinePlayers', src, players)
end)



RegisterServerEvent('rsg-communityservice:server:finishCommunityService', function(targetId)
    local playerId = targetId or source
    ReleaseFromService(playerId)
end)

RegisterServerEvent('rsg-communityservice:server:checkIfSentenced', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData then
        
        return
    end

    local citizenid = Player.PlayerData.citizenid
    if not citizenid then
        
        return
    end

    local data = CommunityServiceData[citizenid]
    if data and data.actions_remaining > 0 then
        TriggerClientEvent('rsg-communityservice:client:inCommunityService', src, data.actions_remaining)
    end
end)

RegisterServerEvent('rsg-communityservice:server:completeService', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData then
        
        return
    end

    local citizenid = Player.PlayerData.citizenid
    if CommunityServiceData[citizenid] then
        CommunityServiceData[citizenid].actions_remaining = CommunityServiceData[citizenid].actions_remaining - 1
        if CommunityServiceData[citizenid].actions_remaining <= 0 then
            ReleaseFromService(src)
        end
    end
end)

RegisterServerEvent('rsg-communityservice:server:extendService', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData then
       
        return
    end

    local citizenid = Player.PlayerData.citizenid
    if CommunityServiceData[citizenid] then
        CommunityServiceData[citizenid].actions_remaining = CommunityServiceData[citizenid].actions_remaining + Config.ServiceExtensionOnEscape
    end
end)

RegisterServerEvent('rsg-communityservice:server:sendToCommunityService', function(target, actions_count)
    local Player = RSGCore.Functions.GetPlayer(target)
    if not Player or not Player.PlayerData then
       
        return
    end

    local citizenid = Player.PlayerData.citizenid
    if not citizenid then
        
        return
    end

    CommunityServiceData[citizenid] = { actions_remaining = actions_count }
    TriggerClientEvent('rsg-communityservice:client:inCommunityService', target, actions_count)
end)

-- === Release Logic === --

function ReleaseFromService(target)
    local Player = RSGCore.Functions.GetPlayer(target)
    if not Player or not Player.PlayerData then
        
        return
    end

    local citizenid = Player.PlayerData.citizenid
    if citizenid then
        CommunityServiceData[citizenid] = nil
    end
    TriggerClientEvent('ox_lib:notify', target, {
        title = 'Community Service',
        description = 'Service completed now behave',
        type = 'success'
    })
    TriggerClientEvent('rsg-communityservice:client:finishCommunityService', target)
end
