-- Native Neovim APIs, no plugins. Run with -u NONE (see tests/README.md).
local function run()
    assert(not package.loaded["generators"], "Run this test with -u NONE, not the full config")
    local temp = vim.env.NVIM_GENERATOR_TEST_ROOT or vim.fn.tempname()
    vim.fn.mkdir(temp, "p")
    local service = require("generators.service")
    local parser = require("generators.parser")
    local arguments = require("generators.arguments")
    local count = 0
    local function root(name)
        local directory = temp .. "/" .. name
        vim.fn.mkdir(directory, "p")
        return directory
    end
    local function write(directory, name, text)
        local filename = directory .. "/" .. name
        vim.fn.mkdir(vim.fn.fnamemodify(filename, ":h"), "p")
        vim.fn.writefile(vim.split(text, "\n", { plain = true }), filename)
    end
    local function content(directory, name)
        assert(vim.fn.filereadable(directory .. "/" .. name) == 1, "missing file: " .. name)
        return table.concat(vim.fn.readfile(directory .. "/" .. name), "\n")
    end
    local function generate(directory, language, line)
        local args = type(line) == "table" and line or vim.split(line, "%s+", { trimempty = true })
        count = count + 1
        return service.generate(directory, language, args)
    end
    local function success(directory, language, line)
        local result, err = generate(directory, language, line)
        assert(result, err)
        return result
    end
    local function failure(directory, language, line, fragment)
        local result, err = generate(directory, language, line)
        assert(not result and type(err) == "string", "expected failure: " .. tostring(line))
        if fragment then assert(err:find(fragment, 1, true), err) end
    end

    -- Every short, multicharacter and long flag, including --option=value.
    for _, schema in ipairs({ arguments.cpp, arguments.csharp }) do
        for _, entry in ipairs(schema) do
            for _, flag in ipairs(entry.flags) do
                local args = { flag }
                if entry.takes then args[#args + 1] = "Value" end
                local parsed, err = parser.parse(args, schema)
                assert(parsed and parsed[entry.key] == (entry.takes and "Value" or entry.value or true), err)
                assert(not parser.parse({ flag, flag }, schema), "duplicate flag accepted: " .. flag)
                if entry.takes and flag:sub(1, 2) == "--" then
                    assert(parser.parse({ flag .. "=Value" }, schema)[entry.key] == "Value")
                    assert(not parser.parse({ flag .. "=" }, schema))
                end
                if entry.takes == "required" then assert(not parser.parse({ flag }, schema)) end
                if entry.takes == "optional" then assert(parser.parse({ flag }, schema)[entry.key] == true) end
                count = count + 1
            end
        end
    end
    for _, args in ipairs({ { "-c", "-s" }, { "-ho", "-so" }, { "-b", "-ho" },
        { "-sp", "-tg" }, { "--class=1" }, { "-cn" }, { "--unknown" }, { "positional" } }) do
        assert(not parser.parse(args, arguments.cpp), "invalid C++ arguments accepted")
    end
    for _, args in ipairs({ { "-r", "-rs" }, { "--public", "--internal" },
        { "--file", "--public" }, { "--file", "--internal" }, { "--private" }, { "--protected" } }) do
        assert(not parser.parse(args, arguments.csharp), "invalid C# arguments accepted")
    end
    assert(parser.parse({ "-rs" }, arguments.csharp).kind == "record_struct")
    assert(parser.parse({ "-so" }, arguments.cpp).output == "source")

    local cpp_root = root("cpp")
    for _, case in ipairs({
        { "-c", "Player", "class Player", 2 }, { "-s", "Vec", "struct Vec", 1 },
        { "-e", "State", "enum class State", 1 }, { "-i", "IWorld", "virtual ~IWorld() = 0", 1 },
        { "--header", "Common", "#pragma once", 1 }, { "--source", "Helpers", "// Helpers.cpp", 1 },
        { "--test", "World", "TEST(WorldTest, Placeholder)", 1 },
    }) do
        local result = success(cpp_root, "cpp", { case[1], "-n", case[2] })
        assert(#result.entries == case[4])
        assert(content(cpp_root, case[2] .. (case[1] == "--test" and "Test.cpp" or case[1] == "--source" and ".cpp" or ".hpp")):find(case[3], 1, true))
    end
    success(cpp_root, "cpp", "-c -n HeaderOnly -ho -p Engine")
    assert(content(cpp_root, "Engine/HeaderOnly.hpp"))
    assert(vim.fn.filereadable(cpp_root .. "/Engine/HeaderOnly.cpp") == 0)
    success(cpp_root, "cpp", "-c -n SourceOnly -so -p Engine")
    assert(content(cpp_root, "Engine/SourceOnly.cpp"):find('#include "SourceOnly.hpp"', 1, true))
    success(cpp_root, "cpp", { "-c", "-n", "Spaced", "-p", "Folder With Spaces" })
    assert(content(cpp_root, "Folder With Spaces/Spaced.hpp"))
    success(cpp_root, "cpp", "-s -n BothStruct -b -sp -p Engine --subdir Math")
    assert(content(cpp_root, "Engine/include/Math/BothStruct.hpp"))
    assert(content(cpp_root, "Engine/src/Math/BothStruct.cpp"):find("../../include/Math/BothStruct.hpp", 1, true))
    for _, args in ipairs({ "-n MissingType", "-c", "-e -n E -so", "-i -n I -b",
        "--header -n H -b", "--source -n S -ho", "--test -n T -ho", "--test -n T -b",
        "-c -n OldFlags -hs Engine", "-c -n OldHeader -h Engine", "-c -n Bad --subdir Dir -tg",
        "-c -n class", "-c -n Bad -p ../escape", "-c -n Bad -p /tmp/absolute",
        "-c -n Bad -p C:/absolute", "-c -n CON" }) do failure(cpp_root, "cpp", args) end
    local before = content(cpp_root, "Player.hpp")
    failure(cpp_root, "cpp", "-c -n Player", "существует")
    assert(content(cpp_root, "Player.hpp") == before)
    write(cpp_root, "Collision.cpp", "existing source")
    failure(cpp_root, "cpp", "-c -n Collision", "существует")
    assert(vim.fn.filereadable(cpp_root .. "/Collision.hpp") == 0, "preflight wrote half a pair")

    local config_root = root("config")
    write(config_root, ".nvim-generator.json", [[{"cpp":{"layout":"split","paths":{"header":"api","source":"impl"},"extensions":{"header":".hh","source":".cc"}},"csharp":{"defaultAccess":"internal"}}]])
    success(config_root, "cpp", "--class --name=Config --path=Engine")
    assert(content(config_root, "Engine/api/Config.hh"))
    assert(content(config_root, "Engine/impl/Config.cc"):find("../api/Config.hh", 1, true))
    success(config_root, "cpp", "-c -n Together -tg -p Explicit")
    assert(content(config_root, "Explicit/Together.hh") and content(config_root, "Explicit/Together.cc"))
    success(config_root, "cpp", "--test -n Configured -sp -p Tests --subdir Unit -so")
    assert(content(config_root, "Tests/impl/Unit/ConfiguredTest.cc"):find("#include <gtest/gtest.h>", 1, true))
    assert(vim.fn.filereadable(config_root .. "/Tests/api/Unit/ConfiguredTest.hh") == 0)
    success(config_root, "csharp", "-c -n Internal")
    success(config_root, "csharp", "-c -n Public --public")
    success(config_root, "csharp", "-c -n Local --file")
    assert(content(config_root, "Internal.cs"):find("internal class Internal", 1, true))
    assert(content(config_root, "Public.cs"):find("public class Public", 1, true))
    assert(content(config_root, "Local.cs"):find("file class Local", 1, true))
    for _, document in ipairs({ "bad JSON", "[]", "null", '{"cpp":null}', '{"cpp":[]}',
        '{"cpp":{"layout":"bad"}}', '{"cpp":{"paths":[]}}', '{"cpp":{"paths":{"header":"../bad"}}}',
        '{"cpp":{"extensions":{"source":"cpp"}}}', '{"cpp":{"extensions":{"header":1}}}',
        '{"csharp":[]}', '{"csharp":{"defaultAccess":"private"}}' }) do
        write(config_root, ".nvim-generator.json", document)
        failure(config_root, "cpp", "-c -n NeverWritten")
        assert(success(config_root, "cpp", "--help").help, "help must work with invalid project config")
    end
    write(config_root, ".nvim-generator.json", "{}")
    success(config_root, "cpp", "-e -n EmptyConfig")
    local config_dir = root("config-is-directory")
    vim.fn.mkdir(config_dir .. "/.nvim-generator.json", "p")
    failure(config_dir, "cpp", "-c -n NotWritten", "Конфигурация")
    local cs_root = root("csharp")
    for _, case in ipairs({ { "-c", "Service", "class" }, { "-i", "IService", "interface" },
        { "-e", "Kind", "enum" }, { "-s", "Vector", "struct" },
        { "-r", "Dto", "record class" }, { "-rs", "Point", "record struct" } }) do
        success(cs_root, "csharp", { case[1], "-n", case[2] })
        local text = content(cs_root, case[2] .. ".cs")
        assert(text:find("public " .. case[3] .. " " .. case[2], 1, true))
        assert(not text:find("namespace", 1, true) and not text:find("using", 1, true))
    end
    for _, args in ipairs({ "-c -n A --readonly", "-r -n A --static", "-rs -n A --ref",
        "-i -n A --abstract", "-s -n A --sealed", "-e -n A --partial", "-c -n A --abstract --sealed",
        "-c -n A --static --abstract", "-c -n A --static --sealed", "-c -n class", "-c -n __arglist", "-n MissingType" }) do
        failure(cs_root, "csharp", args)
    end
    success(cs_root, "csharp", "-c -n @class")
    assert(content(cs_root, "class.cs"):find("class @class", 1, true))
    failure(cs_root, "csharp", "-c -n Service", "существует")

    local ns_root = root("namespace")
    write(ns_root, "App/App.csproj", '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><RootNamespace>Company&#46;App</RootNamespace></PropertyGroup></Project>')
    success(ns_root, "csharp", "-c -n PhotoService -p App/Services/Photos")
    assert(content(ns_root, "App/Services/Photos/PhotoService.cs"):find("namespace Company.App.Services.Photos;", 1, true))
    write(ns_root, "App/Nested/Other.csproj", "<Project />")
    success(ns_root, "csharp", "-i -n IFoo -p App/Nested/Interfaces")
    assert(content(ns_root, "App/Nested/Interfaces/IFoo.cs"):find("namespace Other.Interfaces;", 1, true))
    success(ns_root, "csharp", "-c -n Reserved -p App/class")
    assert(content(ns_root, "App/class/Reserved.cs"):find("namespace Company.App.@class;", 1, true))
    failure(ns_root, "csharp", { "-c", "-n", "BadFolder", "-p", "App/Bad Folder" }, "Namespace")
    write(ns_root, "App/Nested/Second.csproj", "<Project />")
    failure(ns_root, "csharp", "-c -n Ambiguous -p App/Nested", "Несколько .csproj")
    for index, xml in ipairs({
        '<Project><PropertyGroup Condition="debug"><RootNamespace>Conditional</RootNamespace></PropertyGroup></Project>',
        '<Project><PropertyGroup><RootNamespace Condition="debug">Conditional</RootNamespace></PropertyGroup></Project>',
        '<Project><PropertyGroup><RootNamespace>$(ProjectName)</RootNamespace></PropertyGroup></Project>',
        '<Project><PropertyGroup><RootNamespace>A</RootNamespace><RootNamespace>B</RootNamespace></PropertyGroup></Project>',
        '<Project><PropertyGroup>', '<Project><Import Project="Custom.props" /></Project>',
    }) do
        local directory = root("bad-project-" .. index)
        write(directory, "Bad.csproj", xml)
        failure(directory, "csharp", "-c -n NotWritten")
        assert(vim.fn.filereadable(directory .. "/NotWritten.cs") == 0)
    end
    local empty_ns = root("empty-namespace")
    write(empty_ns, "Empty.csproj", "<Project><PropertyGroup><RootNamespace /></PropertyGroup></Project>")
    success(empty_ns, "csharp", "-c -n Global")
    assert(not content(empty_ns, "Global.cs"):find("namespace", 1, true))
    local imports = root("imported-namespace")
    write(imports, "App.csproj", "<Project />")
    write(imports, "Directory.Build.props", "<Project><PropertyGroup><RootNamespace>Imported</RootNamespace></PropertyGroup></Project>")
    failure(imports, "csharp", "-c -n NotWritten", "Импортируемый")

    -- Real filesystem symlink checks, including missing directories behind a symlink.
    local outside, safe = root("outside"), root("safe")
    assert(vim.uv.fs_symlink(outside, safe .. "/link"))
    failure(safe, "cpp", "-c -n Escaped -p link/new", "symlink")
    assert(vim.fn.isdirectory(outside .. "/new") == 0, "mkdir escaped through a symlink")
    local rollback = root("rollback")
    local original_write, writes = vim.uv.fs_write, 0
    vim.uv.fs_write = function(...)
        writes = writes + 1
        if writes == 2 then return nil, "injected write failure" end
        return original_write(...)
    end
    local ok, err = pcall(failure, rollback, "cpp", "-c -n Rollback", "injected")
    vim.uv.fs_write = original_write
    assert(ok, err)
    assert(vim.fn.filereadable(rollback .. "/Rollback.hpp") == 0 and vim.fn.filereadable(rollback .. "/Rollback.cpp") == 0)

    -- Generate all modifier combinations accepted by validation for an independent csc check.
    local matrix = root("compiler-csharp")
    local modifiers = { "abstract", "sealed", "static", "partial", "readonly", "ref" }
    local serial = 0
    for _, kind in ipairs({ "class", "interface", "enum", "struct", "record", "record_struct" }) do
        for mask = 0, 63 do
            for _, access in ipairs({ "public", "internal", "file" }) do
                serial = serial + 1
                local opts = { kind = kind, name = "Matrix" .. serial, access = access }
                for bit, modifier in ipairs(modifiers) do opts[modifier] = math.floor(mask / 2 ^ (bit - 1)) % 2 == 1 end
                if require("generators.csharp").validate(opts, { defaultAccess = "public" }) then
                    local entry = require("generators.csharp").create(opts, "Generated.Matrix")[1]
                    write(matrix, entry.path, table.concat(entry.lines, "\n"))
                end
            end
        end
    end
    write(cpp_root, "compile.cpp", [[#include "Player.hpp"
#include "Vec.hpp"
#include "State.hpp"
#include "IWorld.hpp"
#include <type_traits>
static_assert(std::is_abstract_v<IWorld>);
]])

    -- Exercise the public generators and every C++ type through CreateCpp.
    local command_root = root("commands")
    vim.fn.chdir(command_root)
    require("generators").setup()
    vim.fn.mkdir(command_root .. "/child", "p")
    vim.fn.chdir(command_root .. "/child")
    require("generators").setup()
    vim.cmd("CreateCpp -c -n Native -p Engine")
    vim.cmd("CreateCSharp -rs -n NativePoint --readonly")
    assert(content(command_root, "Engine/Native.hpp") and content(command_root, "NativePoint.cs"))
    local commands = vim.api.nvim_get_commands({ builtin = false })
    local completion = vim.fn.getcompletion("CreateCpp", "command")
    assert(vim.deep_equal(completion, { "CreateCpp" }), "removed commands remain in Ex completion")
    for _, suffix in ipairs({ "Class", "Struct", "Enum", "Interface", "Header", "Source", "Test" }) do
        local removed = "CreateCpp" .. suffix
        assert(not commands[removed] and vim.fn.exists(":" .. removed) == 0, "removed command exists: " .. removed)
    end
    local main_count = 0
    for _ in ipairs(require("generators.catalog").generators()) do main_count = main_count + 1 end
    assert(main_count == 3, "registry must contain CreateCpp, CreateCSharp and CreateDevOps")
    for _, kind in ipairs({ "class", "struct", "enum", "interface", "header", "source", "test" }) do
        local name = "Native_" .. kind
        vim.cmd("CreateCpp --" .. kind .. " -n " .. name .. " -p Types")
        local source_only = kind == "source" or kind == "test"
        local filename = name .. (kind == "test" and "Test" or "") .. (source_only and ".cpp" or ".hpp")
        local body = content(command_root, "Types/" .. filename)
        if kind == "test" then
            assert(body:find("#include <gtest/gtest.h>", 1, true) and body:find("TEST(" .. name .. "Test", 1, true))
            assert(vim.fn.filereadable(command_root .. "/Types/" .. name .. ".hpp") == 0)
        end
    end
    local flags = commands.CreateCpp.complete
    assert(flags, "CreateCpp must offer argument completion")
    local flag_completion = vim.fn.getcompletion("CreateCpp --t", "cmdline")
    assert(vim.tbl_contains(flag_completion, "--test") and vim.tbl_contains(flag_completion, "--together"))
    local old_completion = vim.fn.getcompletion("CreateCpp -h", "cmdline")
    assert(vim.deep_equal(old_completion, { "-ho" }), "old header flag remains in completion")
    local all_help = vim.api.nvim_exec2("CreateHelp", { output = true }).output
    local listed = vim.api.nvim_exec2("GeneratorList", { output = true }).output
    for _, suffix in ipairs({ "Class", "Struct", "Enum", "Interface", "Header", "Source", "Test" }) do
        local removed = "CreateCpp" .. suffix
        assert(not all_help:find(removed, 1, true) and not listed:find(removed, 1, true))
    end
    assert(all_help:find("--test", 1, true))
    assert(vim.api.nvim_exec2("CreateCpp --help", { output = true }).output:find("--header-only", 1, true))
    assert(vim.api.nvim_exec2("CreateCSharp --help", { output = true }).output:find("--record-struct", 1, true))
    assert(vim.api.nvim_exec2("GeneratorList", { output = true }).output:find("CreateCSharp", 1, true))
    print("PASS: native generator integration (" .. count .. " cases); compiler fixtures: " .. temp)
end
local ok, err = xpcall(run, debug.traceback)
if not ok then vim.api.nvim_err_writeln(err); vim.cmd("cquit 1") else vim.cmd("qa!") end
