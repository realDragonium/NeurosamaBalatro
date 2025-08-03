-- View Available Stakes Action
-- Shows all available stakes with their effects

local function get_stake_description(stake)
    local desc = stake.name or "Unknown Stake"
    
    -- Try to get localized description similar to deck approach
    if G.localization and G.localization.descriptions and G.localization.descriptions.Stake and G.localization.descriptions.Stake[stake.key] then
        local desc_template = G.localization.descriptions.Stake[stake.key].text
        if desc_template then
            local effect_desc = ""
            if type(desc_template) == "table" then
                effect_desc = table.concat(desc_template, " ")
            else
                effect_desc = tostring(desc_template)
            end
            
            -- Get loc_vars for variable substitution
            local loc_vars = {}
            if stake.loc_vars and type(stake.loc_vars) == 'function' then
                local res = stake:loc_vars() or {}
                loc_vars = res.vars or {}
            end
            
            -- Replace variables in the description
            if type(loc_vars) == "table" then
                local i = 1
                for k, v in pairs(loc_vars) do
                    if type(v) == "number" then
                        effect_desc = effect_desc:gsub("#" .. i .. "#", tostring(v))
                        i = i + 1
                    elseif type(v) == "string" then
                        effect_desc = effect_desc:gsub("#" .. i .. "#", v)
                        i = i + 1
                    end
                end
            end
            
            -- Clean up formatting codes
            effect_desc = effect_desc:gsub("{[^}]*}", "")
            effect_desc = effect_desc:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
            
            if effect_desc ~= "" then
                desc = desc .. " (" .. effect_desc .. ")"
            end
        end
    end
    
    return desc
end

local function view_available_stakes_executor(params)
    -- Build and send context with available stakes
    local context_parts = {"Available Stakes:"}
    
    if G.P_CENTER_POOLS and G.P_CENTER_POOLS["Stake"] then
        -- Get max available stake for current deck
        local max_stake = 1
        if G.GAME and G.GAME.viewed_back and G.GAME.viewed_back.effect and G.GAME.viewed_back.effect.center then
            max_stake = get_deck_win_stake(G.GAME.viewed_back.effect.center.key) or 1
        end
        
        -- Check if all unlocked profile setting is enabled
        if G.PROFILES and G.SETTINGS and G.PROFILES[G.SETTINGS.profile] and G.PROFILES[G.SETTINGS.profile].all_unlocked then
            max_stake = #G.P_CENTER_POOLS['Stake']
        end
        
        -- Sort stakes by stake_level and filter by availability
        local stakes = {}
        for _, stake in pairs(G.P_CENTER_POOLS["Stake"]) do
            if stake and stake.stake_level and stake.stake_level <= max_stake + 1 then
                table.insert(stakes, stake)
            end
        end
        
        table.sort(stakes, function(a, b) 
            return (a.stake_level or 0) < (b.stake_level or 0) 
        end)
        
        for _, stake in ipairs(stakes) do
            local stake_desc = "  " .. stake.stake_level .. ". " .. get_stake_description(stake)
            
            -- Mark currently selected stake
            local current_stake_level = G.GAME and G.GAME.stake or 1
            if stake.stake_level == current_stake_level then
                stake_desc = stake_desc .. " [SELECTED]"
            end
            
            -- Mark unavailable stakes
            if stake.stake_level > max_stake + 1 then
                stake_desc = stake_desc .. " [LOCKED]"
            end
            
            table.insert(context_parts, stake_desc)
        end
    end
    
    local context_message = table.concat(context_parts, "\n")
    if sendWebSocketMessage then
        sendWebSocketMessage(context_message, true)  -- Silent update
    end
    
    return true, "Available stakes information provided"
end


local function create_view_available_stakes_action()
    -- Only create if we're in New Run tab
    if not (G.OVERLAY_MENU and G.SETTINGS and G.SETTINGS.current_setup == "New Run") then
        return nil
    end

    return {
        name = "view_available_stakes",
        definition = {
            name = "view_available_stakes",
            description = "View all available stakes with their effects",
            parameters = {}
        },
        executor = view_available_stakes_executor
    }
end

return create_view_available_stakes_action