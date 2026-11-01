require("bufferline").setup({
    options = {
        mode = "buffers",
        diagnostics = "nvim_lsp",
        separator_style = "slant",
        show_buffer_close_icons = false,
        custom_filter = function(buf_number)
            -- Терминалы не показываются сверху как вкладки.
            return vim.bo[buf_number].buftype ~= "terminal"
        end,
        offsets = {
            {
                filetype = "NvimTree",
                text = "FamilyCloud",
                text_align = "center",
                separator = true,
            },
        },
    },
})
