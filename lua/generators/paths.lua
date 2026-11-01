-- All paths are project-root-relative. Reject paths that can escape that root.
local M = {}

function M.clean(value)
    if type(value) ~= "string" or value == "" then
        return nil, "Путь должен быть непустой строкой"
    end
    value = value:gsub("\\", "/")
    if value:sub(1, 1) == "/" or value:match("^[A-Za-z]:") or value:sub(1, 2) == "//" then
        return nil, "Абсолютные пути не разрешены: " .. value
    end
    if value:find("[%c:*?\"<>|]") then
        return nil, "Недопустимые символы в пути: " .. value
    end

    local parts = {}
    for item in value:gmatch("[^/]+") do
        if item == ".." then
            return nil, "Выход за пределы проекта запрещён: " .. value
        end
        if item ~= "." then
            if item:match("[%. ]$") then
                return nil, "Папка не может заканчиваться точкой или пробелом (Windows): " .. item
            end
            local upper = item:upper()
            if upper:match("^CON$") or upper:match("^PRN$") or upper:match("^AUX$") or
                upper:match("^NUL$") or upper:match("^COM[1-9]$") or upper:match("^LPT[1-9]$") then
                return nil, "Зарезервированное имя Windows: " .. item
            end
            table.insert(parts, item)
        end
    end
    return #parts == 0 and "." or table.concat(parts, "/")
end

function M.join(a, b)
    if a == "." or a == "" then return b end
    if b == "." or b == "" then return a end
    return a .. "/" .. b
end

function M.file(root, relative)
    if relative == "." then return root end
    return root .. "/" .. relative
end

function M.relative_file_include(source_dir, header_file)
    -- Source and header are both project-root relative.
    local function segments(path)
        local result = {}
        for segment in path:gmatch("[^/]+") do table.insert(result, segment) end
        return result
    end

    local src = segments(source_dir == "." and "" or source_dir)
    local header = segments(header_file)
    local common = 0
    while common < #src and common < #header and src[common + 1] == header[common + 1] do
        common = common + 1
    end
    local parts = {}
    for _ = common + 1, #src do table.insert(parts, "..") end
    for index = common + 1, #header do table.insert(parts, header[index]) end
    return table.concat(parts, "/")
end

return M
