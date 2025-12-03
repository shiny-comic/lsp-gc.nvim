local M = {}

M.config = {
  -- stop all lsps after nvim lost focus for more than `ms`
  stop_after_ms = 1000 * 60 * 15,
  -- exclude these lsps
  exclude = { "null-ls" },
}

local stopped_lsps = {}

local inactivity_timer = nil

M.need_startup = false

function M.stop_lsps()
  stopped_lsps = {}
  M.need_startup = true

  local clients = vim.iter(vim.lsp.get_clients())
      :filter(function(c)
        return not vim.list_contains(M.config.exclude, c.name)
      end)
      :totable()

  for _, v in ipairs(clients) do
    table.insert(stopped_lsps, v.name)
    vim.lsp.enable(v.name, false)
    vim.notify(v.name .. " has stopped", vim.log.levels.INFO, { title = "lsp-gc" })
  end
end

function M.start_stopped_lsps()
  for _, v in ipairs(stopped_lsps) do
    vim.lsp.enable(v, true)
    vim.notify("starting " .. v.name, vim.log.levels.INFO, { title = "lsp-gc" })
  end

  vim.schedule(function() vim.cmd('doautocmd BufEnter') end)
end

function setup_inactivity_timer()
  if inactivity_timer then
    vim.notify(inactivity_timer:get_due_in() .. " seconds remain", vim.log.levels.DEBUG, { title = "lsp-gc" })
  end
  if M.need_startup then
    vim.schedule_wrap(M.start_stopped_lsps)
  end
  if inactivity_timer then
    inactivity_timer:stop()
  end
  M.need_startup = false
  inactivity_timer = vim.uv.new_timer()
  inactivity_timer:start(M.config.stop_after_ms, 0, vim.schedule_wrap(M.stop_lsps))
end

function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts)

  vim.api.nvim_create_autocmd({ "LspAttach", "InsertEnter", "InsertLeave", "CursorMoved" }, {
    callback = setup_inactivity_timer,
  })
end

return M
