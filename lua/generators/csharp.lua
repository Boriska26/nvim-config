local M = {}
local allowed = {
    abstract = { class = true, record = true },
    sealed = { class = true, record = true },
    static = { class = true },
    partial = { class = true, interface = true, struct = true, record = true, record_struct = true },
    readonly = { struct = true, record_struct = true },
    ref = { struct = true },
}
function M.validate(opts, settings)
    if not opts.kind then return nil, "Выбери тип C#: -c/-i/-e/-s/-r/-rs" end
    local name, err = require("generators.identifiers").csharp(opts.name)
    if not name then return nil, err end
    for modifier, kinds in pairs(allowed) do
        if opts[modifier] and not kinds[opts.kind] then return nil, "--" .. modifier .. " несовместим с " .. opts.kind end
    end
    if opts.abstract and opts.sealed then return nil, "--abstract несовместим с --sealed" end
    if opts.static and (opts.abstract or opts.sealed) then return nil, "--static нельзя совмещать с --abstract/--sealed" end
    opts.access = opts.access or settings.defaultAccess
    return true
end
function M.create(opts, namespace)
    local modifiers = { opts.access }
    -- partial must immediately precede the type keyword; readonly precedes ref.
    for _, modifier in ipairs({ "abstract", "sealed", "static", "readonly", "ref", "partial" }) do
        if opts[modifier] then modifiers[#modifiers + 1] = modifier end
    end
    local kind = ({ record = "record class", record_struct = "record struct" })[opts.kind] or opts.kind
    local lines = {}
    if namespace and namespace ~= "" then lines = { "namespace " .. namespace .. ";", "" } end
    lines[#lines + 1] = table.concat(modifiers, " ") .. " " .. kind .. " " .. opts.name
    lines[#lines + 1], lines[#lines + 2] = "{", "}"
    return { { path = require("generators.paths").join(opts.path or ".", opts.name:gsub("^@", "") .. ".cs"), lines = lines } }
end
return M
