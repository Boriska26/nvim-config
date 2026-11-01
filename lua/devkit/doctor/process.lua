local M = {}
function M.spawn(argv, opts, callback)
    local chunks, bytes = {}, 0
    local function capture(_, data)
        if data and bytes < 4096 then
            data = data:sub(1, 4096 - bytes)
            chunks[#chunks + 1], bytes = data, bytes + #data
        end
    end
    -- stdout/stderr are never shown. Only allow-listed version numbers reach results.
    return vim.system(argv, { text = true, timeout = opts.timeout,
        stdout = capture, stderr = capture }, function(result)
        callback({ code = result.code, signal = result.signal, stdout = table.concat(chunks) })
    end)
end
return M
