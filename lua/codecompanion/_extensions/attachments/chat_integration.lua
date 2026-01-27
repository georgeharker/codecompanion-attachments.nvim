local config = require("codecompanion.config")
local log = require("codecompanion.utils.log")

local M = {}

---Add attachment message method to Chat object
---@param attachment CodeCompanion.Attachment
---@param opts? table
---@return nil
function M.add_attachment_message(self, attachment, opts)
	log:debug("=== ADD_ATTACHMENT_MESSAGE CALLED ===")
	log:debug(
		"Attachment: path=%s, source=%s, mimetype=%s, base64_length=%d",
		attachment.path or "nil",
		attachment.source or "nil",
		attachment.mimetype or "nil",
		attachment.base64 and #attachment.base64 or 0
	)

	opts = vim.tbl_deep_extend("force", {
		role = config.constants.USER_ROLE,
		source = "codecompanion._extensions.attachments",
		bufnr = attachment.bufnr,
	}, opts or {})

	local id = "<attachment>" .. (attachment.id or attachment.path) .. "</attachment>"

	local message_opts = {
		context = {
			id = id,
			mimetype = attachment.mimetype,
			path = attachment.path or attachment.id,
			source = attachment.source,
			url = attachment.url,
			file_id = attachment.file_id,
			attachment_type = attachment.mimetype and attachment.mimetype:match("^image/") and "image" or "document",
		},
		_meta = { tag = "attachment" },
		visible = false,
	}

	log:debug(
		"Calling self:add_message with context=%s, _meta=%s",
		vim.inspect(message_opts.context),
		vim.inspect(message_opts._meta)
	)

	self:add_message({
		role = opts.role,
		content = attachment.base64 or "",
	}, message_opts)

	log:debug("Message added to chat")

	self.context:add({
		bufnr = opts.bufnr,
		id = id,
		path = attachment.path or attachment.url or attachment.file_id,
		source = opts.source,
	})
end

---Integrate attachment support into Chat class
---@return nil
function M.integrate()
	local Chat = require("codecompanion.interactions.chat")

	-- Only add the method if it doesn't already exist
	if not Chat.add_attachment_message then
		Chat.add_attachment_message = M.add_attachment_message
	end
end

return M
