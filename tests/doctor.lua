-- Deterministic diagnostics: every external process and platform is substituted.
local function run()
    local context_module = require("devkit.doctor.context")
    local runner = require("devkit.doctor.runner")
    local registry = require("devkit.doctor.checks")
    local model = require("devkit.doctor.model")
    local i18n = require("generators.i18n")
    assert(context_module.platform("Linux", false) == "Linux")
    assert(context_module.platform("Windows_NT", false) == "Windows")
    assert(context_module.platform("MINGW64_NT", false) == "Windows")
    assert(context_module.platform("other", true) == "Windows")
    assert(context_module.platform("Darwin", false) == "Unsupported")
    local function context(platform)
        local c = { platform = platform or "Linux", version = { major = 0, minor = 12, patch = 6 },
            manager = true, specs_ok = true, roslyn = true, msvc_env = true,
            plugins = { { name = "telescope.nvim", installed = true, active = true, loaded = true } },
            modules = { ["config.options"] = { syntax = true, loaded = true },
                ["generators.service"] = { syntax = true, loaded = false } },
            commands = {}, clipboard_used = true, clipboard = "candidate", features = { csharp_format = true }, bins = {} }
        for _, name in ipairs({ "git", "rg", "fd", "dotnet", "g++", "cmake", "clang-format", "docker", "bash", "pwsh", "ssh" }) do c.bins[name] = true end
        c.which = function(name) return c.bins[name] and (c.platform == "Windows" and "C:\\Tools With Spaces\\" or "/tools/") .. name or nil end
        for _, name in ipairs({ "CreateCpp", "CreateCSharp", "CreateDevOps", "GeneratorHelp", "GeneratorList", "DevKitHelp" }) do c.commands[name] = true end
        return c
    end
    local function fake(options)
        options = options or {}
        local stats = { active = 0, maximum = 0, calls = {}, killed = 0 }
        local function spawn(argv, opts, done)
            assert(type(argv) == "table" and type(argv[1]) == "string")
            assert(opts.timeout and opts.timeout > 0)
            stats.calls[#stats.calls + 1] = vim.deepcopy(argv)
            if options.throw then error("SECRET: launch stack") end
            stats.active = stats.active + 1
            stats.maximum = math.max(stats.maximum, stats.active)
            local live = true
            local handle = { kill = function()
                if live then live = false; stats.active = stats.active - 1; stats.killed = stats.killed + 1 end
            end }
            if options.hang then return handle end
            vim.defer_fn(function()
                if not live then return end
                live = false
                stats.active = stats.active - 1
                local result = { code = options.code or 0, stdout = options.output or "Tool 12.3.4\nSECRET_TOKEN=never-display-this" }
                if argv[2] == "--list-sdks" then result.stdout = options.sdk or "8.0.404 [/SECRET/path]\n10.0.100 [/SECRET/path]" end
                if options.timeout then result.code = 124 end
                done(result)
                if options.double then done(result) end
            end, options.delay or 2)
            return handle
        end
        return spawn, stats
    end
    local function execute(c, options, checks)
        local spawn, stats = fake(options)
        local definitions = checks or registry.build(c)
        local state = runner.run(definitions, c, { spawn = spawn, timeout = 30 })
        assert(vim.wait(3000, function() return state.complete end), "runner did not complete")
        assert(stats.maximum <= 2, "process concurrency exceeded two")
        assert(model.count(state.results).complete == #definitions)
        return state, stats
    end
    local c = context()
    local result, stats = execute(c, { double = true })
    assert(result.results["core.git"].status == "OK")
    assert(result.results["csharp.sdk"].status == "OK")
    assert(result.results["cpp.compiler"].status == "OK")
    assert(result.results["csharp.debugger"].status == "SKIPPED")
    assert(result.results["cpp.lsp"].status == "SKIPPED" and result.results["cpp.ctest"].status == "SKIPPED")
    assert(result.results["devops.optional.kubectl"].status == "SKIPPED")
    local json = vim.json.encode(result.results)
    assert(not json:find("SECRET", 1, true) and not json:find("never-display", 1, true), "process secrets leaked into results")
    for _, language in ipairs({ "ru", "en" }) do
        vim.g.devkit_language = language
        for _, entry in pairs(result.results) do
            local view = model.describe(entry, c.platform)
            assert(view.name ~= "" and view.what ~= "" and view.why ~= "" and view.explanation ~= "")
            if language == "en" then assert(not vim.json.encode(view):find("[\208\209]"), "untranslated doctor text") end
        end
    end
    vim.g.devkit_language = nil
    local absent = context()
    absent.bins = {}
    absent.plugins[1].installed = false
    absent.roslyn, absent.clipboard = false, "missing"
    absent.modules["config.options"].syntax = false
    absent.commands.CreateCpp = false
    local missing, missing_stats = execute(absent)
    assert(#missing_stats.calls == 0)
    for _, id in ipairs({ "core.git", "core.rg", "core.plugin.telescope.nvim", "core.modules", "core.command.CreateCpp" }) do
        assert(missing.results[id].status == "ERROR", id)
    end
    for _, id in ipairs({ "cpp.compiler", "csharp.dotnet", "csharp.sdk", "csharp.roslyn", "devops.docker" }) do
        assert(missing.results[id].status == "WARNING", id)
        local view = model.describe(missing.results[id], "Linux")
        assert(view.recommendation:find("Linux", 1, true))
    end
    assert(missing.results["devops.engine"].status == "SKIPPED")
    local no_sdk = execute(context(), { sdk = "" })
    assert(no_sdk.results["csharp.sdk"].reason == "no_sdk")
    local inactive = context()
    inactive.plugins[1].active = false
    assert(execute(inactive).results["core.plugin.telescope.nvim"].reason == "plugin_inactive")
    inactive.plugins[1].active, inactive.plugins[1].loaded = true, false
    assert(execute(inactive).results["core.plugin.telescope.nvim"].reason == "plugin_unloaded")
    local old = context()
    old.version.patch = 5
    assert(execute(old).results["core.nvim"].status == "ERROR")
    local enabled = context()
    enabled.features.cpp_lsp, enabled.features.ctest = "clangd", true
    assert(execute(enabled).results["cpp.lsp"].status == "WARNING")
    assert(execute(enabled).results["cpp.ctest"].status == "WARNING")
    enabled.features.debugger = true
    assert(execute(enabled).results["csharp.debugger"].status == "WARNING")
    local fallback = context()
    fallback.bins["clang++"] = true
    local successful_spawn = fake()
    local fallback_run = runner.run(registry.build(fallback), fallback, { spawn = function(argv, opts, callback)
        if argv[1]:match("/g%+%+$") then vim.schedule(function() callback({ code = 1, stdout = "" }) end); return { kill = function() end } end
        return successful_spawn(argv, opts, callback)
    end })
    assert(vim.wait(3000, function() return fallback_run.complete end))
    assert(fallback_run.results["cpp.compiler"].status == "OK", "working alternative compiler ignored")
    local failed = execute(context(), { code = 1 })
    assert(failed.results["core.git"].status == "ERROR" and failed.results["devops.engine"].reason == "daemon_failed")
    assert(execute(context(), { throw = true }).results["core.git"].reason == "launch")
    assert(execute(context(), { timeout = true }).results["core.git"].reason == "timeout")
    local hung, hung_stats = execute(context(), { hang = true })
    assert(hung.results["core.git"].reason == "timeout" and hung_stats.killed > 0, "watchdog did not kill a hung probe")
    local windows = context("Windows")
    windows.bins["g++"], windows.bins.pwsh, windows.bins.fd = nil, nil, nil
    windows.bins.cl, windows.bins.powershell, windows.bins.fdfind = true, true, true
    local win, win_stats = execute(windows)
    assert(win.results["cpp.compiler"].status == "OK" and win.results["devops.powershell"].status == "OK")
    local used_cl, used_powershell = false, false
    for _, argv in ipairs(win_stats.calls) do
        if argv[1]:match("cl$") then assert(argv[2] == "/?"); used_cl = true end
        if argv[1]:match("powershell$") then assert(argv[2] == "-NoLogo"); used_powershell = true end
    end
    assert(used_cl and used_powershell)
    windows.msvc_env = false
    assert(execute(windows).results["cpp.compiler"].reason == "msvc_env")
    local view = model.describe(missing.results["cpp.compiler"], "Windows")
    vim.g.devkit_language = "en"
    view = model.describe(missing.results["cpp.compiler"], "Windows")
    assert(view.recommendation:find("Developer Command Prompt", 1, true))
    vim.g.devkit_language = nil
    local unsupported = context("Unsupported")
    assert(execute(unsupported).results["devops.docker"].status == "SKIPPED")
    local definitions = registry.build(context())
    local spawn, cancelled_stats = fake({ hang = true })
    local cancelled = runner.run(definitions, context(), { spawn = spawn, timeout = 50 })
    assert(vim.wait(1000, function() return #cancelled_stats.calls == 2 end))
    cancelled.cancel()
    local calls = #cancelled_stats.calls
    vim.wait(120, function() return false end)
    assert(#cancelled_stats.calls == calls and cancelled_stats.active == 0, "cancelled run launched more processes")
    print("PASS: Doctor checks/runner (Linux + simulated Windows, statuses, errors, timeouts, concurrency, privacy, RU/EN)")
end
local ok, err = xpcall(run, debug.traceback)
if not ok then vim.api.nvim_err_writeln(err); vim.cmd("cquit 1") else vim.cmd("qa!") end
