local M = {}
function M.run(checks, context, opts)
    opts = opts or {}
    local model = require("devkit.doctor.model")
    local spawn = opts.spawn or require("devkit.doctor.process").spawn
    local schedule = opts.schedule or vim.schedule
    local state = { results = {}, cancelled = false, complete = false }
    local queue, handles, timers, next_job, active, completed = {}, {}, {}, 1, 0, 0
    local limit, timeout = math.max(1, math.min(opts.concurrency or 2, 2)), opts.timeout or 2500
    local pump
    local function publish()
        state.complete = completed == #checks
        if opts.on_update then opts.on_update(state) end
    end
    local function stop(timer)
        if timer then pcall(function() timer:stop(); if not timer:is_closing() then timer:close() end end) end
    end
    pump = function()
        while not state.cancelled and active < limit and next_job <= #queue do
            local job = queue[next_job]
            next_job, active = next_job + 1, active + 1
            local finished, timer = false, nil
            local function finish(result)
                schedule(function()
                    if finished or state.cancelled then return end
                    stop(timer)
                    finished, active = true, active - 1
                    local ok = pcall(job.callback, result)
                    if not ok and job.failed then job.failed() end
                    pump()
                end)
            end
            local ok, handle = pcall(spawn, job.argv, { timeout = timeout }, finish)
            if ok and handle then
                handles[#handles + 1] = handle
                timer = (opts.defer or vim.defer_fn)(function()
                    if finished or state.cancelled then return end
                    pcall(function() handle:kill(9) end)
                    finish({ code = 124, stdout = "" })
                end, timeout + 50)
                timers[#timers + 1] = timer
            else finish({ code = -1, stdout = "" }) end
        end
    end
    function state.cancel()
        if state.cancelled then return end
        state.cancelled = true
        for _, handle in ipairs(handles) do pcall(function() handle:kill(9) end) end
        for _, timer in ipairs(timers) do stop(timer) end
    end
    schedule(function()
        if state.cancelled then return end
        local ids = {}
        for _, check in ipairs(checks) do
            assert(not ids[check.id], "Duplicate doctor check: " .. check.id)
            ids[check.id] = true
            local done = false
            local function finish(status, reason, values)
                if done or state.cancelled then return end
                local ok, result = pcall(model.result, check, status, reason, values)
                done = true
                state.results[check.id] = ok and result or model.result(check, "ERROR", "internal")
                completed = completed + 1
                publish()
            end
            local ctx = setmetatable({}, { __index = context })
            ctx.exec = function(argv, callback)
                queue[#queue + 1] = { argv = argv, callback = callback, failed = function() finish("ERROR", "internal") end }
                schedule(function() if not state.cancelled then pump() end end)
            end
            local ok = pcall(check.run, ctx, finish)
            if not ok then finish("ERROR", "internal") end
        end
        publish()
        pump()
    end)
    return state
end
return M
