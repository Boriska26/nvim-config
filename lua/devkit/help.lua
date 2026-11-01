local M = {}
local sections = require("devkit.help_data")
local i18n = require("generators.i18n")
local namespace = vim.api.nvim_create_namespace("DevKitHelp")
local state = { selections = { main = 1, generation = 1 } }
local menu_start = 4
local initialized = false

local function highlights()
    -- Tokyo Night Night palette, also available when the theme plugin is absent.
    for name, spec in pairs({
        DevKitHelpNormal = { fg = "#c0caf5", bg = "#1a1b26" },
        DevKitHelpBorder = { fg = "#7aa2f7", bg = "#1a1b26" },
        DevKitHelpTitle = { fg = "#bb9af7", bg = "#1a1b26", bold = true },
        DevKitHelpMuted = { fg = "#a9b1d6", bg = "#1a1b26" },
        DevKitHelpSelected = { fg = "#c0caf5", bg = "#292e42", bold = true },
    }) do vim.api.nvim_set_hl(0, name, spec) end
end

local function geometry()
    local width = math.max(1, math.min(100, vim.o.columns - 4))
    local available = vim.o.lines - vim.o.cmdheight
    local height = math.max(1, math.min(30, available - 4))
    return {
        relative = "editor", width = width, height = height,
        row = math.max(0, math.floor((available - height - 2) / 2)),
        col = math.max(0, math.floor((vim.o.columns - width - 2) / 2)),
        border = "rounded", style = "minimal", zindex = 60,
        title = " DevKitHelp ", title_pos = "center",
        footer = i18n.get(width >= 65 and "help_footer" or "help_footer_short"),
        footer_pos = "center",
    }
end

