#!/usr/bin/env bash
# Linux installer. Never source or execute files from the downloaded repository.
set -euo pipefail
devkit_lang=en
case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in ru*|RU*) devkit_lang=ru ;; esac
devkit_main=false
devkit_stage=''
say() { if [[ $devkit_lang == ru ]]; then printf '%s\n' "$1"; else printf '%s\n' "$2"; fi; }
usage() {
    say 'Использование: bash install.sh [--main] [--lang ru|en] [--help]' \
        'Usage: bash install.sh [--main] [--lang ru|en] [--help]'
    say 'По умолчанию: отдельная конфигурация nvim-devkit; --main выбирает nvim.' \
        'Default: isolated nvim-devkit configuration; --main selects nvim.'
    say '--lang ru|en: язык сообщений. Существующие пути не перезаписываются.' \
        '--lang ru|en: message language. Existing paths are never overwritten.'
}
fail() { say "$1" "$2" >&2; exit 1; }
bad_args() { say 'Неверные аргументы.' 'Invalid arguments.' >&2; usage >&2; exit 2; }
devkit_seen_main=false
devkit_seen_lang=false
devkit_help=false
while (($#)); do
    case "$1" in
        --main) [[ $devkit_seen_main == false ]] || bad_args; devkit_seen_main=true; devkit_main=true; shift ;;
        --lang) [[ $devkit_seen_lang == false && $# -ge 2 ]] || bad_args
            case "$2" in ru|en) devkit_lang=$2 ;; *) bad_args ;; esac
            devkit_seen_lang=true; shift 2 ;;
        --help) [[ $devkit_help == false ]] || bad_args; devkit_help=true; shift ;;
        *) bad_args ;;
    esac
