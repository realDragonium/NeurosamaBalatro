-- View Collection Action  
-- Navigates to the collection screen in the main menu

local function view_collection_executor(params)
    -- Check if we're in main menu
    if not (G.STATE == G.STATES.MAIN_MENU or G.STATE == G.STATES.MENU) then
        return false, "Can only view collection from main menu"
    end
    
    -- Try to find and click the collection button
    local collection_button = nil
    
    -- Look for collection button by ID
    if G.buttons then
        local collection_button_ids = {
            'collection',
            'collection_button', 
            'view_collection',
            'your_collection'
        }
        
        for _, button_id in ipairs(collection_button_ids) do
            collection_button = G.buttons:get_UIE_by_ID(button_id)
            if collection_button then
                break
            end
        end
    end
    
    -- If not found by ID, search through menu UI
    if not collection_button then
        local function find_collection_button(node)
            if not node then return nil end
            
            -- Check if this node is a collection button
            if node.config then
                -- Check button function
                if node.config.button == 'your_collection' or node.config.button == 'collection' then
                    return node
                end
                
                -- Check for collection-related text
                if node.config.text then
                    local text = node.config.text
                    if type(text) == "string" and (text:lower():find("collection") or text:lower():find("your cards")) then
                        return node
                    end
                end
            end
            
            -- Check child nodes recursively
            if node.nodes then
                for _, child in ipairs(node.nodes) do
                    local found_button = find_collection_button(child)
                    if found_button then return found_button end
                end
            end
            
            return nil
        end
        
        -- Search through main menu UI
        if G.OVERLAY_MENU and G.OVERLAY_MENU.definition then
            collection_button = find_collection_button(G.OVERLAY_MENU.definition)
        elseif G.MENU and G.MENU.definition then
            collection_button = find_collection_button(G.MENU.definition)
        end
    end
    
    -- Click the collection button if found
    if collection_button and collection_button.click then
        collection_button:click()
        return true, "Opened collection screen"
    end
    
    -- Fallback: try to use G.FUNCS directly
    if G.FUNCS and G.FUNCS.your_collection then
        G.FUNCS.your_collection()
        return true, "Opened collection screen via direct function call"
    end
    
    return false, "Could not find collection button or function"
end

local function create_view_collection_action()
    -- Only available in main menu states
    if not (G.STATE == G.STATES.MAIN_MENU or G.STATE == G.STATES.MENU) then
        return nil
    end
    
    return {
        name = "view_collection",
        definition = {
            name = "view_collection", 
            description = "Navigate to the collection screen to view discovered cards and jokers",
            parameters = {}
        },
        executor = view_collection_executor
    }
end

return create_view_collection_action