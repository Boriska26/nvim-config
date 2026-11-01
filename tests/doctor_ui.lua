-- Isolated UI/language tests; fake probes only, no real dependency requirements.
local function run()
    local root = vim.env.NVIM_DOCTOR_TEST_ROOT or vim.fn.tempname()
    vim.fn.mkdir(root, "p")
    vim.opt.swapfile = false -- Isolate the harness from the user's swap directory.
    local filename = root .. "/work.txt"
    vim.fn.writefile({ "original file" }, filename)
    vim.fn.chdir(root)
    vim.cmd("edit " .. vim.fn.fnameescape(filename))
    local original_win, original_buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(original_buf, 0, -1, false, { "unsaved user text" })
    local maps = {}
    for _, mode in ipairs({ "n", "i", "x", "t" }) do maps[mode] = vim.api.nvim_get_keymap(mode) end
    local i18n = require("generators.i18n")
    local doctor = require("devkit.doctor")
    i18n.setup(); doctor.setup(); doctor.setup()
    assert(vim.fn.exists(":DevKitDoctor") == 2 and vim.fn.exists(":DevKitLang") == 2)
    local context = { platform = "Linux", version = { major = 0, minor = 12, patch = 6 } }
    local checks = {
        { id = "core.test", category = "core", name = { "Основная проверка", "Core check" },
            what = { "Проверка модуля", "Module check" }, why = { "Нужен для редактора", "Needed by the editor" }, fix = "core",
            run = function(_, done) done("OK", "available") end },
        { id = "cpp.optional", category = "cpp", name = { "Необязательный компилятор", "Optional compiler" },
            what = { "Компилятор C++ в PATH", "C++ compiler on PATH" }, why = { "Для сборки C++", "For building C++" }, fix = "compiler",
            run = function(_, done) done("WARNING", "missing") end },
        { id = "devops.probe", category = "devops", name = { "Проверка процесса", "Process probe" },
            what = { "Диагностическая команда", "Diagnostic command" }, why = { "Для DevOps", "For DevOps" }, fix = "optional",
            run = function(ctx, done) ctx.exec({ "fake-tool", "--version" }, function() done("OK", "version", { "1.2.3" }) end) end },
    }
    for index = 1, 25 do
        checks[#checks + 1] = { id = "core.extra." .. index, category = "core", name = { "Проверка " .. index, "Check " .. index },
            what = { "Локальная проверка", "Local check" }, why = { "Проверка прокрутки", "Scroll verification" }, fix = "core",
            run = function(_, done) done("OK", "available") end }
    end
    local calls, kills = 0, 0
    local function spawn(_, _, done)
        calls = calls + 1
        -- Deliberately deliver late callbacks even after cancellation.
        vim.defer_fn(function() done({ code = 0, stdout = "SECRET_TOKEN" }) end, 30)
        return { kill = function() kills = kills + 1 end }
    end
    local options = { context = context, checks = checks, spawn = spawn, timeout = 100 }
    local function keys(value)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(value, true, false, true), "xt", false)
    end
    local function text()
        return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    end
    local function completed()
        assert(vim.wait(1000, function() return not text():find("Проверяется", 1, true) and not text():find("Checking", 1, true) end))
    end
    local function floats()
        local count = 0
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            if vim.api.nvim_win_get_config(win).relative ~= "" then count = count + 1 end
        end
        return count
    end
    doctor.open(options)
    local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
    assert(vim.bo[buf].filetype == "devkitdoctor" and not vim.bo[buf].buflisted and not vim.bo[buf].modifiable)
    assert(vim.wait(1000, function() return calls == 1 end))
    local heartbeat = false
    vim.defer_fn(function() heartbeat = true end, 2)
    assert(vim.wait(20, function() return heartbeat end), "UI event loop blocked")
    vim.cmd("DevKitDoctor")
    assert(vim.api.nvim_get_current_win() == win and vim.api.nvim_get_current_buf() == buf and floats() == 1)
    completed()
    keys("G")
    assert(vim.api.nvim_win_get_cursor(win)[1] > 25, "native scrolling did not reach the bottom")
    keys("<C-u>k")
    local before_language = calls
    local row
    for index, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
        if line:find("Необязательный компилятор", 1, true) then row = index; break end
    end
    assert(row)
    vim.api.nvim_win_set_cursor(win, { row, 0 })
    keys("<CR>")
    assert(text():find("Что проверялось", 1, true) and text():find("Как исправить", 1, true))
    assert(text():find("pacman", 1, true) and text():find("Developer Command Prompt", 1, true))
    vim.cmd("DevKitLang en")
    assert(i18n.language() == "en" and text():find("What was checked", 1, true) and text():find("How to fix", 1, true))
    assert(not text():find("[\208\209]") and not text():find("SECRET", 1, true))
    assert(calls == before_language, "language change reran processes")
    assert(vim.deep_equal(vim.fn.getcompletion("DevKitLang e", "cmdline"), { "en" }))
    keys("?")
    assert(text():find("Ctrl-d/u", 1, true) and text():find("q/Esc", 1, true))
    keys("<BS>")
    assert(text():find("Warnings: 1", 1, true))
    keys("r")
    completed()
    assert(calls > before_language and kills > 0, "rerun did not cancel/refresh")
    keys("q")
    assert(not vim.api.nvim_buf_is_valid(buf) and floats() == 0)
    assert(vim.api.nvim_get_current_win() == original_win and vim.api.nvim_get_current_buf() == original_buf)
    local columns, lines = vim.o.columns, vim.o.lines
    vim.o.columns, vim.o.lines = 38, 12
    doctor.open(options)
    buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_exec_autocmds("VimResized", {})
    local geometry = vim.api.nvim_win_get_config(0)
    assert(geometry.width <= 34 and geometry.height <= 8)
    keys("<Esc>") -- Close while the asynchronous check is still pending.
    vim.wait(70, function() return false end)
    assert(not vim.api.nvim_buf_is_valid(buf) and floats() == 0)
    vim.o.columns, vim.o.lines = columns, lines
    doctor.open(options)
    buf = vim.api.nvim_get_current_buf()
    vim.cmd("close")
    assert(not vim.api.nvim_buf_is_valid(buf))
    vim.cmd("DevKitLang ru")
    assert(i18n.language() == "ru")
    local notify = vim.notify
    local message
    vim.notify = function(value) message = value end
    vim.cmd("DevKitLang unsupported")
    vim.notify = notify
    assert(i18n.language() == "ru" and message:find("DevKitLang", 1, true))
    assert(vim.api.nvim_buf_get_lines(original_buf, 0, -1, false)[1] == "unsaved user text" and vim.bo[original_buf].modified)
    assert(vim.deep_equal(vim.fn.readfile(filename), { "original file" }))
    assert(vim.fn.getcwd() == root)
    assert(#vim.fn.readdir(root) == 1, "diagnostics created project files")
    for mode, mapping in pairs(maps) do assert(vim.deep_equal(mapping, vim.api.nvim_get_keymap(mode))) end
    vim.g.devkit_language = nil
    print("PASS: Doctor UI (commands, language refresh, rerun, close, details, scrollable buffer, cancellation, no file changes)")
end
local ok, err = xpcall(run, debug.traceback)
if not ok then vim.api.nvim_err_writeln(err); vim.cmd("cquit 1") else vim.cmd("qa!") end
