param([string]$Section = "--help")

switch ($Section) {
    "--doctor" {
@'
:DevKitDoctor   Диагностика Core, C#, C++ и DevOps
:DevKitLang ru  Русский; :DevKitLang en — английский
r              Повторить проверки
Enter          Подробности и рекомендации
?              Клавиши окна
Backspace      Вернуться к списку
q / Esc        Закрыть
Проверки не устанавливают программы и не запускают службы/контейнеры.
'@
    }
    "--create" {
@'
=== ГЕНЕРАТОРЫ C++ / C# / DevOps ===
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

:CreateDevOps -df -p .                 Dockerfile
:CreateDevOps -dc -p deploy/           compose.yaml
:CreateDevOps -di                     .dockerignore
:CreateDevOps -gi                     .gitignore
:CreateDevOps -gl                     .gitlab-ci.yml
:CreateDevOps -b -n backup -p scripts/
:CreateDevOps -ps -n deploy -p scripts/
:CreateDevOps -sd -n app -p deploy/systemd/
:CreateDevOps -ng -n reverse-proxy -p deploy/nginx/
:CreateDevOps --help
DevOps: один вызов — один файл, без запуска и chmod +x.
-n разрешён только для Bash, PowerShell, systemd и Nginx.
Язык: :DevKitLang ru / :DevKitLang en.

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
:GeneratorHelp            Разделы C++ / C# / DevOps встроенной справки
:GeneratorList            Команды генераторов и служебные команды
:CreateHelp               Полная текстовая справка
:CreateRoot               Проверить корень генератора
'@
    }
    default {
@'
NVIMHK — доступные разделы
--create       Создание файлов Neovim
--doctor       Диагностика окружения

Внутри Neovim: :CreateHelp
'@
    }
}
