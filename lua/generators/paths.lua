-- All paths are project-root-relative. Reject paths that can escape that root.
local M = {}
local i18n = require("generators.i18n")

function M.clean(value)
    if type(value) ~= "string" or value == "" then
        return nil, i18n.get("empty_path")
    end
    value = value:gsub("\\", "/")
    if value:sub(1, 1) == "/" or value:match("^[A-Za-z]:") or value:sub(1, 2) == "//" then
        return nil, i18n.get("absolute_path", value)
    end
    if value:find("[%c:*?\"<>|]") then
        return nil, i18n.get("invalid_path", value)
    end

    local parts = {}
    for item in value:gmatch("[^/]+") do
        if item == ".." then
            return nil, i18n.get("outside_path", value)
        end
        if item ~= "." then
            if item:match("[%. ]$") then
                return nil, i18n.get("trailing_path", item)
            end
            local upper = (item:match("^([^.]*)") or item):upper()
            if upper:match("^CON$") or upper:match("^PRN$") or upper:match("^AUX$") or
                upper:match("^NUL$") or upper:match("^COM[1-9]$") or upper:match("^LPT[1-9]$") then
                return nil, i18n.get("reserved_path", item)
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

function M.within(root, directory)
    local function normalize(path)
        path = path:gsub("\\", "/"):gsub("/+$", "")
        if vim.fn.has("win32") == 1 then path = path:lower() end
        return path
    end
    local actual_root = vim.uv.fs_realpath(root)
    local actual_dir = vim.uv.fs_realpath(directory)
    if not actual_root or not actual_dir then return false end
    local a, b = normalize(actual_root), normalize(actual_dir)
    return a == b or b:sub(1, #a + 1) == a .. "/"
end

-- Check the nearest existing ancestor before mkdir, so a symlink cannot create
-- directories outside the captured project root before being rejected.
function M.safe_parent(root, directory)
    local ancestor = directory
    while not vim.uv.fs_stat(ancestor) do
        local parent = vim.fn.fnamemodify(ancestor, ":h")
        if parent == ancestor then return nil, i18n.get("no_parent", directory) end
        ancestor = parent
    end
    if not M.within(root, ancestor) then return nil, i18n.get("symlink_path", directory) end
    return true
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
