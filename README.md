# Neovim Developer Kit

A personal Neovim configuration built for C#, C++, and DevOps development, with a focus on keyboard-driven workflows, customization, and productivity.

## Features

- **C# Development** — Roslyn LSP, IntelliSense, diagnostics, and code navigation.
- **C++ Development** — configurable class, header, and source file generators.
- **File Generation** — `:CreateCpp`, `:CreateCSharp`, `:CreateDevOps`, project JSON settings and minimal templates.
- **Navigation** — Telescope fuzzy search, file explorer, and buffer management.
- **Integrated Terminal** — toggleable terminal without unnecessary buffer tabs.
- **Appearance** — Tokyo Night theme, statusline, and syntax highlighting.
- **Built-in Help** — `:DevKitHelp` opens an interactive reference to the configured tools and shortcuts.
- **Cross-platform Goal** — configuration designed to support Linux and Windows.

## Installation / Установка

Requirements: Linux with Bash and GNU coreutils, or Windows with Windows PowerShell
5.1 / PowerShell 7; **Neovim 0.12.6+ and Git on PATH**. Install these yourself using
your distribution's package manager or official releases. Windows users can use
an official installer or a verified winget/Scoop/Chocolatey package, then restart
the terminal. Docker, .NET SDK and CMake are optional and are not installed or
required by the installer. No administrator/root privileges are needed for the
usual per-user destination.

Clone this official repository into a working directory, review the installer,
and run it locally (do not pipe an unknown download into a shell):

```bash
git clone https://github.com/Boriska26/nvim-config nvim-config-installer
cd nvim-config-installer
bash install.sh --lang en
```

On Windows, clone the same repository and run from PowerShell:

```powershell
.\install.ps1 -Lang en
```

Use `bash install.sh --help` / `.\install.ps1 -Help` for options. `--lang ru`
/ `-Lang ru` select Russian. A reliably detected Russian locale/UI culture selects
Russian automatically; other or unknown environments default to English.
The PowerShell installer is UTF-8 **with BOM** so Windows PowerShell 5.1 reads
Russian text correctly. Follow your organization's script execution policy;
the installer does not change it.

### Isolated installation (default)

| Platform | Default config destination | Override |
| --- | --- | --- |
| Linux | `~/.config/nvim-devkit` | `$XDG_CONFIG_HOME/nvim-devkit` |
| Windows | `%LOCALAPPDATA%\nvim-devkit` | `$env:XDG_CONFIG_HOME\nvim-devkit` |

These use Neovim's [standard path and NVIM_APPNAME mechanism](https://neovim.io/doc/user/starting.html#standard-path).
No existing `nvim` configuration, shell profile, global Git configuration or
system PATH is edited. An inherited `NVIM_APPNAME` does not change the installer
destination. Config roots must be absolute paths.

Launch on Linux:

```bash
NVIM_APPNAME=nvim-devkit nvim .
```

Launch on Windows PowerShell:

```powershell
$env:NVIM_APPNAME = "nvim-devkit"
nvim .
# After finishing, clear the override for subsequent normal Neovim launches:
Remove-Item Env:NVIM_APPNAME
```

If `NVIM_APPNAME` already had a value, restore that value instead of removing it.
The isolated app also gets its own Neovim data/state/cache locations according to
Neovim's standard paths. The installer does not change directory before launching
because it never launches the editor; launch from the project you want to edit.

A launcher is created **inside the new configuration**:

- Linux: `<config>/nvim-devkit/.devkit-launch/nvim-devkit`.
- Windows: `<config>\nvim-devkit\.devkit-launch\nvim-devkit.ps1`.

Run the printed launcher path directly, quoting paths containing spaces. The Linux
launcher sets `NVIM_APPNAME` only for its child process; the Windows launcher
restores the previous process environment value when Neovim exits. No PATH edits
or global launcher installation are performed.
For a convenient `nvim-devkit` command in the current Bash session only:

```bash
nvim-devkit() { "${XDG_CONFIG_HOME:-$HOME/.config}/nvim-devkit/.devkit-launch/nvim-devkit" "$@"; }
nvim-devkit .
```

