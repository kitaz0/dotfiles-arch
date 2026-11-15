return {
  {
    "folke/snacks.nvim",
    opts = {
      lazygit = {
        theme = {
          activeBorderColor = { fg = "GruvboxOrange", bold = true },
          searchingActiveBorderColor = { fg = "GruvboxYellow", bold = true },
          optionsTextColor = { fg = "GruvboxYellow" },
          -- Snacks generates a separate theme when launching Lazygit from Neovim.
          -- NormalFloat supplies cream text on the darker Gruvbox surface.
          selectedLineBgColor = { bg = "NormalFloat" },
          selectedLineFgColor = { fg = "NormalFloat", bold = true },
        },
      },
    },
  },
}
