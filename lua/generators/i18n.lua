-- One shared text layer for generator commands, validation and help.
local M = {}
local messages = {
    generator_error = { "Генератор: %s", "Generator: %s" },
    created = { "Создано: %s", "Created: %s" },
    open_failed = { "Файлы созданы, но не удалось открыть: %s", "Files created, but could not open: %s" },
    root = { "Корень генератора: %s", "Generator root: %s" },
    root_description = { "Показать корень генератора", "Show the captured generator root" },
    help_description = { "Справка по генераторам", "Generator help" },
    list_description = { "Список команд генераторов", "List generator commands" },
    unknown_argument = { "Неизвестный аргумент: %s (см. --help)", "Unknown argument: %s (see --help)" },
    conflicting_arguments = { "Повторные или несовместимые аргументы: %s и %s", "Repeated or incompatible arguments: %s and %s" },
    no_value = { "%s не принимает значение", "%s does not accept a value" },
    value_required = { "После %s требуется значение", "A value is required after %s" },
    empty_value = { "Пустое значение после %s", "Empty value after %s" },
    empty_path = { "Путь должен быть непустой строкой", "Path must be a nonempty string" },
    absolute_path = { "Абсолютные пути не разрешены: %s", "Absolute paths are not allowed: %s" },
    invalid_path = { "Недопустимые символы в пути: %s", "Invalid characters in path: %s" },
    outside_path = { "Выход за пределы проекта запрещён: %s", "Paths outside the project are forbidden: %s" },
    trailing_path = { "Папка не может заканчиваться точкой или пробелом (Windows): %s", "Path components cannot end with a dot or space (Windows): %s" },
    reserved_path = { "Зарезервированное имя Windows: %s", "Reserved Windows name: %s" },
    no_parent = { "Не найден существующий родитель: %s", "No existing parent directory found: %s" },
    symlink_path = { "Каталог выходит за пределы проекта (symlink): %s", "Directory escapes the project (symlink): %s" },
    no_filename = { "Не вычислено имя файла", "Could not determine the filename" },
    duplicate_path = { "Совпадают пути создаваемых файлов: %s", "Generated file paths conflict: %s" },
    exists = { "Файл уже существует: %s", "File already exists: %s" },
    mkdir_failed = { "Не удалось создать безопасный каталог: %s", "Could not create a safe directory: %s" },
    create_failed = { "Не удалось создать %s: %s", "Could not create %s: %s" },
    write_failed = { "Ошибка записи %s: %s", "Could not write %s: %s" },
    config_unreadable = { "Конфигурация недоступна или не является файлом: %s", "Configuration is unreadable or is not a file: %s" },
    invalid_json = { "Некорректный JSON в %s", "Invalid JSON in %s" },
    config_object = { "%s должен быть JSON-объектом", "%s must be a JSON object" },
    config_layout = { "cpp.layout: ожидается split или together", "cpp.layout: expected split or together" },
    config_extension = { "Неправильное расширение cpp.extensions.%s", "Invalid extension cpp.extensions.%s" },
    config_access = { "csharp.defaultAccess: ожидается public или internal", "csharp.defaultAccess: expected public or internal" },
    devops_type = { "Выбери ровно один тип DevOps (см. --help)", "Choose exactly one DevOps file type (see --help)" },
    fixed_name = { "Для %s нельзя использовать -n/--name: имя файла фиксировано", "-n/--name is not allowed for %s: the filename is fixed" },
    filename_only = { "-n/--name: укажи только имя файла, каталог передавай через -p/--path", "-n/--name accepts a filename only; use -p/--path for the directory" },
    filename_stem = { "-n/--name: требуется непустое имя перед расширением %s", "-n/--name requires a nonempty filename before %s" },
    purpose = { "Назначение:", "Purpose:" },
    parameters = { "Параметры:", "Parameters:" },
    no_parameters = { "Нет параметров.", "No parameters." },
    examples = { "Примеры:", "Examples:" },
    generation_hint = { "Ex: команда после ':' из NORMAL. Backspace: категории генераторов.", "Ex: command after ':' in NORMAL. Backspace: generator categories." },
    generation_select = { "Выберите категорию генераторов и нажмите Enter.", "Select a generator category and press Enter." },
    no_generators = { "Зарегистрированных генераторов нет.", "No generators registered." },
    command_count = { "%d команд", "%d commands" },
    help_footer = { " j/k ↑/↓ Enter | h/BS: назад | q/Esc: закрыть ", " j/k ↑/↓ Enter | h/BS: back | q/Esc: close " },
    help_footer_short = { " q/Esc: закрыть | h: назад ", " q/Esc: close | h: back " },
}
function M.language()
    return vim and vim.g and vim.g.devkit_language == "en" and "en" or "ru"
end
function M.pick(ru, en)
    return M.language() == "en" and en or ru
end
function M.get(key, ...)
    local text = assert(messages[key], "Unknown generator translation: " .. key)
    return string.format(M.pick(text[1], text[2]), ...)
end
function M.field(value, key)
    return M.pick(value[key], value[key .. "_en"] or value[key])
end
return M
