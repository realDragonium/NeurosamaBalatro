-- Jokers Context Builder
-- Handles joker card information

local CardUtils = SMODS.load_file("context/card_utils.lua")()
local JokersContext = {}

-- Build joker description string
function JokersContext.build_joker_string(joker, index)
    if not joker then return nil end

    local name = "Unknown Joker"
    local description = "No description"
    local sell_value = nil

    -- Get joker name and basic description
    if joker.config and joker.config.center then
        name = joker.config.center.name or name
        description = joker.config.center.text or description
    end

    -- Get sell value
    if joker.sell_cost then
        sell_value = joker.sell_cost
    end

    -- Process joker information
    
    -- Get both description and attributes in a single call to avoid duplicate generate_card_ui calls
    local joker_effect, special_attrs = CardUtils.get_joker_info(joker)
    
    -- Determine main description and additional effects
    local main_description = ""
    local additional_effects = {}
    
    -- Use the main joker description from attributes (usually the ability description)
    if #special_attrs > 0 then
        -- The main joker ability description is typically in the first attribute
        main_description = special_attrs[1]
        
        -- Process remaining attributes as additional effects  
        for i = 2, #special_attrs do
            table.insert(additional_effects, special_attrs[i])
        end
    end
    
    -- Fallback to joker_effect if no main description found
    if main_description == "" and joker_effect ~= "" then
        main_description = joker_effect
    end
    
    -- Final fallback to basic center description
    if main_description == "" then
        if joker.config and joker.config.center and joker.config.center.text then
            if type(joker.config.center.text) == "table" then
                main_description = table.concat(joker.config.center.text, " ")
            else
                main_description = tostring(joker.config.center.text)
            end
            -- Clean up formatting codes
            main_description = CardUtils.clean_text(main_description)
        else
            main_description = "No description"
        end
    end

    -- Build the final joker description string
    local joker_desc = "  " .. index .. ". " .. name
    if main_description ~= "No description" and main_description ~= "" then
        joker_desc = joker_desc .. " - " .. main_description
    end
    if #additional_effects > 0 then
        joker_desc = joker_desc .. " [" .. table.concat(additional_effects, ", ") .. "]"
    end
    if sell_value then
        joker_desc = joker_desc .. " [Sell: $" .. sell_value .. "]"
    end

    return joker_desc
end

-- Build jokers context string
function JokersContext.build_context_string()
    local parts = {}

    -- Jokers section
    if G.jokers and G.jokers.cards and #G.jokers.cards > 0 then
        table.insert(parts, "Jokers (" .. #G.jokers.cards .. "):")
        for i, joker in ipairs(G.jokers.cards) do
            local joker_desc = JokersContext.build_joker_string(joker, i)
            if joker_desc then
                table.insert(parts, joker_desc)
            end
        end
    else
        table.insert(parts, "Jokers: None")
    end

    return table.concat(parts, "\n")
end

return JokersContext