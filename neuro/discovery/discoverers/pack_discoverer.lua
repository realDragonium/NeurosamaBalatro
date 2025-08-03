-- Pack Discoverer
-- Discovers actions available during pack opening/selection

-- Load pack actions at module level (like other discoverers)
local create_select_from_pack_action = assert(SMODS.load_file("actions/pack/select_from_pack.lua"))()
local create_skip_pack_action = assert(SMODS.load_file("actions/pack/skip_pack.lua"))()

local PackDiscoverer = {}

function PackDiscoverer.discover(current_state)
    local actions = {}

    -- Only discover pack actions when pack cards are available
    if G.pack_cards and G.pack_cards.cards then
        -- Add select_from_pack action
        local select_from_pack_action = create_select_from_pack_action()
        if select_from_pack_action then
            table.insert(actions, select_from_pack_action)
        end

        -- Add skip_pack action
        local skip_pack_action = create_skip_pack_action()
        if skip_pack_action then
            table.insert(actions, skip_pack_action)
        end
    end

    return actions
end

return PackDiscoverer