; extends
((fenced_code_block
  (info_string) @language
  (code_fence_content) @injection.content)
  (#eq? @language "zsh")
  (#set! injection.language "bash"))
