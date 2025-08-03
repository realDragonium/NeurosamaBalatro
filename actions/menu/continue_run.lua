-- Continue Run Action

local function continue_run_executor(params)
    if G.FUNCS and G.FUNCS.start_setup_run then
        G.FUNCS.start_setup_run()
        return true
    end
    return false
end

local function create_continue_run_action()
    -- Only create if save file exists
    if not G.SAVED_GAME then
        return nil
    end

    return {
        name = "continue_run",
        definition = {
            name = "continue_run",
            description = "Continue existing run",
            parameters = {}
        },
        executor = continue_run_executor
    }
end

return create_continue_run_action