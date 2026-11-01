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
