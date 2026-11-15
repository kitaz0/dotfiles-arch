local colors = require("graphite.palette")

return {
  -- Install gruvbox
  {
    "ellisonleao/gruvbox.nvim",
    opts = {
      -- Gruvbox calls its normal/medium contrast "" (only "hard"/"soft" are named).
      contrast = "",
      palette_overrides = {
        dark0 = colors.background, dark1 = colors.surface, dark2 = colors.elevated,
        dark3 = colors.border, light1 = colors.foreground, light4 = colors.muted,
        dark0_hard = colors.background_hard, gray = colors.dim,
        neutral_red = colors.red_dim, neutral_green = colors.green_dim,
        neutral_yellow = colors.gold, neutral_blue = colors.blue_dim,
        neutral_purple = colors.purple_dim, neutral_orange = colors.orange_dim,
        faded_yellow = colors.gold_dim,
        bright_orange = colors.accent, bright_yellow = colors.yellow,
        bright_red = colors.red, bright_green = colors.green,
        bright_blue = colors.blue, bright_purple = colors.tertiary,
        bright_aqua = colors.secondary,
        neutral_aqua = colors.gold,
        faded_aqua = colors.gold_dim,
      },
      overrides = {
        CursorLineNr = { fg = colors.accent, bold = true },
        FloatBorder = { fg = colors.border },
        PmenuSel = { fg = colors.background, bg = colors.accent, bold = true },
        TabLineSel = { fg = colors.background, bg = colors.accent, bold = true },
        Directory = { fg = colors.secondary, bold = true },
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
