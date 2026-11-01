local M = {}
local paths = require("generators.paths")

function M.write(root, entries)
    local seen = {}
    for _, entry in ipairs(entries) do
        local clean, err = paths.clean(entry.path)
        if not clean then return nil, err end
        if clean == "." then return nil, "Не вычислено имя файла" end
        local identity = vim.fn.has("win32") == 1 and clean:lower() or clean
        if seen[identity] then return nil, "Совпадают пути создаваемых файлов: " .. clean end
        seen[identity], entry.path = true, clean
        local filename = paths.file(root, clean)
        if vim.uv.fs_stat(filename) then return nil, "Файл уже существует: " .. clean end
        local safe, parent_err = paths.safe_parent(root, vim.fn.fnamemodify(filename, ":h"))
        if not safe then return nil, parent_err end
    end

    local created, err = {}, nil
    for _, entry in ipairs(entries) do
        local filename = paths.file(root, entry.path)
        local directory = vim.fn.fnamemodify(filename, ":h")
        local ok = pcall(vim.fn.mkdir, directory, "p")
        if not ok or vim.fn.isdirectory(directory) == 0 or not paths.within(root, directory) then
            err = "Не удалось создать безопасный каталог: " .. directory
            break
        end
        local handle, open_err = vim.uv.fs_open(filename, "wx", 420)
        if not handle then err = "Не удалось создать " .. entry.path .. ": " .. tostring(open_err); break end
        created[#created + 1] = filename
        local data = table.concat(entry.lines, "\n") .. "\n"
        local bytes, write_err = vim.uv.fs_write(handle, data, 0)
        vim.uv.fs_close(handle)
        if bytes ~= #data then err = "Ошибка записи " .. entry.path .. ": " .. tostring(write_err or "incomplete write"); break end
    end
    if err then
        for _, filename in ipairs(created) do pcall(vim.uv.fs_unlink, filename) end
        return nil, err
    end
    return true
end
return M
