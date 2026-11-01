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

vim.opt.completeopt = "menuone,noselect,popup"

vim.diagnostic.config({
    virtual_text = { spacing = 2, prefix = "●" },
    signs = true,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
    float = { border = "rounded", source = "if_many" },
})
