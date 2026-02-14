return {
  -- Ensure the theme plugin is installed and loaded early
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },

  -- Tell LazyVim to actually use it
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-macchiato",
    },
  },
}
