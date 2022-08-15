local function map(mode, lhs, rhs, opts)
	local options = { noremap = true }
	if opts then
		options = vim.tbl_extend("force", options, opts)
	end
	vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

map("n", "<c-s>", ":w<CR>")
map("i", "<c-s>", "<Esc>:w<CR>a")

map("n", "<A-Space>", ":NvimTreeToggle<CR>")

map("i", "<c-c>", "<c-[>")

map("n", ",ff", "<cmd>Telescope find_files<cr>")
map("n", ",fg", "<cmd>Telescope live_grep<cr>")
