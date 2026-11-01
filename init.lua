-- =============================
-- БАЗОВЫЕ НАСТРОЙКИ
-- =============================

-- Отключаем netrw в пользу nvim-tree
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Основная клавиша для пользовательских сочетаний
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.opt.timeoutlen = 1500

-- Нумерация и отступы
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.numberwidth = 4
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true

-- Удобство работы
vim.opt.cursorline = true
vim.opt.cursorlineopt = "number,line"
vim.opt.scrolloff = 8
vim.opt.wrap = false
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.clipboard = "unnamedplus"
vim.opt.signcolumn = "yes"
vim.opt.termguicolors = true

-- Команды Neovim при русской раскладке (NORMAL / VISUAL)
-- Это соответствие русских клавиш английским в раскладке ЙЦУКЕН.
-- В режиме INSERT русский текст остаётся русским.
vim.opt.langmap =
    "ФИСВУАПРШОЛДЬТЩЗЙКЫЕГМЦЧНЯ;ABCDEFGHIJKLMNOPQRSTUVWXYZ," ..
    "фисвуапршолдьтщзйкыегмцчня;abcdefghijklmnopqrstuvwxyz"
vim.opt.langremap = false

-- Русское Shift+; (Ж) позволяет открыть командную строку.
-- Сами команды после ':' нужно вводить латиницей.
vim.keymap.set("n", "Ж", ":", {
    desc = "Открыть командную строку с русской раскладкой",
})

-- =============================
-- ПЛАГИНЫ
-- =============================
vim.pack.add({
    { src = "https://github.com/nvim-tree/nvim-tree.lua" },
    { src = "https://github.com/nvim-tree/nvim-web-devicons" },
    { src = "https://github.com/mason-org/mason.nvim" },
    { src = "https://github.com/seblyng/roslyn.nvim" },
    { src = "https://github.com/folke/tokyonight.nvim" },
    { src = "https://github.com/nvim-treesitter/nvim-treesitter" },
    { src = "https://github.com/nvim-lua/plenary.nvim" },
    { src = "https://github.com/nvim-telescope/telescope.nvim" },
    { src = "https://github.com/nvim-lualine/lualine.nvim" },
    { src = "https://github.com/akinsho/bufferline.nvim" },
    { src = "https://github.com/ray-x/lsp_signature.nvim" },
    { src = "https://github.com/hrsh7th/nvim-cmp" },
    { src = "https://github.com/hrsh7th/cmp-nvim-lsp" },
    { src = "https://github.com/hrsh7th/cmp-buffer" },
    { src = "https://github.com/hrsh7th/cmp-path" },
})

-- =============================
-- ТЕМА TOKYO NIGHT
-- =============================
require("tokyonight").setup({
    style = "night",
    transparent = false,
    styles = {
        comments = { italic = true },
        keywords = { italic = true },
    },
})
vim.cmd.colorscheme("tokyonight")

-- Символы и цвета разделителей
vim.opt.fillchars:append({
    horiz = "━",
    vert = "┃",
    horizup = "┻",
    horizdown = "┳",
    verthoriz = "╋",
})

-- Стили задаём после применения темы, чтобы та их не перезаписала.
vim.api.nvim_set_hl(0, "WinSeparator", {
    fg = "#7aa2f7",
    bg = "#292e42",
})
vim.api.nvim_set_hl(0, "WinBar", {
    fg = "#c0caf5",
    bg = "#3b4261",
    bold = true,
})
vim.api.nvim_set_hl(0, "WinBarNC", {
    fg = "#a9b1d6",
    bg = "#292e42",
})

-- =============================
-- ДЕРЕВО ФАЙЛОВ
-- =============================
require("nvim-tree").setup({
    view = { width = 35 },
})
vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", {
    desc = "Открыть дерево файлов",
})

-- =============================
-- ROSLYN / C#
-- =============================
require("mason").setup({
    registries = {
        "github:mason-org/mason-registry",
        "github:Crashdummyy/mason-registry",
    },
})

vim.lsp.config("roslyn", {
    capabilities = require("cmp_nvim_lsp").default_capabilities(),
})
require("roslyn").setup({})

vim.keymap.set("n", "gd", vim.lsp.buf.definition)
vim.keymap.set("n", "gr", vim.lsp.buf.references)
vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename)
vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action)

-- =============================
-- TREESITTER
-- =============================
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "cs", "lua", "json", "yaml", "sh" },
    callback = function()
        -- Если парсер для языка ещё не установлен, не ломаем открытие файла.
        pcall(vim.treesitter.start)
    end,
})

-- =============================
-- TELESCOPE
-- =============================
require("telescope").setup({})
local builtin = require("telescope.builtin")

vim.keymap.set("n", "<leader>ff", builtin.find_files)
vim.keymap.set("n", "<leader>fg", builtin.live_grep)
vim.keymap.set("n", "<leader>fb", builtin.buffers)
vim.keymap.set("n", "<leader>fs", builtin.lsp_document_symbols)

-- =============================
-- LUALINE
-- =============================
require("lualine").setup({
    options = {
        theme = "auto",
        globalstatus = true,
    },
    sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "diagnostics", "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
    },
})

-- =============================
-- BUFFERLINE
-- =============================
require("bufferline").setup({
    options = {
        mode = "buffers",
        diagnostics = "nvim_lsp",
        separator_style = "slant",
        show_buffer_close_icons = false,
        custom_filter = function(buf_number)
            -- Терминалы не показываются сверху как вкладки.
            return vim.bo[buf_number].buftype ~= "terminal"
        end,
        offsets = {
            {
                filetype = "NvimTree",
                text = "FamilyCloud",
                text_align = "center",
                separator = true,
            },
        },
    },
})

