local keys = require("devkit.keymaps").signature
require("lsp_signature").setup({
    bind = true,
    floating_window = true,
    hint_enable = false,
    doc_lines = 3,
    max_height = 12,
    handler_opts = { border = "rounded" },
    toggle_key = keys.toggle_key.lhs,
    select_signature_key = keys.select_signature_key.lhs,
})
