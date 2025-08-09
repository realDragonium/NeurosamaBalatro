-- Hand Evaluation Hook
-- Automatically sends context updates after playing a hand with the score achieved

local HandEvaluationHook = {}

function HandEvaluationHook.install_hook()
    if HandEvaluationHook.hook_installed then
        return
    end
    
    -- Hook into the play_cards_from_highlighted function
    if G.FUNCS and G.FUNCS.play_cards_from_highlighted then
        local original_play_cards = G.FUNCS.play_cards_from_highlighted
        
        G.FUNCS.play_cards_from_highlighted = function(e)
            -- Capture score BEFORE playing the hand
            local score_before = G.GAME and G.GAME.chips or 0
            local hand_type = nil
            
            -- Try to get hand type info before playing
            if G.hand and G.hand.highlighted then
                local hand_name, _, _, _, _ = G.FUNCS.get_poker_hand_info(G.hand.highlighted)
                hand_type = hand_name
            end
            
            -- Call the original function
            local result = original_play_cards(e)
            
            -- After playing the hand, send evaluation context with score difference
            -- Use a longer delay and check for score stability
            G.E_MANAGER:add_event(Event({
                trigger = "after",
                delay = 3.0,  -- Longer delay to let scoring animations complete
                func = function()
                    -- Sometimes scoring takes even longer, so let's check a few times
                    local function check_and_send_score(attempt)
                        attempt = attempt or 1
                        local score_after = G.GAME and G.GAME.chips or 0
                        local hand_score = score_after - score_before
                        
                        -- If we got a reasonable score increase or we've tried enough times, send it
                        if hand_score > 0 or attempt >= 3 then
                            HandEvaluationHook.send_hand_evaluation_context(hand_type, hand_score, score_before, score_after)
                        else
                            -- Wait a bit more and try again
                            G.E_MANAGER:add_event(Event({
                                trigger = "after", 
                                delay = 1.0,
                                func = function()
                                    check_and_send_score(attempt + 1)
                                    return true
                                end
                            }))
                        end
                        return true
                    end
                    
                    check_and_send_score()
                    return true
                end
            }))
            
            return result
        end
        
        HandEvaluationHook.hook_installed = true
        sendInfoMessage("Hand evaluation hook installed", "HandEvaluationHook")
    else
        sendWarnMessage("Could not install hand evaluation hook - play_cards_from_highlighted not found", "HandEvaluationHook")
    end
end

function HandEvaluationHook.send_hand_evaluation_context(hand_type, hand_score, score_before, score_after)
    -- Only send if we have an API handler available
    if not _G.NeuroMod or not _G.NeuroMod.api_handler then
        return
    end
    
    local context_parts = {}
    table.insert(context_parts, "🎯 Hand Played:")
    
    -- Show hand type if we captured it
    if hand_type then
        table.insert(context_parts, "Hand Type: " .. hand_type)
    end
    
    -- Show the specific score this hand achieved
    if hand_score and hand_score > 0 then
        table.insert(context_parts, "Hand Scored: " .. hand_score .. " chips")
    end
    
    -- Show before/after totals
    if score_before and score_after then
        table.insert(context_parts, "Score: " .. score_before .. " → " .. score_after .. " chips")
    elseif score_after then
        table.insert(context_parts, "Current Total Score: " .. score_after .. " chips")
    end
    -- Get blind progress information
    if G.GAME and G.GAME.blind and G.GAME.blind.chips then
        local required_chips = G.GAME.blind.chips
        local current_total = score_after or (G.GAME.chips or 0)
        local remaining_chips = required_chips - current_total
        
        if remaining_chips <= 0 then
            table.insert(context_parts, "✅ BLIND COMPLETED!")
        else
            table.insert(context_parts, "Chips Still Needed: " .. remaining_chips)
            local progress_percent = math.floor((current_total / required_chips) * 100)
            table.insert(context_parts, "Progress: " .. progress_percent .. "%")
        end
    end
    
    -- Get hands and discards remaining
    if G.GAME and G.GAME.current_round then
        local hands_left = G.GAME.current_round.hands_left or 0
        local discards_left = G.GAME.current_round.discards_left or 0
        table.insert(context_parts, "Hands Remaining: " .. hands_left)
        table.insert(context_parts, "Discards Remaining: " .. discards_left)
    end
    
    -- Send the context message
    local context_message = table.concat(context_parts, "\n")
    _G.NeuroMod.api_handler:send_context(context_message, false)
    sendInfoMessage("Sent hand evaluation context", "HandEvaluationHook")
end

return HandEvaluationHook