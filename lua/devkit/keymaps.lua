-- Shared by config/keymaps.lua, completion plugins and the built-in help.
-- Resolvers run only during keymap registration, never while rendering help.
local M = {}

local function lsp(method)
    return function() return vim.lsp.buf[method] end
end

local function telescope(method)
    return function() return require("telescope.builtin")[method] end
end

local function terminal()
    return require("config.terminal").toggle
end

M.editor = {
    { section = "editing", mode = "n", lhs = "Ж", rhs = ":",
        text = "Открыть командную строку с русской раскладкой",
        desc = "Открыть командную строку с русской раскладкой" },
    { section = "windows", mode = "n", lhs = "<leader>e", rhs = "<cmd>NvimTreeToggle<CR>",
        text = "Открыть/закрыть дерево файлов (nvim-tree)", desc = "Открыть дерево файлов" },
    { section = "lsp", mode = "n", lhs = "gd", resolve = lsp("definition"), text = "Перейти к определению" },
    { section = "lsp", mode = "n", lhs = "gr", resolve = lsp("references"), text = "Найти ссылки" },
    { section = "lsp", mode = "n", lhs = "<leader>rn", resolve = lsp("rename"), text = "Переименовать символ" },
    { section = "lsp", mode = "n", lhs = "<leader>ca", resolve = lsp("code_action"), text = "Действия над кодом" },
    { section = "search", mode = "n", lhs = "<leader>ff", resolve = telescope("find_files"), text = "Поиск файлов" },
    { section = "search", mode = "n", lhs = "<leader>fg", resolve = telescope("live_grep"), text = "Поиск текста (нужен rg)" },
    { section = "search", mode = "n", lhs = "<leader>fb", resolve = telescope("buffers"), text = "Поиск открытых буферов" },
    { section = "search", mode = "n", lhs = "<leader>fs", resolve = telescope("lsp_document_symbols"), text = "Символы документа (нужен LSP)" },
    { section = "windows", mode = "n", lhs = "]b", rhs = "<cmd>BufferLineCycleNext<CR>", text = "Следующий буфер (Bufferline)" },
    { section = "windows", mode = "n", lhs = "[b", rhs = "<cmd>BufferLineCyclePrev<CR>", text = "Предыдущий буфер (Bufferline)" },
    { section = "windows", mode = "n", lhs = "<leader>bd", rhs = "<cmd>bdelete<CR>", text = "Удалить текущий буфер" },
    { section = "lsp", mode = "n", lhs = "<leader>d", rhs = function() vim.diagnostic.open_float() end,
        text = "Показать диагностику", desc = "Показать диагностику" },
    { section = "terminal", mode = "n", lhs = "<leader>tt", resolve = terminal,
        text = "Показать/скрыть постоянный терминал", desc = "Показать/скрыть постоянный терминал" },
    { section = "terminal", mode = "n", lhs = "<leader>ее", resolve = terminal,
        text = "Тот же терминал с русской раскладкой", desc = "Показать/скрыть терминал (русская раскладка)" },
    { section = "terminal", mode = "t", lhs = "<Esc><Esc>", rhs = [[<C-\><C-n>]],
        text = "Вернуться из терминала в NORMAL", desc = "Терминал: NORMAL режим" },
    { section = "editing", mode = "n", lhs = "<leader>k", rhs = ":move .-2<CR>==", text = "Переместить строку вверх" },
    { section = "editing", mode = "n", lhs = "<leader>j", rhs = ":move .+1<CR>==", text = "Переместить строку вниз" },
    { section = "editing", mode = "x", lhs = "<leader>k", rhs = ":move '<-2<CR>gv=gv", text = "Переместить выделенные строки вверх" },
    { section = "editing", mode = "x", lhs = "<leader>j", rhs = ":move '>+1<CR>gv=gv", text = "Переместить выделенные строки вниз" },
    { section = "editing", mode = "n", lhs = "<C-s>", rhs = "<cmd>write<CR>", text = "Сохранить файл", desc = "Сохранить файл" },
    { section = "editing", mode = "i", lhs = "<C-s>", rhs = "<C-o>:write<CR>", text = "Сохранить файл и продолжить ввод", desc = "Сохранить файл" },
}

M.completion = {
    { id = "complete", lhs = "<C-Space>", text = "Открыть автодополнение" },
    { id = "next", lhs = "<C-n>", text = "Следующий вариант" },
    { id = "previous", lhs = "<C-p>", text = "Предыдущий вариант" },
    { id = "confirm", lhs = "<CR>", text = "Подтвердить выбранный вариант (select = false)" },
}

M.signature = {
    toggle_key = { lhs = "<C-k>", mode = "I/V/S", text = "Показать/скрыть окно параметров" },
    select_signature_key = { lhs = "<C-l>", mode = "I", text = "Следующая перегрузка метода" },
}

function M.setup()
    for _, entry in ipairs(M.editor) do
        vim.keymap.set(entry.mode, entry.lhs, entry.resolve and entry.resolve() or entry.rhs,
            entry.desc and { desc = entry.desc } or {})
    end
end

return M
