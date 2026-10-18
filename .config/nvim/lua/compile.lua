-- Emacs-style M-x compile. Each project (git root, or cwd) remembers its own
-- shell command across sessions. Output goes to a *compilation* pane at the
-- bottom, which closes when the command exits (<leader>co reopens it), and is
-- parsed into the quickfix list, so ]q / [q walk the errors.
-- Compiler-style "file:line:col:" errors and Godot "(res://file:line)" ones.
--
-- In the *compilation* buffer: <CR> jump to error, r rerun, <C-c> stop, q close
local M = {}

local store = vim.fn.stdpath("data") .. "/compile-commands.json"
local ns = vim.api.nvim_create_namespace("compile")
local buf, job, last

local function read_store()
  local ok, data = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(store), "\n"))
  end)
  return ok and data or {}
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

-- follow the output, unless the user is in the window looking around
local function append(lines)
  set_lines(-1, lines)
  local win = vim.fn.bufwinid(buf)
  if win ~= -1 and win ~= vim.api.nvim_get_current_win() then
    vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
  end
end

-- the first line is a make-style "Entering directory" message, so 'errorformat'
-- resolves relative paths against the compile dir, not nvim's cwd
local function parse(lines)
  local items = vim.fn.getqflist({ lines = lines, efm = vim.go.errorformat }).items
  -- %f matches almost anything, e.g. "built (2026-08-17 01:18:38 UTC)" reads as
  -- file "built (2026-08-17 01", line 18, so only trust files that exist
  for _, item in ipairs(items) do
    if item.valid == 1 and vim.fn.filereadable(vim.api.nvim_buf_get_name(item.bufnr)) == 0 then
      item.valid = 0
    end
  end
  return items
end

-- Godot error locations look like "   at: helper (res://scenes/main.gd:11)".
-- Rewrite them to "scenes/main.gd:11: <msg>", which 'errorformat' understands.
-- res:// is the project root, assumed to be the compile dir.
local function godot_line(line, msg)
  local file, lnum = line:match("%(res://(.-):(%d+)%)%s*$")
  return file and ("%s:%s: %s"):format(file, lnum, msg or line)
end

-- A Godot error is a "KIND: message" line followed by indented lines, where
-- the first res:// one is the script location (for push_error that's the [0]
-- backtrace frame, the "at:" line points into Godot's C++). Give each error a
-- single quickfix entry with that location and the message.
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

-- jump to the location on this line, or on the indented lines below it, so
-- <CR> also works on a Godot "ERROR: ..." line
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
  vim.keymap.set("n", "r", function() M.recompile() end, opts)
  vim.keymap.set("n", "<C-c>", function() M.stop() end, opts)
  vim.keymap.set("n", "q", "<cmd>close<cr>", opts)
end

-- header: command on the left (truncated first), run status on the right
local function update_bar()
  local win = vim.fn.bufwinid(buf)
  if win == -1 then return end
  local cmd = last.cmd:gsub("%%", "%%%%")
  vim.wo[win][0].winbar = (" %%<%s%%= %%#%s#%s %%*"):format(cmd, last.hl, last.status)
end

local function show()
  if vim.fn.bufwinid(buf) == -1 then
    local win = vim.api.nvim_open_win(buf, false, { split = "below", win = -1, height = 15 })
    -- setlocal, so a split made from this window doesn't inherit the look
    local wo = vim.wo[win][0]
    wo.number = false
    wo.relativenumber = false
    wo.signcolumn = "no"
    wo.colorcolumn = ""
    wo.fillchars = "eob: "
    -- own background, so the pane doesn't blend into the code or the cmdline
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
      -- data[1] continues the previous chunk's unfinished line
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
        msg, last.hl, level = ("Compilation exited abnormally with code %d"):format(code), "DiagnosticError", vim.log.levels.ERROR
        last.status = ("✗ exit %d (%.2fs)"):format(code, secs)
      end
      msg = ("%s (%.2fs)"):format(msg, secs)
      append({ "", msg })
      vim.api.nvim_buf_set_extmark(buf, ns, vim.api.nvim_buf_line_count(buf) - 1, 0, {
        end_col = #msg,
        hl_group = last.hl,
      })
      update_bar()

      -- errors only: in a list without valid entries :cnext walks every entry,
      -- and the full output is in the pane anyway
      local items = vim.iter(parse(qf_lines(vim.api.nvim_buf_get_lines(buf, 0, -1, false))))
          :filter(function(i) return i.valid == 1 end)
          :totable()
      local errors = #items
      -- ]q moves past the current entry, which starts as the first one, so
      -- lead with a text-only entry to have ]q land on the first error
      if errors > 0 then
        table.insert(items, 1, { text = "compile: " .. cmd, valid = 0 })
      end
      vim.fn.setqflist({}, " ", { title = cmd, items = items })

      -- get out of the way (<leader>co brings it back), unless the user is in
      -- the pane reading it
      local win = vim.fn.bufwinid(buf)
      if win ~= -1 and win ~= vim.api.nvim_get_current_win() then
        pcall(vim.api.nvim_win_close, win, false)
      end
      vim.notify(
        ("compile: %s%s"):format(last.status, errors > 0 and (", %d error%s"):format(errors, errors == 1 and "" or "s") or ""),
        level
      )
    end,
  })
  job = id
end

local function save_and_run(root, cmd)
  local cmds = read_store()
  cmds[root] = cmd
  vim.fn.mkdir(vim.fs.dirname(store), "p")
  vim.fn.writefile({ vim.json.encode(cmds) }, store)
  run(cmd, root)
end

-- prompt for this project's command (prefilled with the current one), then run
function M.compile()
  local root = project_root()
  local opts = { prompt = "Compile command: ", default = read_store()[root] or "", kind = "compile" }
  vim.ui.input(opts, function(cmd)
    if cmd and cmd ~= "" then save_and_run(root, cmd) end
  end)
end

-- run this project's command, asking for it the first time
function M.recompile()
  local root = project_root()
  local cmd = read_store()[root]
  if cmd then run(cmd, root) else M.compile() end
end

-- stop the running command
function M.stop()
  if not job then
    return vim.notify("compile: nothing running")
  end
  last.stopped = true
  vim.fn.jobstop(job)
end

-- show or hide the output pane of the last run
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
  if o.args == "" then M.compile() else save_and_run(project_root(), o.args) end
end, { nargs = "*" })
vim.api.nvim_create_user_command("Recompile", M.recompile, {})

vim.keymap.set("n", "<leader>cc", M.recompile, { desc = "[C]ompile: run project command" })
vim.keymap.set("n", "<leader>ce", M.compile, { desc = "[C]ompile: [E]dit command and run" })
vim.keymap.set("n", "<leader>co", M.toggle, { desc = "[C]ompile: toggle [O]utput pane" })
vim.keymap.set("n", "<leader>cq", M.stop, { desc = "[C]ompile: [Q]uit running command" })

return M
