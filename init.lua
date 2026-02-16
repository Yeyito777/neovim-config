vim.opt.termguicolors = true

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  {
    "chentoast/marks.nvim",
    opts = {
      default_mappings = true,
      builtin_marks = { ".", "<", ">", "^" },
      cyclic = true,
      force_write_shada = true,
    },
  },

  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    opts = {
      indent = {
        char = "│",
        highlight = { "IblIndent" },
      },
      scope = { enabled = false },
    },
    config = function(_, opts)
      local hooks = require("ibl.hooks")
      hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
        vim.api.nvim_set_hl(0, "IblIndent", { fg = "#090d35", nocombine = true })
      end)
      require("ibl").setup(opts)
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("nvim-treesitter.configs").setup({
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              ["ic"] = "@class.inner",
            },
          },
          move = {
            enable = true,
            set_jumps = true,
            goto_next_start = {
              ["<Space>u"] = "@function.outer",
              ["]]"] = "@class.outer",
            },
            goto_previous_start = {
              ["<Space>i"] = "@function.outer",
              ["[["] = "@class.outer",
            },
          },
        },
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      local on_attach = function(_, bufnr)
        local opts = { buffer = bufnr, noremap = true, silent = true }
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "<leader>r", vim.lsp.buf.rename, opts)
        vim.keymap.set("n", "<leader>c", vim.lsp.buf.code_action, opts)
        vim.keymap.set("n", "<leader>g", vim.lsp.buf.references, opts)
      end
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      local rust_root = vim.fn.trim(vim.fn.system("cargo metadata --no-deps --format-version 1 | jq -r '.workspace_root'"))
      if vim.v.shell_error ~= 0 or rust_root == "" then
        vim.notify("cargo metadata failed, using cwd",vim.log.levels.WARN)
        rust_root = vim.fn.getcwd()
      end

      local servers = {
        pyright = {
          settings = {
          python = {
              analysis = {
              autoImportCompletions = true,
              diagnosticMode = "workspace",
            },
          },
        },},
        clangd = {},   -- C/C++
        ts_ls = {},    -- JS/TS (adjust to tsserver if needed)
        html = {},
        cssls = {},
        rust_analyzer = {
          settings = {
            ["rust-analyzer"] = {
              cargo = {
                allFeatures = true,
                targetDir = rust_root.."/target",
              },
              checkOnSave = true,
              check = {
                command = "clippy"
              },
            },
          },
        },
        lua_ls = {
          settings = {
            Lua = {
              diagnostics = {
                globals = { "vim" },
              },
              workspace = {
                checkThirdParty = false,
              },
            },
          },
        }
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
          "python", "c", "cpp", "java","bash",
          "javascript", "typescript", "html", "css", "lua","markdown","markdown_inline","rust"
        },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },

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
})

-- local plugins
require("persist_local_marks")

-- Show LSP diagnostics
vim.diagnostic.config({
  virtual_text = {
    spacing = 0,
    prefix = ">",
  },
  signs = false,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})
vim.api.nvim_create_autocmd("FileType", {
  pattern = "rust",
  callback = function()
    vim.opt_local.formatoptions:remove({ "t", "c" })
  end,
})
vim.keymap.set("n", "gl", vim.diagnostic.open_float)
vim.keymap.set("n", "]e", function()
  vim.diagnostic.goto_next({
    severity = vim.diagnostic.severity.ERROR,
  })
end, { desc = "Next error" })

vim.keymap.set("n", "[e", function()
  vim.diagnostic.goto_prev({
    severity = vim.diagnostic.severity.ERROR,
  })
end, { desc = "Previous error" })

vim.keymap.set("n", "]w", function()
  vim.diagnostic.goto_next()
end, { desc = "Next diagnostic" })

vim.keymap.set("n", "[w", function()
  vim.diagnostic.goto_prev()
end, { desc = "Previous diagnostic" })

-- Mark configuration
vim.opt.signcolumn = "yes"
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

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.keymap.set({"n", "v"}, "<leader>y", '"+y', { desc = "Yank to system clipboard" })
vim.keymap.set("n", "<leader>Y", '"+Y', { desc = "Yank line to system clipboard" })

