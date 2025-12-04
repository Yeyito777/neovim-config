-- Add this in lazyvim config
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
        flake8.args = vim.list_extend(flake8.args or {}, { "--ignore=E501" })
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
