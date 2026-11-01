local M = {}
local i18n = require("generators.i18n")

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
        if not entry then return nil, i18n.get("unknown_argument", token) end
        if seen[entry.key] then
            return nil, i18n.get("conflicting_arguments", seen[entry.key], flag)
        end
        if not entry.takes and value ~= nil then return nil, i18n.get("no_value", flag) end
        if entry.takes and value == nil then
            local following = args[index + 1]
            if following and following:sub(1, 1) ~= "-" then
                value, index = following, index + 1
            elseif entry.takes == "required" then
                return nil, i18n.get("value_required", flag)
            end
        end
        if value == "" then return nil, i18n.get("empty_value", flag) end
        seen[entry.key] = flag
        result[entry.key] = value or entry.value or true
        index = index + 1
    end
    return result
end

return M
