-- Context Refresh System
-- Automatically detects context changes and sends updates (similar to action refresh)

local ContextRefresh = {}

-- Load context updater
local ContextUpdater = assert(SMODS.load_file("context/context_updater.lua"))()

-- Track previous context state for comparison
ContextRefresh.last_context_state = {
    overlay_active = false,
    current_tab = nil,
    game_state = nil
}

-- Get current context state for comparison
function ContextRefresh.get_current_context_state()
    return {
        overlay_active = G.OVERLAY_MENU or false,
        current_tab = G.SETTINGS and G.SETTINGS.current_setup or nil,
        game_state = G.STATE
    }
end

-- Compare two context states
function ContextRefresh.context_changed(old_state, new_state)
    return old_state.overlay_active ~= new_state.overlay_active or
           old_state.current_tab ~= new_state.current_tab or
           old_state.game_state ~= new_state.game_state
end

-- Main context refresh function
function ContextRefresh.refresh_context()
    if not _G.NeuroMod or not _G.NeuroMod.api_handler then
        return
    end

    -- Defer the context check to avoid blocking main thread
    G.E_MANAGER:add_event(Event({
        trigger = "immediate",
        blocking = false,
        func = function()
            local current_state = ContextRefresh.get_current_context_state()

            -- Check if context has changed
            if ContextRefresh.context_changed(ContextRefresh.last_context_state, current_state) then
                -- Only send update if this wasn't already handled by the game state hook
                -- (Game state hook handles game_state changes immediately, we handle overlay/tab changes)
                local game_state_changed = ContextRefresh.last_context_state.game_state ~= current_state.game_state
                local overlay_or_tab_changed = ContextRefresh.last_context_state.overlay_active ~= current_state.overlay_active or
                                               ContextRefresh.last_context_state.current_tab ~= current_state.current_tab
                
                if overlay_or_tab_changed and not game_state_changed then
                    sendInfoMessage("Context changed - sending update", "ContextRefresh")
                    -- Send context update for overlay/tab changes only
                    ContextUpdater.send_state_context_update(_G.NeuroMod.api_handler, current_state.game_state, ContextRefresh.last_context_state.game_state)
                end

                -- Always update tracked state
                ContextRefresh.last_context_state = current_state
            end

            return true
        end
    }))
end

return ContextRefresh