PowerShell equivalent (use the actual printed config path if overriding XDG):

```powershell
function nvim-devkit { & "$env:LOCALAPPDATA\nvim-devkit\.devkit-launch\nvim-devkit.ps1" @args }
nvim-devkit .
```

Do not add these functions to a shell profile unless you choose to do so yourself.

### Main installation (explicit opt-in)

```bash
bash install.sh --main --lang en
```

```powershell
.\install.ps1 -Main -Lang en
```

This targets `<config-root>/nvim`. **Any existing destination is refused**, even
an empty directory, file or symlink. Move it to a backup yourself first, or choose
the default isolated mode. Existing DevKit installations are also refused:
there is no automatic update, deletion, backup or force-overwrite mode.
Launch the main installation with `NVIM_APPNAME=nvim nvim` on Linux, or set
`$env:NVIM_APPNAME = "nvim"` before `nvim` on Windows and clear/restore it afterward.

### Source selection, safety and first launch

The installer queries tags from `https://github.com/Boriska26/nvim-config`, chooses
the highest stable numeric tag (`vX.Y.Z` or `X.Y.Z`; prerelease/other tag formats
are excluded), and clones that ref. These are published Git tags, not a claim of
GitHub release certification. **If no matching stable tags exist, it explicitly
warns and clones `main`**, which is a development snapshot. A failed tag query
aborts rather than silently falling back to `main`.

A private staging directory is created next to the destination. Clone/validation
failures remove only that staging tree; an existing or concurrently created
user destination is never replaced. Publication is an atomic directory move
without replacement on the same filesystem. Git hooks are disabled for cloning;
no downloaded scripts, Lua configuration or installers are executed. Temporary
parent config directories may remain if they had to be created before a failure.
The scripts never run Neovim except `nvim --version` and do not load plugins.

On your **first deliberate launch**, this configuration calls the built-in
`vim.pack.add(require("plugins.specs"))`. Missing plugins trigger Neovim's initial
installation confirmation. Review and accept it only when you want Git downloads;
network access is then needed. The lockfile records plugin versions. The installer
neither answers this confirmation nor starts background plugin downloads.
Successful cloning alone does not prove plugin/server functionality.
After startup and plugin installation, run:

```vim
:DevKitLang en
:DevKitDoctor
:DevKitHelp
```

### Краткая инструкция (RU)

```bash
bash install.sh --lang ru          # Linux: отдельный nvim-devkit
bash install.sh --main --lang ru   # только если каталог nvim отсутствует
```

```powershell
.\install.ps1 -Lang ru
.\install.ps1 -Main -Lang ru
```

Изолированный режим не меняет обычную конфигурацию. На Linux учитывается
`XDG_CONFIG_HOME`, на Windows — `XDG_CONFIG_HOME` или `LOCALAPPDATA`.
Любой существующий целевой путь защищён: резервную копию делай самостоятельно.
При отсутствии стабильного тега будет явно выбрана ветка `main`; ошибки сети
прерывают установку с очисткой только временного клона.
Запуск: `NVIM_APPNAME=nvim-devkit nvim` на Linux; в PowerShell задай
`$env:NVIM_APPNAME = "nvim-devkit"`, запусти `nvim`, затем выполни
`Remove-Item Env:NVIM_APPNAME` (или восстанови прежнее значение).
Launcher внутри `.devkit-launch` делает это без постоянного изменения окружения.
Первый обычный запуск предлагает установить плагины через `vim.pack`; установщик
их не скачивает. После установки плагинов: `:DevKitLang ru`, `:DevKitDoctor`,
`:DevKitHelp`. Программы и службы автоматически не устанавливаются и не запускаются.

## Configuration Layout

`init.lua` loads modules in dependency order:

