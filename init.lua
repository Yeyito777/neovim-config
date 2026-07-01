local function normalize_color_override(value)
  value = (value or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if value == "3" or value == "truecolor" or value == "24bit" or value == "24-bit" or value == "rgb" then
    return "truecolor"
  end
  if value == "2" or value == "256" or value == "256color" or value == "8bit" or value == "8-bit" then
    return "256"
  end
  if value == "1" or value == "16" or value == "ansi" or value == "basic" then
    return "16"
  end
  return nil
end

local function detect_terminal_color_level()
  local explicit = normalize_color_override(vim.env.NVIM_TUI_COLOR) or normalize_color_override(vim.env.EXOCORTEX_TUI_COLOR)
  if explicit then return explicit end

  if vim.env.NO_COLOR then return "16" end

  local forced = normalize_color_override(vim.env.FORCE_COLOR)
  if forced then return forced end

  local term = (vim.env.TERM or ""):lower()
  local colorterm = (vim.env.COLORTERM or ""):lower()
  local term_program = (vim.env.TERM_PROGRAM or ""):lower()

  if colorterm:find("truecolor", 1, true) or colorterm:find("24bit", 1, true) then
    return "truecolor"
  end
  if term:find("direct", 1, true) or term:find("truecolor", 1, true) or term:find("24bit", 1, true) then
    return "truecolor"
  end

  -- Be conservative: generic xterm-256color is not a truecolor signal. This is
  -- what macOS Terminal.app commonly reports over SSH. Known truecolor terminals
  -- get truecolor even when their TERM name does not use the newer *-direct form.
  if term == "xterm-kitty" or term == "wezterm" or term == "foot" or term == "foot-extra"
      or term == "alacritty" or term == "rio" or term == "ghostty" or term == "st" or term:match("^st%-") then
    return "truecolor"
  end

  -- TERM_PROGRAM is usually absent over SSH unless explicitly forwarded, but use
  -- it when present. Apple Terminal stays on the 256-color path unless one of the
  -- stronger truecolor signals above was set.
  if term_program == "wezterm" or term_program == "ghostty" or term_program == "kitty" or term_program == "iterm.app" then
    return "truecolor"
  end
  if term_program == "apple_terminal" then
    return "256"
  end

  if term:find("256color", 1, true) or term:find("256", 1, true) then
    return "256"
  end
  return "16"
end

local color_level = detect_terminal_color_level()
vim.g.nvim_color_level = color_level
vim.opt.termguicolors = color_level == "truecolor"

-- Neovim's OSC 52 clipboard auto-detection can send an XTGETTCAP query for
-- the `Ms` capability: ESC P + q 4D73 ESC \.  Apple Terminal.app and some SSH
-- paths echo unsupported DCS queries as visible text, which shows up as
-- "+q4D73" where the cursor is.  Over SSH, TERM_PROGRAM is often absent, so
-- treat plain xterm-256color with no COLORTERM as Apple-Terminal-ish and skip
-- the probe.  Set NVIM_OSC52=1 if you explicitly want to try OSC 52 anyway.
local current_term = (vim.env.TERM or ""):lower()
local current_colorterm = (vim.env.COLORTERM or ""):lower()
local current_term_program = (vim.env.TERM_PROGRAM or ""):lower()
if vim.env.NVIM_OSC52 ~= "1"
    and (current_term_program == "apple_terminal"
      or (current_term == "xterm-256color" and current_colorterm == "" and current_term_program == "")) then
  local termfeatures = vim.g.termfeatures or {}
  termfeatures.osc52 = false
  vim.g.termfeatures = termfeatures
end

local xterm_256_levels = { 0, 95, 135, 175, 215, 255 }
local ansi_16_rgb = {
  { 0, 0, 0 },       -- black
  { 205, 0, 0 },     -- red
  { 0, 205, 0 },     -- green
  { 205, 205, 0 },   -- yellow
  { 0, 0, 238 },     -- blue
  { 205, 0, 205 },   -- magenta
  { 0, 205, 205 },   -- cyan
  { 229, 229, 229 }, -- white
  { 127, 127, 127 }, -- bright black / gray
  { 255, 0, 0 },
  { 0, 255, 0 },
  { 255, 255, 0 },
  { 92, 92, 255 },
  { 255, 0, 255 },
  { 0, 255, 255 },
  { 255, 255, 255 },
}

local function clamp_byte(value)
  value = tonumber(value) or 0
  return math.max(0, math.min(255, math.floor(value + 0.5)))
end

local function color_distance_sq(r1, g1, b1, r2, g2, b2)
  return (r1 - r2) ^ 2 + (g1 - g2) ^ 2 + (b1 - b2) ^ 2
end

local function nearest_index(levels, value)
  local best = 1
  local best_dist = math.huge
  for i, level in ipairs(levels) do
    local dist = math.abs(value - level)
    if dist < best_dist then
      best = i
      best_dist = dist
    end
  end
  return best
end

local function hex_to_rgb(hex)
  if type(hex) ~= "string" then return nil end
  local h = hex:gsub("^#", "")
  if #h == 3 then
    h = h:sub(1, 1) .. h:sub(1, 1) .. h:sub(2, 2) .. h:sub(2, 2) .. h:sub(3, 3) .. h:sub(3, 3)
  end
  if not h:match("^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$") then
    return nil
  end
  return tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)
