local M = {}
local parser = require("generators.parser")
local paths = require("generators.paths")
local config = require("generators.config")
local cpp = require("generators.cpp")

local root

local kinds = {
    CreateCppClass = "class",
    CreateCppStruct = "struct",
    CreateCppEnum = "enum",
    CreateCppHeader = "header",
    CreateCppSource = "source",
    CreateCppInterface = "interface",
    CreateCppTest = "test",
}

local help_text = [[
C++ GENERATOR — пути относительно корня запуска Neovim

:CreateCppClass -n Player -hs Engine/
:CreateCppClass -n Player -h include/Engine/ -s src/Engine/
:CreateCppClass -n Player -hs .
:CreateCppClass -n Player --split --subdir Engine/Characters/
:CreateCppStruct -n Vector2 -h Math/
:CreateCppEnum -n EntityType
:CreateCppHeader -n Common -h include/
:CreateCppSource -n Helpers -s src/
:CreateCppInterface -n IRenderer -h include/
:CreateCppTest -n Player -s tests/

-n / --name      Имя типа/файла (обязательно)
-h / --header    Только заголовок; далее необязательный каталог
-s / --source    Только исходник; далее необязательный каталог
-hs              Оба файла; далее необязательный общий каталог
--split          Разнести в include/ и src/ (или пути проекта)
--together       Создать рядом, по умолчанию в корне
--subdir DIR     Общая подпапка к каталогам выбранной раскладки
--help           Эта справка

Для -h, -s и -hs путь может быть '.' (корень проекта).
Явно переданный путь важнее конфигурации layout/--split.
Проверка существования файлов выполняется перед записью.
Файлы .cpp и .hpp не добавляются в CMake автоматически.
]]

local function notify_error(message)
    vim.notify("Генератор: " .. message, vim.log.levels.ERROR)
end

local function validate_paths(entries)
    local seen = {}
    for _, entry in ipairs(entries) do
        local cleaned, err = paths.clean(entry.path)
        if not cleaned then return nil, err end
        if cleaned == "." then return nil, "Не удалось вычислить имя файла" end
        if seen[cleaned] then return nil, "Совпадают пути создаваемых файлов: " .. cleaned end
        seen[cleaned] = true
        entry.path = cleaned

        if vim.uv.fs_stat(paths.file(root, cleaned)) then
            return nil, "Файл уже существует: " .. cleaned
        end
    end
    return true
end

local function is_within_root(directory)
    local actual_root = vim.uv.fs_realpath(root) or root
    local actual_directory = vim.uv.fs_realpath(directory)
    if not actual_directory then return false end
    local norm_root = actual_root:gsub("\\", "/")
    local norm_dir = actual_directory:gsub("\\", "/")
    if vim.fn.has("win32") == 1 then
        norm_root, norm_dir = norm_root:lower(), norm_dir:lower()
    end
    return norm_dir == norm_root or norm_dir:sub(1, #norm_root + 1) == norm_root .. "/"
end

local function write_entries(entries)
    -- Preflight all targets, then create with exclusive 'wx'. Never overwrite.
    local ok, err = validate_paths(entries)
    if not ok then return nil, err end

    local created = {}
    for _, entry in ipairs(entries) do
        local fullpath = paths.file(root, entry.path)
        local dirname = vim.fn.fnamemodify(fullpath, ":h")
        if vim.fn.mkdir(dirname, "p") == 0 and vim.fn.isdirectory(dirname) == 0 then
            err = "Не удалось создать каталог: " .. dirname
            break
        end
        if not is_within_root(dirname) then
            err = "Каталог выходит за пределы проекта (возможно, symlink): " .. dirname
            break
        end

        local file_handle, open_error = vim.uv.fs_open(fullpath, "wx", 420)
        if not file_handle then
            err = "Не удалось создать " .. entry.path .. ": " .. tostring(open_error)
            break
        end
        table.insert(created, fullpath)
        local contents = table.concat(entry.lines, "\n") .. "\n"
        local bytes, write_error = vim.uv.fs_write(file_handle, contents, 0)
        vim.uv.fs_close(file_handle)
        if not bytes or bytes ~= #contents then
            err = "Ошибка записи " .. entry.path .. ": " .. tostring(write_error or "incomplete write")
            break
        end
    end

    if err then
        -- If a later write fails, roll back files created by this invocation.
        for _, filename in ipairs(created) do pcall(vim.uv.fs_unlink, filename) end
        return nil, err
    end
    return true
end

local function create(kind, opts)
    local parsed, parse_error = parser.parse(opts.fargs, kind)
    if not parsed then return notify_error(parse_error) end
    if parsed.help then
        print(help_text)
        return
    end

    local settings, config_error = config.load(root)
    if not settings then return notify_error(config_error) end

    -- Validate all directory arguments before touching the filesystem.
    for _, key in ipairs({ "header_path", "source_path", "shared_path", "subdir" }) do
        if parsed[key] then
            local clean, clean_error = paths.clean(parsed[key])
            if not clean then return notify_error(clean_error) end
            parsed[key] = clean
        end
    end

    local entries = cpp.create(kind, parsed.name, parsed, settings)
    local ok, write_error = write_entries(entries)
    if not ok then return notify_error(write_error) end

    local created = {}
    for _, item in ipairs(entries) do table.insert(created, item.path) end
    vim.notify("Создано: " .. table.concat(created, ", "), vim.log.levels.INFO)

    local path_to_edit = entries[1] and paths.file(root, entries[1].path)
    if path_to_edit then
        local command = vim.bo.modified and "split " or "edit "
        local opened, open_error = pcall(vim.cmd, command .. vim.fn.fnameescape(path_to_edit))
        if not opened then
            vim.notify("Файлы созданы, но не удалось открыть: " .. tostring(open_error), vim.log.levels.WARN)
        end
    end

    local tree_ok, tree = pcall(require, "nvim-tree.api")
    if tree_ok then pcall(tree.tree.reload) end
end

function M.setup()
    -- Capture the starting directory once; :cd and file navigation won't change it.
    root = vim.fn.getcwd()

    for command, kind in pairs(kinds) do
        local selected_kind = kind
        vim.api.nvim_create_user_command(command, function(opts)
            create(selected_kind, opts)
        end, {
            nargs = "*",
            desc = "Создать " .. kind .. " для C++",
            complete = function(lead)
                local choices = { "-n", "-h", "-s", "-hs", "--split", "--together", "--subdir", "--help" }
                local result = {}
                for _, option in ipairs(choices) do
                    if option:sub(1, #lead) == lead then table.insert(result, option) end
                end
                return result
            end,
        })
    end

    vim.api.nvim_create_user_command("CreateRoot", function()
        print("Корень генератора: " .. root)
    end, { desc = "Показать корень генератора" })

    vim.api.nvim_create_user_command("CreateHelp", function()
        print(help_text)
    end, { desc = "Справка по генератору C++" })
end

return M
