local M = {}
local text = require("devkit.doctor.text")
local model = require("devkit.doctor.model")
local state = { token = 0, mode = "list", rows = {} }
local namespace = vim.api.nvim_create_namespace("DevKitDoctor")
local categories = { "core", "csharp", "cpp", "devops" }
local symbols = { OK = "✓", WARNING = "!", ERROR = "✖", SKIPPED = "-" }
local groups = { OK = "DiagnosticOk", WARNING = "DiagnosticWarn", ERROR = "DiagnosticError", SKIPPED = "Comment" }
local function geometry()
    local width = math.max(1, math.min(110, vim.o.columns - 4))
    local height = math.max(1, math.min(32, vim.o.lines - vim.o.cmdheight - 4))
    return { relative = "editor", style = "minimal", border = "rounded", zindex = 65,
        width = width, height = height, row = math.max(0, math.floor((vim.o.lines - height - 3) / 2)),
        col = math.max(0, math.floor((vim.o.columns - width - 2) / 2)),
        title = " DevKitDoctor ", title_pos = "center", footer = text.get("footer"), footer_pos = "center" }
end
local function append(lines, value)
    for line in (value or ""):gmatch("[^\n]+") do lines[#lines + 1] = line end
end
local function valid()
    return state.win and vim.api.nvim_win_is_valid(state.win) and state.buf and vim.api.nvim_buf_is_valid(state.buf)
end
local function render()
    if not valid() then return end
    local row = vim.api.nvim_win_get_cursor(state.win)[1]
    local selected = state.rows[row]
    local lines, rows, marks = { text.get("title") }, {}, {}
    local results = state.run and state.run.results or {}
    if state.mode == "keys" then
        lines[#lines + 1] = ""
        append(lines, text.get("keys"))
        lines[#lines + 1] = ""
        append(lines, text.get("no_changes"))
    elseif state.mode == "details" and results[state.selected] then
        local result = results[state.selected]
        local detail = model.describe(result, state.context.platform)
        lines[#lines + 1] = detail.name .. " [" .. detail.status .. "] — " .. detail.id
        for _, item in ipairs({ { "what", detail.what }, { "found", detail.explanation },
            { "why", detail.why }, { "fix", detail.recommendation } }) do
            if item[2] ~= "" then
                lines[#lines + 1] = ""
                lines[#lines + 1] = text.get(item[1]) .. ":"
                append(lines, item[2])
            end
        end
    else
        local v = state.context.version
        lines[#lines + 1] = text.get("platform", state.context.platform, string.format("%d.%d.%d", v.major, v.minor, v.patch))
        local count = model.count(results)
        lines[#lines + 1] = text.get("summary", count.ERROR, count.WARNING, count.SKIPPED, count.complete, #state.checks)
        lines[#lines + 1] = ""
        for _, category in ipairs(categories) do
            lines[#lines + 1] = "[" .. text.get(category) .. "]"
            for _, check in ipairs(state.checks) do
                if check.category == category then
                    local result = results[check.id]
                    if result then
                        local detail = model.describe(result, state.context.platform)
                        lines[#lines + 1] = symbols[result.status] .. " [" .. detail.status .. "] " .. detail.name .. " — " .. detail.explanation
                        marks[#marks + 1] = { #lines - 1, groups[result.status] }
                    else lines[#lines + 1] = "… " .. text.pair(check.name) .. " — " .. text.get("running") end
                    rows[#lines] = check.id
                end
            end
            lines[#lines + 1] = ""
        end
        append(lines, text.get("no_changes"))
    end
    state.rows = rows
    vim.bo[state.buf].modifiable = true
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
    vim.bo[state.buf].modifiable, vim.bo[state.buf].modified = false, false
    vim.api.nvim_buf_clear_namespace(state.buf, namespace, 0, -1)
    vim.api.nvim_buf_set_extmark(state.buf, namespace, 0, 0, { end_col = #lines[1], hl_group = "Title" })
    for _, mark in ipairs(marks) do
        vim.api.nvim_buf_set_extmark(state.buf, namespace, mark[1], 0, { end_col = #lines[mark[1] + 1], hl_group = mark[2] })
    end
    if selected then for index, id in pairs(rows) do if id == selected then row = index; break end end end
    vim.api.nvim_win_set_cursor(state.win, { math.min(row, #lines), 0 })
    vim.api.nvim_win_set_config(state.win, geometry())
end

function M.refresh()
    if not valid() then return end
    if state.run then state.run.cancel() end
    state.token, state.mode = state.token + 1, "list"
    local token = state.token
    local options = state.options or {}
    local ok, context = pcall(function() return options.context or require("devkit.doctor.context").collect() end)
    state.context = ok and context or { platform = "Unsupported", version = vim.version() }
    if ok then state.checks = options.checks or require("devkit.doctor.checks").build(state.context)
    else state.checks = { { id = "core.context", category = "core", name = { "Контекст DevKit", "DevKit context" },
        what = { "Сбор конфигурации", "Collect configuration" }, why = { "Для диагностики окружения", "For environment diagnostics" },
        fix = "core", run = function(_, done) done("ERROR", "internal") end } } end
    state.run = require("devkit.doctor.runner").run(state.checks, state.context, {
        spawn = options.spawn, timeout = options.timeout, concurrency = 2,
        on_update = function()
            if token == state.token and valid() then render() end
        end,
    })
    render()
end
function M.close()
    if valid() then vim.api.nvim_win_close(state.win, true) end
end
function M.open(options)
    state.options = options or state.options or {}
    if not valid() then
        state.buf = vim.api.nvim_create_buf(false, true)
        local buf = state.buf
        vim.bo[buf].bufhidden, vim.bo[buf].swapfile, vim.bo[buf].filetype = "wipe", false, "devkitdoctor"
        state.win = vim.api.nvim_open_win(buf, true, geometry())
        local win = state.win
        vim.wo[win].wrap, vim.wo[win].linebreak, vim.wo[win].spell = true, true, false
        vim.wo[win].winbar, vim.wo[win].scrolloff = "", 0
        local function map(key, callback)
            vim.keymap.set("n", key, callback, { buffer = buf, silent = true, nowait = true })
        end
        map("q", M.close); map("<Esc>", M.close); map("r", M.refresh)
        map("<CR>", function()
            local id = state.rows[vim.api.nvim_win_get_cursor(win)[1]]
            if id and state.run.results[id] then state.selected, state.mode = id, "details"; render(); vim.api.nvim_win_set_cursor(win, { 1, 0 }) end
        end)
        map("?", function() state.mode = state.mode == "keys" and "list" or "keys"; render() end)
        local function back() state.mode = "list"; render() end
        map("<BS>", back); map("h", back)
        vim.api.nvim_create_autocmd("BufWipeout", { buffer = buf, once = true, callback = function()
            if state.run then state.run.cancel() end
            state.token, state.buf, state.win = state.token + 1, nil, nil
        end })
    else vim.api.nvim_set_current_win(state.win) end
    vim.cmd("stopinsert")
    M.refresh()
end
function M.setup()
    local group = vim.api.nvim_create_augroup("DevKitDoctor", { clear = true })
    local function register()
        vim.api.nvim_create_user_command("DevKitDoctor", function() M.open() end, { desc = text.get("command") })
    end
    vim.api.nvim_create_autocmd("VimResized", { group = group, callback = function()
        if valid() then vim.api.nvim_win_set_config(state.win, geometry()) end
    end })
    vim.api.nvim_create_autocmd("User", { group = group, pattern = "DevKitLanguageChanged", callback = function() register(); render() end })
    register()
end
return M
