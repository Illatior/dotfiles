local M = {}

local config = {
  history = 10, -- per project
}

local store = vim.fn.stdpath("data") .. "/compile-commands.json"
local ns = vim.api.nvim_create_namespace("compile")
local buf, job, last
local launch -- runs a command and remembers it, defined below run()

function M.setup(opts)
  config = vim.tbl_extend("force", config, opts or {})
end

-- { [root] = { default = cmd, saved = { { cmd = cmd, name = name? } }, history = { newest cmd, ... } } }
local function read_store()
  local ok, data = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(store), "\n"))
  end)
  return ok and data or {}
end

local function project(data, root)
  local p = data[root] or {}
  if type(p) == "string" then
    p = { default = p, history = { p } }
  end
  p.saved = p.saved or {}
  p.history = p.history or {}
  return p
end

local function get(root)
  return project(read_store(), root)
end

local function update(root, fn)
  local data = read_store()
  local p = project(data, root)
  fn(p)
  data[root] = (p.default or #p.saved > 0 or #p.history > 0) and p or nil
  vim.fn.mkdir(vim.fs.dirname(store), "p")
  vim.fn.writefile(vim.split(vim.json.encode(data, { indent = "  " }), "\n"), store)
end

local function project_root()
  if last and vim.api.nvim_get_current_buf() == buf then
    return last.cwd
  end
  return vim.fs.root(0, ".git") or vim.fn.getcwd()
end

local function set_lines(start, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, start, -1, false, lines)
  vim.bo[buf].modifiable = false
end

local function append(lines)
  set_lines(-1, lines)
  local win = vim.fn.bufwinid(buf)
  if win ~= -1 and win ~= vim.api.nvim_get_current_win() then
    vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
  end
end

local function parse(lines)
  local items = vim.fn.getqflist({ lines = lines, efm = vim.go.errorformat }).items
  for _, item in ipairs(items) do
    if item.valid == 1 and vim.fn.filereadable(vim.api.nvim_buf_get_name(item.bufnr)) == 0 then
      item.valid = 0
    end
  end
  return items
end

local function godot_line(line, msg)
  local file, lnum = line:match("%(res://(.-):(%d+)%)%s*$")
  return file and ("%s:%s: %s"):format(file, lnum, msg or line)
end

local function qf_lines(lines)
  local out, header = {}, nil
  for i, line in ipairs(lines) do
    out[i] = line
    if line:match("^%u[%u ]*: ") then
      header = line
    elseif not line:match("^%s") then
      header = nil
    elseif header and godot_line(line) then
      out[i] = godot_line(line, header)
      header = nil
    end
  end
  return out
end

local function jump()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local lines = { vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] }
  for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, row - 1, -1, false)) do
    if i > 1 and not line:match("^%s") then break end
    table.insert(lines, godot_line(line) or line)
  end
  local item = vim.iter(parse(lines)):find(function(i) return i.valid == 1 and i.bufnr > 0 end)
  if not item then return end

  vim.cmd("wincmd p")
  if vim.api.nvim_get_current_buf() == buf then
    vim.cmd("aboveleft split")
  end
  vim.cmd.edit(vim.fn.fnameescape(vim.api.nvim_buf_get_name(item.bufnr)))
  pcall(vim.api.nvim_win_set_cursor, 0, { math.max(item.lnum, 1), math.max(item.col - 1, 0) })
end

local function get_buf()
  if buf and vim.api.nvim_buf_is_loaded(buf) then return end
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
  buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "*compilation*")

  local opts = { buffer = buf, nowait = true }
  vim.keymap.set("n", "<CR>", jump, opts)
  vim.keymap.set("n", "r", function() launch(last.cwd, last.cmd) end, opts)
  vim.keymap.set("n", "<C-c>", function() M.stop() end, opts)
  vim.keymap.set("n", "q", "<cmd>close<cr>", opts)
end

local function update_bar()
  local win = vim.fn.bufwinid(buf)
  if win == -1 then return end
  local cmd = last.cmd:gsub("%%", "%%%%")
  vim.wo[win][0].winbar = (" %%<%s%%= %%#%s#%s %%*"):format(cmd, last.hl, last.status)
end

local function show()
  if vim.fn.bufwinid(buf) == -1 then
    local win = vim.api.nvim_open_win(buf, false, { split = "below", win = -1, height = 15 })
    local wo = vim.wo[win][0]
    wo.number = false
    wo.relativenumber = false
    wo.signcolumn = "no"
    wo.colorcolumn = ""
    wo.fillchars = "eob: "
    wo.winhighlight = "Normal:NormalFloat,WinBar:StatusLine,WinBarNC:StatusLine"
  end
  update_bar()
