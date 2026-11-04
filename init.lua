-- Диагностика доступна даже при ошибке последующей настройки редактора.
require("generators.i18n").setup()
require("devkit.doctor").setup()
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

-- Необязательные настройки этой машины загружаются после общих модулей.
-- Путь берётся из конфигурации Neovim, а не из текущего проекта.
local local_config = vim.fs.joinpath(vim.fn.stdpath("config"), "local.lua")
if vim.uv.fs_stat(local_config) then
    local ok, err = pcall(dofile, local_config)
    if not ok then
        vim.schedule(function()
            vim.notify("Failed to load " .. local_config .. ":\n" .. tostring(err), vim.log.levels.ERROR)
        end)
    end
end
