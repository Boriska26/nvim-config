param([string]$Section = "--help")

switch ($Section) {
    "--create" {
@'
=== ГЕНЕРАТОРЫ C++ / C# ===
:CreateCpp -c -n Player -p Engine/
:CreateCpp -s -n Vector2 -p Math/
:CreateCpp -e -n State
:CreateCpp -i -n IRenderer
:CreateCpp --header -n Common
:CreateCpp --source -n Helpers
:CreateCpp --test -n Player -p tests/
:CreateCpp -c -n Renderer -b -sp --subdir Graphics/
:CreateCSharp -c -n PhotoService -p Services/
:CreateCSharp -rs -n Point --readonly

-n / --name NAME          Имя типа / файла
-p / --path DIR           Базовый каталог от корня запуска Neovim
-ho / --header-only       Только заголовок C++
-so / --source-only       Только исходник C++
-b / --both               Оба файла C++
-sp / --split             Раздельные каталоги include/ и src/
-tg / --together          Файлы рядом
--subdir DIR              Вложенный каталог при split
--test                    Один NAMETest.cpp с GoogleTest (без заголовка)
-s / --struct             Структура (для обеих основных команд)
--help                    Справка выбранного генератора
:GeneratorHelp            Разделы C++ / C# встроенной справки
:GeneratorList            Команды генераторов и служебные команды
:CreateHelp               Полная текстовая справка
:CreateRoot               Проверить корень генератора
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