end

local function run(cmd, cwd)
  if job then vim.fn.jobstop(job) end
  vim.cmd("silent! wall")
  last = { cmd = cmd, cwd = cwd, hl = "DiagnosticWarn", status = "Running…" }

  get_buf()
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  set_lines(0, { ("compile: Entering directory '%s'"):format(cwd), "" })
  show()

  local start, partial, id = vim.uv.hrtime(), "", nil
  id = vim.fn.jobstart({ vim.o.shell, "-c", "exec 2>&1; " .. cmd }, {
    cwd = cwd,
    on_stdout = function(_, data)
      if id ~= job then return end
      data[1] = partial .. data[1]
      partial = table.remove(data)
      for i, line in ipairs(data) do
        data[i] = line:gsub("\r$", "")
      end
      if #data > 0 then append(data) end
    end,
    on_exit = function(_, code)
      if id ~= job then return end
      job = nil
      if partial ~= "" then append({ partial }) end

      local secs = (vim.uv.hrtime() - start) / 1e9
      local msg, level
      if last.stopped then
        msg, last.hl, level = "Compilation interrupted", "DiagnosticWarn", vim.log.levels.WARN
        last.status = ("■ stopped (%.2fs)"):format(secs)
      elseif code == 0 then
        msg, last.hl, level = "Compilation finished", "DiagnosticOk", vim.log.levels.INFO
        last.status = ("✓ finished (%.2fs)"):format(secs)
      else
        msg, last.hl, level = ("Compilation exited abnormally with code %d"):format(code), "DiagnosticError",
            vim.log.levels.ERROR
        last.status = ("✗ exit %d (%.2fs)"):format(code, secs)
      end
      msg = ("%s (%.2fs)"):format(msg, secs)
      append({ "", msg })
      vim.api.nvim_buf_set_extmark(buf, ns, vim.api.nvim_buf_line_count(buf) - 1, 0, {
        end_col = #msg,
        hl_group = last.hl,
      })
      update_bar()

      local items = vim.iter(parse(qf_lines(vim.api.nvim_buf_get_lines(buf, 0, -1, false))))
          :filter(function(i) return i.valid == 1 end)
          :totable()
      local errors = #items
      if errors > 0 then
        table.insert(items, 1, { text = "compile: " .. cmd, valid = 0 })
      end
      vim.fn.setqflist({}, " ", { title = cmd, items = items })

      local win = vim.fn.bufwinid(buf)
      if win ~= -1 and (last.stopped or win ~= vim.api.nvim_get_current_win()) then
        pcall(vim.api.nvim_win_close, win, false)
      end
      vim.notify(
        ("compile: %s%s"):format(last.status,
          errors > 0 and (", %d error%s"):format(errors, errors == 1 and "" or "s") or ""),
        level
      )
    end,
  })
  job = id
end

launch = function(root, cmd, make_default)
  update(root, function(p)
    if make_default or not p.default then p.default = cmd end
    local history = vim.tbl_filter(function(c) return c ~= cmd end, p.history)
    table.insert(history, 1, cmd)
    p.history = vim.list_slice(history, 1, config.history)
  end)
  run(cmd, root)
end

local function input(default, on_cmd)
  vim.ui.input({ prompt = "Compile command: ", default = default, kind = "compile" }, function(cmd)
    if cmd and cmd ~= "" then on_cmd(cmd) end
  end)
end

function M.compile()
  local root = project_root()
  input(get(root).default or "", function(cmd) launch(root, cmd, true) end)
end

function M.recompile()
  local root = project_root()
  local cmd = get(root).default
  if cmd then launch(root, cmd) else M.compile() end
end

local function finder(root)
  local p = get(root)
  local items, seen, width = {}, {}, 0
  local function add(cmd, saved, name)
    if seen[cmd] then return end
    seen[cmd] = true
    table.insert(items, { cmd = cmd, saved = saved, name = name })
    width = math.max(width, vim.fn.strdisplaywidth(name or ""))
  end
  for _, s in ipairs(p.saved) do add(s.cmd, true, s.name) end
  if p.default then add(p.default) end
  for _, cmd in ipairs(p.history) do add(cmd) end

  local columns = { { width = 1 }, { width = 1 } }
  if width > 0 then table.insert(columns, { width = width }) end
  table.insert(columns, { remaining = true })
  local displayer = require("telescope.pickers.entry_display").create({ separator = " ", items = columns })

  return require("telescope.finders").new_table({
    results = items,
    entry_maker = function(item)
      return {
        value = item,
        ordinal = (item.name or "") .. " " .. item.cmd,
        display = function()
          local row = {
            item.cmd == p.default and { "●", "DiagnosticOk" } or " ",
            item.saved and { "★", "DiagnosticWarn" } or " ",
          }
          if width > 0 then table.insert(row, { item.name or "", "Title" }) end
          table.insert(row, item.cmd)
          return displayer(row)
        end,
      }
    end,
  })
