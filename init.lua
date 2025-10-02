-- In ~/.config/nvim/init.lua
-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  -- Get lints
  {
    "mfussenegger/nvim-lint",
    config = function()
      local lint = require("lint")

      lint.linters_by_ft = {
        python = { "flake8" },
        c = { "clangtidy" },
        cpp = { "clangtidy" },
        java = { "checkstyle" },
        javascript = { "eslint_d" },
        typescript = { "eslint_d" },
        html = { "tidy" },
        css = { "stylelint" },
      }

      -- Disable "line too long" (E501) from flake8
      do
        local flake8 = lint.linters.flake8
        -- Keep the default args and just add our flag
        flake8.args = vim.list_extend(flake8.args or {}, { "--ignore=E501" })
        -- Alternative: set a higher limit instead of ignoring:
        -- flake8.args = vim.list_extend(flake8.args or {}, { "--max-line-length=120" })
      end

      vim.api.nvim_create_autocmd(
        { "BufEnter", "TextChanged", "InsertLeave", "BufWritePost", "TextChangedI" },
        {
          callback = function(args)
            local bufnr = args.buf or vim.api.nvim_get_current_buf()
            lint.try_lint()
            vim.schedule(function()
              render_one_per_line(bufnr)
            end)
          end,
        }
      )
    end,
  },

  -- Get LSPs
  {
    "neovim/nvim-lspconfig",
    config = function()
      local on_attach = function(_, bufnr)
        local opts = { buffer = bufnr, noremap = true, silent = true }
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
        vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
        vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
      end

      local capabilities = vim.lsp.protocol.make_client_capabilities()

      local servers = {
        pyright = {},  -- Python
        clangd = {},   -- C/C++
        jdtls = {},    -- Java
        ts_ls = {},    -- JS/TS (adjust to tsserver if needed)
        html = {},
        cssls = {},
      }

      local function lsp_setup(name, conf)
        conf = vim.tbl_deep_extend("force", {
          on_attach = on_attach,
          capabilities = capabilities,
        }, conf or {})

        if vim.fn.has("nvim-0.11") == 1 then
          pcall(vim.lsp.config, name, conf)
          pcall(vim.lsp.enable, name)
        else
          require("lspconfig")[name].setup(conf)
        end
      end

      for name, conf in pairs(servers) do
        pcall(lsp_setup, name, conf)
      end
    end,
  },

  -- Get syntax highlighting
    {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "python", "c", "cpp", "java",
          "javascript", "typescript", "html", "css", "lua"
        },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },

  -- Get cool toolbar
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local colors = {
        bg      = "#00050f",
        fg      = "#f1faee",
        cyan    = "#48cae4",
        teal    = "#2ec4b6",
        blue    = "#5fa8d3",
        purple  = "#c77dff",
        yellow  = "#ffe066",
        red     = "#ff6b6b",
        gray    = "#457b9d",
      }

    local theme = {
      normal = {
        a = { fg = colors.bg, bg = colors.cyan, gui = "bold" },
        b = { fg = colors.cyan, bg = colors.bg },
        c = { fg = colors.fg, bg = colors.bg },
        },
        insert = {
          a = { fg = colors.bg, bg = colors.teal, gui = "bold" },
        },
        visual = {
          a = { fg = colors.bg, bg = colors.purple, gui = "bold" },
        },
        replace = {
          a = { fg = colors.bg, bg = colors.red, gui = "bold" },
        },
        command = {
          a = { fg = colors.bg, bg = colors.yellow, gui = "bold" },
        },
        inactive = {
          a = { fg = colors.gray, bg = colors.bg, gui = "bold" },
          b = { fg = colors.gray, bg = colors.bg },
          c = { fg = colors.gray, bg = colors.bg },
        },
      }

      require("lualine").setup({
        options = {
          theme = theme,
          section_separators = { left = "│", right = "│" },
          component_separators = { left = "│", right = "│" },
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff" },
          lualine_c = { "filename" },
          lualine_x = {
                        {
                          "diagnostics",
                          symbols = {
                            error = "E",
                            warn  = "W",
                            info  = "I",
                            hint  = "H",
                          },
                        },
                      },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
      })
    end,
  },
  
  -- Custom tab complete
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",   -- LSP completions
      "hrsh7th/cmp-buffer",     -- buffer words
      "hrsh7th/cmp-path",       -- filesystem paths
      "hrsh7th/cmp-cmdline",    -- command line completion
      "L3MON4D3/LuaSnip",       -- snippet engine
      "saadparwaiz1/cmp_luasnip", -- snippets in cmp
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = {
          -- Manual trigger: <C-Space>
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"]      = cmp.mapping.confirm({ select = true }),
          ["<Tab>"]     = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"]   = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        },
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "buffer" },
          { name = "path" },
        }),
        completion = {
          autocomplete = false, -- 👈 disables auto-popup
        },
      })
    end,
  },
  
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

})

-- Show diagnostics inline + keep gutter signs (we override inline below)
vim.diagnostic.config({
  virtual_text = false,   -- disable built-in inline text
  signs = false,
  underline = true,
  update_in_insert = true,
})

-- === Custom virtual text: one diagnostic per line with priority ===
local ONE_PER_LINE_NS = vim.api.nvim_create_namespace("one_diag_per_line")

local function lsp_namespaces_for_buf(bufnr)
  local set = {}
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    local ok, ns = pcall(vim.lsp.diagnostic.get_namespace, client.id)
    if ok and ns then set[ns] = true end
  end
  return set
end