local function append_text(lines, text)
    for line in (text or ""):gmatch("[^\n]+") do lines[#lines + 1] = line end
end

local function mapping_line(entry, mode)
    local lhs = entry.lhs:gsub("<leader>", "<Space>")
    return string.format("%-5s %-18s %s", mode, lhs, entry.text)
end

local function content(section)
    local lines = { section.title .. "  :" .. section.command,
        "N: NORMAL | I: INSERT | V: VISUAL | S: SELECT | T: TERMINAL | Ex: команда", "" }
    for _, dependency in ipairs(section.dependencies or {}) do
        local available, unavailable
        if dependency.command then
            available = vim.fn.exists(":" .. dependency.command) == 2
            unavailable = "команда недоступна"
        elseif dependency.executable then
            available = vim.fn.executable(dependency.executable) == 1
            unavailable = "не найден в PATH"
        else
            available = package.loaded[dependency.module] ~= nil
            unavailable = "не загружен"
        end
        lines[#lines + 1] = dependency.label .. ": " .. (available and "доступен" or unavailable)
    end
    if section.dependencies then lines[#lines + 1] = "" end
    append_text(lines, i18n.field(section, "text"))

    local keys = require("devkit.keymaps")
    local modes = { n = "N", i = "I", x = "V", t = "T" }
    local mappings = {}
    for _, entry in ipairs(keys.editor) do
        if entry.section == section.id then mappings[#mappings + 1] = mapping_line(entry, modes[entry.mode]) end
    end
    if section.completion then
        for _, entry in ipairs(keys.completion) do mappings[#mappings + 1] = mapping_line(entry, "I") end
        for _, option in ipairs({ "toggle_key", "select_signature_key" }) do
            local entry = keys.signature[option]
            mappings[#mappings + 1] = mapping_line(entry, entry.mode)
        end
    end
    if #mappings > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Сочетания конфигурации (<leader> = Space):"
        vim.list_extend(lines, mappings)
    end
    if section.extra then
        lines[#lines + 1] = ""
        append_text(lines, section.extra)
    end
    return lines
end

local function generator_content(category)
    local lines = { "Generation > " .. category.title .. "  :GeneratorHelp",
        i18n.get("generation_hint"), "" }
    for _, entry in ipairs(category.generators) do
        lines[#lines + 1] = ":" .. entry.command
        lines[#lines + 1] = "  " .. i18n.get("purpose") .. " " .. i18n.field(entry, "description")
        lines[#lines + 1] = "  " .. i18n.get("parameters")
        if #entry.parameters == 0 then lines[#lines + 1] = "    " .. i18n.get("no_parameters") end
        for _, parameter in ipairs(entry.parameters) do
            lines[#lines + 1] = "    " .. parameter.name .. " — " .. i18n.field(parameter, "description")
        end
        lines[#lines + 1] = "  " .. i18n.get("examples")
        for _, example in ipairs(entry.examples) do lines[#lines + 1] = "    " .. example end
        lines[#lines + 1] = ""
    end
    append_text(lines, i18n.field(category, "notes"))
    return lines
end

function M.close()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_close(state.win, true)
    end
end

local function move(delta)
    local menu = state.menu
    if not menu or #menu.items == 0 then return end
    local row = vim.api.nvim_win_get_cursor(state.win)[1]
    local selected = ((row - menu_start + delta) % #menu.items) + 1
    state.selections[menu.key] = selected
    vim.api.nvim_win_set_cursor(state.win, { menu_start + selected - 1, 0 })
end

local function back()
    if state.category then M.open("generation") else M.open() end
end

function M.open(id, category_id)
    if not initialized then M.setup() end
    local section
    if id then
        for index, item in ipairs(sections) do
            if item.id == id then section, state.selections.main = item, index; break end
        end
        assert(section, "Unknown DevKitHelp section: " .. tostring(id))
    end
    state.section = id
    local categories, category
    if section and section.generator then
        categories = require("generators.catalog").categories()
        for index, item in ipairs(categories) do
            if item.id == category_id then category, state.selections.generation = item, index; break end
        end
    end
    state.category = category and category.id or nil
    if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
        state.buf = vim.api.nvim_create_buf(false, true)
        local buf = state.buf
        vim.bo[buf].bufhidden = "wipe"
        vim.bo[buf].swapfile = false
        vim.bo[buf].filetype = "devkithelp"
        vim.api.nvim_create_autocmd("BufWipeout", {
            buffer = buf, once = true,
            callback = function()
                if state.buf == buf then state.buf, state.win = nil, nil end
            end,
        })
    end

    local lines, menu
    if category then
        lines = generator_content(category)
    elseif categories then
        menu = { key = "generation", items = categories }
        lines = { "Generation  :GeneratorHelp", i18n.get("generation_select"), "" }
        for _, item in ipairs(categories) do
            lines[#lines + 1] = string.format("  %-18s %s", item.title, i18n.get("command_count", #item.generators))
        end
        if #categories == 0 then lines[#lines + 1] = i18n.get("no_generators") end
    elseif section then
        lines = content(section)
    else
        menu = { key = "main", items = sections }
        lines = { "Neovim Developer Kit", "Выберите раздел и нажмите Enter. <leader> = Space.", "" }
        for _, item in ipairs(sections) do
            lines[#lines + 1] = string.format("  %-18s :%s", item.title, item.command)
        end
    end
    state.menu = menu
    local buf = state.buf
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].modified = false
    vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
    for index, group in ipairs({ "DevKitHelpTitle", "DevKitHelpMuted" }) do
        vim.api.nvim_buf_set_extmark(buf, namespace, index - 1, 0,
            { end_col = #lines[index], hl_group = group })
    end

    if state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_set_config(state.win, geometry())
        vim.api.nvim_set_current_win(state.win)
    else
        state.win = vim.api.nvim_open_win(buf, true, geometry())
    end
    local win = state.win
    vim.wo[win].wrap = menu == nil
    vim.wo[win].linebreak = true
    vim.wo[win].cursorline = menu ~= nil and #menu.items > 0
    vim.wo[win].scrolloff = 0
    vim.wo[win].winbar = ""
    vim.wo[win].spell = false
    vim.wo[win].winhighlight = "Normal:DevKitHelpNormal,FloatBorder:DevKitHelpBorder,FloatTitle:DevKitHelpTitle,FloatFooter:DevKitHelpMuted,CursorLine:DevKitHelpSelected"

    local function map(lhs, rhs)
        vim.keymap.set("n", lhs, rhs, { buffer = buf, silent = true, nowait = true })
    end
    map("q", M.close)
    map("<Esc>", M.close)
    map("h", back)
    map("<BS>", back)
    for _, key in ipairs({ "j", "<Down>" }) do
        map(key, menu and function() move(1) end or "j")
    end
    for _, key in ipairs({ "k", "<Up>" }) do
        map(key, menu and function() move(-1) end or "k")
    end
    map("<CR>", function()
        local current_menu = state.menu
        if not current_menu or #current_menu.items == 0 then return end
        local row = vim.api.nvim_win_get_cursor(win)[1]
        local index = math.max(1, math.min(#current_menu.items, row - menu_start + 1))
        if current_menu.key == "generation" then
            M.open("generation", current_menu.items[index].id)
        else
            M.open(current_menu.items[index].id)
        end
    end)
    local row = 1
    if menu and #menu.items > 0 then
        local selected = math.max(1, math.min(#menu.items, state.selections[menu.key]))
        state.selections[menu.key] = selected
        row = menu_start + selected - 1
    end
    vim.api.nvim_win_set_cursor(win, { row, 0 })
    vim.cmd("stopinsert")
end

function M.setup()
    highlights()
    local group = vim.api.nvim_create_augroup("DevKitHelp", { clear = true })
    vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = highlights })
    vim.api.nvim_create_autocmd("VimResized", {
        group = group,
        callback = function()
            if state.win and vim.api.nvim_win_is_valid(state.win) then
                vim.api.nvim_win_set_config(state.win, geometry())
            end
        end,
    })
    vim.api.nvim_create_autocmd("User", {
        group = group, pattern = "DevKitGeneratorsChanged",
        callback = function()
            if state.section == "generation" and state.win and vim.api.nvim_win_is_valid(state.win) then
                local current = vim.api.nvim_get_current_win()
                M.open("generation", state.category)
                if vim.api.nvim_win_is_valid(current) then vim.api.nvim_set_current_win(current) end
            end
        end,
    })
    vim.api.nvim_create_user_command("DevKitHelp", function() M.open() end,
        { desc = "Справка Neovim Developer Kit" })
    for _, section in ipairs(sections) do
        local id = section.id
        vim.api.nvim_create_user_command(section.command, function() M.open(id) end,
            { desc = "DevKitHelp: " .. section.title })
    end
    initialized = true
end

return M
