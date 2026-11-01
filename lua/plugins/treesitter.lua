vim.api.nvim_create_autocmd("FileType", {
    pattern = { "cs", "lua", "json", "yaml", "sh" },
    callback = function()
        -- Если парсер для языка ещё не установлен, не ломаем открытие файла.
        pcall(vim.treesitter.start)
    end,
})