```text
init.lua                     Entry point and initialization order
lua/config/
  options.lua                Editor options, leaders, Russian langmap, diagnostics
  keymaps.lua                Editor, LSP, Telescope, buffer and terminal shortcuts
  terminal.lua               Persistent shell buffer and terminal events
  appearance.lua             Tokyo Night Night, separators and window highlights
lua/devkit/
  help.lua                   Floating help window, navigation and Ex commands
  help_data.lua              Section content and section commands
  keymaps.lua                Shared shortcut registry for configuration and help
  doctor/                    Checks, context, async runner, results, UI and recommendations
lua/plugins/
  init.lua / specs.lua       Shared plugin inventory, loaded with vim.pack.add
  mason.lua                  Mason registries and environment
  roslyn.lua                 C# LSP capabilities and formatting on save
  telescope.lua              Fuzzy search setup
  treesitter.lua             Filetype-based highlighting (if a parser is installed)
  cmp.lua                    Completion, snippets and completion shortcuts
  bufferline.lua             Buffer tabs, excluding terminals
  lualine.lua                Statusline
  nvim-tree.lua              File explorer
  lsp_signature.lua          Signature hints and their shortcuts
lua/generators/
  arguments.lua              Flag schemas, completion and help parameters
  parser.lua                 Shared exact-token CLI parser
  config.lua                 Project JSON loading and validation
  paths.lua                  Relative paths and project containment checks
  namespace.lua              Literal .csproj namespace discovery (no MSBuild execution)
  identifiers.lua            C++/C# identifier validation and namespace escaping
  cpp.lua / csharp.lua       Language validation and source templates
  devops.lua                 Nine single-file DevOps templates and filename rules
  i18n.lua                   Shared RU/EN generator text layer
  writer.lua                 Exclusive file creation, preflight and rollback
  service.lua                Shared generation pipeline
  catalog.lua                Command metadata and help text
  init.lua                   Ex command registration and editor integration
tests/                       Generator and configuration smoke tests
```

Editor options load before plugins so the leaders and netrw settings take effect
early. Plugins load before their setup modules; the theme loads before the panels,
and Mason loads before Roslyn. Roslyn uses `cmp-nvim-lsp` capabilities, which are
available after plugin loading; completion setup runs later. General shortcuts
load after plugin setup. Shortcut definitions live in `lua/devkit/keymaps.lua`;
the editor, completion and signature modules use that registry for setup and help.

The persistent terminal uses the same shell process when hidden and reopened,
with both `<Space>tt` and `<Space>ее` shortcuts. Russian normal/visual commands,
`Ж` for the command line, and Russian text in insert mode are preserved.

## File Generators

The generator captures the working directory once when Neovim starts. All output
paths remain relative to that root after `:cd` and repeated setup. `:CreateRoot`
shows it. C++ and C# require one explicit type flag and `-n/--name`. DevOps requires one
file-type flag; its name is optional or fixed, as described below.
Flags are exact tokens: `-rs`, `-ho`, `-so`, `-sp` and `-tg` are not bundled
single-letter options. Long value options also support `--name=Player`.
Duplicate options, incompatible options and unknown arguments are rejected.
Use Neovim argument escaping for spaces, for example `-p Some\ Folder`.

### C++ — `:CreateCpp`

| Kind | Flags | Default files |
| --- | --- | --- |
| Class | `-c`, `--class` | `.hpp` and `.cpp` |
| Struct | `-s`, `--struct` | `.hpp` |
| Enum class | `-e`, `--enum` | `.hpp` |
| Abstract interface | `-i`, `--interface` | `.hpp` |
| Plain header | `--header` | `.hpp` |
| Plain source | `--source` | `.cpp` |
| GoogleTest | `--test` | `NAMETest.cpp` |

| Placement/output | Flags |
| --- | --- |
| Header only | `-ho`, `--header-only` |
| Source only | `-so`, `--source-only` |
| Both files | `-b`, `--both` |
| Separate directories | `-sp`, `--split` |
| Files together | `-tg`, `--together` |
| Name | `-n NAME`, `--name NAME` |
| Base directory | `-p DIR`, `--path DIR` |
| Subdirectory inside split roots | `--subdir DIR` |

