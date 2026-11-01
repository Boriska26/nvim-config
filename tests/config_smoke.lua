-- Run after loading init.lua with the existing plugins installed (see tests/README.md).
local function run()
    assert(vim.g.colors_name == "tokyonight-night", "Tokyo Night Night is not active")

    local toggle = vim.fn.maparg("<leader>tt", "n", false, true).callback
    assert(type(toggle) == "function", "terminal mapping is missing")
    assert(vim.fn.maparg("<leader>ее", "n", false, true).callback == toggle,
        "Russian terminal mapping must share the same state")
    assert(vim.fn.maparg("Ж", "n") == ":", "Russian command-line mapping is missing")

    -- Hiding/reopening must keep both the terminal buffer and the shell process.
    toggle()
    vim.cmd("stopinsert")
    local terminal = vim.api.nvim_get_current_buf()
    local job = vim.b[terminal].terminal_job_id
    assert(vim.bo[terminal].buftype == "terminal")
    assert(vim.bo[terminal].bufhidden == "hide" and not vim.bo[terminal].buflisted)
    assert(vim.wo.winbar:find("TERMINAL", 1, true))
    toggle()
    assert(vim.fn.bufwinid(terminal) == -1, "terminal window was not hidden")
    assert(vim.fn.jobwait({ job }, 0)[1] == -1, "hiding stopped the shell")
    toggle()
    vim.cmd("stopinsert")
    assert(vim.api.nvim_get_current_buf() == terminal, "terminal buffer was replaced")
    assert(vim.b[terminal].terminal_job_id == job, "shell was restarted")

    -- Toggling the last remaining window must not close it.
    local terminal_win = vim.api.nvim_get_current_win()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if win ~= terminal_win then vim.api.nvim_win_close(win, true) end
    end
    toggle()
    assert(vim.api.nvim_win_is_valid(terminal_win), "last window was closed")
    vim.cmd("topleft new")

    -- TermClose should clean up visible and hidden terminals, then allow a new shell.
    vim.api.nvim_chan_send(job, "exit\n")
    assert(vim.wait(5000, function() return not vim.api.nvim_buf_is_valid(terminal) end),
        "exited terminal was not deleted")
    toggle()
    vim.cmd("stopinsert")
    local replacement = vim.api.nvim_get_current_buf()
    assert(replacement ~= terminal, "terminal was not recreated after exit")
    local replacement_job = vim.b[replacement].terminal_job_id
    toggle()
    vim.api.nvim_chan_send(replacement_job, "exit\n")
    assert(vim.wait(5000, function() return not vim.api.nvim_buf_is_valid(replacement) end),
        "hidden exited terminal was not deleted")

    -- Exercise the save event without starting an actual language server.
    local get_clients, format = vim.lsp.get_clients, vim.lsp.buf.format
    local ok, err = pcall(function()
        local calls = {}
        vim.lsp.get_clients = function(filter)
            assert(filter.bufnr == vim.api.nvim_get_current_buf())
            assert(filter.method == "textDocument/formatting")
            return { { name = "other", id = 1 }, { name = "roslyn", id = 2 } }
        end
        vim.lsp.buf.format = function(opts) calls[#calls + 1] = opts end
        local function save_event(filename)
            vim.api.nvim_exec_autocmds("BufWritePre", {
                group = "CSharpFormatOnSave", pattern = filename,
            })
        end
        save_event("Example.cs")
        assert(#calls == 1 and calls[1].id == 2, "save did not select Roslyn")
        assert(calls[1].bufnr == vim.api.nvim_get_current_buf())
        assert(calls[1].async == false and calls[1].timeout_ms == 3000)
        save_event("Example.lua")
        assert(#calls == 1, "formatting ran for a non-C# file")
        vim.lsp.get_clients = function() return { { name = "other", id = 1 } } end
        save_event("Example.cs")
        assert(#calls == 1, "formatting ran without Roslyn")
    end)
    vim.lsp.get_clients, vim.lsp.buf.format = get_clients, format
    assert(ok, err)
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
    vim.api.nvim_err_writeln(err)
    vim.cmd("cquit 1")
else
    print("PASS: configuration smoke test (terminal lifecycle, Russian mappings, C# save)")
    vim.cmd("qa!")
end
