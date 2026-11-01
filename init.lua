-- Leader, netrw и основные опции задаются до загрузки плагинов.
require("config.options")
-- Справка доступна без загрузки необязательных плагинов.
require("devkit.help").setup()
require("plugins")

-- Тема применяется до настройки панелей, использующих её цвета.
require("config.appearance")
require("plugins.nvim-tree")

-- Mason настраивает окружение; Roslyn использует capabilities cmp-nvim-lsp.
require("plugins.mason")
require("plugins.roslyn")
require("plugins.treesitter")
require("plugins.telescope")
require("plugins.lualine")
require("plugins.bufferline")

require("config.terminal")
require("plugins.lsp_signature")
require("plugins.cmp")
require("config.keymaps")

-- Корень генератора фиксируется в текущем каталоге запуска Neovim.
require("generators").setup()
