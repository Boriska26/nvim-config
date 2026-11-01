local M = {}
local function words(text)
    local result = {}
    for word in text:gmatch("%S+") do result[word] = true end
    return result
end
local cs = words([[abstract as base bool break byte case catch char checked class const continue decimal
default delegate do double else enum event explicit extern false finally fixed float for foreach goto if
implicit in int interface internal is lock long namespace new null object operator out override params
private protected public readonly ref return sbyte sealed short sizeof stackalloc static string struct
switch this throw true try typeof uint ulong unchecked unsafe ushort using virtual void volatile while
__arglist __makeref __reftype __refvalue]])
local cpp = words([[alignas alignof and and_eq asm auto bitand bitor bool break case catch char char8_t
char16_t char32_t class compl concept const consteval constexpr constinit const_cast continue co_await
co_return co_yield decltype default delete do double dynamic_cast else enum explicit export extern false
float for friend goto if inline int long mutable namespace new noexcept not not_eq nullptr operator or
or_eq private protected public register reinterpret_cast requires return short signed sizeof static
static_assert static_cast struct switch template this thread_local throw true try typedef typeid typename
union unsigned using virtual void volatile wchar_t while xor xor_eq]])
function M.cpp(name)
    if type(name) ~= "string" or not name:match("^[A-Za-z_][A-Za-z0-9_]*$") or cpp[name] then
        return nil, "Имя C++ должно быть идентификатором, а не ключевым словом"
    end
    return name
end
function M.csharp(name)
    if type(name) ~= "string" or not name:match("^@?[A-Za-z_][A-Za-z0-9_]*$")
        or (cs[name] and name:sub(1, 1) ~= "@") then
        return nil, "Имя C# должно быть идентификатором; ключевые слова экранируются @"
    end
    -- These contextual words are forbidden as type declaration names.
    local raw = name:gsub("^@", "")
    if name:sub(1, 1) ~= "@" and words("record required file scoped")[raw] then
        return nil, "Экранируй контекстное слово в имени типа: @" .. raw
    end
    return name
end
function M.namespace(value)
    if value == "" then return "" end
    if value:sub(1, 1) == "." or value:sub(-1) == "." or value:find("..", 1, true) then return nil end
    local parts = {}
    for part in value:gmatch("[^.]+") do
        if not part:match("^@?[A-Za-z_][A-Za-z0-9_]*$") then return nil end
        parts[#parts + 1] = cs[part] and "@" .. part or part
    end
    return table.concat(parts, ".")
end
return M
