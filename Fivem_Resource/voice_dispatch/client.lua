local voiceActive = false
local voiceThread = false

-- Send NUI message with player ID
local function sendNuiAction(action)
    local playerId = GetPlayerServerId(PlayerId())
    SendNUIMessage({
        action = action,
        playerId = playerId
    })
    print(("[Voice Dispatch] Sent %s to NUI (Player ID: %s)"):format(action, playerId))
end

RegisterCommand("listen", function()
    print("[Voice Dispatch] Listen command activated (toggle mode)")
    sendNuiAction("start")
end)

RegisterCommand('+listen', function()
    if voiceActive then
        print("[Voice Dispatch] Already listening, ignoring")
        return
    end
    
    voiceActive = true
    print("[Voice Dispatch] +listen (KEY PRESSED - Push to Talk activated)")
    sendNuiAction("start")
    
    -- Create a thread to maintain the voice state while key is held
    if not voiceThread then
        voiceThread = true
        CreateThread(function()
            print("[Voice Dispatch] Voice thread started")
            while voiceActive do
                -- Override game controls to prevent conflicts
                SetControlNormal(0, 249, 1.0)
                SetControlNormal(1, 249, 1.0)
                SetControlNormal(2, 249, 1.0)
                Wait(0)
            end
            print("[Voice Dispatch] Voice thread ended")
            voiceThread = false
        end)
    end
end, false)

RegisterCommand('-listen', function()
    if not voiceActive then
        print("[Voice Dispatch] Not listening, ignoring")
        return
    end
    
    voiceActive = false
    print("[Voice Dispatch] -listen (KEY RELEASED - Push to Talk ended)")
    sendNuiAction("stop")
end, false)

RegisterKeyMapping('+listen', 'Push to talk (Speech Recognition)', 'keyboard', 'N')

-- Receive speech result from NUI (sent by C# program) and forward to server
RegisterNUICallback("speechResult", function(data, cb)
    if data.text and data.text ~= "" then
        print(("[Voice Dispatch] Received from C# program: \"%s\""):format(data.text))
        TriggerServerEvent("voice:sendText", data.text)
    else
        print("[Voice Dispatch] No speech recognized")
    end
    cb("ok")
end)

-- Receive dispatch response (follow-up questions)
RegisterNetEvent('voice:dispatchResponse')
AddEventHandler('voice:dispatchResponse', function(message)
    print(("[Voice Dispatch] 📞 Dispatch: %s"):format(message))
    
    -- Show notification to player
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName("~b~[Dispatch]~w~ " .. message)
    EndTextCommandThefeedPostTicker(false, true)
    
    -- Play beep sound
    PlaySoundFrontend(-1, "CONFIRM_BEEP", "HUD_MINI_GAME_SOUNDSET", true)
    
    -- Show on screen
    SendNUIMessage({
        action = "showDispatchMessage",
        message = message
    })
end)

-- Receive backup alert (broadcast to all players)
RegisterNetEvent('voice:backupAlert')
AddEventHandler('voice:backupAlert', function(data)
    local urgencyColor = "~w~"
    if data.urgency == "code3" or data.urgency == "emergency" then
        urgencyColor = "~r~"
    elseif data.urgency == "code2" then
        urgencyColor = "~o~"
    end
    
    local unitText = "All Units"
    if #data.units > 0 then
        unitText = table.concat(data.units, ", "):upper()
    end
    
    -- Show notification
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(urgencyColor .. "[🚨 BACKUP REQUEST]~w~\nUnits: " .. unitText .. "\nOfficer " .. data.playerId)
    EndTextCommandThefeedPostTicker(false, true)
    
    -- Play urgent sound
    PlaySoundFrontend(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", true)
    
    print(("[Voice Dispatch] 🚨 BACKUP ALERT: Player %d needs %s"):format(data.playerId, unitText))
end)

