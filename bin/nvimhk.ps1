param([string]$Section = "--help")

switch ($Section) {
    "--create" {
@'
=== ГЕНЕРАТОР C++ ===
:CreateCppClass -n Player -hs Engine/
:CreateCppClass -n Player -h include/Engine/ -s src/Engine/
:CreateCppClass -n Player --split --subdir Engine/
:CreateCppStruct -n Vector2 -h Math/
:CreateCppEnum -n State
:CreateCppHeader -n Common
:CreateCppSource -n Helpers
:CreateCppInterface -n IRenderer
:CreateCppTest -n Player

-n NAME      Имя
-h DIR       Заголовок + необязательный каталог
-s DIR       Исходник + необязательный каталог
-hs DIR      Оба файла + необязательный каталог
--split      Раздельные каталоги
--together   Файлы рядом
--subdir DIR Дополнительная подпапка
:CreateHelp  Справка внутри Neovim
'@
    }
    default {
@'
NVIMHK — доступные разделы
--create       Создание файлов Neovim

Внутри Neovim: :CreateHelp
'@
    }
}
