-- Select Stake Action

local function select_stake_executor(params)
    -- Select stake level (moved from MenuActions.select_stake)
    local stake_level = params.stake_level
    if not stake_level then
        return false, "Stake level parameter required"
    end

    if G.FUNCS.change_stake then
        local stake_num = tonumber(stake_level)
        if stake_num and stake_num >= 1 and stake_num <= 8 then
            G.FUNCS.change_stake({to_key = stake_num})
            return true, "Selected stake level: " .. stake_num
        end
    end
    return false, "Invalid stake level or function not available"
end

local function create_select_stake_action()
    -- Only available when in New Run setup
    if G.SETTINGS and G.SETTINGS.current_setup == 'New Run' then
        return {
            name = "select_stake",
            definition = {
                name = "select_stake",
                description = "Select stake level for the new run",
                schema = {
                    type = "object",
                    properties = {
                        stake_level = {
                            type = "integer",
                            minimum = 1,
                            maximum = 8,
                        }
                    },
                    required = {"stake_level"}
                }
            },
            executor = select_stake_executor
        }
    end

    return nil
end

return create_select_stake_action