local M = {}

-- nvim-treesitter's legacy `master` branch registers a few query predicates and
-- directives using Neovim <= 0.11's query-match shape, where `match[id]` was a
-- single TSNode.  Neovim 0.12 gives handlers a list of TSNodes for each
-- capture.  Calling `vim.treesitter.get_node_text()` with that list eventually
-- hits `node:range()` in the runtime and raises:
--
--   attempt to call method 'range' (a nil value)
--
-- Keep the legacy plugin working by replacing those handlers with versions that
-- accept either representation.  This can go away once the config is migrated to
-- the rewritten nvim-treesitter `main` branch.

local function first_node(capture)
  if type(capture) == "table" then
    return capture[1]
  end
  return capture
end

local function captured_node(match, id)
  return first_node(match[id])
end

local function add_predicate(query, name, handler)
  pcall(query.add_predicate, name, handler, { force = true })
end

local function add_directive(query, name, handler)
  pcall(query.add_directive, name, handler, { force = true })
end

local markdown_info_aliases = {
  ex = "elixir",
  pl = "perl",
  sh = "bash",
  uxn = "uxntal",
  ts = "typescript",
}

local function parser_from_markdown_info_string(alias)
  alias = (alias or ""):lower()
  return vim.filetype.match({ filename = "a." .. alias }) or markdown_info_aliases[alias] or alias
end

local html_script_type_languages = {
  importmap = "json",
  module = "javascript",
  ["application/ecmascript"] = "javascript",
  ["text/ecmascript"] = "javascript",
}

function M.setup()
  local ok, query = pcall(require, "vim.treesitter.query")
  if not ok then
    return
  end

  add_predicate(query, "nth?", function(match, _pattern, _source, pred)
    local node = captured_node(match, pred[2])
    local n = tonumber(pred[3])
    if node and n and node:parent() and node:parent():named_child_count() > n then
      return node:parent():named_child(n) == node
    end
    return false
  end)

  add_predicate(query, "is?", function(match, _pattern, source, pred)
    local node = captured_node(match, pred[2])
    if not node then
      return true
    end

    local ok_locals, locals = pcall(require, "nvim-treesitter.locals")
    if not ok_locals then
      return false
    end

    local _, _, kind = locals.find_definition(node, source)
    return vim.tbl_contains({ unpack(pred, 3) }, kind)
  end)

  add_predicate(query, "kind-eq?", function(match, _pattern, _source, pred)
    local node = captured_node(match, pred[2])
    if not node then
      return true
    end
    return vim.tbl_contains({ unpack(pred, 3) }, node:type())
  end)

  add_directive(query, "set-lang-from-mimetype!", function(match, _pattern, source, pred, metadata)
    local node = captured_node(match, pred[2])
    if not node then
      return
    end

    local type_attr_value = vim.treesitter.get_node_text(node, source)
    local parts = vim.split(type_attr_value, "/", {})
    metadata["injection.language"] = html_script_type_languages[type_attr_value] or parts[#parts]
  end)

  add_directive(query, "set-lang-from-info-string!", function(match, _pattern, source, pred, metadata)
    local node = captured_node(match, pred[2])
    if not node then
      return
    end

    local alias = vim.treesitter.get_node_text(node, source)
    metadata["injection.language"] = parser_from_markdown_info_string(alias)
  end)

  add_directive(query, "downcase!", function(match, _pattern, source, pred, metadata)
    local id = pred[2]
    local node = captured_node(match, id)
    if not node then
      return
    end

    metadata[id] = metadata[id] or {}
    metadata[id].text = string.lower(vim.treesitter.get_node_text(node, source, { metadata = metadata[id] }) or "")
  end)
end

return M
