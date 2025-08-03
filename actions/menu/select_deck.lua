-- Select Deck Action

local function select_deck_executor(params)
    -- Select deck (moved from MenuActions.select_deck)
    local deck_name = params.deck_name
    if not deck_name then
        return false, "Deck name parameter required"
    end

    -- Find all available decks
    local orderedDeckNames = {}
    for k, v in ipairs(G.P_CENTER_POOLS.Back) do
        orderedDeckNames[#orderedDeckNames + 1] = v.name
    end

    -- Find the deck index
    for id, deck in ipairs(orderedDeckNames) do
        if deck == deck_name then
            local args = { to_val = orderedDeckNames[id], to_key = id }
            G.FUNCS.change_viewed_back(args)
            return true, "Selected deck: " .. deck_name
        end
    end

    return false, "Deck not found: " .. deck_name
end

local function create_select_deck_action()
    -- Only available when in New Run setup
    if G.SETTINGS and G.SETTINGS.current_setup == 'New Run' then
        return {
            name = "select_deck",
            definition = {
                name = "select_deck",
                description = "Select a deck for the new run by name",
                schema = {
                    type = "object",
                    properties = {
                        deck_name = {
                            type = "string",
                        }
                    },
                    required = {"deck_name"}
                }
            },
            executor = select_deck_executor
        }
    end

    return nil
end

return create_select_deck_action