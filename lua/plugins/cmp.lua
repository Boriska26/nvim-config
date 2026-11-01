local cmp = require("cmp")
local actions = {
    complete = cmp.mapping.complete(),
    next = cmp.mapping.select_next_item(),
    previous = cmp.mapping.select_prev_item(),
    confirm = cmp.mapping.confirm({ select = false }),
}
local mappings = {}
for _, entry in ipairs(require("devkit.keymaps").completion) do
    mappings[entry.lhs] = actions[entry.id]
end

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
    mapping = cmp.mapping.preset.insert(mappings),
    sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "path" },
    }, {
        { name = "buffer" },
    }),
})
