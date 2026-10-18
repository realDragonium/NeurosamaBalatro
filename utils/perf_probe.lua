-- Perf probe: every 10 s logs where frame time went (update, Balatro's GC,
-- events, this mod, draw, present), the Lua heap and live object counts.
-- Diagnoses sustained "LONG DT" frames; remove once their cause is fixed.

local PerfProbe = {}

local INTERVAL = 10
local SLOW_MOD_FRAME = 0.05
-- nuGC runs a full collect every frame while the heap is above this many MB.
local GC_CEILING_MB = 300

local now = love.timer.getTime
local w

local function new_window(t)
    return {
        start = t, frames = 0, frame_max = 0, update = 0, gc = 0, gc_max = 0, full_gcs = 0,
        live_kb = nil, heap_max_kb = 0, events = 0, mod = 0, mod_max = 0, draw = 0, present = 0,
        drawcalls = 0,
    }
end

local function count(t)
    local n = 0
    for _ in pairs(t or {}) do
        n = n + 1
    end
    return n
end

local function queue_lengths()
    local parts = {}
    for name, queue in pairs(G.E_MANAGER and G.E_MANAGER.queues or {}) do
        if #queue > 0 then
            parts[#parts + 1] = name .. "=" .. #queue
        end
    end
    table.sort(parts)
    return #parts > 0 and table.concat(parts, ",") or "empty"
end

local function report(t)
    local span = t - w.start
    local frames = math.max(w.frames, 1)
    local function per_frame(total)
        return string.format("%.1f", total / frames * 1000)
    end
    sendInfoMessage(string.format(
        "fps=%.1f frame=%sms max=%.0fms | update=%sms (gc=%sms max=%.0fms full_gcs=%d events=%sms mod=%sms max=%.0fms)"
        .. " draw=%sms present=%sms drawcalls=%d | heap=%.0fMB max=%.0fMB live_after_full=%s | queues %s"
        .. " | nodes=%d moveables=%d cards=%d uiboxes=%d | state=%s",
        w.frames / span, per_frame(span), w.frame_max * 1000,
        per_frame(w.update), per_frame(w.gc), w.gc_max * 1000, w.full_gcs, per_frame(w.events),
        per_frame(w.mod), w.mod_max * 1000,
        per_frame(w.draw), per_frame(w.present), w.drawcalls,
        collectgarbage("count") / 1024, w.heap_max_kb / 1024,
        w.live_kb and string.format("%.0fMB", w.live_kb / 1024) or "-",
        queue_lengths(),
        count(G.I and G.I.NODE), count(G.MOVEABLES), count(G.I and G.I.CARD), count(G.I and G.I.UIBOX),
        tostring(G.STATE)), "PerfProbe")
end

-- Call once from inside love.update, when the game's globals all exist.
function PerfProbe.install()
    local last_frame
    local update = love.update
    love.update = function(dt)
        local t = now()
        if not w then
            w = new_window(t)
        end
        if last_frame then
            local frame = t - last_frame
            w.frames = w.frames + 1
            if frame > w.frame_max then
                w.frame_max = frame
            end
        end
        last_frame = t
        update(dt)
        w.update = w.update + (now() - t)
        if t - w.start >= INTERVAL then
            report(t)
            w = new_window(t)
        end
    end

    local draw = love.draw
    love.draw = function()
        local t = now()
        draw()
        if w then
            w.draw = w.draw + (now() - t)
        end
    end

    local present = love.graphics.present
    love.graphics.present = function()
        local t = now()
        if w then
            w.drawcalls = math.max(w.drawcalls, love.graphics.getStats().drawcalls)
        end
        present()
        if w then
            w.present = w.present + (now() - t)
        end
    end

    local gc = nuGC
    nuGC = function(time_budget, memory_ceiling, disable_otherwise)
        local t = now()
        local before = collectgarbage("count")
        gc(time_budget, memory_ceiling, disable_otherwise)
        if not w then
            return
        end
        local spent = now() - t
        w.gc = w.gc + spent
        if spent > w.gc_max then
            w.gc_max = spent
        end
        if before > w.heap_max_kb then
            w.heap_max_kb = before
        end
        if before / 1024 > (memory_ceiling or GC_CEILING_MB) then
            w.full_gcs = w.full_gcs + 1
            w.live_kb = collectgarbage("count")
        end
    end

    local events = EventManager.update
    EventManager.update = function(self, ...)
        local t = now()
        events(self, ...)
        if w then
            w.events = w.events + (now() - t)
        end
    end

    sendInfoMessage("Perf probe installed", "PerfProbe")
end

-- Runs this mod's per-frame work and records its cost. Balatro stops the GC
-- between nuGC calls, so the heap delta is what the mod allocated.
function PerfProbe.measure_mod(fn)
    local t, heap = now(), collectgarbage("count")
    fn()
    local spent = now() - t
    if not w then
        return
    end
    w.mod = w.mod + spent
    if spent > w.mod_max then
        w.mod_max = spent
    end
    if spent > SLOW_MOD_FRAME then
        sendInfoMessage(string.format("Slow mod frame: %.0fms, allocated %.1fMB",
            spent * 1000, (collectgarbage("count") - heap) / 1024), "PerfProbe")
    end
end

return PerfProbe
