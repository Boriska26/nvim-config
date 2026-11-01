local M = {}

function M.parse(args, schema)
    local flags, result, seen = {}, {}, {}
    for _, entry in ipairs(schema) do
        for _, flag in ipairs(entry.flags) do flags[flag] = entry end
    end
    local index = 1
    while index <= #args do
        local token = args[index]
        local flag, value = token:match("^(%-%-[^=]+)=(.*)$")
        flag = flag or token
        local entry = flags[flag]
        if not entry then return nil, "Неизвестный аргумент: " .. token .. " (см. --help)" end
        if seen[entry.key] then
            return nil, "Повторные или несовместимые аргументы: " .. seen[entry.key] .. " и " .. flag
        end
        if not entry.takes and value ~= nil then return nil, flag .. " не принимает значение" end
        if entry.takes and value == nil then
            local following = args[index + 1]
            if following and following:sub(1, 1) ~= "-" then
                value, index = following, index + 1
            elseif entry.takes == "required" then
                return nil, "После " .. flag .. " требуется значение"
            end
        end
        if value == "" then return nil, "Пустое значение после " .. flag end
        seen[entry.key] = flag
        result[entry.key] = value or entry.value or true
        index = index + 1
    end
    return result
end

return M
