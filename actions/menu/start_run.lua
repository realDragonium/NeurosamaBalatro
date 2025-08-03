-- Start Run Action

local function start_run_executor(params)
    -- Start a new run (moved from MenuActions.start_run)
    if G.FUNCS and G.FUNCS.start_setup_run then
        G.FUNCS.start_setup_run()
        return true
    end
    return false
end

local function create_start_run_action()
    -- Only available when in New Run setup
    if G.SETTINGS and G.SETTINGS.current_setup == 'New Run' then
        return {
            name = "start_run",
            definition = {
                name = "start_run",
                description = "Start a new run",
                parameters = {}
            },
            executor = start_run_executor
        }
    end
    
    return nil
end

return create_start_run_action