Class and struct accept all three output modes. Enum, interface and plain header
require header-only output; plain source and GoogleTest require source-only output. Source-only
class/struct output includes its expected header, which must be supplied separately.
New interfaces use a pure virtual destructor with an inline definition, making
them abstract. `--subdir` requires split placement, including split from JSON.

```vim
:CreateCpp -c -n Player -p Engine/
:CreateCpp -c -n Player -ho -p Engine/
:CreateCpp -s -n Vector2 -p Math/
:CreateCpp -c -n Player -b -sp -p Engine/
:CreateCpp -e -n EntityType -p Core/
:CreateCpp --class --name=Renderer --split --subdir Graphics
:CreateCpp --test -n Player -p tests/
```

`-p` is a base directory: `-sp -p Engine --subdir Graphics` creates
`Engine/include/Graphics/NAME.hpp` and `Engine/src/Graphics/NAME.cpp` by default.
Without split, `-p Engine` creates the files directly in `Engine/`. This explicit
base is combined with the chosen layout and configured header/source directories.

### C# — `:CreateCSharp`

Types: `-c/--class`, `-i/--interface`, `-e/--enum`, `-s/--struct`,
`-r/--record` (record class), `-rs/--record-struct`.
Common options: `-n/--name`, `-p/--path`, `--help`.
Accessibility defaults to `public`, can be configured as `internal`, and can be
explicitly selected using `--public`, `--internal` or `--file`.
`--file` replaces accessibility; combining it with an explicit access flag fails.
Top-level `private` and `protected` types are unsupported.

| Modifier | Supported types |
| --- | --- |
| `-a`, `--abstract` | Class, record class |
| `--sealed` | Class, record class |
| `--static` | Class |
| `--partial` | All except enum |
| `--readonly` | Struct, record struct |
| `--ref` | Struct |

