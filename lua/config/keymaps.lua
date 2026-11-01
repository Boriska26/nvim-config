-- Русское Shift+; (Ж) позволяет открыть командную строку.
-- Сами команды после ':' нужно вводить латиницей.
vim.keymap.set("n", "Ж", ":", {
    desc = "Открыть командную строку с русской раскладкой",
})

-- Дерево файлов
vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", {
    desc = "Открыть дерево файлов",
})

-- LSP
vim.keymap.set("n", "gd", vim.lsp.buf.definition)
vim.keymap.set("n", "gr", vim.lsp.buf.references)
vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename)
vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action)

-- Telescope загружен и настроен в lua/plugins/telescope.lua.
local builtin = require("telescope.builtin")

vim.keymap.set("n", "<leader>ff", builtin.find_files)
vim.keymap.set("n", "<leader>fg", builtin.live_grep)
vim.keymap.set("n", "<leader>fb", builtin.buffers)
vim.keymap.set("n", "<leader>fs", builtin.lsp_document_symbols)

-- Буферы
vim.keymap.set("n", "]b", "<cmd>BufferLineCycleNext<CR>")
vim.keymap.set("n", "[b", "<cmd>BufferLineCyclePrev<CR>")
vim.keymap.set("n", "<leader>bd", "<cmd>bdelete<CR>")

vim.keymap.set("n", "<leader>d", function()
    vim.diagnostic.open_float()
end, { desc = "Показать диагностику" })

-- Обе раскладки используют одно состояние постоянного терминала.
local toggle_terminal = require("config.terminal").toggle
vim.keymap.set("n", "<leader>tt", toggle_terminal, {
    desc = "Показать/скрыть постоянный терминал",
})

-- Русская раскладка: на физических клавишах t,t печатается е,е.
-- Явный алиас на случай, если langmap не применяется к сочетанию.
vim.keymap.set("n", "<leader>ее", toggle_terminal, {
    desc = "Показать/скрыть терминал (русская раскладка)",
})

-- Дважды Esc возвращает из терминала в NORMAL.
vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], {
    desc = "Терминал: NORMAL режим",
})

-- Перемещение строк
vim.keymap.set("n", "<leader>k", ":move .-2<CR>==")
vim.keymap.set("n", "<leader>j", ":move .+1<CR>==")
vim.keymap.set("x", "<leader>k", ":move '<-2<CR>gv=gv")
vim.keymap.set("x", "<leader>j", ":move '>+1<CR>gv=gv")

-- Сохранение; форматирование C# настраивается в lua/plugins/roslyn.lua.
vim.keymap.set("n", "<C-s>", "<cmd>write<CR>", {
    desc = "Сохранить файл",
})
vim.keymap.set("i", "<C-s>", "<C-o>:write<CR>", {
    desc = "Сохранить файл",
})