vim.keymap.set("n", "]b", "<cmd>BufferLineCycleNext<CR>")
vim.keymap.set("n", "[b", "<cmd>BufferLineCyclePrev<CR>")
vim.keymap.set("n", "<leader>bd", "<cmd>bdelete<CR>")

-- =============================
-- ДИАГНОСТИКА LSP
-- =============================
vim.diagnostic.config({
    virtual_text = { spacing = 2, prefix = "●" },
    signs = true,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
    float = { border = "rounded", source = "if_many" },
})

vim.keymap.set("n", "<leader>d", function()
    vim.diagnostic.open_float()
end, { desc = "Показать диагностику" })

-- =============================
-- ОДИН ПОСТОЯННЫЙ ТЕРМИНАЛ
-- =============================
local terminal_buf = nil

-- Заголовок над любым новым встроенным терминалом.
vim.api.nvim_create_autocmd("TermOpen", {
    callback = function()
        vim.wo.winbar = "  󰆍  TERMINAL  "
    end,
})

local function toggle_terminal()
    -- Если терминал уже виден, прячем его окно, но сохраняем процесс.
    if terminal_buf and vim.api.nvim_buf_is_valid(terminal_buf) then
        local win = vim.fn.bufwinid(terminal_buf)
        if win ~= -1 then
            -- Не пытаемся скрыть единственное оставшееся окно.
            if #vim.api.nvim_tabpage_list_wins(0) > 1 then
                vim.api.nvim_win_hide(win)
            end
            return
        end
    end

    -- Открываем нижнее окно высотой 24 строки.
    vim.cmd("botright 24split")

    if terminal_buf and vim.api.nvim_buf_is_valid(terminal_buf) then
        -- Возвращаем уже работающую оболочку.
        vim.api.nvim_win_set_buf(0, terminal_buf)
    else
        -- Создаём терминал только при первом вызове или после exit.
        vim.cmd("terminal")
        terminal_buf = vim.api.nvim_get_current_buf()
        vim.bo[terminal_buf].bufhidden = "hide"
        vim.bo[terminal_buf].buflisted = false
    end

    vim.wo.winbar = "  󰆍  TERMINAL  "
    vim.cmd("startinsert")
end

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

-- После exit закрываем завершённый терминал.
vim.api.nvim_create_autocmd("TermClose", {
    callback = function(args)
        if args.buf ~= terminal_buf then
            return
        end

        terminal_buf = nil
        local closed_buf = args.buf

        -- Удаление буфера переносим за пределы события TermClose.
        vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(closed_buf) then
                return
            end

            -- Если остались другие окна, убираем завершённый терминал.
            local win = vim.fn.bufwinid(closed_buf)
            if win ~= -1 and #vim.api.nvim_tabpage_list_wins(0) > 1 then
                vim.api.nvim_win_hide(win)
            end

            -- Без force здесь может мешать признак modified у терминала.
            pcall(vim.api.nvim_buf_delete, closed_buf, { force = true })
        end)
    end,
})

-- =============================
-- ПОДСКАЗКИ ПАРАМЕТРОВ
-- =============================
require("lsp_signature").setup({
    bind = true,
    floating_window = true,
    hint_enable = false,
    doc_lines = 3,
    max_height = 12,
    handler_opts = { border = "rounded" },
    toggle_key = "<C-k>",
    select_signature_key = "<C-l>",
})

-- =============================
-- АВТОДОПОЛНЕНИЕ
-- =============================
local cmp = require("cmp")
vim.opt.completeopt = "menuone,noselect,popup"

cmp.setup({
    snippet = {
        expand = function(args)
            vim.snippet.expand(args.body)
        end,
    },
    completion = {
        autocomplete = {
            require("cmp.types").cmp.TriggerEvent.TextChanged,
        },
    },
    window = {
        completion = cmp.config.window.bordered(),
        documentation = cmp.config.window.bordered(),
    },
    mapping = cmp.mapping.preset.insert({
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<C-n>"] = cmp.mapping.select_next_item(),
        ["<C-p>"] = cmp.mapping.select_prev_item(),
        ["<CR>"] = cmp.mapping.confirm({ select = false }),
    }),
    sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "path" },
    }, {
        { name = "buffer" },
    }),
})

-- =============================
-- РЕДАКТИРОВАНИЕ СТРОК
-- =============================
vim.keymap.set("n", "<leader>k", ":move .-2<CR>==")
vim.keymap.set("n", "<leader>j", ":move .+1<CR>==")
vim.keymap.set("x", "<leader>k", ":move '<-2<CR>gv=gv")
vim.keymap.set("x", "<leader>j", ":move '>+1<CR>gv=gv")

-- =============================
-- СОХРАНЕНИЕ И C# FORMAT
-- =============================
vim.keymap.set("n", "<C-s>", "<cmd>write<CR>", {
    desc = "Сохранить файл",
})
vim.keymap.set("i", "<C-s>", "<C-o>:write<CR>", {
    desc = "Сохранить файл",
})

vim.api.nvim_create_autocmd("BufWritePre", {
    group = vim.api.nvim_create_augroup("CSharpFormatOnSave", {
        clear = true,
    }),
    pattern = "*.cs",
    callback = function(args)
        local clients = vim.lsp.get_clients({
            bufnr = args.buf,
            method = "textDocument/formatting",
        })

        for _, client in ipairs(clients) do
            if client.name == "roslyn" then
                vim.lsp.buf.format({
                    bufnr = args.buf,
                    id = client.id,
                    async = false,
                    timeout_ms = 3000,
                })
                break
            end
        end
    end,
})

-- =============================
-- ГЕНЕРАТОР ФАЙЛОВ
-- =============================
-- Модуль генератора: lua/generators/ (переносимый между Linux и Windows).
require("generators").setup()
