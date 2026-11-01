local M = {}
local catalog = require("generators.catalog")
local arguments = require("generators.arguments")
local root

local function run(language, opts)
    local result, err = require("generators.service").generate(root, language, opts.fargs)
    if not result then return vim.notify("Генератор: " .. err, vim.log.levels.ERROR) end
    if result.help then
        print(catalog.help(language))
        return
    end
    local created = {}
    for _, entry in ipairs(result.entries) do created[#created + 1] = entry.path end
    vim.notify("Создано: " .. table.concat(created, ", "), vim.log.levels.INFO)
    local filename = require("generators.paths").file(root, result.entries[1].path)
    local opened, open_err = pcall(vim.cmd, (vim.bo.modified and "split " or "edit ") .. vim.fn.fnameescape(filename))
    if not opened then vim.notify("Файлы созданы, но не удалось открыть: " .. tostring(open_err), vim.log.levels.WARN) end
    local ok, tree = pcall(require, "nvim-tree.api")
    if ok then pcall(tree.tree.reload) end
end

function M.setup()
    -- Repeated command registration must never change the captured launch root.
    root = root or vim.fn.getcwd()
    for _, metadata in ipairs(catalog.commands) do
        local language = metadata.language
        catalog.register(metadata, function(opts) run(language, opts) end, {
            nargs = "*", complete = function(lead) return arguments.complete(arguments[language], lead) end,
        })
    end
    vim.api.nvim_create_user_command("CreateRoot", function()
        print("Корень генератора: " .. root)
    end, { desc = "Показать корень генератора" })
    vim.api.nvim_create_user_command("CreateHelp", function()
        print(catalog.help("cpp") .. "\n\n" .. catalog.help("csharp"))
    end, { desc = "Справка по генераторам C++ и C#" })
    vim.api.nvim_create_user_command("GeneratorHelp", function()
        require("devkit.help").open("generation")
    end, { desc = "Справка по генераторам" })
    vim.api.nvim_create_user_command("GeneratorList", function()
        print(table.concat(catalog.command_names(), "\n"))
    end, { desc = "Список команд генераторов" })
end
return M
