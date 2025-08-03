-- Press Play Action

local function press_play_executor(params)
    -- Start a new run from main menu (moved from MenuActions.press_play)
    if G.MAIN_MENU_UI then
        local play_button = G.MAIN_MENU_UI:get_UIE_by_ID('main_menu_play')
        if play_button and play_button.click then
            play_button:click()
            return true
        end
    end
    return false
end

local function create_press_play_action()
    return {
        name = "press_play",
        definition = {
            name = "press_play",
            description = "Press the play button",
            parameters = {}
        },
        executor = press_play_executor
    }
end

return create_press_play_action