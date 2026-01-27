local config = require("codecompanion.config")

local M = {}

---Add attachment message method to Chat object
---@param attachment CodeCompanion.Attachment
---@param opts? table
---@return nil
function M.add_attachment_message(self, attachment, opts)
    opts = vim.tbl_deep_extend("force", {
        role = config.constants.USER_ROLE,
        source = "codecompanion._extensions.attachments",
        bufnr = attachment.bufnr,
    }, opts or {})

    local id = "<attachment>" .. (attachment.id or attachment.path) .. "</attachment>"

    self:add_message({
        role = opts.role,
        content = attachment.base64 or "",
    }, {
        context = {
            id = id,
            mimetype = attachment.mimetype,
            path = attachment.path or attachment.id,
            source = attachment.source,
            url = attachment.url,
            file_id = attachment.file_id,
        },
        _meta = { tag = "attachment" },
        visible = false,
    })

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
