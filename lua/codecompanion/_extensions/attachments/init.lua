local M = {}

---@class CodeCompanion.Extension.Attachments.Config
---@field adapters? table Custom adapter transformers
local defaults = {
	adapters = {},
}

---@type CodeCompanion.Extension.Attachments.Config
M.config = vim.deepcopy(defaults)

---Setup the extension
---@param opts? CodeCompanion.Extension.Attachments.Config
---@return nil
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})

	-- Install adapter patches
	local adapter_patches = require("codecompanion._extensions.attachments.adapter_patches")
	adapter_patches.install()

	-- Register any custom adapter transformers
	for adapter_name, transformer in pairs(M.config.adapters) do
		adapter_patches.register_transformer(adapter_name, transformer)
	end

	-- Integrate chat methods
	local chat_integration = require("codecompanion._extensions.attachments.chat_integration")
	chat_integration.integrate()

	-- Register slash command in CodeCompanion config
	local ok, config = pcall(require, "codecompanion.config")
	if ok and config.interactions and config.interactions.chat and config.interactions.chat.slash_commands then
		-- Get provider from image slash command or default
		local provider = config.interactions.chat.slash_commands.image
				and config.interactions.chat.slash_commands.image.opts
				and config.interactions.chat.slash_commands.image.opts.provider
			or require("codecompanion.providers").pickers

		config.interactions.chat.slash_commands["attachment"] = {
			callback = "codecompanion._extensions.attachments.slash_command",
			description = "Upload documents and images as attachments",
			enabled = require("codecompanion._extensions.attachments.slash_command").enabled,
			opts = {
				contains_code = false,
				dirs = {}, -- Directories to search for attachments
				provider = provider, -- Use same provider as image command
			},
		}
	end

	-- Load debug helpers (creates user commands)
	require("codecompanion._extensions.attachments.debug_helpers")

	local log = require("codecompanion.utils.log")
	log:info("attachments extension loaded")
end

---Extension exports for CodeCompanion
M.exports = {
	slash_commands = {
		attachment = require("codecompanion._extensions.attachments.slash_command"),
	},
}

---CodeCompanion.Extension interface
---@class CodeCompanion.Extension.Attachments
local Extension = {
	setup = M.setup,
	exports = M.exports,
}

return Extension
