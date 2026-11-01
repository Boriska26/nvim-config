local M = {}
function M.platform(sysname, win32)
    local name = (sysname or ""):lower()
    if win32 or name:find("windows", 1, true) or name:find("mingw", 1, true) then return "Windows" end
    if name == "linux" then return "Linux" end
    return "Unsupported"
end
local plugin_modules = {
    ["nvim-tree.lua"] = { "nvim-tree", "plugins.nvim-tree", "NvimTreeToggle" },
    ["mason.nvim"] = { "mason", "plugins.mason", "Mason" },
    ["roslyn.nvim"] = { "roslyn", "plugins.roslyn" },
    ["tokyonight.nvim"] = { "tokyonight", "config.appearance" },
    ["telescope.nvim"] = { "telescope", "plugins.telescope", "Telescope" },
    ["lualine.nvim"] = { "lualine", "plugins.lualine" },
    ["bufferline.nvim"] = { "bufferline", "plugins.bufferline", "BufferLineCycleNext" },
    ["lsp_signature.nvim"] = { "lsp_signature", "plugins.lsp_signature" },
    ["nvim-cmp"] = { "cmp", "plugins.cmp" },
}
function M.collect()
    local context = {
        platform = M.platform(vim.uv.os_uname().sysname, vim.fn.has("win32") == 1),
        version = vim.version(), plugins = {}, modules = {}, commands = {},
        manager = type(vim.pack) == "table" and type(vim.pack.add) == "function",
        features = { csharp_format = vim.fn.exists("#CSharpFormatOnSave#BufWritePre") == 1,
            debugger = false, ctest = vim.fn.exists(":CTest") == 2 },
        msvc_env = vim.env.INCLUDE ~= nil and vim.env.INCLUDE ~= "" and vim.env.LIB ~= nil and vim.env.LIB ~= "",
    }
    context.which = function(name)
        if vim.fn.executable(name) ~= 1 then return nil end
        local path = vim.fn.exepath(name)
        return path ~= "" and path or name
    end
    local inventory = {}
    if context.manager then
        local ok, plugins = pcall(vim.pack.get, nil, { info = false }) -- No git processes.
        if ok then for _, plugin in ipairs(plugins) do inventory[plugin.spec.name] = plugin end end
    end
    local specs_ok, specs = pcall(require, "plugins.specs") -- Pure data, never vim.pack.add.
    context.specs_ok = specs_ok
    for _, spec in ipairs(specs_ok and specs or {}) do
        local name = spec.name or spec.src:match("([^/]+)$")
        local plugin, mapping = inventory[name], plugin_modules[name]
        local stat = plugin and vim.uv.fs_stat(plugin.path)
        local loaded = mapping and type(package.loaded[mapping[1]]) == "table"
        local configured = mapping and package.loaded[mapping[2]] ~= nil
        local command = not mapping or not mapping[3] or vim.fn.exists(":" .. mapping[3]) == 2
        context.plugins[#context.plugins + 1] = { name = name, installed = stat ~= nil and stat.type == "directory",
            active = plugin and plugin.active or false, loaded = loaded and configured and command,
            lazy = mapping == nil }
    end
    for _, name in ipairs({ "config.options", "config.keymaps", "config.terminal", "config.appearance", "devkit.help",
        "generators", "generators.arguments", "generators.parser", "generators.config", "generators.paths",
        "generators.writer", "generators.cpp", "generators.csharp", "generators.devops", "generators.service" }) do
        local path = "lua/" .. name:gsub("%.", "/")
        local filename = vim.api.nvim_get_runtime_file(path .. ".lua", false)[1]
            or vim.api.nvim_get_runtime_file(path .. "/init.lua", false)[1]
        local fn = filename and loadfile(filename) -- Compile only: no generator/setup side effects.
        context.modules[name] = { syntax = fn ~= nil, loaded = package.loaded[name] ~= nil }
    end
    for _, name in ipairs({ "CreateCpp", "CreateCSharp", "CreateDevOps", "GeneratorHelp", "GeneratorList", "DevKitHelp" }) do
        context.commands[name] = vim.fn.exists(":" .. name) == 2
    end
    context.clipboard_used = vim.o.clipboard:find("unnamed", 1, true) ~= nil
    context.clipboard = "missing"
    local custom = vim.g.clipboard
    if custom ~= nil and custom ~= false then
        context.clipboard = "custom" -- Never invoke provider callbacks or copy/paste commands.
    elseif context.platform == "Windows" then
        if context.which("win32yank.exe") or (context.which("clip.exe") and context.which("powershell.exe")) then context.clipboard = "candidate" end
    elseif context.platform == "Linux" then
        if (vim.env.WAYLAND_DISPLAY and vim.env.WAYLAND_DISPLAY ~= "" and context.which("wl-copy") and context.which("wl-paste"))
            or (vim.env.DISPLAY and vim.env.DISPLAY ~= "" and context.which("xclip")) then context.clipboard = "candidate" end
    end
    if vim.lsp and vim.lsp.config and package.loaded["roslyn"] then
        local ok, config = pcall(function() return vim.lsp.config.roslyn end)
        if ok and config then
            local cmd = config.cmd
            context.roslyn = type(cmd) == "table" and type(cmd[1]) == "string" and context.which(cmd[1]) ~= nil
        end
    end
    if vim.lsp and vim.lsp.is_enabled then
        for _, name in ipairs({ "clangd", "ccls" }) do
            if vim.lsp.is_enabled(name) then context.features.cpp_lsp = name; break end
        end
    end
    local dap = package.loaded["dap"] -- Inspect only; never load or launch an adapter.
    local adapter = type(dap) == "table" and dap.adapters and dap.adapters.coreclr
    if adapter then
        context.features.debugger = true
        context.debugger = type(adapter) == "table" and type(adapter.command) == "string" and context.which(adapter.command) ~= nil
    end
    return context
end
return M
