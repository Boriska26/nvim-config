-- Native APIs, no plugins or external programs. Run in a separate process with -u NONE.
local function run()
    assert(not package.loaded["generators"], "Run with -u NONE")
    local base = vim.env.NVIM_DEVOPS_TEST_ROOT or vim.fn.tempname()
    vim.fn.mkdir(base, "p")
    local service = require("generators.service")
    local args = require("generators.arguments")
    local catalog = require("generators.catalog")
    local count = 0
    local function directory(name)
        local path = base .. "/" .. name
        vim.fn.mkdir(path, "p")
        return path
    end
    local function read(root, name)
        local file = assert(io.open(root .. "/" .. name, "rb"), name)
        local text = file:read("*a")
        file:close()
        return text
    end
    local function files(root)
        local result = {}
        local function visit(path, prefix)
            local scan = assert(vim.uv.fs_scandir(path))
            while true do
                local name, kind = vim.uv.fs_scandir_next(scan)
                if not name then break end
                if kind == "directory" then visit(path .. "/" .. name, prefix .. name .. "/")
                else result[#result + 1] = prefix .. name end
            end
        end
        visit(root, "")
        table.sort(result)
        return result
    end
    local function generate(root, flags)
        count = count + 1
        return service.generate(root, "devops", flags)
    end
    local function success(root, flags, expected)
        local cwd = vim.fn.getcwd()
        local result, err = generate(root, flags)
        assert(result and #result.entries == 1, err)
        assert(result.entries[1].path == expected, result.entries[1].path)
        assert(vim.fn.getcwd() == cwd, "generator changed cwd")
        return result
    end
    local function failure(root, flags, fragment)
        local before = files(root)
        local result, err = generate(root, flags)
        assert(not result and type(err) == "string", "expected failure")
        if fragment then assert(err:find(fragment, 1, true), err) end
        assert(vim.deep_equal(before, files(root)), "failed generation changed project files")
        return err
    end
    -- Expected bytes come from the specification, independently of the template module.
    local templates = {
        { "-df", "--dockerfile", "Dockerfile", "FROM alpine:latest\n\nWORKDIR /app\n\nCOPY . .\n\nCMD [\"sh\"]\n" },
        { "-dc", "--compose", "compose.yaml", "services:\n  app:\n    image: my-image:latest\n    ports:\n      - \"8080:8080\"\n" },
        { "-di", "--dockerignore", ".dockerignore", "# Docker build exclusions\n" },
        { "-gi", "--gitignore", ".gitignore", "# Project-specific ignored files\n" },
        { "-gl", "--gitlab-ci", ".gitlab-ci.yml", "stages:\n  - build\n\nbuild:\n  stage: build\n  script:\n    - echo \"Build started\"\n" },
        { "-b", "--bash", "script.sh", "#!/usr/bin/env bash\n\nset -euo pipefail\n", ".sh" },
        { "-ps", "--powershell", "script.ps1", "# PowerShell script\n", ".ps1" },
        { "-sd", "--systemd", "app.service", "[Unit]\nDescription=Application service\n\n[Service]\nType=simple\nExecStart=/path/to/application\nRestart=on-failure\n\n[Install]\nWantedBy=multi-user.target\n", ".service" },
        { "-ng", "--nginx", "nginx.conf", "server {\n    listen 80;\n    server_name localhost;\n\n    location / {\n        proxy_pass http://127.0.0.1:8080;\n    }\n}\n", ".conf" },
    }
    for index, template in ipairs(templates) do
        for alias = 1, 2 do
            local root = directory("template-" .. index .. "-" .. alias)
            local flags = alias == 1 and { template[alias] } or { template[alias], "-p", "." }
            success(root, flags, template[3])
            local bytes = read(root, template[3])
            assert(bytes == template[4], "template bytes differ: " .. template[3])
            assert(not bytes:find("\r", 1, true) and not bytes:find("\239\187\191", 1, true))
            assert(pcall(vim.str_utfindex, bytes), "invalid UTF-8")
            assert(vim.deep_equal(files(root), { template[3] }), "one call created multiple files")
            if vim.fn.has("win32") == 0 then
                local mode = vim.uv.fs_stat(root .. "/" .. template[3]).mode
                for _, mask in ipairs({ 1, 8, 64 }) do assert(math.floor(mode / mask) % 2 == 0, "executable permission set") end
            end
            failure(root, flags, template[3])
            assert(read(root, template[3]) == bytes, "existing file overwritten")
            assert(vim.tbl_contains(args.complete(args.devops, template[alias]), template[alias]))
        end
        local nested = directory("nested-" .. index)
        success(nested, { template[1], "--path=deploy/nested" }, "deploy/nested/" .. template[3])
        if template[5] then
            for variant, name in ipairs({ "backup", "backup" .. template[5], "backup" .. template[5]:upper(), "backup.other", "резервная-копия" }) do
                local root = directory("named-" .. index .. "-" .. variant)
                local filename = name:lower():sub(-#template[5]) == template[5] and name or name .. template[5]
                success(root, { template[2], "--name=" .. name }, filename)
                assert(read(root, filename) == template[4])
            end
            for _, name in ipairs({ ".", "..", "../outside", "sub/file", "sub\\file", "CON", "bad:", "bad.", template[5] }) do
                failure(directory("bad-name-" .. index), { template[1], "-n", name })
            end
        else
            failure(directory("fixed-name-" .. index), { template[1], "-n", "custom" }, "фиксировано")
        end
    end
    local bad = directory("bad-arguments")
    for _, flags in ipairs({ {}, { "-df", "-dc" }, { "--bash", "--bash" }, { "-b", "--bash" },
        { "--unknown" }, { "-dfdc" }, { "-d" }, { "--dockerfile=true" }, { "-df", "-n" },
        { "-b", "--name=" }, { "-df", "-p" }, { "-b", "-n", "one", "--name", "two" },
        { "-df", "-p", ".", "--path", "." }, { "-df", "--split" }, { "-b", "--readonly" } }) do failure(bad, flags) end
    for _, path in ipairs({ "../outside", "inside/../../outside", "/tmp/absolute", "C:/absolute", "C:relative", "\\\\server\\share", "bad\npath", "NUL", "trailing.", "bad*path" }) do
        failure(bad, { "-df", "-p", path })
    end
    local outside = directory("outside")
    assert(vim.uv.fs_symlink(outside, bad .. "/link"))
    failure(bad, { "-df", "-p", "link/new" }, "symlink")
    assert(vim.fn.isdirectory(outside .. "/new") == 0, "mkdir escaped the root")

    local config = directory("config")
    local config_bytes = '{"cpp":{"layout":"split","paths":{"header":"api","source":"impl"}},"csharp":{"defaultAccess":"internal"}}'
    vim.fn.writefile({ config_bytes }, config .. "/.nvim-generator.json")
    success(config, { "-df", "-p", "deploy" }, "deploy/Dockerfile")
    assert(read(config, ".nvim-generator.json") == config_bytes .. "\n")
    vim.fn.writefile({ "invalid JSON" }, config .. "/.nvim-generator.json")
    failure(config, { "-df" }, "JSON")
    assert(generate(config, { "--help" }).help, "help depends on valid config")

    -- Actual commands: a captured root, modified-buffer split, file opening and no execution.
    local native = directory("native")
    vim.fn.chdir(native)
    require("generators").setup()
    vim.fn.mkdir(native .. "/child", "p")
    vim.fn.chdir(native .. "/child")
    require("generators").setup()
    local current_cwd = vim.fn.getcwd()
    local original_system, original_vim_system, original_jobstart = vim.fn.system, vim.system, vim.fn.jobstart
    local function forbidden() error("generator attempted to execute a process") end
    vim.fn.system, vim.system, vim.fn.jobstart = forbidden, forbidden, forbidden
    local notifications, original_notify = {}, vim.notify
    vim.notify = function(message, level) notifications[#notifications + 1] = { message, level } end
    local draft = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_set_current_buf(draft)
    vim.api.nvim_buf_set_lines(draft, 0, -1, false, { "unsaved draft" })
    for index, template in ipairs(templates) do
        vim.cmd("CreateDevOps " .. template[1] .. " -p Ex/" .. index)
        assert(read(native, "Ex/" .. index .. "/" .. template[3]) == template[4])
        assert(vim.api.nvim_buf_get_name(0) == native .. "/Ex/" .. index .. "/" .. template[3])
        assert(vim.fn.getcwd() == current_cwd and vim.fn.filereadable(current_cwd .. "/Ex/" .. index .. "/" .. template[3]) == 0)
    end
    assert(vim.api.nvim_buf_get_lines(draft, 0, -1, false)[1] == "unsaved draft")
    for _, language in ipairs({ "ru", "en" }) do
        vim.g.devkit_language = language
        require("generators").setup()
        local help = vim.api.nvim_exec2("CreateDevOps --help", { output = true }).output
        for _, template in ipairs(templates) do
            assert(help:find(template[1], 1, true) and help:find(template[2], 1, true) and help:find(template[3], 1, true))
        end
        assert(help:find(language == "en" and "minimal template" or "минимальным шаблоном", 1, true))
        if language == "en" then assert(not help:find("[\208\209]"), "Russian text leaked into English DevOps help") end
        vim.cmd("CreateDevOps -ps -n " .. language .. " -p localized")
        assert(notifications[#notifications][1]:find(language == "en" and "Created:" or "Создано:", 1, true))
        local function command_error(command, fragment)
            vim.cmd(command)
            local notification = notifications[#notifications]
            assert(notification[2] == vim.log.levels.ERROR and notification[1]:find(fragment, 1, true), notification[1])
        end
        command_error("CreateDevOps -df -n forbidden", language == "en" and "filename is fixed" or "фиксировано")
        command_error("CreateDevOps --unknown", language == "en" and "Unknown argument" or "Неизвестный аргумент")
        command_error("CreateDevOps -df -dc", language == "en" and "Repeated or incompatible" or "Повторные или несовместимые")
        command_error("CreateDevOps", language == "en" and "Choose exactly one" or "Выбери ровно один")
        command_error("CreateDevOps -df -p ../escape", language == "en" and "outside the project" or "Выход за пределы")
        command_error("CreateDevOps -df -p Ex/1", language == "en" and "already exists" or "уже существует")
        require("devkit.help").open("generation", "devops")
        local page = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
        assert(page:find(language == "en" and "Purpose:" or "Назначение:", 1, true))
        assert(page:find("CreateDevOps", 1, true) and page:find("--nginx", 1, true))
        if language == "en" then
            assert(not page:find("[\208\209]"), "Russian text leaked into the English DevOps page")
            assert(vim.api.nvim_win_get_config(0).footer[1][1]:find("back", 1, true))
        end
        require("devkit.help").close()
    end
    vim.fn.system, vim.system, vim.fn.jobstart, vim.notify = original_system, original_vim_system, original_jobstart, original_notify
    vim.g.devkit_language = nil
    assert(require("generators.i18n").language() == "ru")
    vim.g.devkit_language = "unsupported"
    assert(require("generators.i18n").language() == "ru")
    vim.g.devkit_language = nil
    assert(vim.tbl_contains(vim.fn.getcompletion("CreateDevOps --doc", "cmdline"), "--dockerfile"))
    assert(vim.fn.exists(":DevKitDoctor") == 0)
    assert(#catalog.generators() == 3 and #catalog.categories() == 3)
    assert(vim.api.nvim_exec2("GeneratorList", { output = true }).output:find("CreateDevOps", 1, true))
    assert(vim.api.nvim_exec2("CreateHelp", { output = true }).output:find("--gitlab-ci", 1, true))
    print("PASS: DevOps integration (" .. count .. " service cases, 9 Ex types, RU/EN); fixtures: " .. base)
end
local ok, err = xpcall(run, debug.traceback)
if not ok then vim.api.nvim_err_writeln(err); vim.cmd("cquit 1") else vim.cmd("qa!") end
