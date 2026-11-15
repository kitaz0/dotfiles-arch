return {
  -- Install gruvbox
  {
    "ellisonleao/gruvbox.nvim",
    opts = {
      -- Gruvbox calls its normal/medium contrast "" (only "hard"/"soft" are named).
      contrast = "",
      palette_overrides = {
        bright_aqua = "#fabd2f",
        neutral_aqua = "#d79921",
        faded_aqua = "#b57614",
      },
      overrides = {
        CursorLineNr = { fg = "#fe8019", bold = true },
        FloatBorder = { fg = "#665c54" },
        PmenuSel = { fg = "#282828", bg = "#fe8019", bold = true },
        TabLineSel = { fg = "#282828", bg = "#fe8019", bold = true },
        Directory = { fg = "#fabd2f", bold = true },
      },
    },
  },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox",
    },
  },
}
