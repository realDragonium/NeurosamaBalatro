-- Pack Discoverer
-- Discovers actions available during pack opening/selection

-- Load pack actions at module level (like other discoverers)
local create_select_single_from_pack_action = assert(SMODS.load_file("actions/pack/select_single_from_pack.lua"))()
local create_select_multiple_from_pack_action = assert(SMODS.load_file("actions/pack/select_multiple_from_pack.lua"))()
local create_select_from_pack_targeted_action = assert(SMODS.load_file("actions/pack/select_from_pack_targeted.lua"))()
local create_skip_pack_action = assert(SMODS.load_file("actions/pack/skip_pack.lua"))()
local create_select_specific_cards_action = assert(SMODS.load_file("actions/gameplay/select_specific_cards.lua"))()

local PackDiscoverer = {}

function PackDiscoverer.discover(current_state)
    local actions = {}

    -- Pack states where pack selection is available
    local pack_states = {
        G.STATES.TAROT_PACK,
        G.STATES.SPECTRAL_PACK,
        G.STATES.STANDARD_PACK,
        G.STATES.BUFFOON_PACK,
        G.STATES.PLANET_PACK
    }
    
    -- Check if we're in a pack state OR have pack cards (fallback for mods)
    local is_pack_state = false
    for _, state in ipairs(pack_states) do
        if current_state == state then
            is_pack_state = true
            break
        end
    end
    
    -- Available if either in pack state OR pack cards exist (mod compatibility)
    if (is_pack_state or (G.pack_cards and G.pack_cards.cards)) and G.pack_cards and G.pack_cards.cards then
        -- Add single card selection action
        local select_single_from_pack_action = create_select_single_from_pack_action()
        if select_single_from_pack_action then
            table.insert(actions, select_single_from_pack_action)
        end

        -- Add multiple card selection action
        local select_multiple_from_pack_action = create_select_multiple_from_pack_action()
        if select_multiple_from_pack_action then
            table.insert(actions, select_multiple_from_pack_action)
        end

        -- Add targeted select_from_pack action (for cards that need targeting)
        local select_from_pack_targeted_action = create_select_from_pack_targeted_action()
        if select_from_pack_targeted_action then
            table.insert(actions, select_from_pack_targeted_action)
        end

        -- Add skip_pack action
        local skip_pack_action = create_skip_pack_action()
        if skip_pack_action then
            table.insert(actions, skip_pack_action)
        end
        
        -- Add hand selection action (needed for targeting pack cards)
        local select_specific_cards_action = create_select_specific_cards_action()
        if select_specific_cards_action then
            table.insert(actions, select_specific_cards_action)
        end
    end

    return actions
end

return PackDiscoverer