local function hl_from_severity(sev)
  local s = vim.diagnostic.severity
  if sev == s.ERROR then return "DiagnosticError"
  elseif sev == s.WARN then return "DiagnosticWarn"
  elseif sev == s.INFO then return "DiagnosticInfo"
  else return "DiagnosticHint" end
end

function render_one_per_line(bufnr)
  if not vim.api.nvim_buf_is_loaded(bufnr) then return end
  vim.api.nvim_buf_clear_namespace(bufnr, ONE_PER_LINE_NS, 0, -1)

  local all = vim.diagnostic.get(bufnr)
  if #all == 0 then return end

  local lsp_ns = lsp_namespaces_for_buf(bufnr)

  local sev_rank = {
    [vim.diagnostic.severity.ERROR] = 1,
    [vim.diagnostic.severity.WARN]  = 2,
    [vim.diagnostic.severity.INFO]  = 3,
    [vim.diagnostic.severity.HINT]  = 4,
  }

  local best_by_line = {}
  for _, d in ipairs(all) do
    local line = d.lnum
    local is_lsp = lsp_ns[d.namespace] and 0 or 1
    local rank = { sev_rank[d.severity] or 9, is_lsp }

    local cur = best_by_line[line]
    if not cur then
      best_by_line[line] = { diag = d, rank = rank }
    else
      local r = cur.rank
      if (rank[1] < r[1]) or (rank[1] == r[1] and rank[2] < r[2]) then
        best_by_line[line] = { diag = d, rank = rank }
      end
    end
  end

  for line, entry in pairs(best_by_line) do
    -- make sure the line still exists (prevents out-of-range errors after deletes)
    if line < vim.api.nvim_buf_line_count(bufnr) then
      local d = entry.diag
      local msg = d.message and d.message:gsub("%s+", " "):gsub("%.$", "") or ""
      local hl = hl_from_severity(d.severity)

      vim.api.nvim_buf_set_extmark(bufnr, ONE_PER_LINE_NS, line, -1, {
        virt_text = { { "  " .. msg, hl } },
        virt_text_pos = "eol",
        hl_mode = "combine",
        priority = 2048,
      })
    end
  end

end

vim.api.nvim_create_autocmd("DiagnosticChanged", {
  callback = function(args)
    local bufnr = args.buf or (args.data and args.data.buf) or 0
    render_one_per_line(bufnr)
  end,
})
vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave", "ColorScheme" }, {
  callback = function() render_one_per_line(0) end,
})
-- File tree colors
vim.api.nvim_set_hl(0, "FzfLuaBorder", { fg = "#1d9bf0" })
vim.api.nvim_set_hl(0, "FzfLuaCursorLine", { bg = "#123466" })
vim.api.nvim_set_hl(0, "FzfLuaHeaderText", { fg = "#5fa8d3", bold = true })
vim.api.nvim_set_hl(0, "FzfLuaHeaderBind", { fg = "#1d9bf0", bold = true })
vim.api.nvim_set_hl(0, "FzfLuaHeaderText", { fg = "#5fa8d3", bold = true })
-- Completion menu colors
vim.api.nvim_set_hl(0, "Pmenu",     { bg = "#001f3f", fg = "#f1faee" })  -- popup background
vim.api.nvim_set_hl(0, "PmenuSel",  { bg = "#00509e", fg = "#ffffff", bold = true }) -- selected item
vim.api.nvim_set_hl(0, "PmenuSbar", { bg = "#001f3f" }) -- scrollbar
vim.api.nvim_set_hl(0, "PmenuThumb",{ bg = "#00509e" }) -- scrollbar thumb
-- Casual stuff 
vim.api.nvim_set_hl(0, "Normal",     { fg = "#f1faee", bg = "#00050f" })
vim.api.nvim_set_hl(0, "Cursor",     { fg = "#00050f", bg = "#48cae4" })
vim.api.nvim_set_hl(0, "LineNr",     { fg = "#5fa8d3", bg = "#00050f" })
vim.api.nvim_set_hl(0, "Comment",    { fg = "#457b9d", italic = true })
vim.api.nvim_set_hl(0, "Statement",  { fg = "#ff6b6b" })
vim.api.nvim_set_hl(0, "Identifier", { fg = "#2ec4b6" })
vim.api.nvim_set_hl(0, "Constant",   { fg = "#ffd166" })
vim.api.nvim_set_hl(0, "Type",       { fg = "#48cae4" })
vim.api.nvim_set_hl(0, "Special",    { fg = "#c77dff" })
vim.api.nvim_set_hl(0, "Directory",  { fg = "#5fa8d3" })
vim.api.nvim_set_hl(0, "Search",     { fg = "#00050f", bg = "#ffe066" })
vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.cursorline = true
vim.api.nvim_set_hl(0, "LineNr", { fg = "#457b9d", bg = "#00050f" })
vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#48cae4", bg = "#00050f", bold = true })
vim.api.nvim_set_hl(0, "CursorLine",    { bg = "#090d35" })
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true

vim.opt.undolevels = 10000
vim.opt.undoreload = 100000

vim.opt.undofile = true
vim.opt.undodir = vim.fn.stdpath("data") .. "/undo"
vim.opt.shortmess:append("I")

-- Extra bindings
vim.keymap.set("n", "<C-j>", ":m .+1<CR>==", { silent = true })
vim.keymap.set("n", "<C-k>", ":m .-2<CR>==", { silent = true })

vim.keymap.set("x", "<C-j>", ":m '>+1<CR>gv=gv", { silent = true })
vim.keymap.set("x", "<C-k>", ":m '<-2<CR>gv=gv", { silent = true })

vim.keymap.set({"n", "v"}, "y", '"+y')
vim.keymap.set("n", "Y", '"+Y')
