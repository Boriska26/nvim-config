# Neovim Developer Kit

A personal Neovim configuration built for C#, C++, and DevOps development, with a focus on keyboard-driven workflows, customization, and productivity.

## Features

- **C# Development** — Roslyn LSP, IntelliSense, diagnostics, and code navigation.
- **C++ Development** — configurable class, header, and source file generators.
- **File Generation** — `:CreateCpp`, `:CreateCSharp`, project JSON settings and GoogleTest templates.
- **Navigation** — Telescope fuzzy search, file explorer, and buffer management.
- **Integrated Terminal** — toggleable terminal without unnecessary buffer tabs.
- **Appearance** — Tokyo Night theme, statusline, and syntax highlighting.
- **Built-in Help** — `:DevKitHelp` opens an interactive reference to the configured tools and shortcuts.
- **Cross-platform Goal** — configuration designed to support Linux and Windows.

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
lua/plugins/
  init.lua                   Existing plugin list, loaded with vim.pack.add
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
shows it. New commands require one explicit type flag and `-n/--name`.
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

The public generation API has exactly two commands: `:CreateCpp` and
`:CreateCSharp`. Choose C++ types using `--class`, `--struct`, `--enum`,
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

`CreateHelp` prints the C++ and C# references. `GeneratorHelp` opens the existing
Generation menu. `GeneratorList` lists the two generators and the help/root
utilities. The registry, Ex completion and help expose the same two generators.

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

Generation reads metadata for C++ and C# commands from the same registry:
`DevKitHelp → Generation → C++ / C# → commands, parameters and examples`.
DevOps is not implemented and has no category. Empty categories are omitted.

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
