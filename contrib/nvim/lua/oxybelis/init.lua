local M = {}

local lsp_cmd = vim.fn.executable("ox-lsp") == 1 and { "ox-lsp" }
  or vim.fn.executable("python") == 1 and { "python", "ox_lsp.py" }
  or nil

function M.setup(opts)
  opts = opts or {}
  local on_attach = opts.on_attach or function(client, bufnr)
    local bufopts = { noremap = true, silent = true, buffer = bufnr }
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, bufopts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, bufopts)
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, bufopts)
    vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, bufopts)
    vim.keymap.set("n", "<leader>wa", vim.lsp.buf.add_workspace_folder, bufopts)
    vim.keymap.set("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, bufopts)
    vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition, bufopts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, bufopts)
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, bufopts)
    vim.keymap.set("n", "gr", vim.lsp.buf.references, bufopts)
    vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, bufopts)
    vim.keymap.set("n", "]d", vim.diagnostic.goto_next, bufopts)
    vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, bufopts)
    vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, bufopts)

    if client.server_capabilities.documentFormattingProvider then
      vim.keymap.set("n", "<leader>f", function()
        vim.lsp.buf.format({ async = true })
      end, bufopts)
    end
  end

  local capabilities = vim.lsp.protocol.make_client_capabilities()
  if opts.capabilities then
    capabilities = vim.tbl_deep_extend("force", capabilities, opts.capabilities)
  end

  vim.api.nvim_create_autocmd("FileType", {
    pattern = "ox",
    callback = function()
      if lsp_cmd then
        vim.lsp.start({
          name = "ox-lsp",
          cmd = lsp_cmd,
          root_dir = vim.fs.dirname(vim.fs.find({
            ".git",
            "*.ox",
          }, { upward = true })[1]),
          on_attach = on_attach,
          capabilities = capabilities,
        })
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = { "*.ox" },
    callback = function()
      vim.diagnostic.reset(nil, 0)
      vim.cmd("checktime")
    end,
  })
end

return M
