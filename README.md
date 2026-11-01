# nvim-config

Личная переносимая конфигурация **Neovim 0.12+** для CachyOS/Linux и Windows. Содержит рабочий `init.lua` (Tokyo Night, nvim-tree, Roslyn, Telescope, Lualine, Bufferline, один терминал, автодополнение), генератор C++ файлов и шпаргалку `nvimhk`.

## Установка

**Сначала сделай резервную копию своей конфигурации.** Git-репозиторий нужно разместить именно в стандартной папке настроек Neovim:

- Linux: `~/.config/nvim`
- Windows: `%LOCALAPPDATA%\nvim` (в PowerShell: `$env:LOCALAPPDATA\nvim`)

Linux (замени URL на адрес **своего** Git-репозитория):

```bash
# Если конфигурация существует, сначала сохрани её:
mv ~/.config/nvim ~/.config/nvim.backup

git clone <URL_ТВОЕГО_REPO> ~/.config/nvim
nvim
```

Если каталога `~/.config/nvim` ещё нет, строка `mv` не нужна. Установи Neovim и Git отдельно; `ripgrep`, `fd`, `dotnet`, компилятор и плагины Treesitter необходимы только для соответствующих функций.

Windows (PowerShell):

```powershell
# Если папка конфигурации уже существует, сначала сделай резервную копию:
Move-Item "$env:LOCALAPPDATA\nvim" "$env:LOCALAPPDATA\nvim.backup"

git clone <URL_ТВОЕГО_REPO> "$env:LOCALAPPDATA\nvim"
nvim
```

На Windows Neovim, Git и .NET SDK устанавливаются отдельно. Если нужен Roslyn, после загрузки конфигурации проверь `:Mason` и наличие подходящего .NET SDK. Если использование GitHub/скачивание расширений на работе ограничено, согласуй установку с администратором.

**Создать свой Git-репозиторий из этого архива:** распаковать, выполнить `git init`, `git add .`, `git commit -m "Initial Neovim config"`, создать пустой удалённый репозиторий и `git remote add origin <URL>`, `git push -u origin main` (при необходимости: `git branch -M main`).

## Генератор C++

Корень генератора — каталог запуска Neovim (`pwd` перед `nvim .`). Он сохраняется при загрузке конфигурации. Смена файла или команда `:cd` не меняют корень генератора. **Это не каталог текущего открытого файла**.

Пример запуска:

```bash
cd ~/Projects/DytellEngine
nvim .
```

В Neovim:

```vim
:CreateRoot
:CreateHelp
:CreateCppClass -n Player -hs Engine/
:CreateCppClass -n Player -h include/Engine/ -s src/Engine/
:CreateCppClass -n Player -hs .
:CreateCppClass -n Player --split --subdir Engine/Characters/
:CreateCppStruct -n Vector2 -h Math/
:CreateCppEnum -n EntityType
:CreateCppHeader -n Common -h include/
:CreateCppSource -n Helpers -s src/
:CreateCppInterface -n IRenderer -h include/
:CreateCppTest -n Player -s tests/
```

### Аргументы

| Опция | Значение |
| --- | --- |
| `-n Player` / `--name Player` | Имя типа / файла (обязательно) |
| `-h [DIR]` / `--header [DIR]` | Создать только заголовок, необязательный каталог |
| `-s [DIR]` / `--source [DIR]` | Создать только исходник, необязательный каталог |
| `-hs [DIR]` | Создать оба файла, необязательный общий каталог |
| `--split` | Раздельные каталоги: `include/` и `src/` или пути из JSON |
| `--together` | Файлы рядом (по умолчанию в корне) |
| `--subdir Engine/` | Дополнительная подпапка для автоматически выбранных каталогов |
| `--help` | Справка |

Если `-h/-s/-hs` не имеют значения, используется расположение из `--split`/`--together` или `.nvim-generator.json`. Если каталог указан явно, **он имеет приоритет** над настройками layout (например, `-hs Engine/ --split` создаёт файлы рядом в `Engine/`). Для двух разных каталогов используй `-h <dir> -s <dir>`. В комбинации с явным путём `--subdir` учитывается только для файлов, путь которых *не задан* явно.

`-hs .` создаёт оба файла в корне проекта. Папки создаются автоматически. Существующие файлы не перезаписываются. Генератор не обновляет `CMakeLists.txt` и не проверяет корректность имени как C++ идентификатора с точки зрения ключевых слов.

### Настройки конкретного проекта

Скопируй `examples/.nvim-generator.json` в **корень C++ проекта** (не в Git-конфигурацию Neovim). Например:

```json
{
  "cpp": {
    "layout": "split",
    "paths": { "header": "include", "source": "src" },
    "extensions": { "header": ".hpp", "source": ".cpp" }
  }
}
```

Допустимые значения `layout`: `split`, `together`. `paths` определяет, где лежат заголовки и исходники в режиме `split`. Путь `--subdir Engine/` означает `include/Engine/` и `src/Engine/` в режиме split. Если файла настроек нет, оба файла создаются рядом в корне. Настройки читаются **при каждом вызове команды**, чтобы изменения JSON не требовали перезапуска.

Для C++ source, созданного в раздельных каталогах, `#include` использует **относительный путь к заголовку** (например, `../../include/Engine/Player.hpp`), поэтому не нужно угадывать CMake include directories. Если захочешь более короткий `#include "Engine/Player.hpp"`, это можно отдельно настроить позже под целевую CMake-структуру.

### Команды по типам

`CreateCppClass` по умолчанию создаёт `.hpp` и `.cpp`. `CreateCppStruct` создаёт `.hpp` (можно запросить `.cpp` через `-hs`), `CreateCppEnum`, `CreateCppHeader`, `CreateCppInterface` — только заголовки; `CreateCppSource` — один `.cpp`; `CreateCppTest -n Player` создаёт `PlayerTest.cpp`.

У интерфейса создаётся базовая заготовка с виртуальным деструктором; методы нужно объявить самостоятельно. Для GoogleTest требуется добавить тест в сборку и подключить библиотеку GoogleTest.

## Структура

```text
nvim-config/
├── init.lua                   # Все текущие настройки редактора
├── lua/generators/            # Логика генератора: parser, config, paths, cpp
├── examples/.nvim-generator.json
├── bin/nvimhk                # Шпаргалка для Bash/Zsh/Fish
├── bin/nvimhk.ps1            # Справка для PowerShell
├── tests/                    # Проверки генератора
├── .gitignore
└── README.md
```

Модуль генератора подключён в конце `init.lua` через `require("generators").setup()`. Старый `lua/file_templates.lua` **больше не нужен**; не оставляй одновременный `require("file_templates")` в `init.lua`.

### Команда `nvimhk`

Linux:

```bash
mkdir -p ~/.local/bin
ln -s ~/.config/nvim/bin/nvimhk ~/.local/bin/nvimhk
nvimhk --create
```

Если исполняемый каталог не добавлен в `$PATH`, сначала добавь его в настройки Bash/Zsh/Fish. В Windows запускай `& "$env:LOCALAPPDATA\nvim\bin\nvimhk.ps1" --create` в PowerShell. Для работы `.ps1` применяется корпоративная политика исполнения скриптов.

## Дальнейшие шаги

1. Проверить генерацию классов и путей в Dytell Engine.
2. Вынести настройки плагинов из большого `init.lua` по отдельным модулям.
3. Подключить C#, Docker, Bash и PowerShell генераторы, сохраняя правило `Create + Язык + Тип`.
4. Добавить автодополнение каталогов и аргументов, расширить тестирование на Windows.