vim.keymap.set({"n", "v"}, "<leader>p", '"+p', { desc = "Paste from system clipboard" })
vim.keymap.set({"n", "v"}, "<leader>P", '"+P', { desc = "Paste before from system clipboard" })

local function jump_to_mark()
  local mark = vim.fn.getcharstr()
  if mark == " " then
    vim.cmd("normal! ``zz")
  else
    local pos = vim.fn.getpos("'" .. mark)
    if pos[2] == 0 then
      vim.notify("Mark '" .. mark .. "' is not set", vim.log.levels.WARN, { title = "Marks" })
    else
      vim.cmd("normal! `" .. mark .. "zz")
    end
  end
end

vim.keymap.set({ "n", "v" }, "<leader>j", jump_to_mark, {
  desc = "Jump to mark or last position and center"
})

local function clone_line()
  local lnum = vim.fn.line(".")
  local line = vim.fn.getline(lnum)
  vim.fn.append(lnum, line)
end
vim.keymap.set({"n"}, "<leader>k", clone_line, { desc = "Clones the current line or selection below" })
vim.keymap.set({"n", "x", "o"}, "<leader>l", "``zz", { desc = "Jump back and center" })

vim.keymap.set("n", "<leader>s", function()
  local word = vim.fn.expand("<cword>")
  if word == "" then return end
  local escaped = vim.fn.escape(word, "/\\")
  local keys = vim.api.nvim_replace_termcodes(":%s/\\<" .. escaped .. "\\>//gc<Left><Left><Left>", true, false, true)
  vim.api.nvim_feedkeys(keys, "n", false)
end, { desc = "Substitute word under cursor (confirm)" })

vim.keymap.set("n", "<leader>S", function()
  local word = vim.fn.expand("<cword>")
  if word == "" then return end
  local escaped = vim.fn.escape(word, "/\\")
  local keys = vim.api.nvim_replace_termcodes(":%s/\\<" .. escaped .. "\\>//g<Left><Left>", true, false, true)
  vim.api.nvim_feedkeys(keys, "n", false)
end, { desc = "Substitute word under cursor (no confirm)" })

-- Extra configs
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- == Keep cursor position.
-- Save view (cursor, folds, scroll position, etc.) when leaving a buffer
vim.api.nvim_create_autocmd("BufWinLeave", {
  callback = function()
    local ignore_ft = { "gitcommit", "gitrebase", "help", "nofile", "quickfix" }
    if not vim.tbl_contains(ignore_ft, vim.bo.filetype) then
      vim.cmd("silent! mkview")
    end
  end,
})

-- Load view (restore everything) when re-entering a buffer
vim.api.nvim_create_autocmd("BufWinEnter", {
  callback = function()
    local ignore_ft = { "gitcommit", "gitrebase", "help", "nofile", "quickfix" }
    if not vim.tbl_contains(ignore_ft, vim.bo.filetype) then
      vim.cmd("silent! loadview")
    end
  end,
})

-- Also restore last known cursor position (based on mark `"`),
-- in case view files don't exist yet (new files, etc.)
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Custom commands:

local function add_to_lines(text, line1, line2)
  local bufnr = vim.api.nvim_get_current_buf()

  for i = line1 - 1, line2 - 1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
    if line then
      -- Find first non-blank character
      local first_nonblank = line:find("%S")
      if first_nonblank then
        -- Insert text before first non-blank
        local new_line = line:sub(1, first_nonblank - 1) .. text .. line:sub(first_nonblank)
        vim.api.nvim_buf_set_lines(bufnr, i, i + 1, false, { new_line })
      else
        -- Blank line, just leave it blank (or you could insert text if desired)
        vim.api.nvim_buf_set_lines(bufnr, i, i + 1, false, { text })
      end
    end
  end
end

-- Create :add command that works in normal and visual mode properly
vim.api.nvim_create_user_command('PP', function(opts)
  add_to_lines(opts.args, opts.line1, opts.line2)
end, { nargs = 1, range = '%' })

