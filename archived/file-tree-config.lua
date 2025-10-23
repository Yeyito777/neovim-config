-- At the imports in lazyvim
  -- File tree
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local fzf = require("fzf-lua")
      fzf.setup({
        -- 1) Tab navigation like Alt-Tab
        keymap = {
          fzf = {
            ["tab"]       = "down",
            ["shift-tab"] = "up",
          },
        },
        -- 2) No multi-select → Enter always opens the highlighted row
        fzf_opts = {
          ["--no-multi"] = true,
        },
        -- 3) Remove glyph/devicons
        defaults = {
          file_icons  = false,
          git_icons   = false,
          color_icons = false,
        },
        -- 4) (Optional clarity) ensure Enter edits file
        actions = {
          files = {
            ["enter"] = fzf.actions.file_edit,
          },
        },
      })

      -- open files picker with Tab in normal mode
      vim.keymap.set("n", "<Tab>", "<cmd>FzfLua files<CR>", { desc = "Fuzzy find files" })
    end,
  },
-- At the bottom of your neovim config
-- File tree colors
vim.api.nvim_set_hl(0, "FzfLuaBorder", { fg = "#1d9bf0" })
vim.api.nvim_set_hl(0, "FzfLuaCursorLine", { bg = "#123466" })
vim.api.nvim_set_hl(0, "FzfLuaHeaderText", { fg = "#5fa8d3", bold = true })
vim.api.nvim_set_hl(0, "FzfLuaHeaderBind", { fg = "#1d9bf0", bold = true })
vim.api.nvim_set_hl(0, "FzfLuaHeaderText", { fg = "#5fa8d3", bold = true })
