# Native visible-width Markdown wrapping

This setup uses a locally patched Neovim 0.12.2 (upstream base
4b35336f6f850ce68a230716401cdaa21bdb6a25), not a rendered/shadow buffer.

The `conceal_compact=true` extmark extension gives hidden URL spans zero display
width in Neovim's renderer, line sizing, cursor geometry, and mouse hit testing.
Only the Markdown module's URL extmarks opt in. Ordinary conceal and other
filetypes retain their existing behavior. The buffer and saved file always
contain the original Markdown source.

## Locations

- Active launcher: `~/.local/bin/nvim`
- Patched installation: `~/.local/opt/neovim-visible-wrap/`
- Source and regression tests: `~/.local/src/neovim-visible-wrap/`
- Portable patch: `~/.local/src/neovim-visible-wrap/compact-wrap.patch`
- Link module: `~/.config/nvim/lua/markdown_links.lua`

Check the running binary with `:echo has('conceal_compact')` (must print `1`).
Opening a new Neovim is required; reloading Lua cannot patch an already-running
Neovim process. Run `rehash` in zsh if it still remembers the old executable.

The original package-managed Neovim is untouched: `/opt/homebrew/bin/nvim` on
macOS and `/usr/bin/nvim` on Whale. Package-manager upgrades will not update this
separate custom build. Updating it requires rebasing/reapplying the patch and
rerunning its tests.

## Rebuild

From the source directory:

```sh
make CMAKE_BUILD_TYPE=RelWithDebInfo \
  CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$HOME/.local/opt/neovim-visible-wrap" \
  CMAKE_BUILD_PARALLEL_LEVEL=8
cmake --install build
```

Tests added to the native source are `test/functional/ui/compact_wrap_spec.lua`
and `compact_mouse_spec.lua`. Run them through the normal Neovim functional-test
harness, for example:

```sh
TEST_FILE=test/functional/ui/compact_wrap_spec.lua make functionaltest
```

Additional Python integration/projection tests are under `local-tests/` and use
`pynvim`. Set `NVIM_TEST_BIN` to the absolute patched binary path. When testing an
uninstalled build with the user's full config, also set `VIMRUNTIME` to the source
`runtime/` directory. Do not mix a 0.12 binary with the stock 0.11 runtime.

## Rollback

Run the package-managed binary directly, or remove only the `~/.local/bin/nvim`
symlink that points at the custom installation, then `rehash`. The Markdown Lua
module detects the extension and safely falls back on stock Neovim (with the
original conceal-wrapping limitation). Original configuration backups are under
`~/.config/nvim/backups/`.
