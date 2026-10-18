-- Score Preview
-- Scores candidate plays with the game's own scoring code, so jokers, card
-- enhancements, editions, seals and boss blinds all count. The scoring runs on
-- copies of everything it can change (G.GAME and every card's ability) with
-- animations, sounds, money and events muted, and the originals are put back
-- afterwards, so the game is left exactly as it was.
--
-- Mirrors G.FUNCS.evaluate_play (Steamodded 1.0.0~BETA-0711a) up to the final
-- score. Not run: destroying cards, context.after, and context.before for
-- jokers that create or convert cards there (DNA, Midas Mask, Vampire, ...).

local ScorePreview = {}

-- Their context.before only grows their own counters, which the real play
-- does before scoring.
local BEFORE_SAFE = {
    ["Spare Trousers"] = true,
    ["Square Joker"] = true,
    ["Runner"] = true,
    ["Ride the Bus"] = true,
    ["Obelisk"] = true,
    ["Green Joker"] = true,
}

local MUTED_GLOBALS = {
    "juice_card", "update_hand_text", "card_eval_status_text", "ease_dollars", "play_sound",
    "delay", "attention_text", "check_for_unlock", "check_and_set_high_score", "highlight_card",
    "play_area_status_text", "inc_career_stat", "level_up_hand", "ease_colour",
}

local SCORING_GLOBALS = { "hand_chips", "mult", "percent", "percent_delta" }
local SMODS_FIELDS = { "displayed_hand", "displaying_scoring", "post_prob", "saved", "no_resolve" }

local MAX_PLAYS_LISTED = 5

local function copy_plain(value, seen)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        return value
    end
    if seen[value] then
        return seen[value]
    end
    local copy = {}
    seen[value] = copy
    for k, v in pairs(value) do
        copy[k] = copy_plain(v, seen)
    end
    return copy
end

local function noop() end

-- Replaces fields with no-ops and returns a function that puts them back.
local function mute(targets)
    local saved = {}
    for i, target in ipairs(targets) do
        local tbl, key = target[1], target[2]
        if tbl then
            saved[i] = { tbl, key, rawget(tbl, key) }
            rawset(tbl, key, noop)
        end
    end
    return function()
        for _, entry in pairs(saved) do
            rawset(entry[1], entry[2], entry[3])
        end
    end
end

local function cards_in(areas)
    local cards = {}
    for _, area in ipairs(areas) do
        if area and area.cards then
            for _, card in ipairs(area.cards) do
                cards[#cards + 1] = card
            end
        end
    end
    return cards
end

-- Runs fn(...) against copies of the mutable game state; nothing it changes
-- survives the call. Returns pcall's results.
local function sandboxed(fn, ...)
    local targets = { { G.E_MANAGER, "add_event" }, { SMODS, "juice_up_blind" },
        { SMODS, "smart_level_up_hand" }, { Card, "juice_up" }, { Moveable, "juice_up" },
        { Blind, "wiggle" } }
    for _, name in ipairs(MUTED_GLOBALS) do
        if _G[name] then
            targets[#targets + 1] = { _G, name }
        end
    end

    local game = G.GAME
    local blind = game.blind
    local blind_triggered = blind and blind.triggered
    local globals = {}
    for _, name in ipairs(SCORING_GLOBALS) do
        globals[name] = _G[name]
    end
    local smods_fields = {}
    for _, name in ipairs(SMODS_FIELDS) do
        smods_fields[name] = SMODS[name]
    end
    local cards = cards_in({ G.jokers, G.consumeables, G.vouchers, G.hand, G.play })
    local abilities = {}
    for i, card in ipairs(cards) do
        abilities[i] = { card.ability, card.lucky_trigger }
        card.ability = copy_plain(card.ability, {})
    end
    local play_cards, hand_cards = G.play.cards, G.hand.cards

    local unmute = mute(targets)
    G.GAME = copy_plain(game, {})
    local results = { pcall(fn, ...) }
    G.GAME = game
    unmute()

    G.play.cards, G.hand.cards = play_cards, hand_cards
    for i, card in ipairs(cards) do
        card.ability, card.lucky_trigger = abilities[i][1], abilities[i][2]
    end
    for name, value in pairs(globals) do
        _G[name] = value
    end
    for name, value in pairs(smods_fields) do
        SMODS[name] = value
    end
    if blind then
        blind.triggered = blind_triggered
    end
    return unpack(results)
end

local function scoring_cards(cards, scoring_hand)
    local splash = next(find_joker("Splash"))
    local final = {}
    for _, card in ipairs(cards) do
        local scores = splash or SMODS.always_scores(card)
        if not scores then
            for _, scoring in ipairs(scoring_hand) do
                if scoring == card then
                    scores = true
                end
            end
        end
        if scores and not SMODS.never_scores(card) then
            final[#final + 1] = card
        end
    end
    return final
end

-- The joker phase of G.FUNCS.evaluate_play.
local function score_jokers(ctx)
    for _, area in ipairs(SMODS.get_card_areas("jokers")) do
        for _, _card in ipairs(area.cards) do
            local effects = {}
            local eval = eval_card(_card, { cardarea = G.jokers, full_hand = ctx.full_hand, scoring_hand = ctx.scoring_hand, scoring_name = ctx.scoring_name, poker_hands = ctx.poker_hands, edition = true, pre_joker = true })
            if eval.edition then effects[#effects + 1] = eval end

            local joker_eval, post = eval_card(_card, { cardarea = G.jokers, full_hand = ctx.full_hand, scoring_hand = ctx.scoring_hand, scoring_name = ctx.scoring_name, poker_hands = ctx.poker_hands, joker_main = true })
            if next(joker_eval) then
                if joker_eval.edition then joker_eval.edition = {} end
                table.insert(effects, joker_eval)
                for _, v in ipairs(post) do effects[#effects + 1] = v end
                if joker_eval.retriggers then
                    for rt = 1, #joker_eval.retriggers do
                        local rt_eval, rt_post = eval_card(_card, { cardarea = G.jokers, full_hand = ctx.full_hand, scoring_hand = ctx.scoring_hand, scoring_name = ctx.scoring_name, poker_hands = ctx.poker_hands, joker_main = true, retrigger_joker = true })
                        table.insert(effects, { retriggers = joker_eval.retriggers[rt] })
                        table.insert(effects, rt_eval)
                        for _, v in ipairs(rt_post) do effects[#effects + 1] = v end
                    end
                end
            end

            local other_key = "other_unknown"
            if _card.ability.set == "Joker" then other_key = "other_joker" end
            if _card.ability.consumeable then other_key = "other_consumeable" end
            if _card.ability.set == "Voucher" then other_key = "other_voucher" end
            for _, _area in ipairs(SMODS.get_card_areas("jokers")) do
                for _, _joker in ipairs(_area.cards) do
                    local other_eval, other_post = eval_card(_joker, { full_hand = ctx.full_hand, scoring_hand = ctx.scoring_hand, scoring_name = ctx.scoring_name, poker_hands = ctx.poker_hands, [other_key] = _card, other_main = _card })
                    if next(other_eval) then
                        if other_eval.edition then other_eval.edition = {} end
                        other_eval.jokers.juice_card = _joker
                        table.insert(effects, other_eval)
                        for _, v in ipairs(other_post) do effects[#effects + 1] = v end
                        if other_eval.retriggers then
                            for rt = 1, #other_eval.retriggers do
                                local rt_eval, rt_post = eval_card(_joker, { full_hand = ctx.full_hand, scoring_hand = ctx.scoring_hand, scoring_name = ctx.scoring_name, poker_hands = ctx.poker_hands, [other_key] = _card, retrigger_joker = true })
                                table.insert(effects, { retriggers = other_eval.retriggers[rt] })
                                table.insert(effects, rt_eval)
                                for _, v in ipairs(rt_post) do effects[#effects + 1] = v end
                            end
                        end
                    end
                end
            end
            for _, _area in ipairs(SMODS.get_card_areas("individual")) do
                local ind_eval, ind_post = SMODS.eval_individual(_area, { full_hand = ctx.full_hand, scoring_hand = ctx.scoring_hand, scoring_name = ctx.scoring_name, poker_hands = ctx.poker_hands, [other_key] = _card, other_main = _card })
                if next(ind_eval) then
                    ind_eval.individual.juice_card = _area.scored_card
                    table.insert(effects, ind_eval)
                    for _, v in ipairs(ind_post) do effects[#effects + 1] = v end
                end
            end

            local post_eval = eval_card(_card, { cardarea = G.jokers, full_hand = ctx.full_hand, scoring_hand = ctx.scoring_hand, scoring_name = ctx.scoring_name, poker_hands = ctx.poker_hands, edition = true, post_joker = true })
            if post_eval.edition then effects[#effects + 1] = post_eval end

            SMODS.trigger_effects(effects, _card)
        end
    end
end

-- Must run inside sandboxed(): it moves `played` into G.play and changes G.GAME.
local function score_play(played, held)
    G.play.cards, G.hand.cards = played, held
    local text, _, poker_hands, scoring_hand = G.FUNCS.get_poker_hand_info(played)
    scoring_hand = scoring_cards(played, scoring_hand)
    local hand = G.GAME.hands[text]
    hand.played = hand.played + 1
    hand.played_this_round = hand.played_this_round + 1
    G.GAME.last_hand_played = text
    if G.GAME.blind:debuff_hand(played, poker_hands, text, true) then
        return text, #scoring_hand, 0
    end

    local ctx = { full_hand = played, scoring_hand = scoring_hand, scoring_name = text, poker_hands = poker_hands }
    for _, joker in ipairs(G.jokers.cards) do
        if BEFORE_SAFE[joker.ability.name] and not joker.debuff then
            joker:calculate_joker({ full_hand = played, scoring_hand = scoring_hand, scoring_name = text, poker_hands = poker_hands, before = true })
        end
    end

    mult = mod_mult(hand.mult)
    hand_chips = mod_chips(hand.chips)
    mult, hand_chips = G.GAME.blind:modify_hand(played, poker_hands, text, mult, hand_chips, scoring_hand)
    mult, hand_chips = mod_mult(mult), mod_chips(hand_chips)
    percent, percent_delta = 0.3, 0.08
    SMODS.calculate_context({ initial_scoring_step = true, full_hand = played, scoring_hand = scoring_hand, scoring_name = text, poker_hands = poker_hands })
    for _, area in ipairs(SMODS.get_card_areas("playing_cards")) do
        SMODS.calculate_main_scoring({ cardarea = area, full_hand = played, scoring_hand = scoring_hand, scoring_name = text, poker_hands = poker_hands }, area == G.play and scoring_hand or nil)
    end
    score_jokers(ctx)
    SMODS.calculate_context({ full_hand = played, scoring_hand = scoring_hand, scoring_name = text, poker_hands = poker_hands, final_scoring_step = true })
    local nu_chip, nu_mult = G.GAME.selected_back:trigger_effect({ context = "final_scoring_step", chips = hand_chips, mult = mult })
    mult = mod_mult(nu_mult or mult)
    hand_chips = mod_chips(nu_chip or hand_chips)
    return text, #scoring_hand, math.floor(hand_chips * mult)
end

local function preview(indices)
    local played, held, chosen = {}, {}, {}
    for _, i in ipairs(indices) do
        chosen[i] = true
    end
    for i, card in ipairs(G.hand.cards) do
        if chosen[i] then
            played[#played + 1] = card
        else
            held[#held + 1] = card
        end
    end
    local ok, text, scoring, score = sandboxed(score_play, played, held)
    if not ok then
        sendWarnMessage("Score preview failed: " .. tostring(text), "ScorePreview")
        return nil
    end
    return { indices = indices, hand = text, scoring = scoring, score = score }
end

local function each_subset(n, max_size, fn)
    local picked = {}
    local function walk(start)
        if #picked > 0 then
            fn({ unpack(picked) })
        end
        if #picked == max_size then
            return
        end
        for i = start, n do
            picked[#picked + 1] = i
            walk(i + 1)
            picked[#picked] = nil
        end
    end
    walk(1)
end

-- Plays worth scoring: those whose every card scores (a kicker adds nothing),
-- or every play of the size a boss blind demands.
local function candidates()
    local n = #G.hand.cards
    local blind = G.GAME.blind
    local min_size = blind and not blind.disabled and blind.debuff and blind.debuff.h_size_ge or 1
    local list = {}
    each_subset(n, 5, function(indices)
        if #indices < min_size then
            return
        end
        if min_size > 1 then
            list[#list + 1] = indices
            return
        end
        local cards = {}
        for _, i in ipairs(indices) do
            cards[#cards + 1] = G.hand.cards[i]
        end
        local _, _, _, scoring_hand = G.FUNCS.get_poker_hand_info(cards)
        if #scoring_cards(cards, scoring_hand) == #cards then
            list[#list + 1] = indices
        end
    end)
    return list
end

local function format_play(play)
    return play.hand .. " [" .. table.concat(play.indices, ",") .. "]: " .. play.score
end

function ScorePreview.build_context_string()
    if G.STATE ~= G.STATES.SELECTING_HAND or not G.hand or not G.play or #G.play.cards > 0
        or #G.hand.cards == 0 then
        return ""
    end

    local best_by_hand = {}
    for _, indices in ipairs(candidates()) do
        local play = preview(indices)
        if not play then
            return ""
        end
        local best = best_by_hand[play.hand]
        if not best or play.score > best.score then
            best_by_hand[play.hand] = play
        end
    end
    local plays = {}
    for _, play in pairs(best_by_hand) do
        plays[#plays + 1] = play
    end
    table.sort(plays, function(a, b) return a.score > b.score end)

    local lines = { "Scored plays (the game's own scoring with your jokers, best first):" }
    for i = 1, math.min(MAX_PLAYS_LISTED, #plays) do
        lines[#lines + 1] = "  " .. format_play(plays[i])
    end

    local selected = {}
    for i, card in ipairs(G.hand.cards) do
        if card.highlighted then
            selected[#selected + 1] = i
        end
    end
    if #selected > 0 and #selected <= 5 then
        local play = preview(selected)
        if play then
            lines[#lines + 1] = "Selected cards: " .. format_play(play)
        end
    end
    return table.concat(lines, "\n")
end

return ScorePreview
