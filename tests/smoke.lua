-- Minimal Neovim API shim for smoke-testing generator behavior with plain Lua 5.4.
-- Run with a Lua interpreter; no actual plugins are required.
local repo = assert(os.getenv("NVIM_GEN_REPO"), "NVIM_GEN_REPO required")
local temp = assert(os.getenv("NVIM_GEN_TEST_ROOT"), "NVIM_GEN_TEST_ROOT required")
package.path = repo .. "/lua/?.lua;" .. repo .. "/lua/?/init.lua;" .. package.path

local commands, notifications, opened = {}, {}, {}
local cwd = temp
local function exists(path)
    local handle = io.open(path, "rb")
    if handle then handle:close(); return true end
    return false
end
local function mkdir(dir)
    local result = os.execute("mkdir -p '" .. dir:gsub("'", "'\\''") .. "'")
    return result and 1 or 0
end
local function readfile(path)
    local file = assert(io.open(path, "rb"))
    local lines = {}
    for line in file:lines() do table.insert(lines, line) end
    file:close()
    return lines
end

vim = {
    api = {
        nvim_create_user_command = function(name, callback) commands[name] = callback end,
        nvim_get_commands = function() return commands end,
        nvim_exec_autocmds = function() end,
    },
    notify = function(message, level)
        table.insert(notifications, { message = message, level = level })
    end,
    log = { levels = { ERROR = 1, WARN = 2, INFO = 3 } },
    fn = {
        getcwd = function() return cwd end,
        filereadable = function(file) return exists(file) and 1 or 0 end,
        readfile = readfile,
        fnamemodify = function(path, flag)
            assert(flag == ":h")
            return path:match("^(.*)/[^/]+$") or "."
        end,
        mkdir = mkdir,
        isdirectory = function(dir)
            return os.execute("test -d '" .. dir .. "'") and 1 or 0
        end,
        has = function() return 0 end,
        fnameescape = function(path) return path end,
    },
    uv = {
        fs_stat = function(file) return exists(file) and {} or nil end,
        fs_realpath = function(file) return file end,
        fs_open = function(file, mode)
            assert(mode == "wx")
            if exists(file) then return nil, "already exists" end
            return io.open(file, "wb")
        end,
        fs_write = function(file, data)
            local ok, err = file:write(data)
            if not ok then return nil, err end
            return #data
        end,
        fs_close = function(file) return file:close() end,
        fs_unlink = function(file) return os.remove(file) end,
    },
    bo = { modified = false },
    cmd = function(s) table.insert(opened, s) end,
    list_extend = function(a, b)
        for _, v in ipairs(b) do table.insert(a, v) end
    end,
    deepcopy = function(a)
        local result = {}
        for k, v in pairs(a) do
            result[k] = type(v) == "table" and vim.deepcopy(v) or v
        end
        return result
    end,
    deep_equal = function(a, b)
        if type(a) ~= type(b) then return false end
        if type(a) ~= "table" then return a == b end
        for key, value in pairs(a) do if not vim.deep_equal(value, b[key]) then return false end end
        for key in pairs(b) do if a[key] == nil then return false end end
        return true
    end,
    json = {
        decode = function(s)
            if not s:match('^%s*{') then error('invalid JSON') end
            return {
                cpp = {
                    layout = s:match('"layout"%s*:%s*"([^"]+)"'),
                    paths = {
                        header = s:match('"header"%s*:%s*"([^"]+)"') or 'include',
                        source = s:match('"source"%s*:%s*"([^"]+)"') or 'src',
                    },
                },
            }
        end,
    },
}

require("generators").setup()

-- Exactly two generating commands; the remaining commands are help/root utilities.
for _, suffix in ipairs({ "Class", "Struct", "Enum", "Header", "Source", "Interface", "Test" }) do
    assert(not commands["CreateCpp" .. suffix], "removed command was registered: " .. suffix)
end
for command in pairs(commands) do
    if command:match("^CreateCpp") then assert(command == "CreateCpp") end
end

-- Public help aliases and the command list must remain callable.
local output = {}
local original_print = print
print = function(message) table.insert(output, message) end
commands.CreateHelp({})
local help_section
package.loaded["devkit.help"] = { open = function(section) help_section = section end }
commands.GeneratorHelp({})
package.loaded["devkit.help"] = nil
commands.GeneratorList({})
commands.CreateRoot({})
print = original_print
assert(help_section == "generation", "GeneratorHelp must open the generation section")
assert(output[1]:find(":CreateCpp", 1, true) and output[1]:find("--test", 1, true))
local listed = {}
for command in output[2]:gmatch("[^\n]+") do
    assert(commands[command], "listed command is not registered: " .. command)
    listed[command] = true
end
for command in pairs(commands) do assert(listed[command], "command is not listed: " .. command) end
assert(output[3]:find(temp, 1, true), "CreateRoot must show the captured project root")

