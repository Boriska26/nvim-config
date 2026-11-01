local M = {}
local paths = require("generators.paths")
local i18n = require("generators.i18n")

-- Template contents are platform-neutral data. The shared writer emits LF and 0644.
M.templates = {
    { kind = "dockerfile", flags = { "-df", "--dockerfile" }, filename = "Dockerfile",
        description = "Dockerfile: минимальный образ Alpine", description_en = "Dockerfile: minimal Alpine image",
        lines = { "FROM alpine:latest", "", "WORKDIR /app", "", "COPY . .", "", 'CMD ["sh"]' } },
    { kind = "compose", flags = { "-dc", "--compose" }, filename = "compose.yaml",
        description = "Docker Compose: один сервис app", description_en = "Docker Compose: one app service",
        lines = { "services:", "  app:", "    image: my-image:latest", "    ports:", '      - "8080:8080"' } },
    { kind = "dockerignore", flags = { "-di", "--dockerignore" }, filename = ".dockerignore",
        description = "Исключения сборки Docker", description_en = "Docker build exclusions",
        lines = { "# Docker build exclusions" } },
    { kind = "gitignore", flags = { "-gi", "--gitignore" }, filename = ".gitignore",
        description = "Исключения Git для проекта", description_en = "Project-specific Git exclusions",
        lines = { "# Project-specific ignored files" } },
    { kind = "gitlab_ci", flags = { "-gl", "--gitlab-ci" }, filename = ".gitlab-ci.yml",
        description = "GitLab CI: стадия build", description_en = "GitLab CI: a build stage",
        lines = { "stages:", "  - build", "", "build:", "  stage: build", "  script:", '    - echo "Build started"' } },
    { kind = "bash", flags = { "-b", "--bash" }, filename = "script.sh", extension = ".sh",
        description = "Bash: строгий режим скрипта", description_en = "Bash: strict script mode",
        lines = { "#!/usr/bin/env bash", "", "set -euo pipefail" } },
    { kind = "powershell", flags = { "-ps", "--powershell" }, filename = "script.ps1", extension = ".ps1",
        description = "PowerShell: пустой скрипт", description_en = "PowerShell: empty script",
        lines = { "# PowerShell script" } },
    { kind = "systemd", flags = { "-sd", "--systemd" }, filename = "app.service", extension = ".service",
        description = "systemd: заготовка службы", description_en = "systemd: service stub",
        lines = { "[Unit]", "Description=Application service", "", "[Service]", "Type=simple",
            "ExecStart=/path/to/application", "Restart=on-failure", "", "[Install]", "WantedBy=multi-user.target" } },
    { kind = "nginx", flags = { "-ng", "--nginx" }, filename = "nginx.conf", extension = ".conf",
        description = "Nginx: заготовка reverse proxy", description_en = "Nginx: reverse proxy stub",
        lines = { "server {", "    listen 80;", "    server_name localhost;", "", "    location / {",
            "        proxy_pass http://127.0.0.1:8080;", "    }", "}" } },
}

function M.plan(opts)
    local template
    for _, entry in ipairs(M.templates) do if entry.kind == opts.kind then template = entry; break end end
    if not template then return nil, i18n.get("devops_type") end
    local filename = template.filename
    if opts.name then
        if not template.extension then return nil, i18n.get("fixed_name", template.filename) end
        if opts.name:find("[/\\]") or opts.name == "." then return nil, i18n.get("filename_only") end
        local clean, err = paths.clean(opts.name)
        if not clean then return nil, err end
        filename = clean
        local extension = template.extension
        if filename:lower():sub(-#extension) ~= extension then filename = filename .. extension end
        if filename:lower() == extension then return nil, i18n.get("filename_stem", extension) end
    end
    return { { path = paths.join(opts.path or ".", filename), lines = vim.deepcopy(template.lines) } }
end
return M
