-- Content has no plugin imports. Shared keymaps and generator metadata are read lazily.
return {
    {
        id = "generation", title = "Generation", command = "GeneratorHelp",
        generator = true,
    },
    {
        id = "windows", title = "Windows", command = "WindowHelp",
        dependencies = { { label = "nvim-tree", command = "NvimTreeToggle" },
            { label = "Bufferline", command = "BufferLineCycleNext" } },
        text = [[
Окна показывают буферы. Bufferline отображает буферы, исключая терминалы.
N  <C-w>h/j/k/l      Перейти в соседнее окно
N  <C-w>w            Следующее окно
N  <C-w>=            Выровнять размеры окон
Ex :split / :vsplit  Горизонтальное / вертикальное разделение
Ex :close            Закрыть окно
Ex :bdelete          Удалить буфер (изменённый файл сначала сохранить)
Ex :NvimTreeToggle   Дерево файлов шириной 35 колонок
N  g?                Локальная справка в окне nvim-tree
Пример: :vsplit README.md, затем <C-w>h для перехода в левое окно.
]],
    },
    {
        id = "search", title = "Search", command = "SearchHelp",
        dependencies = { { label = "Telescope", command = "Telescope" },
            { label = "ripgrep (live_grep)", executable = "rg" } },
        text = [[
Ex :Telescope find_files / live_grep / buffers / lsp_document_symbols
Telescope (INSERT): ввод сужает список; <C-n>/<C-p> выбирают, Enter открывает.
N  /текст<Enter>      Поиск вперёд в текущем файле
N  ?текст<Enter>      Поиск назад
N  n / N             Следующее / предыдущее совпадение
Поиск игнорирует регистр, пока запрос не содержит заглавные буквы (smartcase).
Пример: <Space>ff, ввести init.lua, Enter; <Space>fg ищет текст проекта.
Поиск символов документа требует подключённого LSP; live_grep требует rg.
]],
    },
    {
        id = "editing", title = "Editing", command = "EditingHelp",
        text = [[
N  i / a             Ввод перед / после курсора
I  <Esc>             Вернуться в NORMAL
N  v / V             Выделять символы / строки (VISUAL)
N  u / <C-r>         Отменить / повторить изменение
N/V y / d / p        Копировать / удалить / вставить
Ex :write / :wq      Сохранить / сохранить и выйти
Используется системный буфер обмена unnamedplus (нужен clipboard provider).
Отступ: 4 пробела, expandtab; автоматические отступы smartindent.
В NORMAL/VISUAL работает русский langmap; в INSERT русский текст сохраняется.
После Ж команды Ex вводятся латиницей. <leader> — пробел.
Пример: V, выделить строки, <Space>j, затем <C-s>.
]],
    },
    {
        id = "lsp", title = "LSP & Completion", command = "LspHelp",
        dependencies = { { label = "Mason", command = "Mason" },
            { label = "Roslyn", module = "roslyn" }, { label = "nvim-cmp", module = "cmp" },
            { label = "lsp_signature", module = "lsp_signature" } },
        text = [[
Roslyn обслуживает C#. Сервер нужно отдельно установить через :Mason.
При сохранении *.cs форматирует только подключённый Roslyn, синхронно, до 3 с.
Без Roslyn сохранение работает без форматирования. Отдельного C++ LSP здесь нет.
Диагностика: текст, знаки, подчёркивание; обновление в INSERT отключено.
Автодополнение: nvim_lsp, path, buffer; встроенные snippets Neovim.
I  <Up>/<Down>       Выбор в меню дополнения (стандартный preset nvim-cmp)
I  <C-y>             Подтвердить выбранное дополнение
I  <C-e>             Отменить дополнение
Подсказки параметров lsp_signature появляются при подключённом LSP.
Пример: открыть .cs в проекте, gd на символе; <Space>rn для переименования.
В INSERT: <C-Space>, выбрать <C-n>/<C-p>, затем Enter.
]],
        completion = true,
    },
    {
        id = "terminal", title = "Terminal", command = "TerminalHelp",
        text = [[
Терминал открывается снизу в окне высотой 24 строки, используя настроенный shell.
Скрытие сохраняет буфер и процесс оболочки. Повторное открытие возвращает их.
Если терминал — единственное окно, переключение оставляет его открытым.
После exit буфер удаляется; следующее открытие запускает новую оболочку.
Ex :terminal         Отдельный встроенный терминал; постоянное окно его не подхватывает
T  exit<Enter>       Завершить оболочку (команда внутри shell)
Пример: <Space>tt, выполнить pwd (Linux) или Get-Location (PowerShell),
затем <Esc><Esc>, <Space>tt — скрыть; ещё <Space>tt — вернуть тот же процесс.
]],
    },
    {
        id = "git", title = "Git", command = "GitHelp",
        dependencies = { { label = "Git", executable = "git" },
            { label = "Lualine", module = "lualine" } },
        text = [[
Lualine показывает branch и diff, когда текущий файл находится в Git-репозитории.
Используются встроенные команды Neovim и системный git.
Ex :!git status --short    Показать статус репозитория
Ex :!git diff             Показать незакоммиченные изменения
Ex :!git log -5 --oneline  Показать последние пять коммитов
Для интерактивной работы открой постоянный терминал через <Space>tt
и выполняй git status или git diff в оболочке, из каталога репозитория.
Пример: :!git diff -- README.md
Специальных Git-сочетаний, команд :Git и Git-плагина в конфигурации нет.
]],
    },
    {
        id = "appearance", title = "Appearance", command = "AppearanceHelp",
        dependencies = { { label = "Tokyo Night", module = "tokyonight" },
            { label = "Lualine", module = "lualine" }, { label = "Bufferline", module = "bufferline" } },
        text = [[
Tokyo Night, стиль night; непрозрачный фон, курсив комментариев и ключевых слов.
Ex :colorscheme tokyonight  Повторно применить настроенную тему
Ex :set number?            Проверить нумерацию строк
Ex :set relativenumber?    Проверить относительные номера
Lualine: mode, branch, diff, filename, diagnostics, filetype, progress, location.
Bufferline: буферы, диагностика LSP, разделители slant; терминалы скрыты.
Treesitter запускается для cs/lua/json/yaml/sh, если установлен парсер.
Подсветка текущей строки и номера, цветные разделители и winbar терминала.
Специальных сочетаний смены темы в конфигурации нет.
Пример: :set relativenumber? показывает текущее значение без изменения настроек.
]],
    },
}
