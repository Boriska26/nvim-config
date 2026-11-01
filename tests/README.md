# Проверки конфигурации

Команды ниже запускаются из корня репозитория на Linux. Проверки полной
конфигурации требуют Neovim 0.12.6 и уже установленных плагинов из
`nvim-pack-lock.json`. На первом запуске `vim.pack.add` устанавливает отсутствующие
плагины, поэтому без них потребуется доступ к сети.

## Синтаксис Lua

Если установлен `luac`:

```bash
rg --files -g '*.lua' -0 | xargs -0 -n 1 luac -p
```

Проверка синтаксиса движком Lua самого Neovim, без загрузки плагинов:

```bash
nvim --headless -u NONE -i NONE \
  '+lua for _, path in ipairs(vim.fn.glob("**/*.lua", false, true)) do assert(loadfile(path)) end; print("PASS: Lua syntax")' \
  '+qa!'
```

## Smoke-тест генераторов без плагинов

Нужен Lua 5.4. Тест создаёт файлы только во временном каталоге:

```bash
test_root=$(mktemp -d)
NVIM_GEN_REPO="$PWD" NVIM_GEN_TEST_ROOT="$test_root" lua tests/smoke.lua
```

Проверяются виды генераторов, режимы together/split, конфигурация проекта,
приоритет явных путей, относительные include, запрет перезаписи и выхода за
корень проекта, сохранение корня при смене каталога, справка и список команд.

## DevKitDoctor: детерминированные тесты

```bash
NVIM_CONFIG_REPO="$PWD" nvim --headless -u NONE -i NONE \
  --cmd 'lua vim.opt.runtimepath:prepend(vim.env.NVIM_CONFIG_REPO)' \
  '+lua dofile(vim.env.NVIM_CONFIG_REPO .. "/tests/doctor.lua")'

NVIM_CONFIG_REPO="$PWD" nvim --headless -u NONE -i NONE \
  --cmd 'lua vim.opt.runtimepath:prepend(vim.env.NVIM_CONFIG_REPO)' \
  '+lua dofile(vim.env.NVIM_CONFIG_REPO .. "/tests/doctor_ui.lua")'
```

Первый тест подменяет платформу и все внешние процессы. Проверяются статусы,
отсутствующие/сломанные инструменты, SDK без runtime-путей в выводе, ошибки
запуска, тайм-ауты и зависшие процессы, лимит двух процессов, отмена, запасной
компилятор, MSVC/Developer Prompt, Windows PowerShell, RU/EN и отсутствие утечки
сырых stdout/stderr. Windows здесь **моделируется**, это не проверка на реальной ОС.

Второй тест использует настоящий Neovim UI и фиктивные процессы. Он проверяет
команды, `:DevKitLang`, обновление языка без повторных процессов, прокрутку,
подробности, рекомендации, повторный запуск, маленькое окно, q/Esc/внешнее
закрытие и поздние callbacks. На диске и в изменённом буфере сохраняются исходные
данные; диагностикой новые файлы не создаются. Исходный файл теста заранее
создаётся только в отдельном временном каталоге.

Реальное окружение проверяется отдельно через `:DevKitDoctor` с обычным init.lua.
Результаты зависят от машины; предупреждения об отсутствующих инструментах
не означают провал автоматических тестов. Команды внешних проверок только
читают версии/состояние и имеют тайм-аут; установка и запуск служб запрещены.

## C++/C#: интеграционные тесты генераторов

Только Neovim 0.12.6, без плагинов, серверов LSP и загрузки пакетов.
Запускай с `-u NONE`: тест регистрирует команды, меняет cwd и создаёт файлы
в отдельном временном проекте.

```bash
test_root=$(mktemp -d)
NVIM_CONFIG_REPO="$PWD" NVIM_GENERATOR_TEST_ROOT="$test_root" \
nvim --headless -u NONE -i NONE \
  --cmd 'lua vim.opt.runtimepath:prepend(vim.env.NVIM_CONFIG_REPO)' \
  '+lua dofile(vim.env.NVIM_CONFIG_REPO .. "/tests/generators_integration.lua")'
```

