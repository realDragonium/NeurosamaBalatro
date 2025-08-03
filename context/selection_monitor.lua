-- Selection Monitor
-- Detects manual card selection/deselection and sends context updates

local SelectionMonitor = {}

SelectionMonitor.original_add_to_highlighted = nil
SelectionMonitor.original_remove_from_highlighted = nil
SelectionMonitor.original_card_click = nil
SelectionMonitor.hooks_installed = false

-- Install hooks to monitor card selection changes
function SelectionMonitor.install_hooks()
    if SelectionMonitor.hooks_installed then
        return
    end
    
    -- Hook into Card.click method to catch manual UI clicks
    if Card and Card.click then
        SelectionMonitor.original_card_click = Card.click
        
        function Card:click()
            -- Call original function first
            local result = SelectionMonitor.original_card_click(self)
            
            -- Check if this is a hand card and send context update
            if G.hand and G.hand.cards then
                for _, hand_card in ipairs(G.hand.cards) do
                    if hand_card == self then
                        -- This is a hand card click, send context update
                        if sendWebSocketMessage then
                            local HandContext = require('context/hand_context')
                            local context = HandContext.build_context_string()
                            sendWebSocketMessage(context, "hand_manual_selection")
                            sendInfoMessage("Hand card clicked - context updated", "SelectionMonitor")
                        end
                        break
                    end
                end
            end
            
            return result
        end
    end
    
    -- Keep the CardArea hooks as backup for programmatic selection
    if G.hand and G.hand.add_to_highlighted then
        SelectionMonitor.original_add_to_highlighted = G.hand.add_to_highlighted
        
        G.hand.add_to_highlighted = function(self, card)
            local result = SelectionMonitor.original_add_to_highlighted(self, card)
            
            if sendWebSocketMessage then
                local HandContext = require('context/hand_context')
                local context = HandContext.build_context_string()
                sendWebSocketMessage(context, "hand_programmatic_selection")
            end
            
            return result
        end
    end
    
    if G.hand and G.hand.remove_from_highlighted then
        SelectionMonitor.original_remove_from_highlighted = G.hand.remove_from_highlighted
        
        G.hand.remove_from_highlighted = function(self, card)
            local result = SelectionMonitor.original_remove_from_highlighted(self, card)
            
            if sendWebSocketMessage then
                local HandContext = require('context/hand_context')
                local context = HandContext.build_context_string()
                sendWebSocketMessage(context, "hand_programmatic_deselection")
            end
            
            return result
        end
    end
    
    SelectionMonitor.hooks_installed = true
    sendInfoMessage("Selection monitoring hooks installed (Card.click + CardArea methods)", "SelectionMonitor")
end

-- Remove hooks (for cleanup)
function SelectionMonitor.remove_hooks()
    if not SelectionMonitor.hooks_installed then
        return
    end
    
    if G.hand and SelectionMonitor.original_add_to_highlighted then
        G.hand.add_to_highlighted = SelectionMonitor.original_add_to_highlighted
    end
    
    if G.hand and SelectionMonitor.original_remove_from_highlighted then
        G.hand.remove_from_highlighted = SelectionMonitor.original_remove_from_highlighted
    end
    
    SelectionMonitor.hooks_installed = false
    sendInfoMessage("Selection monitoring hooks removed", "SelectionMonitor")
end

-- Check if hooks need to be reinstalled (in case hand was recreated)
function SelectionMonitor.check_and_reinstall()
    if not G.hand then
        return
    end
    
    -- Check if our hooks are still in place
    if SelectionMonitor.hooks_installed then
        if G.hand.add_to_highlighted ~= SelectionMonitor.original_add_to_highlighted and
           G.hand.remove_from_highlighted ~= SelectionMonitor.original_remove_from_highlighted then
            -- Hooks seem to be in place, no need to reinstall
            return
        end
    end
    
    -- Need to install/reinstall hooks
    SelectionMonitor.hooks_installed = false
    SelectionMonitor.install_hooks()
end

return SelectionMonitor