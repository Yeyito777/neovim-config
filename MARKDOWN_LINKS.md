# Markdown links

Markdown links render as cyan, underlined `[labels]`, matching the existing Type
highlight (including terminal-color fallbacks). Concealment only changes display;
the file on disk remains ordinary Markdown.

Normal mode, in Markdown buffers:

- Enter or gx on a parsed link: open with xdg-open (macOS open fallback).
- Left click a label: open it. Terminal mouse reporting must be supported.
- Space m e: toggle the current link's source for editing; press i/a normally.
- Space m a: toggle all links' source in the current buffer. Collapsing all also
  clears individual expansions.
- :MarkdownLinkToggle / :MarkdownLinksToggle are the command equivalents.

Links stay collapsed on the cursor line, including insert mode, unless explicitly
expanded. Use Enter to open while collapsed; use Space m e before editing a URL.
Enter elsewhere retains its normal next-line behavior. Mouse support is enabled
globally so the terminal sends clicks to Neovim.

Supports inline links (including balanced parentheses and titles), reference links,
and angle-bracket URL/email autolinks. Code spans/fences are not treated as links.
Reference expansion shows the original [label][reference] syntax; edit its matching
[reference]: URL definition to change its destination. Standalone #anchor links
are recognized but do not launch an external application. Relative file links are
resolved from the Markdown file's directory. Images are not interactive links.

Implementation: lua/markdown_links.lua, loaded at the end of init.lua. The local
queries/markdown_inline/highlights.scm override keeps Tree-sitter from separately
concealing link syntax, so individual expansion works. Other Markdown punctuation
stays visible, as in the original configuration. Keep this override in mind when
upgrading the Markdown parser/query package.

Original init.lua backup: backups/native-wrap-20260914-121046/init.lua

Restart Neovim to load everything. For an already-running Neovim, use:

    :lua require('markdown_links').setup()

If that session has already cached its old Tree-sitter highlighting query, restart
Neovim instead. Do not source all of init.lua repeatedly (unrelated plugins are not
necessarily reload-safe).
