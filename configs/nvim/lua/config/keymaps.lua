-- Keymaps
-- Leader is <Space>

local map = vim.keymap.set

-- Better window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })

-- Resize windows
map("n", "<C-Up>", ":resize +2<CR>", { silent = true })
map("n", "<C-Down>", ":resize -2<CR>", { silent = true })
map("n", "<C-Left>", ":vertical resize -2<CR>", { silent = true })
map("n", "<C-Right>", ":vertical resize +2<CR>", { silent = true })

-- Buffers
map("n", "<S-l>", ":bnext<CR>", { silent = true, desc = "Next buffer" })
map("n", "<S-h>", ":bprevious<CR>", { silent = true, desc = "Prev buffer" })
map("n", "<leader>bd", ":bdelete<CR>", { silent = true, desc = "Delete buffer" })

-- Clear search highlight
map("n", "<Esc>", ":nohlsearch<CR>", { silent = true, desc = "Clear search" })

-- Stay in indent mode
map("v", "<", "<gv", { silent = true })
map("v", ">", ">gv", { silent = true })

-- Move lines up/down
map("v", "J", ":m '>+1<CR>gv=gv", { silent = true })
map("v", "K", ":m '<-2<CR>gv=gv", { silent = true })

-- Keep cursor centered
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- Don't lose yank when pasting over selection
map("x", "p", [["_dP]])

-- Save / quit shortcuts
map("n", "<leader>w", ":w<CR>", { silent = true, desc = "Save" })
map("n", "<leader>q", ":q<CR>", { silent = true, desc = "Quit" })

-- Plugin shortcuts
map("n", "<leader>e", ":Neotree toggle<CR>", { silent = true, desc = "File explorer" })
map("n", "<leader>ff", ":Telescope find_files<CR>", { silent = true, desc = "Find files" })
map("n", "<leader>fg", ":Telescope live_grep<CR>", { silent = true, desc = "Grep" })
map("n", "<leader>fb", ":Telescope buffers<CR>", { silent = true, desc = "Buffers" })
map("n", "<leader>fr", ":Telescope oldfiles<CR>", { silent = true, desc = "Recent files" })
map("n", "<leader>gg", ":LazyGit<CR>", { silent = true, desc = "LazyGit" })
