print("[Voice Dispatch Server] Server script loaded")

-- Track player conversation state
local playerConversations = {}

-- Parse intent from speech text
local function ParseIntent(text)
    local lower = string.lower(text)
    local intent = {
        type = "unknown",
        urgency = "normal",
        units = {},
        situation = nil
    }
    
    -- Detect backup request
    if string.find(lower, "backup") or string.find(lower, "need units") or string.find(lower, "send units") then
        intent.type = "backup"
        
        -- Detect urgency codes
        if string.find(lower, "code 2") or string.find(lower, "code two") then
            intent.urgency = "code2"
        elseif string.find(lower, "code 3") or string.find(lower, "code three") then
            intent.urgency = "code3"
        elseif string.find(lower, "officer down") or string.find(lower, "officer in trouble") then
            intent.urgency = "emergency"
        end
        
        -- Detect specific unit types
        if string.find(lower, "air") or string.find(lower, "helicopter") then
            table.insert(intent.units, "air")
        end
        if string.find(lower, "k9") or string.find(lower, "canine") then
            table.insert(intent.units, "k9")
        end
        if string.find(lower, "swat") then
            table.insert(intent.units, "swat")
        end
        if string.find(lower, "supervisor") or string.find(lower, "sergeant") then
            table.insert(intent.units, "supervisor")
        end
        
        -- Detect situation
        if string.find(lower, "pursuit") then
            intent.situation = "pursuit"
            -- Auto-suggest air unit for pursuits
            if #intent.units == 0 then
                table.insert(intent.units, "air")
            end
        elseif string.find(lower, "shots fired") or string.find(lower, "shooting") then
            intent.situation = "shooting"
            intent.urgency = "emergency"
        elseif string.find(lower, "robbery") then
            intent.situation = "robbery"
        end
    end
    
    return intent
end

-- Ask follow-up question
local function AskFollowUp(playerId, question)
    playerConversations[playerId] = {
        waitingForResponse = true,
        question = question,
        timestamp = os.time()
    }
    
    -- Send question to player's UI
    TriggerClientEvent('voice:dispatchResponse', playerId, question)
    print(string.format("[Voice Dispatch] 📞 Asking Player %d: \"%s\"", playerId, question))
end

-- Process backup request
local function ProcessBackupRequest(playerId, intent, originalText)
    local urgencyText = ""
    if intent.urgency == "code2" then
        urgencyText = "Code 2 (Non-Emergency)"
    elseif intent.urgency == "code3" then
        urgencyText = "Code 3 (Emergency - Lights & Sirens)"
    elseif intent.urgency == "emergency" then
        urgencyText = "🚨 EMERGENCY 🚨"
    else
        urgencyText = "Routine"
    end
    
    local unitsText = "All available units"
    if #intent.units > 0 then
        unitsText = table.concat(intent.units, ", "):upper()
    end
    
    local situationText = intent.situation or "Unknown situation"
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print(string.format("🚨 BACKUP REQUEST - Player %d", playerId))
    print(string.format("   Urgency: %s", urgencyText))
    print(string.format("   Units: %s", unitsText))
    print(string.format("   Situation: %s", situationText))
    print(string.format("   Original: \"%s\"", originalText))
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    -- Broadcast to all players
    TriggerClientEvent('voice:backupAlert', -1, {
        playerId = playerId,
        urgency = intent.urgency,
        units = intent.units,
        situation = intent.situation,
        text = originalText
    })
end

-- Receive speech text from client
RegisterNetEvent("voice:sendText", function(text)
    local playerId = source
    
    -- Log the recognized text
    print(string.format("[Voice Dispatch] Player %d: \"%s\"", playerId, text))
    
    -- Check if player is in a conversation
    if playerConversations[playerId] and playerConversations[playerId].waitingForResponse then
        -- This is a response to a follow-up question
        local question = playerConversations[playerId].question
        playerConversations[playerId] = nil
        
        print(string.format("[Voice Dispatch] 📞 Response: \"%s\"", text))
        
        -- Parse the response
        local intent = ParseIntent(text)
        intent.type = "backup" -- Force backup type since we're in follow-up
        ProcessBackupRequest(playerId, intent, text)
        
    else
        -- New voice command
        local intent = ParseIntent(text)
        
        if intent.type == "backup" then
            -- Check if we need more information
            if #intent.units == 0 and intent.urgency == "normal" and not intent.situation then
                -- Not enough context, ask for clarification
                AskFollowUp(playerId, "10-4 Officer, what type of backup do you need?")
            else
                -- We have enough information, process immediately
                ProcessBackupRequest(playerId, intent, text)
            end
        else
            -- Not a backup request, just log it
            TriggerClientEvent('voice:generalMessage', -1, playerId, text)
        end
    end
end)

-- Clear conversation timeout (30 seconds)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000)
        
        local currentTime = os.time()
        for playerId, conversation in pairs(playerConversations) do
            if conversation.waitingForResponse and (currentTime - conversation.timestamp) > 30 then
                print(string.format("[Voice Dispatch] ⏱️ Conversation timeout for Player %d", playerId))
                playerConversations[playerId] = nil
                TriggerClientEvent('voice:dispatchResponse', playerId, "Request timed out. Please try again.")
            end
        end
    end
end)

