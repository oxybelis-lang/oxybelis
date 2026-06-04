vim.filetype.add {
  extension = { ox = "ox" },
  filename = { [".oxlintrc"] = "json" },
  pattern = {
    [".*%.ox$"] = "ox",
  },
}
