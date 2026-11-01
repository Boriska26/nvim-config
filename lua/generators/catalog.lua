local M = {}

M.utility_commands = { "CreateHelp", "CreateRoot", "GeneratorHelp", "GeneratorList" }

local entries = {}

local cpp_category = {
    id = "cpp", title = "C++", order = 10,
    notes = [[
:CreateHelp и --help печатают текстовую справку; :GeneratorList перечисляет команды.
:CreateRoot показывает корень запуска Neovim. Смена :cd этот корень не меняет.
Настройки проекта: .nvim-generator.json в корне запуска Neovim.
Пример: {"cpp":{"layout":"split","paths":{"header":"include","source":"src"}}}
По умолчанию: together, расширения .hpp/.cpp; --split использует include/ и src/.
CreateCpp: -p — база; split -p Engine создаёт Engine/include и Engine/src.
--subdir добавляется внутри header/source каталогов только при split.
--test создаёт только NAMETest.cpp с GoogleTest (либо расширение cpp.extensions.source).
--split нельзя совмещать с --together.
Пути только внутри проекта; существующие файлы не перезаписываются.
Файлы не добавляются в CMake автоматически.
]],
}

local arguments = require("generators.arguments")
local csharp_category = {
    id = "csharp", title = "C#", order = 20,
    notes = [[
Тип указывается явно. По умолчанию public; defaultAccess берётся из JSON.
--file заменяет доступность и не сочетается с --public/--internal (C# 11+).
Namespace: ближайший родительский .csproj, RootNamespace или имя проекта,
затем каталоги до файла. Без .csproj используется глобальный namespace.
Неоднозначные проекты, условные свойства и MSBuild-выражения отклоняются.
MSBuild не запускается, using по пути не добавляются. Нужен C# 10+.
]],
}
M.commands = {
    { command = "CreateCpp", language = "cpp", category = cpp_category,
        description = "Создать C++ тип, файл или тест GoogleTest",
        parameters = arguments.parameters(arguments.cpp),
        examples = { ":CreateCpp -c -n Player -p Engine/", ":CreateCpp -c -n Player -ho -p Engine/",
            ":CreateCpp -s -n Vector2 -p Math/", ":CreateCpp -c -n Player -b -sp -p Engine/",
            ":CreateCpp -e -n EntityType -p Core/", ":CreateCpp --test -n Player -p tests/" } },
    { command = "CreateCSharp", language = "csharp", category = csharp_category,
        description = "Создать C# class/interface/enum/struct/record/record struct",
        parameters = arguments.parameters(arguments.csharp),
        examples = { ":CreateCSharp -c -n PhotoService -p Services/",
            ":CreateCSharp -i -n IPhotoService -p Interfaces/", ":CreateCSharp -r -n PhotoDto -p Models/",
            ":CreateCSharp -rs -n Point --readonly", ":CreateCSharp -c -n BaseService -a" } },
}
function M.help(language)
    for _, entry in ipairs(M.commands) do
        if entry.language == language then
            local lines = { ":" .. entry.command .. " — " .. entry.description, "" }
            for _, parameter in ipairs(entry.parameters) do lines[#lines + 1] = parameter.name .. "  " .. parameter.description end
            lines[#lines + 1] = ""
            for _, example in ipairs(entry.examples) do lines[#lines + 1] = example end
            lines[#lines + 1] = entry.category.notes
            return table.concat(lines, "\n")
        end
    end
end

local function nonempty(value)
    return type(value) == "string" and value:find("%S") ~= nil
end

local function changed()
    vim.api.nvim_exec_autocmds("User", { pattern = "DevKitGeneratorsChanged", modeline = false })
end

-- Register metadata and its Ex handler together, so metadata alone cannot create a category.
function M.register(metadata, callback, opts)
    assert(type(metadata) == "table", "generator metadata must be a table")
    assert(type(metadata.command) == "string" and metadata.command:match("^[A-Z][A-Za-z0-9]*$"),
        "generator command must be an Ex command name")
    for _, command in ipairs(M.utility_commands) do
        assert(metadata.command ~= command, "reserved generator utility command: " .. command)
    end
    assert(nonempty(metadata.description), "generator description is required")
    local category = metadata.category
    assert(type(category) == "table" and type(category.id) == "string"
        and category.id:match("^[a-z][a-z0-9_-]*$") and nonempty(category.title),
        "generator category requires an id and title")
    assert(category.order == nil or type(category.order) == "number", "category order must be a number")
    assert(category.notes == nil or type(category.notes) == "string", "category notes must be a string")
    assert(type(metadata.parameters) == "table", "generator parameters are required")
    for _, parameter in ipairs(metadata.parameters) do
        assert(type(parameter) == "table" and nonempty(parameter.name) and nonempty(parameter.description),
            "each generator parameter requires a name and description")
    end
    assert(type(metadata.examples) == "table" and #metadata.examples > 0, "generator examples are required")
    for _, example in ipairs(metadata.examples) do assert(nonempty(example), "generator example must not be empty") end
    assert(type(callback) == "function", "generator handler is required")
    for command, entry in pairs(entries) do
        if command ~= metadata.command and entry.category.id == category.id then
            assert(vim.deep_equal(entry.category, category), "conflicting generator category metadata: " .. category.id)
        end
    end
    local entry = vim.deepcopy(metadata)
    local command_opts = { nargs = "*" }
    for key, value in pairs(opts or {}) do command_opts[key] = value end
    command_opts.desc = entry.description
    vim.api.nvim_create_user_command(entry.command, callback, command_opts)
    entries[entry.command] = entry
    changed()
end

function M.unregister(command)
    if not entries[command] then return false end
    if vim.api.nvim_get_commands({ builtin = false })[command] then
        vim.api.nvim_del_user_command(command)
    end
    entries[command] = nil
    changed()
    return true
end

function M.generators()
    local commands = vim.api.nvim_get_commands({ builtin = false })
    local result = {}
    for command, entry in pairs(entries) do
        if commands[command] then result[#result + 1] = vim.deepcopy(entry) end
    end
    table.sort(result, function(a, b) return a.command < b.command end)
    return result
end

function M.categories()
    local result, indexed = {}, {}
    for _, entry in ipairs(M.generators()) do
        local id = entry.category.id
        if not indexed[id] then
            local category = vim.deepcopy(entry.category)
            category.generators = {}
            indexed[id] = category
            result[#result + 1] = category
        end
        local generators = indexed[id].generators
        generators[#generators + 1] = entry
    end
    table.sort(result, function(a, b)
        local a_order, b_order = a.order or 100, b.order or 100
        if a_order ~= b_order then return a_order < b_order end
        return a.title < b.title
    end)
    return result
end

function M.command_names()
    local commands = {}
    local registered = vim.api.nvim_get_commands({ builtin = false })
    for _, command in ipairs(M.utility_commands) do
        if registered[command] then commands[#commands + 1] = command end
    end
    for _, entry in ipairs(M.generators()) do commands[#commands + 1] = entry.command end
    table.sort(commands)
    return commands
end

return M
