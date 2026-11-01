local text = require("devkit.doctor.text")
local M = {}
local general = {
    Linux = { "Установи пакет менеджером своего дистрибутива (apt, dnf, pacman, zypper и др.) или из официального выпуска. Ничего не устанавливается автоматически.", "Use your distribution's package manager (apt, dnf, pacman, zypper, etc.) or an official release. Nothing is installed automatically." },
    Windows = { "Используй официальный установщик или проверенный пакет winget/Scoop/Chocolatey. Перезапусти терминал и Neovim, чтобы обновился PATH.", "Use an official installer or a verified winget/Scoop/Chocolatey package. Restart your terminal and Neovim to refresh PATH." },
}
local notes = {
    core = { "Проверь конфигурацию DevKit и сообщения :messages. Загружай init.lua этой конфигурации; Doctor не исправляет файлы автоматически.", "Inspect the DevKit configuration and :messages. Load this configuration's init.lua; Doctor does not repair files automatically." },
    nvim = { "Установи Neovim 0.12.6+ из официального выпуска: https://github.com/neovim/neovim/releases", "Install Neovim 0.12.6+ from an official release: https://github.com/neovim/neovim/releases" },
    plugins = { "Проверь Git, сеть и сообщения загрузки vim.pack. Перезапусти Neovim с обычным init.lua. Doctor не скачивает и не активирует плагины.", "Check Git, network access and vim.pack startup messages. Restart Neovim with the usual init.lua. Doctor does not download or activate plugins." },
    clipboard = { "Linux: для Wayland нужны wl-copy/wl-paste (wl-clipboard), для X11 — xclip и рабочая графическая сессия. Windows: проверь win32yank или штатную пару clip/PowerShell. Пользовательский g:clipboard проверь вручную.", "Linux: Wayland needs wl-copy/wl-paste (wl-clipboard); X11 needs xclip and a graphical session. Windows: check win32yank or the standard clip/PowerShell pair. Test a custom g:clipboard manually." },
    dotnet = { "Установи именно .NET SDK, не только runtime: https://dotnet.microsoft.com/download. Проверь dotnet --list-sdks в том же терминале.", "Install the .NET SDK, not just a runtime: https://dotnet.microsoft.com/download. Check dotnet --list-sdks in the same terminal." },
    roslyn = { "Проверь :Mason и пакет roslyn из настроенного реестра. Также допустим roslyn-language-server в PATH. Перезапусти Neovim; запуск сервера выполняется штатной LSP-интеграцией при открытии проекта C#.", "Check :Mason and its roslyn package in the configured registry. roslyn-language-server on PATH is also supported. Restart Neovim; the normal LSP integration starts the server when opening a C# project." },
    compiler = { "Linux: установи GCC C++ или Clang. Windows: установи MSVC Build Tools с Desktop development with C++; запускай Neovim из Developer Command Prompt/Developer PowerShell (cl требует также INCLUDE/LIB), либо настрой LLVM/MinGW. Doctor не изменяет окружение.", "Linux: install GCC C++ or Clang. Windows: install MSVC Build Tools with Desktop development with C++; launch Neovim from Developer Command Prompt/Developer PowerShell (cl also needs INCLUDE/LIB), or configure LLVM/MinGW. Doctor does not change the environment." },
    docker = { "Проверь официальную установку Docker CLI/Engine или Docker Desktop, текущий context и права подключения. При необходимости запусти Engine вручную. Не меняй права сокета на общедоступные; Doctor не управляет службами и контейнерами. https://docs.docker.com/engine/install/", "Check the official Docker CLI/Engine or Docker Desktop installation, current context and connection permissions. Start the Engine manually if needed. Do not make its socket world-writable; Doctor does not manage services or containers. https://docs.docker.com/engine/install/" },
    compose = { "Установи официальный Docker Compose plugin; команда проверки: docker compose version --short. Docker Desktop обычно включает Compose.", "Install the official Docker Compose plugin; diagnostic command: docker compose version --short. Docker Desktop normally includes Compose." },
    bash = { "Linux: установи Bash. Windows: используй Git for Windows/Git Bash или подходящее окружение WSL. Не запускай PowerShell-скрипт командой bash.", "Linux: install Bash. Windows: use Git for Windows/Git Bash or a suitable WSL environment. Do not run a PowerShell script with bash." },
    powershell = { "Установи PowerShell (pwsh) из официального выпуска. На Windows также проверяется Windows PowerShell (powershell.exe). https://learn.microsoft.com/powershell/scripting/install/installing-powershell", "Install PowerShell (pwsh) from an official release. Windows PowerShell (powershell.exe) is also checked on Windows. https://learn.microsoft.com/powershell/scripting/install/installing-powershell" },
    optional = { "Устанавливай этот инструмент только для соответствующего рабочего процесса. Используй официальный выпуск; отсутствие не мешает генераторам DevKit.", "Install this tool only for its corresponding workflow. Use an official release; its absence does not block DevKit generators." },
}
function M.get(key, platform, status)
    if status == "OK" or status == "SKIPPED" then return "" end
    local lines = {}
    if general[platform] then lines[#lines + 1] = platform .. ": " .. text.pair(general[platform]) end
    if notes[key] then lines[#lines + 1] = text.pair(notes[key]) end
    lines[#lines + 1] = text.get("after")
    return table.concat(lines, "\n\n")
end
return M
