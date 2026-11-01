local M = {}
local paths = require("generators.paths")

function M.generate(root, language, args)
    local schema = require("generators.arguments")[language]
    local parsed, err = require("generators.parser").parse(args, schema)
    if not parsed then return nil, err end
    if parsed.help then return { help = true } end
    local settings
    settings, err = require("generators.config").load(root)
    if not settings then return nil, err end
    for _, key in ipairs({ "path", "subdir" }) do
        if parsed[key] then
            local cleaned
            cleaned, err = paths.clean(parsed[key])
            if not cleaned then return nil, err end
            parsed[key] = cleaned
        end
    end
    local entries
    if language == "cpp" then
        entries, err = require("generators.cpp").plan(parsed, settings.cpp)
    elseif language == "devops" then
        entries, err = require("generators.devops").plan(parsed)
    else
        local csharp = require("generators.csharp")
        local valid
        valid, err = csharp.validate(parsed, settings.csharp)
        if not valid then return nil, err end
        local safe
        safe, err = paths.safe_parent(root, paths.file(root, parsed.path or "."))
        if not safe then return nil, err end
        local namespace
        namespace, err = require("generators.namespace").resolve(root, parsed.path or ".")
        if namespace == nil then return nil, err end
        entries = csharp.create(parsed, namespace)
    end
    if not entries then return nil, err end
    local ok
    ok, err = require("generators.writer").write(root, entries)
    if not ok then return nil, err end
    return { entries = entries }
end
return M
