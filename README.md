# Neovim Developer Kit

A personal Neovim configuration built for C#, C++, and DevOps development, with a focus on keyboard-driven workflows, customization, and productivity.

## Features

- **C# Development** — Roslyn LSP, IntelliSense, diagnostics, and code navigation.
- **C++ Development** — configurable class, header, and source file generators.
- **File Generation** — custom `:CreateCppClass` and related commands with project-specific directory layouts.
- **Navigation** — Telescope fuzzy search, file explorer, and buffer management.
- **Integrated Terminal** — toggleable terminal without unnecessary buffer tabs.
- **Appearance** — Tokyo Night theme, statusline, and syntax highlighting.
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
lua/generators/              C++ generation, argument parsing and project paths
tests/                       Generator and configuration smoke tests
```

Editor options load before plugins so the leaders and netrw settings take effect
early. Plugins load before their setup modules; the theme loads before the panels,
and Mason loads before Roslyn. Roslyn uses `cmp-nvim-lsp` capabilities, which are
available after plugin loading; completion setup runs later. General shortcuts
load after plugin setup. Completion and signature shortcuts stay with their plugins.

The persistent terminal uses the same shell process when hidden and reopened,
with both `<Space>tt` and `<Space>ее` shortcuts. Russian normal/visual commands,
`Ж` for the command line, and Russian text in insert mode are preserved.

## C++ Generator Commands

The generator captures the working directory when Neovim starts. Existing commands
remain available: `CreateCppClass`, `CreateCppStruct`, `CreateCppEnum`,
`CreateCppHeader`, `CreateCppSource`, `CreateCppInterface`, `CreateCppTest`,
`CreateHelp` and `CreateRoot`. `GeneratorHelp` is an alias for `CreateHelp`;
`GeneratorList` lists all generator commands.

```vim
:CreateCppClass -n Player -hs Engine/
:CreateCppClass -n Renderer --split --subdir Graphics/
:GeneratorHelp
:GeneratorList
```

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
