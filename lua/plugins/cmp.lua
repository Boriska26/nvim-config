local cmp = require("cmp")

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
