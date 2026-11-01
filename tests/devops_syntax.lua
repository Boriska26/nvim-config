-- Validate generated fixtures without executing scripts, containers or services.
local function run()
    local root = assert(vim.env.NVIM_DEVOPS_TEST_ROOT, "NVIM_DEVOPS_TEST_ROOT required")
    local function file(index, name) return root .. "/template-" .. index .. "-1/" .. name end
    local function parse(language, filenames, label)
        local ok, added = pcall(vim.treesitter.language.add, language)
        if not ok or not added then print("SKIP: " .. label .. " (Tree-sitter parser unavailable)"); return end
        for _, filename in ipairs(filenames) do
            local text = table.concat(vim.fn.readfile(filename), "\n")
            local parser = vim.treesitter.get_string_parser(text, language)
            local tree = assert(parser:parse()[1])
            assert(not tree:root():has_error(), "syntax error: " .. filename)
        end
        print("PASS: " .. label .. " (Tree-sitter syntax only)")
    end
    if vim.fn.executable("bash") == 1 then
        local result = vim.system({ "bash", "-n", file(6, "script.sh") }, { text = true }):wait()
        assert(result.code == 0, result.stderr)
        print("PASS: Bash syntax (bash -n; script not executed)")
    else print("SKIP: Bash syntax (bash unavailable)") end
    parse("yaml", { file(2, "compose.yaml"), file(5, ".gitlab-ci.yml") }, "YAML: Compose and GitLab CI")
    parse("dockerfile", { file(1, "Dockerfile") }, "Dockerfile")
    parse("nginx", { file(9, "nginx.conf") }, "Nginx")
    parse("ini", { file(8, "app.service") }, "systemd INI")
    if vim.fn.executable("pwsh") == 1 then
        local code = [[
$tokens = $null; $parseErrors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($env:NVIM_DEVOPS_PS_FILE, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { $parseErrors | Out-String | Write-Error; exit 1 }
]]
        local result = vim.system({ "pwsh", "-NoProfile", "-NonInteractive", "-Command", code }, {
            text = true, env = { NVIM_DEVOPS_PS_FILE = file(7, "script.ps1") },
        }):wait()
        assert(result.code == 0, result.stderr)
        print("PASS: PowerShell AST parsing (script not executed)")
    else print("SKIP: PowerShell AST parsing (pwsh unavailable)") end
    print("INFO: Docker, Nginx and systemd services were not run; placeholders require review")
end
local ok, err = xpcall(run, debug.traceback)
if not ok then vim.api.nvim_err_writeln(err); vim.cmd("cquit 1") else vim.cmd("qa!") end
