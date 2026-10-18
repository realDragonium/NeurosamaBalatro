-- Card Utility Functions
-- Shared utilities for card interactions in shop actions

local CardUtils = {}

-- Helper function to push a button using G.FUNCS (based on balatrobot)
function CardUtils.push_button(button)
    if button and button.config and button.config.button then
        G.FUNCS[button.config.button](button)
    end
end

-- Clicks a live game button the way a player would. UIElement:click ignores the press when the
-- game has disabled the button or a one-press button was already used; last_clicked shows whether it took it.
function CardUtils.press(button)
    if not button then return false end
    local before = button.last_clicked
    button:click()
    return button.last_clicked ~= before
end

-- Helper function to find and click the appropriate button on a card
function CardUtils.use_card(card)
    if not card then return false end

    -- Based on balatrobot's usecard function
    local use_button = card.children.use_button and card.children.use_button.definition
    if use_button and use_button.config and use_button.config.button == nil then
        -- Special handling for use buttons with nodes
        local node_index = card.ability and card.ability.consumeable and 2 or 1
        local button_node = use_button.nodes and use_button.nodes[node_index]

        if card.area and card.area.config and card.area.config.type == 'joker' then
            -- Special path for jokers
            button_node = use_button.nodes[1].nodes[1].nodes[1].nodes[1]
        end

        if button_node then
            CardUtils.push_button(button_node)
            return true
        end
        return false
    end

    -- Try buy_and_use_button first, then buy_button (get definitions)
    local buy_and_use_button = card.children.buy_and_use_button and card.children.buy_and_use_button.definition
    local buy_button = card.children.buy_button and card.children.buy_button.definition

    if buy_and_use_button then
        CardUtils.push_button(buy_and_use_button)
        return true
    elseif buy_button then
        CardUtils.push_button(buy_button)
        return true
    end

    return false
end

-- How many hand cards a consumable needs selected, or nil. Aura's need is
-- hardcoded in Card:can_use_consumeable rather than declared as max_highlighted.
function CardUtils.hand_targets(card)
    local center = card and card.config and card.config.center
    if not center then return nil end
    if center.key == 'c_aura' then return 1 end
    local max_highlighted = center.config and center.config.max_highlighted
    if max_highlighted and max_highlighted > 0 then return max_highlighted end
    return nil
end

-- The game's own Use-button check. Using a consumable it rejects can crash the game.
-- skip_check leaves out the controller lock; callers check busy() for a use still resolving.
-- check_use catches Ankh with full joker slots, which can_use_consumeable lets through.
function CardUtils.can_use_now(card)
    if not (card and card.ability and card.ability.consumeable) then return true end
    if not card.can_use_consumeable then return true end
    if not card:can_use_consumeable(nil, true) then return false end
    return not card:check_use()
end

-- Runs one of the game's button enablers (G.FUNCS.can_buy, can_sell_card, ...) on a
-- stand-in button. An enabler clears config.button when the game would refuse the press.
function CardUtils.game_allows(enabler, card)
    local e = { config = { ref_table = card }, UIBox = { states = {} } }
    G.FUNCS[enabler](e)
    return e.config.button ~= nil
end

-- A use, sell or pack pick is still resolving; acting now can apply twice or after a pack closed.
function CardUtils.busy()
    return G.CONTROLLER.locks.use or (G.GAME.STOP_USE or 0) > 0
end

CardUtils.BUSY_MESSAGE = "The game is still finishing the last move; try again in a moment"

-- The rule behind the button the game shows on a pack card (G.UIDEF.use_and_sell_buttons).
-- booster_obj is the game's global for the open pack.
function CardUtils.can_pick(card)
    if card.ability.consumeable then
        if booster_obj and booster_obj.select_card and card:selectable_from_pack(booster_obj) then
            return CardUtils.game_allows('can_select_from_booster', card)
        end
        return CardUtils.can_use_now(card)
    end
    return CardUtils.game_allows('can_select_card', card)
end

function CardUtils.pick_refusal(card)
    if card.ability.set == 'Joker' then return CardUtils.no_room_message(card) end
    return CardUtils.card_name(card) .. " can't be used right now"
end

function CardUtils.no_room_message(card)
    local kind = card.ability.consumeable and "consumable" or "joker"
    local area = card.ability.consumeable and G.consumeables or G.jokers
    local fix = card.ability.consumeable and "Use or sell a consumable" or "Sell a joker"
    return string.format("No room for %s: all %d %s slots are full. %s first to make room, or leave it.",
        CardUtils.card_name(card), area.config.card_limit, kind, fix)
end

function CardUtils.sell(card)
    if card:can_sell_card() then
        G.FUNCS.sell_card({ config = { ref_table = card } })
        return true
    end
    return false
end

function CardUtils.sell_refusal(card)
    if SMODS.is_eternal(card, { from_sell = true }) then
        return CardUtils.card_name(card) .. " is Eternal and can't be sold"
    end
    return CardUtils.BUSY_MESSAGE
end

-- The game ignores hand clicks while a played hand is scored.
function CardUtils.hand_locked()
    return G.STATE == G.STATES.HAND_PLAYED
end

-- add_to_highlighted silently drops cards past the selection limit, so count what the game kept.
function CardUtils.highlight_hand_cards(indices)
    local selected, refused, invalid = 0, {}, {}
    for _, index in ipairs(indices) do
        local card = type(index) == "number" and G.hand.cards[index]
        if not card then
            table.insert(invalid, tostring(index))
        else
            if not card.highlighted then G.hand:add_to_highlighted(card) end
            if card.highlighted then
                selected = selected + 1
            else
                table.insert(refused, index)
            end
        end
    end
    local message = "Selected " .. selected .. " cards"
    if #refused > 0 then
        message = message .. "; not selected: " .. table.concat(refused, ", ")
            .. " (at most " .. G.hand.config.highlighted_limit .. " cards can be selected at once)"
    end
    if #invalid > 0 then
        message = message .. "; no card at position " .. table.concat(invalid, ", ")
    end
    return selected > 0 and #refused == 0 and #invalid == 0, message
end

function CardUtils.card_name(card)
    local center = card and card.config and card.config.center
    return (center and center.name) or "This card"
end

return CardUtils