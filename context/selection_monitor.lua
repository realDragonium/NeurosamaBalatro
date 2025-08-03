-- Selection Monitor
-- Detects manual card selection/deselection and sends context updates

local SelectionMonitor = {}
local HandContext = assert(SMODS.load_file("context/hand_context.lua"))()
local ContextRegistry = assert(SMODS.load_file("neuro/context_registry.lua"))()

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
            -- Store previous highlight state for hand cards only
            local was_highlighted = nil
            local is_hand_card = false

            -- Check if this is a hand card before the click
            if G.hand and G.hand.cards then
                for _, hand_card in ipairs(G.hand.cards) do
                    if hand_card == self then
                        is_hand_card = true
                        was_highlighted = self.highlighted
                        break
                    end
                end
            end

            -- Call original function
            local result = SelectionMonitor.original_card_click(self)

            -- Only send context update if this was a hand card and highlight state changed
            if is_hand_card then
                -- Convert nil to false for proper comparison
                local was_highlighted_bool = was_highlighted and true or false
                local is_highlighted_bool = self.highlighted and true or false

                if was_highlighted_bool ~= is_highlighted_bool then
                    -- Send context update
                    local context = HandContext.build_context_string()
                    local context_registry = ContextRegistry.get_instance()
                    context_registry:send_context_update(context, false)
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

            local context = HandContext.build_context_string()
            local context_registry = ContextRegistry.get_instance()
            context_registry:send_context_update(context, false)

            return result
        end
    end

    if G.hand and G.hand.remove_from_highlighted then
        SelectionMonitor.original_remove_from_highlighted = G.hand.remove_from_highlighted

        G.hand.remove_from_highlighted = function(self, card)
            local result = SelectionMonitor.original_remove_from_highlighted(self, card)

            local context = HandContext.build_context_string()
            local context_registry = ContextRegistry.get_instance()
            context_registry:send_context_update(context, false)

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

    if Card and SelectionMonitor.original_card_click then
        Card.click = SelectionMonitor.original_card_click
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
        local card_hook_ok = (Card and Card.click ~= SelectionMonitor.original_card_click)
        local hand_hooks_ok = true

        if G.hand.add_to_highlighted and G.hand.remove_from_highlighted then
            hand_hooks_ok = (G.hand.add_to_highlighted ~= SelectionMonitor.original_add_to_highlighted and
                           G.hand.remove_from_highlighted ~= SelectionMonitor.original_remove_from_highlighted)
        end

        if card_hook_ok and hand_hooks_ok then
            -- Hooks seem to be in place, no need to reinstall
            return
        end
    end

    -- Need to install/reinstall hooks
    SelectionMonitor.hooks_installed = false
    SelectionMonitor.install_hooks()
end

return SelectionMonitor