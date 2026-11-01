-- Parse options for :CreateCpp* commands.
local M = {}

local function fail(message)
    return nil, message
end

local function take_value(args, index, option)
    local value = args[index + 1]
    if not value or value:sub(1, 1) == "-" then
        return nil, "После " .. option .. " требуется значение"
    end
    return value
end

function M.parse(args, kind)
    local opts = {
        name = nil,
        layout = nil,
        header = false,
        source = false,
        header_path = nil,
        source_path = nil,
        shared_path = nil,
        subdir = nil,
        explicit_selection = false,
        help = false,
    }

    local index = 1
    while index <= #args do
        local arg = args[index]

        if arg == "--help" then
            opts.help = true
        elseif arg == "-n" or arg == "--name" then
            local value, err = take_value(args, index, arg)
            if not value then return fail(err) end
            if opts.name then return fail("Имя -n указано повторно") end
            opts.name = value
            index = index + 1
        elseif arg:match("^%-%-name=") then
            if opts.name then return fail("Имя -n указано повторно") end
            opts.name = arg:sub(#"--name=" + 1)
        elseif arg == "--split" or arg == "--together" then
            local new_layout = arg == "--split" and "split" or "together"
            if opts.layout and opts.layout ~= new_layout then
                return fail("Нельзя одновременно использовать --split и --together")
            end
            opts.layout = new_layout
        elseif arg == "--subdir" then
            local value, err = take_value(args, index, arg)
            if not value then return fail(err) end
            if opts.subdir then return fail("--subdir указан повторно") end
            opts.subdir = value
            index = index + 1
        elseif arg:match("^%-%-subdir=") then
            if opts.subdir then return fail("--subdir указан повторно") end
            opts.subdir = arg:sub(#"--subdir=" + 1)
        elseif arg == "-h" or arg == "--header" or arg == "-s" or arg == "--source" or arg == "-hs" then
            if opts.shared_path and arg ~= "-hs" then
                return fail("Нельзя совмещать -hs с -h или -s")
            end
            if arg == "-hs" then
                if opts.explicit_selection then
                    return fail("-hs нельзя совмещать с -h или -s")
                end
                opts.header, opts.source, opts.explicit_selection = true, true, true
                local value = args[index + 1]
                if value and value:sub(1, 1) ~= "-" then
                    opts.shared_path = value
                    index = index + 1
                end
            else
                if arg == "-h" or arg == "--header" then
                    if opts.header then return fail("-h указан повторно") end
                    opts.header = true
                    local value = args[index + 1]
                    if value and value:sub(1, 1) ~= "-" then
                        opts.header_path = value
                        index = index + 1
                    end
                else
                    if opts.source then return fail("-s указан повторно") end
                    opts.source = true
                    local value = args[index + 1]
                    if value and value:sub(1, 1) ~= "-" then
                        opts.source_path = value
                        index = index + 1
                    end
                end
                opts.explicit_selection = true
            end
        else
            return fail("Неизвестный аргумент: " .. arg .. " (см. --help)")
        end
        index = index + 1
    end

    if opts.help then return opts end
    if not opts.name or opts.name == "" then
        return fail("Укажи имя: -n Player")
    end
    if not opts.name:match("^[A-Za-z_][A-Za-z0-9_]*$") then
        return fail("Имя должно быть идентификатором C++: латинские буквы, цифры, _")
    end

    if not opts.explicit_selection then
        opts.header = kind ~= "source" and kind ~= "test"
        opts.source = kind == "class" or kind == "source" or kind == "test"
    end

    if (kind == "enum" or kind == "header" or kind == "interface") and opts.source then
        return fail("Для этого типа доступен только заголовочный файл (-h)")
    end
    if (kind == "source" or kind == "test") and opts.header then
        return fail("Для этого типа доступен только исходный файл (-s)")
    end

    if opts.shared_path and (opts.header_path or opts.source_path) then
        return fail("-hs с общим путём нельзя совмещать с отдельными путями")
    end

    return opts
end

return M
