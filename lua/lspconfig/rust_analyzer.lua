local configs = require 'lspconfig/configs'
local util = require 'lspconfig/util'
local lsp = vim.lsp

local function reload_workspace(bufnr)
  bufnr = util.validate_bufnr(bufnr)
  lsp.buf_request(bufnr, 'rust-analyzer/reloadWorkspace', nil, function(err, _, result, _)
    if err then
      error(tostring(err))
    end
    vim.notify 'Cargo workspace reloaded'
  end)
end

configs.rust_analyzer = {
  default_config = {
    cmd = { 'rust-analyzer' },
    filetypes = { 'rust' },
    root_dir = function(fname)
      local cargo_crate_dir = util.root_pattern 'Cargo.toml'(fname)
      local cmd = { 'cargo', 'metadata', '--no-deps', '--format-version', '1' }
      if cargo_crate_dir ~= nil then
        cmd[#cmd + 1] = '--manifest-path'
        cmd[#cmd + 1] = util.path.join(cargo_crate_dir, 'Cargo.toml')
      end
      local cargo_metadata = ''
      local cargo_metadata_err = ''
      local cm = vim.fn.jobstart(cmd, {
        on_stdout = function(j, d, e)
          cargo_metadata = table.concat(d, '\n')
        end,
        on_stderr = function(j, d, e)
          cargo_metadata_err = table.concat(d, '\n')
        end,
        stdout_buffered = true,
        stderr_buffered = true,
      })
      if cm > 0 then
        cm = vim.fn.jobwait({ cm })[1]
      else
        cm = -1
      end
      local cargo_workspace_dir = nil
      if cm == 0 then
        cargo_workspace_dir = vim.fn.json_decode(cargo_metadata)['workspace_root']
      else
        vim.notify(
          string.format('cmd [%q] failed:\n%s', table.concat(cmd, ' '), cargo_metadata_err),
          vim.log.levels.Warning
        )
      end
      return cargo_workspace_dir
        or cargo_crate_dir
        or util.root_pattern 'rust-project.json'(fname)
        or util.find_git_ancestor(fname)
    end,
    settings = {
      ['rust-analyzer'] = {},
    },
  },
  commands = {
    CargoReload = {
      function()
        reload_workspace(0)
      end,
      description = 'Reload current cargo workspace',
    },
  },
  docs = {
    package_json = 'https://raw.githubusercontent.com/rust-analyzer/rust-analyzer/master/editors/code/package.json',
    description = [[
https://github.com/rust-analyzer/rust-analyzer

rust-analyzer (aka rls 2.0), a language server for Rust

See [docs](https://github.com/rust-analyzer/rust-analyzer/tree/master/docs/user#settings) for extra settings.
    ]],
    default_config = {
      root_dir = [[root_pattern("Cargo.toml", "rust-project.json")]],
    },
  },
}

configs.rust_analyzer.reload_workspace = reload_workspace
