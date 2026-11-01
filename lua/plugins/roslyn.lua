-- Mason и cmp-nvim-lsp должны быть доступны до настройки Roslyn.
vim.lsp.config("roslyn", {
    capabilities = require("cmp_nvim_lsp").default_capabilities(),
})
require("roslyn").setup({})

-- Форматирование C# при сохранении выполняется только клиентом Roslyn.
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