local function run(command, ...)
    local previous = #notifications
    assert(commands[command], "missing command: " .. command)
    commands[command]({ fargs = { ... } })
    return notifications[#notifications], #notifications ~= previous
end
local function content(filename)
    local file = assert(io.open(temp .. "/" .. filename, "rb"), "missing " .. filename)
    local result = file:read("*a")
    file:close()
    return result
end

-- Together: explicit base creates a pair.
run("CreateCpp", "-c", "-n", "Player", "-p", "Engine/")
assert(content("Engine/Player.hpp"):find("class Player", 1, true))
assert(content("Engine/Player.cpp"):find('#include "Player.hpp"', 1, true))

-- --split + --subdir: maintains hierarchy.
run("CreateCpp", "-c", "-n", "Renderer", "--split", "--subdir", "Graphics/")
assert(content("include/Graphics/Renderer.hpp"))
assert(content("src/Graphics/Renderer.cpp"):find('#include "../../include/Graphics/Renderer.hpp"', 1, true))

-- Only one side, explicit root, and arbitrary directories.
run("CreateCpp", "-c", "-n", "HeaderOnly", "-ho", "-p", ".")
assert(content("HeaderOnly.hpp"))
assert(not exists(temp .. "/HeaderOnly.cpp"))
run("CreateCpp", "-c", "-n", "ImplementationOnly", "-so", "-p", "src/custom/")
assert(content("src/custom/ImplementationOnly.cpp"))
assert(not exists(temp .. "/src/custom/ImplementationOnly.hpp"))

-- Project JSON (stubbed decode): split layout.
local cfg = assert(io.open(temp .. "/.nvim-generator.json", "wb"))
cfg:write('{"cpp":{"layout":"split","paths":{"header":"api","source":"implementation"}}}')
cfg:close()
run("CreateCpp", "-c", "-n", "FromConfig")
assert(content("api/FromConfig.hpp"))
assert(content("implementation/FromConfig.cpp"))

-- Explicit together overrides project layout split.
run("CreateCpp", "-c", "-n", "AtRoot", "-tg", "-p", ".")
assert(content("AtRoot.hpp"))
assert(content("AtRoot.cpp"))

-- Configured distinct header/source roots keep relative includes correct.
cfg = assert(io.open(temp .. "/.nvim-generator.json", "wb"))
cfg:write('{"cpp":{"layout":"split","paths":{"header":"vendor/inc","source":"engine/code"}}}')
cfg:close()
run("CreateCpp", "-c", "-n", "Different")
assert(content("vendor/inc/Different.hpp"))
assert(content("engine/code/Different.cpp"):find('../../vendor/inc/Different.hpp', 1, true))
cfg = assert(io.open(temp .. "/.nvim-generator.json", "wb"))
cfg:write('{"cpp":{"layout":"split","paths":{"header":"api","source":"implementation"}}}')
cfg:close()

-- Other types use the same public command.
run("CreateCpp", "-s", "-n", "Vec2", "-tg", "-p", "Math/")
assert(content("Math/Vec2.hpp"):find("struct Vec2", 1, true))
run("CreateCpp", "-e", "-n", "State")
assert(content("api/State.hpp"):find("enum class State", 1, true))
run("CreateCpp", "-i", "-n", "IWorld")
assert(content("api/IWorld.hpp"):find("virtual ~IWorld()", 1, true))
run("CreateCpp", "--header", "-n", "Common")
assert(content("api/Common.hpp"):find("#pragma once", 1, true))
run("CreateCpp", "--source", "-n", "Utilities")
assert(content("implementation/Utilities.cpp"))
run("CreateCpp", "--test", "-n", "World")
assert(content("implementation/WorldTest.cpp"):find("TEST(WorldTest", 1, true))

-- Files can't be overwritten.
local original = content("AtRoot.hpp")
local message = run("CreateCpp", "-c", "-n", "AtRoot", "-tg", "-p", ".")
assert(message and message.level == vim.log.levels.ERROR)
assert(content("AtRoot.hpp") == original)

-- Paths outside of project are forbidden.
message = run("CreateCpp", "-c", "-n", "Bad", "-p", "../outside")
assert(message and message.level == vim.log.levels.ERROR)
assert(not exists(temp .. "/../outside/Bad.hpp"))

-- --split and --together conflict; unknown args rejected.
message = run("CreateCpp", "-c", "-n", "Bad", "--split", "--together")
assert(message and message.level == vim.log.levels.ERROR)

-- Root remains captured despite shell cwd changes.
cwd = temp .. "/Engine"
run("CreateCpp", "-c", "-n", "RootFixed", "-tg", "-p", ".")
assert(content("RootFixed.hpp"))
assert(not exists(temp .. "/Engine/RootFixed.hpp"))

print("PASS: generator smoke test")
