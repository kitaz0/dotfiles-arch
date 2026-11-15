local colors = require("graphite.palette")

return {
  {
    "folke/snacks.nvim",
    opts = {
      lazygit = {
        -- Keep Snacks integration; share the standalone Lazygit contrast choices.
        config = { gui = { theme = {
          activeBorderColor = { colors.accent, "bold" },
          inactiveBorderColor = { colors.border },
          searchingActiveBorderColor = { colors.secondary, "bold" },
          optionsTextColor = { colors.secondary },
          defaultFgColor = { colors.foreground },
          selectedLineBgColor = { colors.surface },
          selectedLineFgColor = { colors.foreground, "bold" },
          inactiveViewSelectedLineBgColor = { colors.surface },
        } } },
      },
    },
  },
}
