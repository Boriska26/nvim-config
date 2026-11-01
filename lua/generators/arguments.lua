-- Flags are exact tokens: -rs and -ho are never split into letters.
local M = {}
local function option(key, flags, description, takes, value, description_en)
    return { key = key, flags = flags, description = description, description_en = description_en, takes = takes, value = value }
end
local common = {
    option("name", { "-n", "--name" }, "Имя типа или файла", "required", nil, "Type or file name"),
    option("path", { "-p", "--path" }, "Базовый каталог относительно корня запуска", "required", nil, "Directory relative to the captured launch root"),
    option("help", { "--help" }, "Справка без создания файлов", nil, nil, "Show help without creating files"),
}
local function schema(options)
    for _, entry in ipairs(common) do options[#options + 1] = entry end
    return options
end
M.cpp = schema({
    option("kind", { "-c", "--class" }, "Класс (.hpp и .cpp)", nil, "class"),
    option("kind", { "-s", "--struct" }, "Структура (.hpp)", nil, "struct"),
    option("kind", { "-e", "--enum" }, "enum class (.hpp)", nil, "enum"),
    option("kind", { "-i", "--interface" }, "Абстрактный интерфейс (.hpp)", nil, "interface"),
    option("kind", { "--header" }, "Обычный заголовок", nil, "header"),
    option("kind", { "--source" }, "Обычный исходник", nil, "source"),
    option("kind", { "--test" }, "GoogleTest: один NAMETest.cpp", nil, "test"),
    option("output", { "-ho", "--header-only" }, "Только заголовок", nil, "header"),
    option("output", { "-so", "--source-only" }, "Только исходник", nil, "source"),
    option("output", { "-b", "--both" }, "Оба файла", nil, "both"),
    option("layout", { "-sp", "--split" }, "Раздельные каталоги header/source", nil, "split"),
    option("layout", { "-tg", "--together" }, "Файлы рядом", nil, "together"),
    option("subdir", { "--subdir" }, "Вложенный каталог при split", "required"),
})
M.csharp = schema({
    option("kind", { "-c", "--class" }, "class", nil, "class"),
    option("kind", { "-i", "--interface" }, "interface", nil, "interface"),
    option("kind", { "-e", "--enum" }, "enum", nil, "enum"),
    option("kind", { "-s", "--struct" }, "struct", nil, "struct"),
    option("kind", { "-r", "--record" }, "record class", nil, "record"),
    option("kind", { "-rs", "--record-struct" }, "record struct", nil, "record_struct"),
    option("access", { "--public" }, "public (по умолчанию)", nil, "public"),
    option("access", { "--internal" }, "internal", nil, "internal"),
    option("access", { "--file" }, "file без public/internal (C# 11+)", nil, "file"),
    option("abstract", { "-a", "--abstract" }, "Абстрактный class или record class"),
    option("sealed", { "--sealed" }, "Запрет наследования class или record class"),
    option("static", { "--static" }, "Статический class"),
    option("partial", { "--partial" }, "Частичный тип (кроме enum)"),
    option("readonly", { "--readonly" }, "readonly struct или record struct"),
    option("ref", { "--ref" }, "ref struct (не record struct)"),
})
M.devops = {}
for _, template in ipairs(require("generators.devops").templates) do
    M.devops[#M.devops + 1] = option("kind", template.flags,
        template.filename .. ": " .. template.description, nil, template.kind,
        template.filename .. ": " .. template.description_en)
end
schema(M.devops)
function M.parameters(options)
    local result = {}
    for _, entry in ipairs(options) do
        local suffix = entry.takes == "required" and " VALUE" or entry.takes == "optional" and " [DIR]" or ""
        result[#result + 1] = { name = table.concat(entry.flags, " / ") .. suffix,
            description = entry.description, description_en = entry.description_en }
    end
    return result
end
function M.complete(options, lead)
    local result = {}
    for _, entry in ipairs(options) do
        for _, flag in ipairs(entry.flags) do
            if flag:sub(1, #lead) == lead then result[#result + 1] = flag end
        end
    end
    return result
end
return M
