-- Builds {relative_path, lines} entries for C++ templates.
local M = {}
local paths = require("generators.paths")

function M.create(kind, name, opts, settings)
    local layout = opts.layout or settings.layout
    local header_root = layout == "split" and settings.paths.header or "."
    local source_root = layout == "split" and settings.paths.source or "."

    local subdir = opts.subdir or "."
    local header_dir = opts.header_path or paths.join(header_root, subdir)
    local source_dir = opts.source_path or paths.join(source_root, subdir)

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
            "    virtual ~" .. name .. "() = 0;", "};", "",
            "inline " .. name .. "::~" .. name .. "() = default;",
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

function M.plan(opts, settings)
    if not opts.kind then return nil, "Выбери тип C++: -c/-s/-e/-i/--header/--source/--test" end
    local name, err = require("generators.identifiers").cpp(opts.name)
    if not name then return nil, err end
    local header_only = opts.kind == "enum" or opts.kind == "header" or opts.kind == "interface"
    local source_only = opts.kind == "source" or opts.kind == "test"
    if header_only and opts.output and opts.output ~= "header" then return nil, "Для этого типа доступен только --header-only" end
    if source_only and opts.output and opts.output ~= "source" then return nil, "Для --source/--test доступен только --source-only" end
    local output = opts.output or (opts.kind == "class" and "both" or source_only and "source" or "header")
    opts.header, opts.source = output ~= "source", output ~= "header"
    local layout = opts.layout or settings.layout
    if opts.subdir and layout ~= "split" then return nil, "--subdir используется только с размещением split" end
    local base, subdir = opts.path or ".", opts.subdir or "."
    opts.header_path = paths.join(base, layout == "split" and paths.join(settings.paths.header, subdir) or ".")
    opts.source_path = paths.join(base, layout == "split" and paths.join(settings.paths.source, subdir) or ".")
    return M.create(opts.kind, name, opts, settings)
end

return M
