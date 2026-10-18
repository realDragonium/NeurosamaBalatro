-- Cash Out Action

local CardUtils = SMODS.load_file("utils/card_utils.lua")()

-- Cashing out before the payout screen has built its button crashes the game, so press the real button.
local function find_cash_out_button()
    for _, box in ipairs(G.I.UIBOX) do
        local button = box.get_UIE_by_ID and box:get_UIE_by_ID('cash_out_button')
        if button then return button end
    end
end

local function cash_out_executor(params)
    if G.STATE ~= G.STATES.ROUND_EVAL then
        return false, "Not on the payout screen"
    end
    if CardUtils.press(find_cash_out_button()) then
        return true, "Successfully cashed out!"
    end
    return false, "The payout is still being counted; try again in a moment"
end

local function create_cash_out_action()
    return {
        name = "cash_out",
        definition = {
            name = "cash_out",
            description = "Cash out and end the blind",
            parameters = {}
        },
        executor = cash_out_executor
    }
end

return create_cash_out_action