end

function M.pick(root)
  root = root or project_root()
  local actions = require("telescope.actions")
  local state = require("telescope.actions.state")
  local opts = require("telescope.themes").get_dropdown({
    previewer = false,
    prompt_title = "Compile in " .. vim.fn.fnamemodify(root, ":~"),
    results_title = "<CR> run  <C-e> edit  <C-d> default  <C-s> save  <C-x> remove",
  })

  require("telescope.pickers").new(opts, {
    finder = finder(root),
    sorter = require("telescope.config").values.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      local function selected()
        local entry = state.get_selected_entry()
        return entry and entry.value or { cmd = vim.trim(state.get_current_line()) }
      end
      local function refresh()
        state.get_current_picker(prompt_bufnr):refresh(finder(root), { reset_prompt = false })
      end
      local function close_then(fn)
        actions.close(prompt_bufnr)
        vim.schedule(fn)
      end

      actions.select_default:replace(function()
        local cmd = selected().cmd
        if cmd ~= "" then close_then(function() launch(root, cmd) end) end
      end)
      map({ "i", "n" }, "<C-e>", function()
        local cmd = selected().cmd
        close_then(function() input(cmd, function(c) launch(root, c) end) end)
      end)
      map({ "i", "n" }, "<C-d>", function()
        local entry = state.get_selected_entry()
        if not entry then return end
        update(root, function(p) p.default = entry.value.cmd end)
        refresh()
      end)
      map({ "i", "n" }, "<C-s>", function()
        local entry = state.get_selected_entry()
        if not entry then return end
        local item = entry.value
        close_then(function()
          vim.ui.input({ prompt = "Name (optional): ", default = item.name or "", kind = "compile" }, function(name)
            if name then
              update(root, function(p)
                local s = vim.iter(p.saved):find(function(x) return x.cmd == item.cmd end)
                if not s then
                  s = { cmd = item.cmd }
                  table.insert(p.saved, s)
                end
                name = vim.trim(name)
                s.name = name ~= "" and name or nil
              end)
            end
            M.pick(root)
          end)
        end)
      end)
      map({ "i", "n" }, "<C-x>", function()
        local entry = state.get_selected_entry()
        if not entry then return end
        local cmd = entry.value.cmd
        update(root, function(p)
          if entry.value.saved then
            p.saved = vim.tbl_filter(function(s) return s.cmd ~= cmd end, p.saved)
            return
          end
          p.history = vim.tbl_filter(function(c) return c ~= cmd end, p.history)
          if p.default == cmd then p.default = nil end
        end)
        refresh()
      end)
      return true
    end,
  }):find()
end

function M.stop()
  if not job then
    return vim.notify("compile: nothing running")
  end
  last.stopped = true
  vim.fn.jobstop(job)
end

function M.toggle()
  local win = buf and vim.fn.bufwinid(buf) or -1
  if win ~= -1 then
    pcall(vim.api.nvim_win_close, win, false)
  elseif last and vim.api.nvim_buf_is_loaded(buf) then
    show()
  else
    vim.notify("Nothing compiled yet")
  end
end

vim.api.nvim_create_user_command("Compile", function(o)
  if o.args == "" then M.compile() else launch(project_root(), o.args, true) end
end, { nargs = "*" })
vim.api.nvim_create_user_command("Recompile", M.recompile, {})

vim.keymap.set("n", "<leader>cc", M.recompile, { desc = "[C]ompile: run project default command" })
vim.keymap.set("n", "<leader>ce", M.compile, { desc = "[C]ompile: [E]dit default command and run" })
vim.keymap.set("n", "<leader>cp", function() M.pick() end, { desc = "[C]ompile: [P]ick a project command" })
vim.keymap.set("n", "<leader>co", M.toggle, { desc = "[C]ompile: toggle [O]utput pane" })
vim.keymap.set("n", "<leader>cq", M.stop, { desc = "[C]ompile: [Q]uit running command" })

return M