Проверяются все алиасы флагов, ошибки CLI, типы C++/C#, размещение файлов,
приоритет JSON и параметров, namespace из `.csproj`, допустимость модификаторов,
защита от перезаписи и symlink-выхода, откат после ошибки записи,
фиксированный корень после `:cd` и повторного setup, отсутствие удалённых Ex-команд
и работу всех семи типов через `:CreateCpp`, включая GoogleTest (`--test`).
Примеры метаданных отдельно разбираются настоящим парсером.

При установленных .NET SDK (C# 11+) и `g++` можно скомпилировать оставленные
тестом шаблоны. Скрипт не запускает MSBuild/restore и ничего не скачивает:

```bash
python3 tests/compile_generators.py "$test_root"
```

Проверяются все созданные `.cs`, включая матрицу допустимых комбинаций
модификаторов, и C++ class/struct/enum/abstract interface с относительными include.
При установленных заголовках GoogleTest также компилируются три тестовых шаблона:
обычный, с размещением и расширением из JSON и созданный через `:CreateCpp --test`.
Если компилятор не установлен, соответствующая часть сообщает `SKIP`.
Ошибка компилятора приводит к ненулевому коду завершения; `PASS` означает
успешную компиляцию, `SKIP` — отсутствие соответствующего компилятора.

## DevOps: файлы, CLI, безопасность и RU/EN

```bash
devops_root=$(mktemp -d)
NVIM_CONFIG_REPO="$PWD" NVIM_DEVOPS_TEST_ROOT="$devops_root" \
nvim --headless -u NONE -i NONE \
  --cmd 'lua vim.opt.runtimepath:prepend(vim.env.NVIM_CONFIG_REPO)' \
  '+lua dofile(vim.env.NVIM_CONFIG_REPO .. "/tests/devops_integration.lua")'
```

Проверяются байты всех девяти шаблонов, обе формы каждого флага, стандартные и
пользовательские имена, расширения без дублирования, вложенные каталоги, `-p .`,
ошибки CLI, JSON-конфигурация, UTF-8/LF, отказ от перезаписи и выхода через symlink.
Отдельно проверены все девять типов через настоящую Ex-команду, открытие файла,
сохранность изменённого буфера, cwd и корня после `:cd`, отсутствие исполняемых
прав и вызовов запуска процессов. RU/EN проверяются для справки, метаданных,
уведомлений и общих ошибок. Язык задаётся через `vim.g.devkit_language`.

Без запуска контейнеров, служб и созданных скриптов можно дополнительно проверить
синтаксис оставленных шаблонов:

```bash
NVIM_DEVOPS_TEST_ROOT="$devops_root" nvim --headless -u NONE -i NONE \
  '+luafile tests/devops_syntax.lua'
```

Bash проверяется через `bash -n`; YAML, Dockerfile, Nginx и INI — доступными
Tree-sitter парсерами. Это проверка грамматики, а не Docker/GitLab/systemd schema
или готовности к развёртыванию. При наличии `pwsh` вызывается только AST Parser,
не сам скрипт. Отсутствующие инструменты/парсеры помечаются `SKIP`.
Docker, Nginx и службы systemd не запускаются; заполнители остаются для пользователя.

## Загрузка полной конфигурации и интеграционный smoke-тест

Запускай в отдельном процессе Neovim: тест закрывает окна и запускает оболочки.
Он проверяет повторное использование буфера и процесса терминала, русские
сочетания, единственное окно, очистку после `exit` в видимом и скрытом терминале,
а также выбор Roslyn для форматирования C# при сохранении. Сам сервер Roslyn
для теста не требуется: его ответы подменяются только на время проверки.

```bash
repo="$PWD"
test_root=$(mktemp -d)
NVIM_CONFIG_REPO="$repo" \
XDG_STATE_HOME="$test_root/state" \
XDG_CACHE_HOME="$test_root/cache" \
NVIM_LOG_FILE="$test_root/nvim.log" \
nvim --headless -i NONE \
  --cmd 'lua vim.opt.runtimepath:prepend(vim.env.NVIM_CONFIG_REPO)' \
  -u "$repo/init.lua" \
  '+lua dofile(vim.env.NVIM_CONFIG_REPO .. "/tests/config_smoke.lua")'
```

Успех: сообщение `PASS` и код завершения 0. Интеграционный smoke-тест при
ошибке завершается с ненулевым кодом. Данные плагинов берутся из обычного
каталога Neovim; кэш, журнал и состояние этой проверки вынесены в `/tmp`.

## Smoke-тест встроенной справки

Запуск без плагинов (тест блокирует их загрузку, чтобы проверить независимость
справки). Проверяются все девять команд справки и команды генератора, выбор
разделов клавишами, возврат в меню, повторное открытие, q/Esc, очистка буферов,
внешнее закрытие окна, изменение размера и сохранность глобальных сочетаний:

```bash
NVIM_CONFIG_REPO="$PWD" nvim --headless -u NONE -i NONE \
  --cmd 'lua vim.opt.runtimepath:prepend(vim.env.NVIM_CONFIG_REPO)' \
  '+lua dofile(vim.env.NVIM_CONFIG_REPO .. "/tests/help_smoke.lua")'
```

Для проверки с полной конфигурацией используй команду из предыдущего раздела,
заменив `tests/config_smoke.lua` на `tests/help_smoke.lua`. Успех — сообщение
`PASS` и код 0; ошибка завершает тест с ненулевым кодом.

## Реестр генераторов и вложенное меню Generation

```bash
NVIM_CONFIG_REPO="$PWD" nvim --headless -u NONE -i NONE \
  --cmd 'lua vim.opt.runtimepath:prepend(vim.env.NVIM_CONFIG_REPO)' \
  '+lua dofile(vim.env.NVIM_CONFIG_REPO .. "/tests/generator_catalog_smoke.lua")'
```

Тест проверяет пустой реестр, отсутствие пустых категорий, обязательные
метаданные, регистрацию настоящей Ex-команды вместе с обработчиком,
появление новых категорий в уже открытом меню, повторную регистрацию,
удаление последнего генератора и возврат с исчезнувшей страницы.
Временные команды дополнительных категорий используются только как тестовые заглушки,
файлы не создают и удаляются после проверки. Отдельно проверяется исключение
внешне удалённых команд из справки и `GeneratorList`.

`tests/help_smoke.lua` проверяет переходы `DevKitHelp → Generation → C++ / C# / DevOps`,
возврат на каждый уровень через Backspace и вывод метаданных всех команд.
Примеры C++, C# и DevOps из реестра проверяются настоящим парсером аргументов.
Оба теста можно запускать и с полной конфигурацией, заменив путь тестового
скрипта в команде из раздела интеграционного smoke-теста.

## Ручная проверка генератора в Neovim

```bash
repo="$PWD"
test_root=$(mktemp -d)
(
  cd "$test_root" || exit 1
  NVIM_CONFIG_REPO="$repo" nvim --headless -u NONE -i NONE \
    --cmd 'lua vim.opt.runtimepath:prepend(vim.env.NVIM_CONFIG_REPO)' \
    '+lua require("generators").setup()' \
    '+CreateCpp -c -n Player -p .' \
    '+GeneratorList' \
    '+qa!'
  ls -la
)
```

`Player.hpp` и `Player.cpp` должны появиться в этом каталоге. Повторный вызов
той же команды должен отказать в перезаписи файлов. В Windows можно запускать
`tests/config_smoke.lua` через `:luafile` в отдельном Neovim с полной
конфигурацией; приведённые shell-команды и тест с Lua shim рассчитаны на Linux.
