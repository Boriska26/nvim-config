# Быстрая проверка C++-генератора (без установки плагинов)

Запусти в пустом временном каталоге:

```bash
mkdir -p /tmp/nvim-generator-test
cd /tmp/nvim-generator-test
nvim --headless -u NONE \
  --cmd 'lua package.path = os.getenv("HOME") .. "/.config/nvim/lua/?.lua;" .. os.getenv("HOME") .. "/.config/nvim/lua/?/init.lua;" .. package.path' \
  '+lua require("generators").setup()' \
  '+CreateCppClass -n Player -hs .' \
  '+qa!'
ls -la
```

`Player.hpp` и `Player.cpp` должны появиться в этом каталоге. В тестовой папке запускай команду только один раз: повторный вызов должен отказать в перезаписи файлов.