vim.keymap.set("n", "<C-_>", "gcc", {
  remap = true,
  desc = "Toggle comment for current line",
})

vim.keymap.set("x", "<C-_>", "gc", {
  remap = true,
  desc = "Toggle comment for selection",
})

-- When pressing enter on comments do not create a new comment
vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function()
    -- Don't continue comments when pressing <CR> or using 'o' / 'O'
    vim.opt_local.formatoptions:remove({ "r", "o" })
  end,
})

-- ANSI ESCAPE COMMANDS
local function ansi_cmd(name, code)
  vim.api.nvim_create_user_command(name, function()
    vim.api.nvim_put({ "\\x1b" .. "[" .. code .. "m" }, "c", true, true)
  end, {})
end

ansi_cmd("Black",   "30")
ansi_cmd("Red",     "31")
ansi_cmd("Green",   "32")
ansi_cmd("Yellow",  "33")
ansi_cmd("Blue",    "34")
ansi_cmd("Magenta", "35")
ansi_cmd("Cyan",    "36")
ansi_cmd("White",   "37")
ansi_cmd("Bold",    "1")
ansi_cmd("Reset",   "0")

-- Ctrl+1-9: Jump to (n*10)% of visible screen
-- These use CSI u encoded sequences from st terminal
local function jump_to_screen_percent(percent)
  local win_height = vim.api.nvim_win_get_height(0)
  local top_line = vim.fn.line("w0")
  local target_offset = math.floor((win_height - 1) * percent / 100 + 0.5)
  local target_line = top_line + target_offset
  local max_line = vim.fn.line("$")
  target_line = math.min(target_line, max_line)
  target_line = math.max(target_line, 1)
  local view = vim.fn.winsaveview()
  view.lnum = target_line
  vim.fn.winrestview(view)
end

-- Ctrl+1-9,0,-: Map F14-F24 keys (sent by st terminal)
-- Ctrl+1 = 0%, Ctrl+2 = 10%, ..., Ctrl+9 = 80%, Ctrl+0 = 90%, Ctrl+- = 100%
local fkeys = {"<F14>", "<F15>", "<F16>", "<F17>", "<F18>", "<F19>", "<F20>", "<F21>", "<F22>", "<F23>", "<F24>"}
local percents = {0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100}
for i, fkey in ipairs(fkeys) do
  local pct = percents[i]
  vim.keymap.set({"n", "v"}, fkey, function()
    jump_to_screen_percent(pct)
  end, { desc = string.format("Jump to %d%% of screen", pct) })
end

-- F14-F24 in insert mode: special characters
vim.keymap.set("i", "<F14>", "←", { desc = "Insert left arrow" })
vim.keymap.set("i", "<F15>", "•", { desc = "Insert bullet point" })
vim.keymap.set("i", "<F16>", "→", { desc = "Insert right arrow" })
vim.keymap.set("i", "<F22>", "…", { desc = "Insert ellipsis" })
vim.keymap.set("i", "<F23>", "–", { desc = "Insert en dash" })
vim.keymap.set("i", "<F24>", "—", { desc = "Insert em dash" })

-- Cool separators:
vim.api.nvim_create_user_command("Sep", function()
  local left  = "/* ───────────────────────────────   "
  local right = "   ─────────────────────────────────────────── */"
  local line = left .. right
  local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
  vim.api.nvim_buf_set_lines(0, row, row, false, { line })
  local col = #left
  vim.api.nvim_win_set_cursor(0, { row + 1, col })
  vim.cmd("startinsert")
end, {})

-- Auto-reload files changed outside of Neovim
vim.o.autoread = true

vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold" }, {
  command = "checktime",
})

local reload_timer = vim.uv.new_timer()
reload_timer:start(500, 500, vim.schedule_wrap(function()
  if vim.api.nvim_get_mode().mode == "n" then
    local old_tick = vim.b.changedtick
    vim.cmd("silent! checktime")
    if vim.b.changedtick ~= old_tick then
      vim.notify("File changed on disk. Buffer reloaded.", vim.log.levels.WARN)
    end
  end
end))
