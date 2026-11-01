local M = {}
local function version(output)
    -- Never return arbitrary stdout, paths, environment or stderr to the UI.
    return (output or ""):match("(%d+%.%d+%.?%d*)")
end
local function process_result(result, done, failure)
    if result.code == -1 then done(failure, "launch"); return false end
    if result.code == 124 then done(failure, "timeout"); return false end
    if result.code ~= 0 then done(failure, "failed"); return false end
    return true
end
function M.build(context)
    local checks = {}
    local function add(id, category, name, why, fix, run, what)
        local actual_run = run
        run = function(ctx, done)
            if ctx.platform == "Unsupported" and category ~= "core" then done("SKIPPED", "unsupported")
            else actual_run(ctx, done) end
        end
        checks[#checks + 1] = { id = id, category = category, name = name, why = why, fix = fix, run = run,
            what = what or { "Проверка доступности: " .. name[1], "Availability check: " .. name[2] } }
    end
    local function tool(id, category, name, candidates, argv, required, fix, why, presence_only)
        add(id, category, name, why, fix, function(ctx, done)
            if ctx.platform == "Unsupported" then done("SKIPPED", "unsupported"); return end
            local available = {}
            for _, candidate in ipairs(candidates) do
                local path = ctx.which(candidate)
                if path then available[#available + 1] = { path, candidate } end
            end
            local failure = required and "ERROR" or "WARNING"
            if #available == 0 then done(presence_only and "SKIPPED" or failure, presence_only and "optional_missing" or "missing"); return end
            if presence_only then done("OK", "available"); return end
            local function probe(index)
                local executable, selected = unpack(available[index])
                local command = { executable }
                local flags = type(argv) == "function" and argv(selected) or argv
                for _, arg in ipairs(flags) do command[#command + 1] = arg end
                ctx.exec(command, function(result)
                    local found = result.code == 0 and version(result.stdout)
                    if (result.code ~= 0 or not found) and index < #available then probe(index + 1); return end
                    if not process_result(result, done, failure) then return end
                    if selected == "cl" and not ctx.msvc_env then done("WARNING", "msvc_env"); return end
                    if found then done("OK", "version", { found }) else done(failure, "unexpected") end
                end)
            end
            probe(1)
        end)
    end
    local core_why = { "Необходимо для штатной конфигурации DevKit.", "Required by the normal DevKit configuration." }
    local optional_why = { "Необязательно: отсутствие не мешает редактированию и генераторам.", "Optional: absence does not block editing or file generators." }
    add("core.nvim", "core", { "Версия Neovim", "Neovim version" }, core_why, "nvim", function(ctx, done)
        local v = ctx.version
        local good = v.major > 0 or v.minor > 12 or v.minor == 12 and v.patch >= 6
        done(good and "OK" or "ERROR", good and "version" or "old_nvim",
            good and { string.format("%d.%d.%d", v.major, v.minor, v.patch) } or nil)
    end)
    add("core.platform", "core", { "Платформа", "Platform" }, core_why, "core", function(ctx, done)
        done(ctx.platform == "Unsupported" and "SKIPPED" or "OK", ctx.platform == "Unsupported" and "unsupported" or "available")
    end)
    tool("core.git", "core", { "Git", "Git" }, { "git" }, { "--version" }, true, "tool",
        { "vim.pack использует Git для установки плагинов.", "vim.pack uses Git to install plugins." })
    tool("core.rg", "core", { "ripgrep", "ripgrep" }, { "rg" }, { "--version" }, true, "tool",
        { "Telescope live_grep ищет текст через rg.", "Telescope live_grep uses rg to search text." })
    tool("core.fd", "core", { "fd / fdfind", "fd / fdfind" }, { "fd", "fdfind" }, { "--version" }, false, "optional",
        { "Ускоряет поиск файлов; Telescope имеет альтернативные способы поиска.", "Speeds up file finding; Telescope has alternative search backends." })
    add("core.pack", "core", { "Менеджер vim.pack", "vim.pack manager" }, core_why, "plugins", function(ctx, done)
        done(ctx.manager and ctx.specs_ok and "OK" or "ERROR", ctx.manager and ctx.specs_ok and "available" or "plugin_missing")
    end)
    for _, plugin in ipairs(context.plugins) do
        local data = plugin
        add("core.plugin." .. data.name, "core", { data.name, data.name }, core_why, "plugins", function(_, done)
            if not data.installed then done("ERROR", "plugin_missing")
            elseif not data.active then done("ERROR", "plugin_inactive")
            elseif data.lazy then done("OK", "plugin_lazy")
            elseif not data.loaded then done("ERROR", "plugin_unloaded")
            else done("OK", "available") end
        end, { "Установка, активация vim.pack и загрузка настроенного модуля/команды.", "Installation, vim.pack activation, and loading of the configured module/command." })
    end
    add("core.modules", "core", { "Основные Lua-модули", "Core Lua modules" }, core_why, "core", function(ctx, done)
        for name, data in pairs(ctx.modules) do
            local must_load = name:match("^config%.") or name == "generators" or name == "devkit.help"
            if not data.syntax or must_load and not data.loaded then done("ERROR", "module_bad_name", { name }); return end
        end
        done("OK", "available")
    end, { "Синтаксис основных модулей и загрузка entry points. Ленивые шаблоны не исполняются.", "Core module syntax and loaded entry points. Lazy templates are not executed." })
    for _, name in ipairs({ "CreateCpp", "CreateCSharp", "CreateDevOps", "GeneratorHelp", "GeneratorList", "DevKitHelp" }) do
        local command = name
        add("core.command." .. command, "core", { ":" .. command, ":" .. command }, core_why, "core", function(ctx, done)
            done(ctx.commands[command] and "OK" or "ERROR", ctx.commands[command] and "available" or "command_missing")
        end, { "Регистрация команды; генерация файлов и открытие справки не вызываются.", "Command registration; no generation or help opening is invoked." })
    end
    add("core.clipboard", "core", { "Буфер обмена", "Clipboard" },
        { "unnamedplus использует системный буфер обмена.", "unnamedplus uses the system clipboard." }, "clipboard", function(ctx, done)
            if not ctx.clipboard_used then done("SKIPPED", "not_configured")
            elseif ctx.clipboard == "candidate" then done("OK", "clipboard")
            elseif ctx.clipboard == "custom" then done("WARNING", "clipboard_custom")
            else done("WARNING", "missing") end
        end)
    add("csharp.dotnet", "csharp", { ".NET CLI", ".NET CLI" }, optional_why, "dotnet", function(ctx, done)
        done(ctx.which("dotnet") and "OK" or "WARNING", ctx.which("dotnet") and "available" or "missing")
    end)
    add("csharp.sdk", "csharp", { ".NET SDK", ".NET SDK" },
        { "Сборка проектов C# требует SDK, а не только runtime.", "Building C# projects needs an SDK, not just a runtime." }, "dotnet", function(ctx, done)
            local executable = ctx.which("dotnet")
            if not executable then done("WARNING", "missing"); return end
            ctx.exec({ executable, "--list-sdks" }, function(result)
                if not process_result(result, done, "WARNING") then return end
                local versions, seen = {}, {}
                for line in (result.stdout or ""):gmatch("[^\r\n]+") do
                    local found = line:match("^%s*(%d+%.%d+%.%d+)")
                    if found and not seen[found] and #versions < 10 then versions[#versions + 1], seen[found] = found, true end
                end
                if #versions == 0 then done("WARNING", "no_sdk") else done("OK", "version", { table.concat(versions, ", ") }) end
            end)
        end, { "dotnet --list-sdks; пути установки из вывода не отображаются.", "dotnet --list-sdks; installation paths in the output are not displayed." })
    add("csharp.roslyn", "csharp", { "Roslyn LSP", "Roslyn LSP" },
        { "Навигация, диагностика и форматирование C# используют Roslyn.", "C# navigation, diagnostics and formatting use Roslyn." }, "roslyn", function(ctx, done)
            done(ctx.roslyn and "OK" or "WARNING", ctx.roslyn and "roslyn" or "missing")
        end)
    add("csharp.format", "csharp", { "Форматирование C#", "C# formatting" }, optional_why, "roslyn", function(ctx, done)
        if not ctx.features.csharp_format then done("SKIPPED", "not_configured")
        else done(ctx.roslyn and "OK" or "WARNING", ctx.roslyn and "roslyn_format" or "missing") end
    end)
    add("csharp.debugger", "csharp", { "Отладчик C#", "C# debugger" }, optional_why, "optional", function(ctx, done)
        if not ctx.features.debugger then done("SKIPPED", "not_configured")
        else done(ctx.debugger and "OK" or "WARNING", ctx.debugger and "available" or "missing") end
    end)
    tool("cpp.compiler", "cpp", { "Компилятор C++", "C++ compiler" }, context.platform == "Windows" and { "g++", "clang++", "cl" } or { "g++", "clang++" }, function(name)
        return name == "cl" and { "/?" } or { "--version" }
    end, false, "compiler", optional_why)
    tool("cpp.cmake", "cpp", { "CMake", "CMake" }, { "cmake" }, { "--version" }, false, "optional", optional_why)
    tool("cpp.format", "cpp", { "clang-format", "clang-format" }, { "clang-format" }, { "--version" }, false, "optional", optional_why)
    add("cpp.lsp", "cpp", { "C++ LSP", "C++ LSP" }, optional_why, "optional", function(ctx, done)
        if not ctx.features.cpp_lsp then done("SKIPPED", "not_configured")
        else done(ctx.which(ctx.features.cpp_lsp) and "OK" or "WARNING", ctx.which(ctx.features.cpp_lsp) and "available" or "missing") end
    end)
    add("cpp.ctest", "cpp", { "CTest", "CTest" }, optional_why, "optional", function(ctx, done)
        if not ctx.features.ctest then done("SKIPPED", "not_configured")
        else done(ctx.which("ctest") and "OK" or "WARNING", ctx.which("ctest") and "available" or "missing") end
    end)
    tool("devops.git", "devops", { "Git", "Git" }, { "git" }, { "--version" }, false, "core", optional_why)
    tool("devops.docker", "devops", { "Docker CLI", "Docker CLI" }, { "docker" }, { "--version" }, false, "docker", optional_why)
    add("devops.engine", "devops", { "Docker Engine", "Docker Engine" },
        { "CLI может быть установлен без доступного Engine. Контейнеры и службы не запускаются.", "The CLI may be installed without a reachable Engine. No containers or services are started." }, "docker", function(ctx, done)
            local executable = ctx.which("docker")
            if not executable then done("SKIPPED", "no_docker"); return end
            ctx.exec({ executable, "version", "--format", "{{.Server.Version}}" }, function(result)
                if result.code == 124 then done("WARNING", "timeout")
                elseif result.code == -1 then done("WARNING", "launch")
                elseif result.code ~= 0 then done("WARNING", "daemon_failed")
                else
                    local found = version(result.stdout)
                    done(found and "OK" or "WARNING", found and "version" or "unexpected", found and { found } or nil)
                end
            end)
        end, { "docker version --format {{.Server.Version}} с тайм-аутом; используется текущий Docker context.", "Timed docker version --format {{.Server.Version}}; uses the current Docker context." })
    tool("devops.compose", "devops", { "Docker Compose", "Docker Compose" }, { "docker" }, { "compose", "version", "--short" }, false, "compose", optional_why)
    tool("devops.bash", "devops", { "Bash", "Bash" }, { "bash" }, { "--version" }, false, "bash", optional_why)
    tool("devops.powershell", "devops", { "PowerShell", "PowerShell" }, context.platform == "Windows" and { "pwsh", "powershell" } or { "pwsh" },
        { "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "$PSVersionTable.PSVersion.ToString()" }, false, "powershell", optional_why)
    tool("devops.ssh", "devops", { "SSH", "SSH" }, { "ssh" }, { "-V" }, false, "optional", optional_why)
    for _, name in ipairs({ "glab", "kubectl", "helm", "terraform" }) do
        tool("devops.optional." .. name, "devops", { name, name }, { name }, {}, false, "optional", optional_why, true)
    end
    return checks
end
return M
