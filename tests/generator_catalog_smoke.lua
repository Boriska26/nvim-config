-- Run in a separate Neovim process; fixture commands never generate files.
local function run()
    local catalog = require("generators.catalog")
    local help = require("devkit.help")
    help.setup()
    for _, entry in ipairs(catalog.generators()) do catalog.unregister(entry.command) end
    assert(#catalog.categories() == 0, "empty registry created categories")

    local function keys(value)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(value, true, false, true), "xt", false)
    end
    local function text()
        return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    end
    local function categories()
        local indexed = {}
        for _, category in ipairs(catalog.categories()) do
            assert(#category.generators > 0, "empty category: " .. category.id)
            assert(not indexed[category.id], "duplicate category: " .. category.id)
            for _, entry in ipairs(category.generators) do
                assert(vim.fn.exists(":" .. entry.command) == 2, "category contains an absent command")
            end
            indexed[category.id] = category
        end
        return indexed
    end
    vim.cmd("GeneratorHelp")
    assert(text():find("Зарегистрированных генераторов нет.", 1, true))
    assert(not text():find("C++", 1, true) and not text():find("C#", 1, true)
        and not text():find("DevOps", 1, true), "empty categories are visible")
    keys("jk<Down><Up><CR>") -- An empty menu must remain usable.
    keys("q")

    local fixture = {
        command = "DevKitTestGenerator",
        category = { id = "testgens", title = "Test generators", order = 15 },
        description = "Test fixture for generator registration",
        parameters = { { name = "NAME", description = "Test argument" } },
        examples = { ":DevKitTestGenerator Example" },
    }
    assert(not pcall(catalog.register, fixture), "metadata without a handler must be rejected")
    assert(vim.fn.exists(":" .. fixture.command) == 0 and #catalog.categories() == 0)
    local invalid = vim.deepcopy(fixture)
    invalid.examples = {}
    assert(not pcall(catalog.register, invalid, function() end), "empty examples accepted")
    assert(#catalog.categories() == 0, "invalid registration left an empty category")

    require("generators").setup()
    local initial = categories()
    assert(#catalog.categories() == 2 and #initial.cpp.generators == 1 and #initial.csharp.generators == 1)
    assert(not initial.testgens and not initial.devops)
    -- Check that every documented C++/C# example parses using the real argument parser.
    for _, entry in ipairs(catalog.generators()) do
        for _, example in ipairs(entry.examples) do
            local args = vim.split(example, "%s+", { trimempty = true })
            assert(table.remove(args, 1) == ":" .. entry.command)
            local parsed, err = require("generators.parser").parse(args, require("generators.arguments")[entry.language])
            assert(parsed, err)
        end
    end
    vim.cmd("GeneratorHelp")
    assert(text():find("C++", 1, true) and not text():find("--class", 1, true),
        "Generation should be a category menu")
    local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
    local calls = 0
    catalog.register(fixture, function(opts)
        calls = calls + 1
        assert(opts.fargs[1] == "Example")
    end)
    assert(text():find("Test generators", 1, true), "new category did not appear in the open menu")
    vim.cmd(fixture.command .. " Example")
    assert(calls == 1, "generator handler was not registered")
    assert(vim.api.nvim_get_current_win() == win and vim.api.nvim_get_current_buf() == buf)

    local devops = {
        command = "DevKitTestDevOpsGenerator",
        category = { id = "devops", title = "DevOps", order = 30 },
        description = "Test fixture for DevOps registration", parameters = {},
        examples = { ":DevKitTestDevOpsGenerator" },
    }
    catalog.register(devops, function() end, { nargs = 0 })
    assert(text():find("DevOps", 1, true), "DevOps category did not appear automatically")
    local all = categories()
    assert(#catalog.categories() == 4 and #all.testgens.generators == 1 and #all.devops.generators == 1)
    local listed = vim.api.nvim_exec2("GeneratorList", { output = true }).output
    assert(listed:find(fixture.command, 1, true) and listed:find(devops.command, 1, true))

    -- Registration snapshots metadata; later caller mutations must not change help.
    fixture.description = "mutated outside the registry"
    assert(categories().testgens.generators[1].description ~= fixture.description)
    local alternative = vim.deepcopy(categories().testgens.generators[1])
    alternative.command = "DevKitTestAlternative"
    alternative.examples = { ":DevKitTestAlternative Example" }
    catalog.register(alternative, function() end)
    catalog.register(alternative, function() end) -- Updating a command must not duplicate it.
    assert(#categories().testgens.generators == 2)
    catalog.unregister(fixture.command)
    assert(#categories().testgens.generators == 1 and text():find("Test generators", 1, true))
    keys("j<CR>")
    assert(text():find("Generation > Test generators", 1, true))
    assert(text():find(":" .. alternative.command, 1, true))
    assert(text():find(alternative.parameters[1].description, 1, true))
    assert(text():find(alternative.examples[1], 1, true))
    assert(not text():find(".nvim-generator.json", 1, true), "C++ notes leaked into a new category")
    catalog.unregister(alternative.command)
    assert(not categories().testgens and not text():find("Test generators", 1, true))
    assert(text():find("Generation  :GeneratorHelp", 1, true), "removed category left an orphan page")

    -- Even external removal cannot leave an unavailable command in the catalog views.
    vim.api.nvim_del_user_command(devops.command)
    vim.cmd("GeneratorHelp")
    assert(not categories().devops and not text():find("DevOps", 1, true))
    assert(not vim.api.nvim_exec2("GeneratorList", { output = true }).output:find(devops.command, 1, true))
    assert(catalog.unregister(devops.command) and not catalog.unregister(devops.command))
    assert(#catalog.categories() == 2 and #catalog.generators() == 2)
    keys("<Esc>")
    assert(not vim.api.nvim_buf_is_valid(buf), "generator help buffer leaked")
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
    vim.api.nvim_err_writeln(err)
    vim.cmd("cquit 1")
else
    print("PASS: generator registry (dynamic categories, metadata, no empty sections, lifecycle)")
    vim.cmd("qa!")
end
