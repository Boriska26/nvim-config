-- Read project data without running MSBuild, imports or arbitrary project code.
local M = {}
local paths = require("generators.paths")
local identifiers = require("generators.identifiers")
local function read(filename)
    local ok, lines = pcall(vim.fn.readfile, filename)
    if not ok then return nil, "Не удалось прочитать проект: " .. filename end
    return table.concat(lines, "\n"):gsub("<!%-%-.-%-%->", "")
end
local function decode(value)
    local entities = { amp = "&", lt = "<", gt = ">", quot = '"', apos = "'" }
    return (value:gsub("&([^;]+);", function(entity)
        if entities[entity] then return entities[entity] end
        local number = entity:match("^#(%d+)$")
        local hex = entity:match("^#x(%x+)$")
        number = number and tonumber(number) or hex and tonumber(hex, 16)
        return number and number >= 32 and number < 127 and string.char(number) or "&" .. entity .. ";"
    end))
end
local function root_namespace(filename)
    local xml, err = read(filename)
    if not xml then return nil, err end
    local stack, values, position, roots = {}, {}, 1, 0
    while true do
        local start, finish, token = xml:find("<([^>]+)>", position)
        if not start then break end
        if #stack == 0 and xml:sub(position, start - 1):find("%S") then return nil, "Некорректный XML в " .. filename end
        position = finish + 1
        if token:sub(1, 1) ~= "?" then
            local closing, tag, attributes, selfclose = token:match("^%s*(/?)%s*([%w_:.-]+)(.-)%s*(/?)%s*$")
            if not tag then return nil, "Неподдерживаемый или некорректный XML в " .. filename end
            tag = tag:match("([^:]+)$"):lower()
            if tag == "import" then return nil, "Namespace с явным MSBuild Import не вычисляется: " .. filename end
            if closing == "/" then
                if attributes:find("%S") or selfclose == "/" then return nil, "Некорректный закрывающий XML-тег в " .. filename end
                local node = table.remove(stack)
                if not node or node.tag ~= tag then return nil, "Некорректный XML в " .. filename end
                if tag == "rootnamespace" then
                    if node.conditional then return nil, "Условный RootNamespace неоднозначен: " .. filename end
                    values[#values + 1] = decode(xml:sub(node.start, start - 1):match("^%s*(.-)%s*$"))
                end
            else
                if #stack == 0 then
                    roots = roots + 1
                    if roots > 1 or tag ~= "project" then return nil, "Ожидается XML Project: " .. filename end
                end
                local parent = stack[#stack]
                local conditional = attributes:lower():find("condition%s*=") ~= nil or parent and parent.conditional
                if tag == "rootnamespace" and (not parent or parent.tag ~= "propertygroup") then
                    return nil, "RootNamespace ожидается в PropertyGroup: " .. filename
                end
                if selfclose == "/" then
                    if tag == "rootnamespace" then
                        if conditional then return nil, "Условный RootNamespace: " .. filename end
                        values[#values + 1] = ""
                    end
                else
                    stack[#stack + 1] = { tag = tag, conditional = conditional, start = finish + 1 }
                end
            end
        end
    end
    if #stack > 0 or roots ~= 1 or xml:sub(position):find("%S") then return nil, "Некорректный XML в " .. filename end
    if #values > 1 then return nil, "Несколько RootNamespace: " .. filename end
    local value = values[1]
    if value and (value:find("$", 1, true) or value:find("<", 1, true) or value:find("@(", 1, true)
        or value:find("%(", 1, true)) then return nil, "Вычисляемый RootNamespace не поддерживается: " .. filename end
    return { value = value }
end

function M.resolve(root, relative_dir)
    local directory = paths.file(root, relative_dir)
    local ancestor, project = directory, nil
    while true do
        local candidates = {}
        local scan = vim.uv.fs_scandir(ancestor)
        if scan then
            while true do
                local name = vim.uv.fs_scandir_next(scan)
                if not name then break end
                if name:lower():match("%.csproj$") then
                    local filename = paths.file(ancestor, name)
                    local stat = vim.uv.fs_stat(filename)
                    if stat and stat.type == "file" then candidates[#candidates + 1] = filename end
                end
            end
        end
        if #candidates > 1 then return nil, "Несколько .csproj в ближайшем каталоге: " .. ancestor end
        if #candidates == 1 then project = candidates[1]; break end
        local parent = vim.fn.fnamemodify(ancestor, ":h")
        if parent == ancestor then return "" end -- No project: valid global-namespace source.
        ancestor = parent
    end
    local property, err = root_namespace(project)
    if not property then return nil, err end
    -- Imported namespace settings cannot be interpreted reliably as literal XML data.
    local current = ancestor
    while true do
        for _, name in ipairs({ "Directory.Build.props", "Directory.Build.targets" }) do
            local filename = paths.file(current, name)
            if vim.fn.filereadable(filename) == 1 then
                local text, read_err = read(filename)
                if not text then return nil, read_err end
                text = text:lower()
                if text:find("rootnamespace", 1, true) or text:find("<import[%s>]") then
                    return nil, "Импортируемый RootNamespace не вычисляется: " .. filename
                end
            end
        end
        local parent = vim.fn.fnamemodify(current, ":h")
        if parent == current then break end
        current = parent
    end
    local base = property.value
    if base == nil then base = vim.fn.fnamemodify(project, ":t:r") end
    local suffix = directory:sub(#ancestor + 1):gsub("^[\\/]+", ""):gsub("[\\/]", ".")
    local combined = base == "" and suffix or suffix == "" and base or base .. "." .. suffix
    local namespace = identifiers.namespace(combined)
    if namespace == nil then return nil, "Namespace содержит недопустимый идентификатор: " .. combined end
    return namespace
end
return M
