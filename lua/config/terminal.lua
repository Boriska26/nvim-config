local M = {}

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

M.toggle = toggle_terminal

return M
