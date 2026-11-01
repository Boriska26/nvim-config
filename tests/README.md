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

## Ручная проверка генератора в Neovim

```bash
repo="$PWD"
test_root=$(mktemp -d)
(
  cd "$test_root" || exit 1
  NVIM_CONFIG_REPO="$repo" nvim --headless -u NONE -i NONE \
    --cmd 'lua vim.opt.runtimepath:prepend(vim.env.NVIM_CONFIG_REPO)' \
    '+lua require("generators").setup()' \
    '+CreateCppClass -n Player -hs .' \
    '+GeneratorList' \
    '+qa!'
  ls -la
)
```

`Player.hpp` и `Player.cpp` должны появиться в этом каталоге. Повторный вызов
той же команды должен отказать в перезаписи файлов. В Windows можно запускать
`tests/config_smoke.lua` через `:luafile` в отдельном Neovim с полной
конфигурацией; приведённые shell-команды и тест с Lua shim рассчитаны на Linux.