done
if [[ $devkit_help == true ]]; then usage; exit 0; fi
[[ $(uname -s) == Linux ]] || fail 'Этот установщик поддерживает только Linux.' 'This installer supports Linux only.'
command -v nvim >/dev/null 2>&1 || fail 'Установи Neovim 0.12.6+ из пакета дистрибутива или официального выпуска: https://github.com/neovim/neovim/releases' 'Install Neovim 0.12.6+ using your distribution or an official release: https://github.com/neovim/neovim/releases'
command -v git >/dev/null 2>&1 || fail 'Установи Git менеджером пакетов дистрибутива (apt/dnf/pacman/zypper и др.) или с https://git-scm.com/downloads' 'Install Git with your distribution package manager (apt/dnf/pacman/zypper, etc.) or from https://git-scm.com/downloads'
devkit_version=$(nvim --version 2>/dev/null) || fail 'Не удалось проверить Neovim.' 'Could not check Neovim.'
if [[ $devkit_version =~ NVIM\ v([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
    devkit_major=$((10#${BASH_REMATCH[1]})); devkit_minor=$((10#${BASH_REMATCH[2]})); devkit_patch=$((10#${BASH_REMATCH[3]}))
    ((devkit_major > 0 || devkit_minor > 12 || (devkit_minor == 12 && devkit_patch >= 6))) || fail 'Требуется Neovim 0.12.6+. Обнови пакет или установи официальный выпуск.' 'Neovim 0.12.6+ is required. Upgrade the package or install an official release.'
else fail 'Не распознана версия Neovim; требуется 0.12.6+.' 'Unrecognized Neovim version; 0.12.6+ is required.'; fi
if [[ -n ${XDG_CONFIG_HOME:-} ]]; then devkit_base=$XDG_CONFIG_HOME
else [[ -n ${HOME:-} ]] || fail 'HOME не задан.' 'HOME is unset.'; devkit_base=$HOME/.config; fi
[[ $devkit_base == /* ]] || fail 'Каталог конфигурации должен быть абсолютным путём.' 'The configuration directory must be an absolute path.'
devkit_app=nvim-devkit
if [[ $devkit_main == true ]]; then devkit_app=nvim; fi
devkit_target=${devkit_base%/}/$devkit_app
if [[ -e $devkit_target || -L $devkit_target ]]; then
    if [[ -f $devkit_target/lua/generators/init.lua && -f $devkit_target/lua/devkit/help.lua ]]; then
        say 'DevKit уже установлен; автоматического обновления нет.' 'DevKit is already installed; automatic updates are not supported.' >&2
    fi
    printf '%s\n' "$devkit_target" >&2
    fail 'Путь уже существует. Самостоятельно перемести конфигурацию в резервную копию либо выбери изолированный режим без --main.' 'Path already exists. Move the configuration to a backup yourself, or choose isolated mode without --main.'
fi
mkdir -p -- "$devkit_base" || fail 'Каталог конфигурации недоступен.' 'The configuration directory is not accessible.'
devkit_stage=$(mktemp -d "${devkit_base%/}/.nvim-devkit-install.XXXXXXXX") || fail 'Нет прав на запись в каталог конфигурации.' 'Cannot write to the configuration directory.'
cleanup() { if [[ -n $devkit_stage && -d $devkit_stage ]]; then rm -rf -- "$devkit_stage"; fi; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
devkit_repo=https://github.com/Boriska26/nvim-config
say 'Проверка опубликованных тегов…' 'Checking published tags…'
if ! git ls-remote --tags --refs "$devkit_repo" >"$devkit_stage/tags" 2>"$devkit_stage/git.log"; then
    fail 'Не удалось прочитать теги Git. Проверь сеть, прокси и доступ к GitHub; установка отменена.' 'Git tag query failed. Check network, proxy and GitHub access; installation cancelled.'
fi
devkit_ref=$(
    while IFS= read -r devkit_tag; do
        if [[ $devkit_tag =~ refs/tags/(v?([0-9]+\.[0-9]+\.[0-9]+))$ ]]; then
            printf '%s\t%s\n' "${BASH_REMATCH[2]}" "${BASH_REMATCH[1]}"
        fi
    done <"$devkit_stage/tags" | sort -t $'\t' -k1,1V -k2,2 | tail -n 1 | cut -f2
)
if [[ -z $devkit_ref ]]; then
    devkit_ref=main
    say 'Стабильных SemVer-тегов нет: будет установлена ветка main, а не стабильный релиз.' 'No stable SemVer tags found: installing main, not a stable release.'
fi
printf '%s\n' "$devkit_ref"
if ! git -c "core.hooksPath=$devkit_stage/no-hooks" -c core.fsmonitor=false clone --depth 1 --branch "$devkit_ref" -- "$devkit_repo" "$devkit_stage/repo" >"$devkit_stage/git.log" 2>&1; then
    fail 'Клонирование не удалось. Проверь сеть и GitHub; целевая конфигурация не создана.' 'Clone failed. Check network and GitHub; target configuration was not created.'
fi
[[ -f $devkit_stage/repo/init.lua && -f $devkit_stage/repo/lua/plugins/init.lua ]] || fail 'В клоне нет ожидаемых файлов DevKit.' 'The clone lacks the expected DevKit files.'
if [[ $devkit_main == false ]]; then
    mkdir -- "$devkit_stage/repo/.devkit-launch" || fail 'Конфликт каталога launcher в репозитории.' 'Launcher directory conflicts with repository contents.'
    cat >"$devkit_stage/repo/.devkit-launch/nvim-devkit" <<'LAUNCHER'
#!/usr/bin/env bash
NVIM_APPNAME=nvim-devkit exec nvim "$@"
LAUNCHER
    chmod 755 "$devkit_stage/repo/.devkit-launch/nvim-devkit"
fi
# GNU mv -T -n refuses replacement, including a directory/symlink created during clone.
mv -T -n -- "$devkit_stage/repo" "$devkit_target" || fail 'Не удалось опубликовать установку.' 'Could not publish the installation.'
[[ ! -d $devkit_stage/repo ]] || fail 'Целевой путь появился во время установки. Он оставлен без изменений.' 'Target appeared during installation. It has been left unchanged.'
say 'Установлено:' 'Installed:'
printf '%s\n' "$devkit_target"
if [[ $devkit_main == false ]]; then
    printf '%s\n' 'NVIM_APPNAME=nvim-devkit nvim'
    printf '%s\n' "$devkit_target/.devkit-launch/nvim-devkit"
else printf '%s\n' 'NVIM_APPNAME=nvim nvim'; fi
say 'Neovim и плагины не запускались. При первом запуске vim.pack предложит установку плагинов. Затем: :DevKitLang ru, :DevKitDoctor, :DevKitHelp.' 'Neovim and plugins were not launched. On first launch vim.pack prompts to install plugins. Then run :DevKitLang en, :DevKitDoctor, :DevKitHelp.'
