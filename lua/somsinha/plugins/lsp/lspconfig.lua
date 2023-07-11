-- import lspconfig plugin safely
local lspconfig_status, lspconfig = pcall(require, "lspconfig")
if not lspconfig_status then
	return
end

-- import cmp-nvim-lsp plugin safely
local cmp_nvim_lsp_status, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
if not cmp_nvim_lsp_status then
	return
end

-- import typescript plugin safely
local typescript_setup, typescript = pcall(require, "typescript")
if not typescript_setup then
	return
end

local keymap = vim.keymap -- for conciseness

local home = os.getenv("HOME")
local jdtls = require("jdtls")

-- File types that signify a Java project's root directory. This will be
-- used by eclipse to determine what constitutes a workspace
local root_markers = { "gradlew", "mvnw", ".git" }
local root_dir = require("jdtls.setup").find_root(root_markers)

-- eclipse.jdt.ls stores project specific data within a folder. If you are working
-- with multiple different projects, each project must use a dedicated data directory.
-- This variable is used to configure eclipse to use the directory name of the
-- current project found using the root_marker as the folder for project specific data.
local workspace_folder = home .. "/.local/share/eclipse/" .. vim.fn.fnamemodify(root_dir, ":p:h:t")

-- Helper function for creating keymaps
function nnoremap(rhs, lhs, bufopts, desc)
	bufopts.desc = desc
	vim.keymap.set("n", rhs, lhs, bufopts)
end

-- enable keybinds only for when lsp server available
local on_attach = function(client, bufnr)
	-- keybind options
	local opts = { noremap = true, silent = true, buffer = bufnr }
	local bufopts = { noremap = true, silent = true, buffer = bufnr }

	-- set keybinds
	keymap.set("n", "gf", "<cmd>Lspsaga lsp_finder<CR>", opts) -- show definition, references
	keymap.set("n", "gD", "<Cmd>lua vim.lsp.buf.declaration()<CR>", opts) -- got to declaration
	keymap.set("n", "gd", "<cmd>Lspsaga peek_definition<CR>", opts) -- see definition and make edits in window
	keymap.set("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts) -- go to implementation
	keymap.set("n", "<leader>ca", "<cmd>Lspsaga code_action<CR>", opts) -- see available code actions
	keymap.set("n", "<leader>rn", "<cmd>Lspsaga rename<CR>", opts) -- smart rename
	keymap.set("n", "<leader>D", "<cmd>Lspsaga show_line_diagnostics<CR>", opts) -- show  diagnostics for line
	keymap.set("n", "<leader>d", "<cmd>Lspsaga show_cursor_diagnostics<CR>", opts) -- show diagnostics for cursor
	keymap.set("n", "[d", "<cmd>Lspsaga diagnostic_jump_prev<CR>", opts) -- jump to previous diagnostic in buffer
	keymap.set("n", "]d", "<cmd>Lspsaga diagnostic_jump_next<CR>", opts) -- jump to next diagnostic in buffer
	keymap.set("n", "K", "<cmd>Lspsaga hover_doc<CR>", opts) -- show documentation for what is under cursor
	keymap.set("n", "<leader>o", "<cmd>LSoutlineToggle<CR>", opts) -- see outline on right h knd side

	-- typescript specific keymaps (e.g. rename file and update imports)
	if client.name == "tsserver" then
		keymap.set("n", "<leader>rf", ":TypescriptRenameFile<CR>") -- rename file and update imports
		keymap.set("n", "<leader>oi", ":TypescriptOrganizeImports<CR>") -- organize imports (not in youtube nvim video)
		keymap.set("n", "<leader>ru", ":TypescriptRemoveUnused<CR>") -- remove unused variables (not in youtube nvim video)
	end

	if client.name == "jdtls" then
		nnoremap("gD", vim.lsp.buf.declaration, bufopts, "Go to declaration")
		nnoremap("gd", vim.lsp.buf.definition, bufopts, "Go to definition")
		nnoremap("gi", vim.lsp.buf.implementation, bufopts, "Go to implementation")
		nnoremap("K", vim.lsp.buf.hover, bufopts, "Hover text")
		nnoremap("<C-k>", vim.lsp.buf.signature_help, bufopts, "Show signature")
		nnoremap("<space>wa", vim.lsp.buf.add_workspace_folder, bufopts, "Add workspace folder")
		nnoremap("<space>wr", vim.lsp.buf.remove_workspace_folder, bufopts, "Remove workspace folder")
		nnoremap("<space>wl", function()
			print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
		end, bufopts, "List workspace folders")
		nnoremap("<space>D", vim.lsp.buf.type_definition, bufopts, "Go to type definition")
		nnoremap("<space>rn", vim.lsp.buf.rename, bufopts, "Rename")
		nnoremap("<space>ca", vim.lsp.buf.code_action, bufopts, "Code actions")
		vim.keymap.set(
			"v",
			"<space>ca",
			"<ESC><CMD>lua vim.lsp.buf.range_code_action()<CR>",
			{ noremap = true, silent = true, buffer = bufnr, desc = "Code actions" }
		)
		nnoremap("<space>f", function()
			vim.lsp.buf.format({ async = true })
		end, bufopts, "Format file")

		-- Java extensions provided by jdtls
		nnoremap("<C-o>", jdtls.organize_imports, bufopts, "Organize imports")
		nnoremap("<space>ev", jdtls.extract_variable, bufopts, "Extract variable")
		nnoremap("<space>ec", jdtls.extract_constant, bufopts, "Extract constant")
		vim.keymap.set(
			"v",
			"<space>em",
			[[<ESC><CMD>lua require('jdtls').extract_method(true)<CR>]],
			{ noremap = true, silent = true, buffer = bufnr, desc = "Extract method" }
		)
	end
end

-- used to enable autocompletion (assign to every lsp server config)
local capabilities = cmp_nvim_lsp.default_capabilities()

-- Change the Diagnostic symbols in the sign column (gutter)
-- (not in youtube nvim video)
local signs = { Error = " ", Warn = " ", Hint = "ﴞ ", Info = " " }
for type, icon in pairs(signs) do
	local hl = "DiagnosticSign" .. type
	vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
end

-- configure lua server (with special settings)
lspconfig["lua_ls"].setup({
	capabilities = capabilities,
	on_attach = on_attach,
	settings = { -- custom settings for lua
		Lua = {
			-- make the language server recognize "vim" global
			diagnostics = {
				globals = { "vim" },
			},
			workspace = {
				-- make language server aware of runtime files
				library = {
					[vim.fn.expand("$VIMRUNTIME/lua")] = true,
					[vim.fn.stdpath("config") .. "/lua"] = true,
				},
			},
		},
	},
})

local config = {
	cmd = { "/home/som/.local/share/nvim/mason/bin/jdtls" },
	root_dir = vim.fs.dirname(vim.fs.find({ "gradlew", ".git", "mvnw" }, { upward = true })[1]),
}

-- Finally, start jdtls. This will run the language server using the configuration we specified,
-- setup the keymappings, and attach the LSP client to the current buffer
jdtls.start_or_attach(config)
