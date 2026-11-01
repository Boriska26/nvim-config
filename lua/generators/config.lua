local M = {}

local defaults = {
    layout = "together",
    paths = { header = "include", source = "src" },
    extensions = { header = ".hpp", source = ".cpp" },
}

function M.load(root)
    local result = vim.deepcopy(defaults)
    local filepath = root .. "/.nvim-generator.json"
    if vim.fn.filereadable(filepath) == 0 then return result end

    local ok, document = pcall(function()
        return vim.json.decode(table.concat(vim.fn.readfile(filepath), "\n"))
    end)
    if not ok or type(document) ~= "table" then
        return nil, "Некорректный JSON в " .. filepath
    end

    local cpp = document.cpp or {}
    if type(cpp) ~= "table" then return nil, "cpp должен быть объектом JSON" end

    if cpp.layout ~= nil then
        if cpp.layout ~= "split" and cpp.layout ~= "together" then
            return nil, 'cpp.layout может быть только "split" или "together"'
        end
        result.layout = cpp.layout
    end

    if cpp.paths ~= nil then
        if type(cpp.paths) ~= "table" then return nil, "cpp.paths должен быть объектом" end
        for _, key in ipairs({ "header", "source" }) do
            if cpp.paths[key] ~= nil then result.paths[key] = cpp.paths[key] end
        end
    end
    if cpp.extensions ~= nil then
        if type(cpp.extensions) ~= "table" then return nil, "cpp.extensions должен быть объектом" end
        for _, key in ipairs({ "header", "source" }) do
            if cpp.extensions[key] ~= nil then result.extensions[key] = cpp.extensions[key] end
        end
    end

    local paths = require("generators.paths")
    for _, key in ipairs({ "header", "source" }) do
        local cleaned, err = paths.clean(result.paths[key])
        if not cleaned then return nil, "cpp.paths." .. key .. ": " .. err end
        result.paths[key] = cleaned
        local ext = result.extensions[key]
        if type(ext) ~= "string" or not ext:match("^%.[a-zA-Z0-9]+$") then
            return nil, "Неправильное расширение cpp.extensions." .. key
        end
    end
    return result
end

return M