end

local function rgb_to_xterm256(r, g, b)
  r, g, b = clamp_byte(r), clamp_byte(g), clamp_byte(b)
  local ri = nearest_index(xterm_256_levels, r)
  local gi = nearest_index(xterm_256_levels, g)
  local bi = nearest_index(xterm_256_levels, b)

  local cube_code = 16 + (36 * (ri - 1)) + (6 * (gi - 1)) + (bi - 1)
  local cube_r, cube_g, cube_b = xterm_256_levels[ri], xterm_256_levels[gi], xterm_256_levels[bi]
  local cube_dist = color_distance_sq(r, g, b, cube_r, cube_g, cube_b)

  local chroma = math.max(r, g, b) - math.min(r, g, b)
  if chroma > 12 then return cube_code end

  local avg = (r + g + b) / 3
  local gray_index
  if avg <= 8 then
    gray_index = 0
  elseif avg >= 248 then
    gray_index = 23
  else
    gray_index = math.max(0, math.min(23, math.floor(((avg - 8) / 10) + 0.5)))
  end
  local gray_value = 8 + (gray_index * 10)
  local gray_code = 232 + gray_index
  local gray_dist = color_distance_sq(r, g, b, gray_value, gray_value, gray_value)

  if gray_dist < cube_dist then return gray_code end
  return cube_code
end

local function rgb_to_ansi16(r, g, b)
  r, g, b = clamp_byte(r), clamp_byte(g), clamp_byte(b)
  local best = 0
  local best_dist = math.huge
  for i, rgb in ipairs(ansi_16_rgb) do
    local dist = color_distance_sq(r, g, b, rgb[1], rgb[2], rgb[3])
    if dist < best_dist then
      best = i - 1
      best_dist = dist
    end
  end
  return best
end

local function color_to_cterm(color)
  if type(color) == "number" then return color end
  if type(color) ~= "string" or color:lower() == "none" then return nil end
  local r, g, b = hex_to_rgb(color)
  if not r then return nil end
  if color_level == "16" then
    return rgb_to_ansi16(r, g, b)
  end
  return rgb_to_xterm256(r, g, b)
end

local function set_hl(ns, name, opts)
  if color_level ~= "truecolor" then
    opts = vim.tbl_extend("force", {}, opts)
    if opts.fg ~= nil and opts.ctermfg == nil then
      opts.ctermfg = color_to_cterm(opts.fg)
    end
    if opts.bg ~= nil and opts.ctermbg == nil then
      opts.ctermbg = color_to_cterm(opts.bg)
    end
  end
  vim.api.nvim_set_hl(ns, name, opts)
end

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
        set_hl(0, "IblIndent", { fg = "#090d35", nocombine = true })
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
set_hl(0, "Pmenu",     { bg = "#001f3f", fg = "#f1faee" })  -- popup background
set_hl(0, "PmenuSel",  { bg = "#00509e", fg = "#ffffff", bold = true }) -- selected item
set_hl(0, "PmenuSbar", { bg = "#001f3f" }) -- scrollbar
set_hl(0, "PmenuThumb",{ bg = "#00509e" }) -- scrollbar thumb
-- Casual stuff 
set_hl(0, "Normal",     { fg = "#f1faee", bg = "#00050f" })
set_hl(0, "Cursor",     { fg = "#00050f", bg = "#48cae4" })
set_hl(0, "LineNr",     { fg = "#5fa8d3", bg = "#00050f" })
set_hl(0, "Comment",    { fg = "#457b9d", italic = true })
set_hl(0, "Statement",  { fg = "#ff6b6b" })
set_hl(0, "Identifier", { fg = "#2ec4b6" })
set_hl(0, "Constant",   { fg = "#ffd166" })
set_hl(0, "Type",       { fg = "#48cae4" })
set_hl(0, "Special",    { fg = "#c77dff" })
set_hl(0, "Directory",  { fg = "#5fa8d3" })
set_hl(0, "Search",     { fg = "#00050f", bg = "#ffe066" })
vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.cursorline = true
set_hl(0, "LineNr", { fg = "#457b9d", bg = "#00050f" })
set_hl(0, "CursorLineNr", { fg = "#48cae4", bg = "#00050f", bold = true })
set_hl(0, "CursorLine",    { bg = "#090d35" })
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
