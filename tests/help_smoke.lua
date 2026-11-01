-- Run with -u NONE and this repo on runtimepath, or after loading the full config.
local function run()
    local optional = { "telescope", "telescope.builtin", "cmp", "lsp_signature", "mason",
        "roslyn", "tokyonight", "nvim-tree", "bufferline", "lualine" }
    local blocked = {}
    for _, name in ipairs(optional) do
        if not package.loaded[name] then
            blocked[#blocked + 1] = name
            package.preload[name] = function() error("help attempted to load optional plugin: " .. name) end
        end
    end

    local initial_win, initial_buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
    local initial_lines = vim.api.nvim_buf_get_lines(initial_buf, 0, -1, false)
    local global_maps = {}
    for _, mode in ipairs({ "n", "i", "x", "t", "v", "s" }) do
        global_maps[mode] = vim.api.nvim_get_keymap(mode)
    end
    local help = require("devkit.help")
    require("generators").setup()
    -- GeneratorHelp also works when only the generator was explicitly initialized.
    vim.cmd("GeneratorHelp")
    assert(vim.bo.filetype == "devkithelp")
    help.close()
    help.setup()
    help.setup() -- Repeated setup must not duplicate commands or autocmds.
    local sections = require("devkit.help_data")
    local commands = vim.api.nvim_get_commands({ builtin = false })
    for _, name in ipairs({ "DevKitHelp", "GeneratorHelp", "WindowHelp", "SearchHelp",
        "EditingHelp", "LspHelp", "TerminalHelp", "GitHelp", "AppearanceHelp" }) do
        assert(commands[name], "missing command: " .. name)
    end
    for _, name in ipairs(require("generators.catalog").command_names()) do
        assert(commands[name], "generator command lost: " .. name)
    end
    local function keys(value)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(value, true, false, true), "xt", false)
    end
    local function text()
        return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    end
    local function floats()
        local count = 0
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            if vim.api.nvim_win_get_config(win).relative ~= "" then count = count + 1 end
        end
        return count
    end
    local function assert_closed(buf)
        assert(floats() == 0, "help left a floating window")
        assert(not vim.api.nvim_buf_is_valid(buf), "help scratch buffer leaked")
        assert(vim.api.nvim_get_current_win() == initial_win, "original window not restored")
    end

    vim.cmd("DevKitHelp")
    local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
    assert(floats() == 1 and vim.bo[buf].filetype == "devkithelp")
    assert(not vim.bo[buf].modifiable and not vim.bo[buf].buflisted)
    for _, section in ipairs(sections) do
        assert(text():find(section.title, 1, true) and text():find(":" .. section.command, 1, true))
    end
    local first_row = vim.api.nvim_win_get_cursor(win)[1]
    keys("j<Down>")
    assert(vim.api.nvim_win_get_cursor(win)[1] == first_row + 2, "down navigation failed")
    keys("k<Up>")
    assert(vim.api.nvim_win_get_cursor(win)[1] == first_row, "up navigation failed")
    keys("<CR>")
    assert(text():find("Generation  :GeneratorHelp", 1, true), "Enter did not open selection")
    assert(text():find("C++", 1, true) and text():find("C#", 1, true)
        and text():find("DevOps", 1, true), "Generation must show only implemented categories")
    keys("<CR>")
    assert(text():find("Generation > C++", 1, true), "Enter did not open C++ generators")
    for _, entry in ipairs(require("generators.catalog").categories()[1].generators) do
        assert(text():find(":" .. entry.command, 1, true) and text():find(entry.description, 1, true))
        for _, parameter in ipairs(entry.parameters) do assert(text():find(parameter.name, 1, true)) end
        for _, example in ipairs(entry.examples) do assert(text():find(example, 1, true)) end
    end
    keys("<BS>")
    assert(text():find("Generation  :GeneratorHelp", 1, true), "Backspace skipped Generation")
    keys("j<CR>")
    assert(text():find("Generation > C#", 1, true) and text():find(":CreateCSharp", 1, true))
    assert(text():find("--record-struct", 1, true))
    keys("<BS>")
    keys("j<CR>")
    assert(text():find("Generation > DevOps", 1, true) and text():find(":CreateDevOps", 1, true))
    assert(text():find("--dockerfile", 1, true) and text():find("--nginx", 1, true))
    keys("<BS>")
    keys("<BS>")
    assert(text():find("Neovim Developer Kit", 1, true), "Backspace did not return to menu")
    keys("j<CR>")
    assert(text():find("Windows  :WindowHelp", 1, true))
    keys("h")
    assert(text():find("Neovim Developer Kit", 1, true), "h did not return to menu")
    assert(vim.api.nvim_get_current_win() == win and vim.api.nvim_get_current_buf() == buf)
    vim.cmd("DevKitHelp")
    assert(floats() == 1 and vim.api.nvim_get_current_buf() == buf, "reopening duplicated help")
    keys("q")
    assert_closed(buf)

    for _, section in ipairs(sections) do
        vim.cmd(section.command)
        buf = vim.api.nvim_get_current_buf()
        assert(text():find(section.title .. "  :" .. section.command, 1, true))
        assert(vim.bo.filetype == "devkithelp")
        keys("<Esc>")
        assert_closed(buf)
    end
    -- The generator may be set up after help in init.lua; its alias must still open the UI.
    require("generators").setup()
    vim.cmd("GeneratorHelp")
    assert(vim.bo.filetype == "devkithelp")
    help.close()
    assert(vim.api.nvim_exec2("CreateHelp", { output = true }).output:find(":CreateCpp", 1, true))
    local listed = vim.api.nvim_exec2("GeneratorList", { output = true }).output
    for _, name in ipairs(require("generators.catalog").command_names()) do
        assert(listed:find(name, 1, true))
    end

    vim.cmd("SearchHelp")
    buf = vim.api.nvim_get_current_buf()
    local columns, lines = vim.o.columns, vim.o.lines
    vim.o.columns, vim.o.lines = 40, 12
    vim.api.nvim_exec_autocmds("VimResized", {})
    local config = vim.api.nvim_win_get_config(0)
    assert(config.width <= 36 and config.height <= 8, "help did not fit the smaller editor")
    keys("j") -- Native scrolling remains available in a section.
    assert(vim.api.nvim_win_get_cursor(0)[1] == 2)
    vim.o.columns, vim.o.lines = columns, lines
    vim.api.nvim_exec_autocmds("VimResized", {})
    vim.cmd("close") -- Closing externally must also clean up state.
    assert_closed(buf)
    vim.cmd("DevKitHelp")
    buf = vim.api.nvim_get_current_buf()
    keys("q")
    assert_closed(buf)

    assert(vim.api.nvim_get_current_buf() == initial_buf)
    assert(vim.deep_equal(initial_lines, vim.api.nvim_buf_get_lines(initial_buf, 0, -1, false)))
    for mode, mappings in pairs(global_maps) do
        assert(vim.deep_equal(mappings, vim.api.nvim_get_keymap(mode)), "global mappings changed: " .. mode)
    end
    for _, name in ipairs(blocked) do
        assert(not package.loaded[name], "optional plugin loaded by help: " .. name)
        package.preload[name] = nil
    end
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
    vim.api.nvim_err_writeln(err)
    vim.cmd("cquit 1")
else
    print("PASS: DevKitHelp smoke test (commands, navigation, lifecycle, resize, optional plugins)")
    vim.cmd("qa!")
end
