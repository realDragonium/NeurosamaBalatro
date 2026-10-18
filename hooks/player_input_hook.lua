-- Player Input Hook
-- Reports clicks made by the human player, so a co-op AI can tell its own
-- moves from the player's. Reports are silent context lines starting with
-- "Player input:".

local PlayerInputHook = {}

local ContextRegistry = assert(SMODS.load_file("neuro/context_registry.lua"))()

-- Some actions click cards or buttons in events queued up to ~1s after the
-- action arrives, so clicks shortly after an action are treated as the mod's.
local MOD_ACTION_WINDOW_SECONDS = 2.0

local function state()
    _G._NEURO_PLAYER_INPUT = _G._NEURO_PLAYER_INPUT or { last_mod_action = -math.huge, ui_hooked = false }
    return _G._NEURO_PLAYER_INPUT
end

function PlayerInputHook.mark_mod_action()
    state().last_mod_action = love.timer.getTime()
end

local function is_player_click()
    return love.timer.getTime() - state().last_mod_action > MOD_ACTION_WINDOW_SECONDS
end

local function report(text)
    ContextRegistry.get_instance():send_context_update("Player input: " .. text, true)
end

local function area_name(card)
    local areas = {
        { G.hand, "hand" },
        { G.jokers, "jokers" },
        { G.consumeables, "consumables" },
        { G.shop_jokers, "shop" },
        { G.shop_vouchers, "shop voucher" },
        { G.shop_booster, "shop pack" },
        { G.pack_cards, "pack" },
    }
    for _, entry in ipairs(areas) do
        if entry[1] and card.area == entry[1] then
            return entry[2]
        end
    end
    return "other"
end

local function card_name(card)
    if card.area == G.hand and card.base and card.base.value and card.base.suit then
        return card.base.value .. " of " .. card.base.suit
    end
    if card.ability and card.ability.name then
        return card.ability.name
    end
    return "card"
end

-- Called from SelectionMonitor's Card:click hook after the original click ran.
function PlayerInputHook.report_card_click(card)
    if not is_player_click() then
        return
    end
    local selected = card.highlighted and "selected" or "deselected"
    report(selected .. " " .. card_name(card) .. " (" .. area_name(card) .. ")")
end

function PlayerInputHook.install_ui_hook()
    local s = state()
    if s.ui_hooked or not UIElement then
        return
    end
    local original_click = UIElement.click
    function UIElement:click()
        local button = self.config and self.config.button
        if button and is_player_click() then
            report("pressed " .. tostring(button))
        end
        return original_click(self)
    end
    s.ui_hooked = true
end

return PlayerInputHook
