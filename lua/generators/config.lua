local M = {}
local i18n = require("generators.i18n")
local paths = require("generators.paths")
local defaults = {
    cpp = { layout = "together", paths = { header = "include", source = "src" },
        extensions = { header = ".hpp", source = ".cpp" } },
    csharp = { defaultAccess = "public" },
}
local function object(value)
    return type(value) == "table" and not (vim.islist and vim.islist(value))
end
function M.load(root)
    local result = vim.deepcopy(defaults)
    local filepath = paths.file(root, ".nvim-generator.json")
    if vim.fn.filereadable(filepath) == 0 then
        if vim.uv.fs_stat(filepath) then return nil, i18n.get("config_unreadable", filepath) end
        return result
    end
    local ok, document = pcall(function()
        local text = table.concat(vim.fn.readfile(filepath), "\n")
        assert(text:match("^%s*{"), "ожидается JSON-объект")
        return vim.json.decode(text)
    end)
    if not ok or not object(document) then return nil, i18n.get("invalid_json", filepath) end
    for _, language in ipairs({ "cpp", "csharp" }) do
        if document[language] ~= nil and not object(document[language]) then
            return nil, i18n.get("config_object", language)
        end
    end
    local cpp = document.cpp or {}
    if cpp.layout ~= nil then
        if cpp.layout ~= "split" and cpp.layout ~= "together" then return nil, i18n.get("config_layout") end
        result.cpp.layout = cpp.layout
    end
    for _, field in ipairs({ "paths", "extensions" }) do
        if cpp[field] ~= nil then
            if not object(cpp[field]) then return nil, i18n.get("config_object", "cpp." .. field) end
            for _, key in ipairs({ "header", "source" }) do
                if cpp[field][key] ~= nil then result.cpp[field][key] = cpp[field][key] end
            end
        end
    end
    for _, key in ipairs({ "header", "source" }) do
        local cleaned, err = paths.clean(result.cpp.paths[key])
        if not cleaned then return nil, "cpp.paths." .. key .. ": " .. err end
        result.cpp.paths[key] = cleaned
        local ext = result.cpp.extensions[key]
        if type(ext) ~= "string" or not ext:match("^%.[a-zA-Z0-9]+$") then
            return nil, i18n.get("config_extension", key)
        end
    end
    local csharp = document.csharp or {}
    if csharp.defaultAccess ~= nil then
        if csharp.defaultAccess ~= "public" and csharp.defaultAccess ~= "internal" then
            return nil, i18n.get("config_access")
        end
        result.csharp.defaultAccess = csharp.defaultAccess
    end
    return result
end
return M
