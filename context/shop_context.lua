-- Shop Context Builder
-- Handles shop inventory and pricing information

local ShopContext = {}

-- Build shop joker description string
function ShopContext.build_shop_joker_string(joker, index)
    if not joker then return nil end

    local name = "Unknown Joker"
    local cost = 0
    local description = ""

    -- Get joker details
    if joker.config and joker.config.center then
        local center = joker.config.center
        name = center.name or name
        cost = center.cost or cost
        description = center.text or ""
    end

    -- Try to get dynamic description with current values
    if joker.generate_UIBox_ability_table and joker.config and joker.config.center then
        local success, loc_vars = pcall(joker.generate_UIBox_ability_table, joker, true)
        if success and loc_vars then
            -- Get localized description with current values
            local loc_success, localized_text = pcall(localize, {type = 'descriptions', key = joker.config.center.key, set = joker.config.center.set}, loc_vars)
            if loc_success and localized_text and localized_text.text then
                -- Join the text lines
                description = table.concat(localized_text.text, " ")
            end
        end
    end

    local joker_desc = "  " .. index .. ". " .. name .. " - $" .. cost
    if description and description ~= "" then
        joker_desc = joker_desc .. " (" .. description .. ")"
    end

    return joker_desc
end

-- Build shop pack description string
function ShopContext.build_shop_pack_string(pack, index)
    if not pack then return nil end

    local name = "Unknown Pack"
    local cost = 0
    local description = ""

    -- Get pack details
    if pack.config and pack.config.center then
        local center = pack.config.center
        name = center.name or name
        cost = center.cost or cost
        description = center.text or ""
    end

    -- Try to get dynamic description with current values
    if pack.generate_UIBox_ability_table and pack.config and pack.config.center then
        local success, loc_vars = pcall(pack.generate_UIBox_ability_table, pack, true)
        if success and loc_vars then
            -- Get localized description with current values
            local loc_success, localized_text = pcall(localize, {type = 'descriptions', key = pack.config.center.key, set = pack.config.center.set}, loc_vars)
            if loc_success and localized_text and localized_text.text then
                -- Join the text lines
                description = table.concat(localized_text.text, " ")
            end
        end
    end

    local pack_desc = "  " .. index .. ". " .. name .. " - $" .. cost
    if description and description ~= "" then
        pack_desc = pack_desc .. " (" .. description .. ")"
    end

    return pack_desc
end

-- Build shop voucher description string
function ShopContext.build_shop_voucher_string(voucher, index)
    if not voucher then return nil end

    local name = "Unknown Voucher"
    local cost = 0
    local description = ""

    -- Get voucher details
    if voucher.config and voucher.config.center then
        local center = voucher.config.center
        name = center.name or name
        cost = center.cost or cost
        description = center.text or ""
    end

    -- Try to get dynamic description with current values
    if voucher.generate_UIBox_ability_table and voucher.config and voucher.config.center then
        local success, loc_vars = pcall(voucher.generate_UIBox_ability_table, voucher, true)
        if success and loc_vars then
            -- Get localized description with current values
            local loc_success, localized_text = pcall(localize, {type = 'descriptions', key = voucher.config.center.key, set = voucher.config.center.set}, loc_vars)
            if loc_success and localized_text and localized_text.text then
                -- Join the text lines
                description = table.concat(localized_text.text, " ")
            end
        end
    end

    local voucher_desc = "  " .. index .. ". " .. name .. " - $" .. cost
    if description and description ~= "" then
        voucher_desc = voucher_desc .. " (" .. description .. ")"
    end

    return voucher_desc
end

-- Build shop context string
function ShopContext.build_context_string()
    local parts = {}

    -- Only show shop context when in shop
    if G.STATE ~= G.STATES.SHOP then
        return ""
    end

    -- Shop jokers
    if G.shop_jokers and G.shop_jokers.cards and #G.shop_jokers.cards > 0 then
        table.insert(parts, "Shop Jokers:")
        for i, joker in ipairs(G.shop_jokers.cards) do
            local joker_desc = ShopContext.build_shop_joker_string(joker, i)
            if joker_desc then
                table.insert(parts, joker_desc)
            end
        end
    else
        table.insert(parts, "Shop Jokers: None")
    end

    -- Shop packs
    if G.shop_booster and G.shop_booster.cards and #G.shop_booster.cards > 0 then
        table.insert(parts, "Shop Packs:")
        for i, pack in ipairs(G.shop_booster.cards) do
            local pack_desc = ShopContext.build_shop_pack_string(pack, i)
            if pack_desc then
                table.insert(parts, pack_desc)
            end
        end
    else
        table.insert(parts, "Shop Packs: None")
    end

    -- Shop vouchers
    if G.shop_vouchers and G.shop_vouchers.cards and #G.shop_vouchers.cards > 0 then
        table.insert(parts, "Shop Vouchers:")
        for i, voucher in ipairs(G.shop_vouchers.cards) do
            local voucher_desc = ShopContext.build_shop_voucher_string(voucher, i)
            if voucher_desc then
                table.insert(parts, voucher_desc)
            end
        end
    else
        table.insert(parts, "Shop Vouchers: None")
    end

    return table.concat(parts, "\n")
end

return ShopContext