Abstract and sealed conflict; static conflicts with either. Readonly ref structs
are supported. Ref record structs are rejected. The generated syntax uses C# 10+
(file-scoped namespaces and record structs); `--file` requires C# 11+.
See the [C# class rules](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/language-specification/classes)
and [file modifier rules](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/file).

```vim
:CreateCSharp -c -n PhotoService -p Services/
:CreateCSharp -i -n IPhotoService -p Interfaces/
:CreateCSharp -r -n PhotoDto -p Models/
:CreateCSharp -rs -n Point --readonly
:CreateCSharp -c -n BaseService -a
:CreateCSharp -s -n SpanView --readonly --ref --partial
```

Namespace discovery starts at the output directory and walks its parents to the
nearest `.csproj`. A literal unconditional `RootNamespace` wins; otherwise the
project filename is used. Directories below the project become namespace segments.
For example, `App/App.csproj` with `RootNamespace=Company.App` and output path
`App/Services/Photos` produces `namespace Company.App.Services.Photos;`.
No `using` directives are inferred from a path.

Predictable namespace policies:

- No parent `.csproj`: generate a valid type in the global namespace; sibling/child
  projects are not searched recursively or guessed.
- Several `.csproj` files in the nearest directory: fail and ask for a path within
  an unambiguous project.
- Empty explicit `RootNamespace`: omit the root prefix; nested directories still apply.
- Conditional/duplicate/computed `RootNamespace`, explicit MSBuild imports or namespace
  settings from `Directory.Build.props/targets`: fail without executing MSBuild.
- Names and namespace segments use ASCII identifiers; C# keywords can be escaped
  with `@`. Reserved namespace segments are escaped automatically. Invalid project
  names or directory segments are rejected instead of silently renamed.

### DevOps — `:CreateDevOps`

One invocation creates exactly **one file**, opens it for editing, and preserves
Neovim's working directory. No stack detection, infrastructure generation,
interactive prompts, script execution or executable permission changes occur.

| Flags | Default filename | Custom `-n/--name` |
| --- | --- | --- |
| `-df`, `--dockerfile` | `Dockerfile` | Not accepted |
| `-dc`, `--compose` | `compose.yaml` | Not accepted |
| `-di`, `--dockerignore` | `.dockerignore` | Not accepted |
| `-gi`, `--gitignore` | `.gitignore` | Not accepted |
| `-gl`, `--gitlab-ci` | `.gitlab-ci.yml` | Not accepted |
| `-b`, `--bash` | `script.sh` | Appends `.sh` |
| `-ps`, `--powershell` | `script.ps1` | Appends `.ps1` |
| `-sd`, `--systemd` | `app.service` | Appends `.service` |
| `-ng`, `--nginx` | `nginx.conf` | Appends `.conf` |

Common options are `-p/--path DIR` (default `.`), `-n/--name NAME` where accepted,
and `--help`. Each alias is an exact flag; two type selectors or repeated options
are errors. Fixed-name templates reject `-n` even when it matches the default.
Custom names are basenames: put directory components in `-p`. A matching extension
is preserved, case-insensitively; another extension gets the required suffix
(e.g. `backup.other` becomes `backup.other.sh`). Unicode filenames are supported.

```vim
:CreateDevOps -df -p .
:CreateDevOps --compose -p deploy/
:CreateDevOps -di
:CreateDevOps -gi
:CreateDevOps -gl
:CreateDevOps -b -n backup -p scripts/
:CreateDevOps -ps -n deploy -p scripts/
:CreateDevOps -sd -n familycloud -p deploy/systemd/
:CreateDevOps -ng -n reverse-proxy -p deploy/nginx/
:CreateDevOps --help
```

Templates contain the specified minimal Alpine Dockerfile, a Compose `app` service
(without the obsolete `version` field), ignore-file comments, GitLab's `build`
stage, a strict-mode Bash skeleton, a PowerShell comment, a systemd service stub,
and an Nginx reverse proxy block. Output uses UTF-8 and LF. They contain no secrets
or inferred framework dependencies. Review placeholders such as `my-image:latest`,
`/path/to/application` and the upstream address before deployment; these are
starting points rather than validated production configurations.

DevOps shares project JSON validation, captured-root paths, exclusive file creation
and rollback with C++/C#. No extra DevOps JSON settings are defined in this version.
Directories are created as needed; only the requested file is written. `..`, absolute
paths, unsafe names, and symlinks outside the captured root are rejected.
`--help` works without valid project configuration. Completion offers the common
and template flags; this version's shared completion does not complete path values.

### Generator language

Russian (`ru`) is the default. To switch to English inside a running Neovim:

```vim
:DevKitLang en
:CreateDevOps --help
```

To switch back to Russian:

```vim
:DevKitLang ru
```

`:DevKitLang` without arguments prints the current language. Existing direct
`g:devkit_language` settings remain supported. Reopen ordinary help to refresh it;
an open Doctor updates immediately after `:DevKitLang ru/en`, without rerunning probes.

To keep English after restarting Neovim, add this **at the top of `init.lua`,
before the first `require(...)`**:

```lua
vim.g.devkit_language = "en"
```

For a single launch, use `nvim --cmd 'let g:devkit_language="en"' .`.
Values other than `en` fall back to Russian.
DevOps descriptions, parameter hints, errors, creation notices and help follow this
setting, as do shared parser/path/config/writer messages and Generation labels.
Commands, flags and generated template bytes remain the same in both languages.
Existing C++/C# type-specific descriptions and other help sections retain their
Russian text. The shared text layer is `lua/generators/i18n.lua`.
Help and messages use the selected language immediately when shown again.
To also refresh the Ex command descriptions registered earlier, run
`:lua require("generators").setup()`; this is not required for `--help`.

### Project configuration and file safety

`.nvim-generator.json` is read as JSON data from the captured launch root:

```json
{
  "cpp": {
    "layout": "split",
    "paths": { "header": "include", "source": "src" },
    "extensions": { "header": ".hpp", "source": ".cpp" }
  },
  "csharp": { "defaultAccess": "public" }
}
```

See [examples/.nvim-generator.json](examples/.nvim-generator.json).
Priority: explicit command values, explicit placement flags, project JSON, defaults.
An absent config uses defaults; malformed or invalid config fails rather than
silently falling back. `--help` works even with an invalid config. Configured paths
are relative to the command's base. Existing files are never overwritten.
Absolute paths, `..`, Windows device names and symlinks escaping the captured root
are rejected. All targets are checked before writing; files created by an invocation
are removed if a later write fails. Output files are not added to CMake or `.csproj`.

### Public commands and help

The public generation API has three commands: `:CreateCpp`, `:CreateCSharp`
and `:CreateDevOps`. Choose C++ types using `--class`, `--struct`, `--enum`,
`--interface`, `--header`, `--source` or `--test`.
`-s` means struct; output selection uses `-ho`, `-so` or `-b`.

`--test` writes one `NAMETest.cpp` containing `#include <gtest/gtest.h>` and
`TEST(NAMETest, Placeholder)`, without a header. Split/together, `-p`, `--subdir`
and the configured source directory and extension apply as for other source files.
With a custom `cpp.extensions.source`, the configured extension replaces `.cpp`.
Compiling this template requires GoogleTest.

```vim
:CreateCpp -c -n Player -p Engine/
:CreateCpp --test -n Player -sp --subdir Unit
:CreateCpp --help
:CreateCSharp --help
:CreateHelp
:GeneratorHelp
:GeneratorList
```

`CreateHelp` prints the C++, C# and DevOps references. `GeneratorHelp` opens the existing
Generation menu. `GeneratorList` lists the three generators and the help/root
utilities. The registry, Ex completion and help expose the same three generators.

## Built-in Help

Run `:DevKitHelp` to open the category menu in a Tokyo Night Night floating
window. Each row shows the command that opens its section directly:

| Category | Command |
| --- | --- |
| Generation | `:GeneratorHelp` |
| Windows | `:WindowHelp` |
| Search | `:SearchHelp` |
| Editing | `:EditingHelp` |
| LSP & Completion | `:LspHelp` |
| Terminal | `:TerminalHelp` |
| Git | `:GitHelp` |
| Appearance | `:AppearanceHelp` |
| Doctor | `:DoctorHelp` |

Generation reads metadata from the same registry:
`DevKitHelp → Generation → C++ / C# / DevOps → commands, parameters and examples`.
Empty categories are omitted.

Use `j`/`k` or the arrow keys and Enter to select a menu item. In a reference page,
`j`/`k` and arrows scroll, `h` or Backspace returns one level, and `q` or Esc
closes the window at any level. Reopening help reuses the existing window. The reference
includes modes, examples and plugin availability, and works without optional
plugins. The Git section describes the system Git commands and Lualine's
branch/diff display. No new plugins or global shortcuts are added.

Generator extensions use `require("generators.catalog").register(metadata,
handler, opts)`. This registers the actual Ex command and its metadata together:

- `command`, `description`: Ex command name and purpose.
- `category`: `id`, `title`, optional `order` and shared `notes`.
- `parameters`: a list of `{ name, description }` entries (empty for commands with no parameters).
- `examples`: a nonempty list of complete Ex command examples.
- `handler`, `opts`: the command callback and Neovim user-command options.

The help window and `GeneratorList` read this registry. Registering a generator
updates an open Generation menu automatically. Definitions in the same category
share identical category metadata. `catalog.unregister(command)` removes the
command and metadata; removing the last command removes its category. Commands
deleted outside the registry are omitted on the next read. The existing help UI
is reused; flag schemas also supply command completion and help parameters.

## Environment diagnostics — `:DevKitDoctor`

Run `:DevKitDoctor` to open a scratch floating window. Repeated calls reuse and
refresh it. Use `j`/`k`, arrows and Ctrl-d/u to scroll, `r` to rerun, Enter for the
selected check's details and installation advice, Backspace/`h` for the list,
`?` for keys, and `q`/Esc to close. `:DoctorHelp` is also listed in `:DevKitHelp`.
The working file, unsaved changes, cwd, clipboard contents and configuration are
preserved. Checks never generate project files or run project builds.

Checks cover Core, C#, C++ and DevOps on Linux and Windows:

- **Core:** Neovim 0.12.6+, Git, ripgrep, optional fd/fdfind and clipboard,
  `vim.pack`, the shared plugin inventory, module syntax/loading and actual
  registration of generator/help commands. Plugin installation, activation and
  loaded configuration/commands are checked separately. Lazy dependencies are
  reported as active, without pretending their lazy functionality was exercised.
- **C#:** dotnet on PATH, installed SDK versions (`dotnet --list-sdks`), executable
  Roslyn command and configured format-on-save. Roslyn is not started. No separate
  formatter or debugger is required by this configuration.
- **C++:** a usable g++/clang++/cl version probe, CMake and clang-format. MSVC also
  needs the Developer Command Prompt/Developer PowerShell INCLUDE/LIB environment.
  C++ LSP and CTest are skipped when unconfigured. A loaded coreclr DAP adapter is
  inspected only if present; this repository does not install a debugger.
- **DevOps:** Git, Docker CLI, a timed Engine availability query, Compose, Bash,
  PowerShell (pwsh or Windows PowerShell), SSH, and optional glab/kubectl/helm/terraform.

`ERROR` means a required Core dependency or DevKit configuration is broken.
`WARNING` marks an unavailable optional workflow or unverified clipboard provider.
`SKIPPED` means a tool/integration is inapplicable or not configured. Missing C++
compilers, .NET SDKs or Docker do not make Core fail. An unreachable Docker Engine
may mean service state, permissions or context; Doctor does not guess which one.

The runner uses argv arrays and `vim.system`, at most **two concurrent processes**,
a **2500 ms per-process timeout** and a hard watchdog. Rerun/close cancels owned
probes. It does not install packages, alter PATH, access clipboard contents, start
or stop services, launch containers, compile code or execute generated scripts.
Only bounded version tokens are extracted; raw stdout/stderr, SDK paths and
sensitive environment values are never shown, including in details. Clipboard
availability is inspected without a round-trip. This is an environment check,
not proof that a project builds or a service configuration is production-ready.

Docker's read-only queries are documented by Docker:
[`docker version`](https://docs.docker.com/reference/cli/docker/version/) and
[`docker compose version --short`](https://docs.docker.com/reference/cli/docker/compose/version/).
Windows MSVC setup is described in Microsoft's
[command-line tools documentation](https://learn.microsoft.com/en-us/cpp/build/building-on-the-command-line).
Recommendations distinguish Linux package managers from Windows official
installers/verified packages and never run an installation command.

### Быстрый старт Doctor (RU)

```vim
:DevKitLang ru
:DevKitDoctor
```

`r` повторяет проверки, Enter открывает объяснение и рекомендации для текущей ОС,
`?` показывает клавиши, Backspace возвращает список, `q`/Esc закрывают окно.
Для английского выполни `:DevKitLang en` — открытый Doctor перерисуется сразу.
Отсутствие Docker, SDK или C++ компилятора — предупреждение, а ненастроенные
отладчик/LSP/CTest пропускаются. Doctor ничего не устанавливает, не меняет
пользовательские файлы и не запускает службы или контейнеры. Сырые системные
логи и переменные окружения не выводятся. Linux проверен отдельно; Windows
покрывается имитацией в тестах и требует дополнительной проверки на реальной ОС.

## Requirements and Checks

The configuration targets Neovim **0.12.6**, using its built-in `vim.pack` plugin
manager, LSP and snippets. The plugin list and `nvim-pack-lock.json` are unchanged.
Initial plugin installation requires Git and network access. Install the Roslyn
server through Mason and the desired Treesitter parsers separately as needed.

Linux checks and test commands are documented in [tests/README.md](tests/README.md).
The Lua modules use Neovim APIs and no fixed Linux paths or shell commands;
the terminal uses Neovim's configured `shell`. Windows remains a compatibility
target but requires separate validation on Windows. Shortcut reference scripts
are provided in `bin/nvimhk` and `bin/nvimhk.ps1`.

## Project Status

🚧 Work in progress. This project is being developed and improved as part of my journey toward a more terminal-driven development workflow.

    Feedback, suggestions, and contributions are welcome!
