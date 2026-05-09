-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Shorten paths in all quickfix lists
_G.qf_text_func = function(info)
  local items = vim.fn.getqflist({ id = info.id, items = 1 }).items
  local result = {}
  for i = info.start_idx, info.end_idx do
    local item = items[i]
    -- item.text is already the full formatted line from the file
    -- just shorten the filepath portion within it
    local text = item.text:gsub("([^%s]+/[^%s]+%.java)", function(path)
      return path:match("[^/]+/[^/]+$") or path
    end)
    table.insert(result, text)
  end
  return result
end
vim.o.quickfixtextfunc = "v:lua.qf_text_func"
