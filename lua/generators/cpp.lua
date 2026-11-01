-- Builds {relative_path, lines} entries for C++ templates.
local M = {}
local paths = require("generators.paths")

function M.create(kind, name, opts, settings)
    local layout = opts.layout or settings.layout
    local header_root = layout == "split" and settings.paths.header or "."
    local source_root = layout == "split" and settings.paths.source or "."

    local subdir = opts.subdir or "."
    local header_dir = opts.header_path or opts.shared_path or paths.join(header_root, subdir)
    local source_dir = opts.source_path or opts.shared_path or paths.join(source_root, subdir)

    local header_name = name .. settings.extensions.header
    local source_name = (kind == "test" and name .. "Test" or name) .. settings.extensions.source
    local header_file = paths.join(header_dir, header_name)
    local source_file = paths.join(source_dir, source_name)
    local source_include = paths.relative_file_include(source_dir, header_file)

    local header_lines = { "#pragma once", "" }
    if kind == "class" then
        vim.list_extend(header_lines, {
            "class " .. name,
            "{",
            "public:",
            "    " .. name .. "() = default;",
            "    ~" .. name .. "() = default;",
            "};",
        })
    elseif kind == "struct" then
        vim.list_extend(header_lines, { "struct " .. name, "{", "};" })
    elseif kind == "enum" then
        vim.list_extend(header_lines, { "enum class " .. name, "{", "};" })
    elseif kind == "interface" then
        vim.list_extend(header_lines, {
            "class " .. name, "{", "public:",
            "    virtual ~" .. name .. "() = default;", "};",
        })
    end

    local source_lines = { '#include "' .. source_include .. '"', "" }
    if kind == "source" then
        source_lines = { "// " .. source_name, "" }
    elseif kind == "test" then
        source_lines = {
            "#include <gtest/gtest.h>", "",
            'TEST(' .. name .. 'Test, Placeholder)', "{", "    // TODO: Add assertions", "}",
        }
    end

    local result = {}
    if opts.header then table.insert(result, { path = header_file, lines = header_lines }) end
    if opts.source then table.insert(result, { path = source_file, lines = source_lines }) end
    return result
end

return M
