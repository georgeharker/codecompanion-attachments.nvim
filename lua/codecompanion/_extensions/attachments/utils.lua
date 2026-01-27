local M = {}

---Attachment types configuration
---@type table<string, { extensions: string[], max_size_mb: number }>
local ATTACHMENT_TYPES = {
    image = {
        extensions = { "png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "svg" },
        max_size_mb = 10,
    },
    document = {
        extensions = { "pdf", "rtf", "docx", "csv", "xlsx", "pptx" },
        max_size_mb = 32,
    },
}

---Attachment-specific MIME types
---@type table<string, string>
local ATTACHMENT_MIME_TYPES = {
    -- Extended image types
    bmp = "image/bmp",
    tiff = "image/tiff",
    svg = "image/svg+xml",
    -- Document types
    rtf = "text/rtf",
    xlsx = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    pptx = "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    csv = "text/csv",
    docx = "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    pdf = "application/pdf",
    -- Common image types
    png = "image/png",
    jpg = "image/jpeg",
    jpeg = "image/jpeg",
    gif = "image/gif",
    webp = "image/webp",
}

---Keep track of temp files, and GC them at VimLeavePre
---@type string[]
local temp_files = {}

vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
        vim.iter(temp_files):each(function(p)
            (vim.uv or vim.loop).fs_unlink(p)
        end)
    end,
    group = vim.api.nvim_create_augroup("codecompanion_attachments", { clear = true }),
    desc = "Clear temporary attachment files.",
})

---@class CodeCompanion.Attachment
---@field id string
---@field path string
---@field bufnr? integer
---@field base64? string
---@field mimetype? string
---@field source? string "base64"|"url"|"file"
---@field url? string
---@field file_id? string
---@field attachment_type? string "image"|"document"

---Get image file extensions
---@return string[]
function M.get_image_filetypes()
    return vim.deepcopy(ATTACHMENT_TYPES.image.extensions)
end

---Get document file extensions
---@return string[]
function M.get_document_filetypes()
    return vim.deepcopy(ATTACHMENT_TYPES.document.extensions)
end

---Get all supported file extensions
---@return string[]
function M.get_all_filetypes()
    local all = {}
    for _, type_info in pairs(ATTACHMENT_TYPES) do
        vim.list_extend(all, type_info.extensions)
    end
    return all
end

---Get MIME type for a file
---@param path string
---@return string|nil
function M.get_mimetype(path)
    local ext = path:match("%.([^%.]+)$")
    if ext then
        ext = ext:lower()
        return ATTACHMENT_MIME_TYPES[ext]
    end
    return nil
end

---Get all supported file extensions
---@return table<string, string> Map of extension to type
function M.get_supported_extensions()
    local exts = {}
    for type_name, type_info in pairs(ATTACHMENT_TYPES) do
        for _, ext in ipairs(type_info.extensions) do
            exts[ext] = type_name
        end
    end
    return exts
end

---Detect attachment type from file extension
---@param path string
---@return string|nil type "image"|"document" or nil if unsupported
local function detect_attachment_type(path)
    local ext = path:match("%.([^%.]+)$")
    if not ext then
        return nil
    end
    ext = ext:lower()

    for type_name, type_info in pairs(ATTACHMENT_TYPES) do
        if vim.tbl_contains(type_info.extensions, ext) then
            return type_name
        end
    end

    return nil
end

---Validate attachment file
---@param path string
---@return boolean success, string? error_message
local function validate_attachment(path)
    local stat = vim.loop.fs_stat(path)
    if not stat then
        return false, "File does not exist"
    end

    local attachment_type = detect_attachment_type(path)
    if not attachment_type then
        local supported_exts = {}
        for _, type_info in pairs(ATTACHMENT_TYPES) do
            vim.list_extend(supported_exts, type_info.extensions)
        end
        local ext = path:match("%.([^%.]+)$")
        return false,
            string.format("Unsupported file type: .%s (supported: %s)", ext or "unknown", table.concat(supported_exts, ", "))
    end

    local type_info = ATTACHMENT_TYPES[attachment_type]
    local max_size = type_info.max_size_mb * 1024 * 1024
    if stat.size > max_size then
        return false,
            string.format(
                "File too large: %.2fMB (max %dMB for %s)",
                stat.size / 1024 / 1024,
                type_info.max_size_mb,
                attachment_type
            )
    end

    return true, nil
end

---Base64 encode a file
---@param path string
---@return string|nil content, string|nil error
local function base64_encode_file(path)
    local file = io.open(path, "rb")
    if not file then
        return nil, "Could not open file: " .. path
    end

    local content = file:read("*all")
    file:close()

    if not content then
        return nil, "Could not read file: " .. path
    end

    -- Use vim.base64.encode if available (Neovim 0.10+)
    if vim.base64 and vim.base64.encode then
        return vim.base64.encode(content), nil
    end

    -- Fallback to base64 command
    local handle = io.popen(string.format("base64 < %s", vim.fn.shellescape(path)))
    if not handle then
        return nil, "Could not execute base64 command"
    end

    local encoded = handle:read("*all")
    handle:close()

    if not encoded or encoded == "" then
        return nil, "Base64 encoding failed"
    end

    -- Remove newlines
    encoded = encoded:gsub("\n", "")

    return encoded, nil
end

---Base64 encode the given attachment
---@param attachment CodeCompanion.Attachment
---@return CodeCompanion.Attachment|string The encoded attachment or error message
function M.encode_attachment(attachment)
    if attachment.source == "url" then
        return attachment -- URLs don't need encoding
    end

    if attachment.source == "file" then
        return attachment -- Files API references don't need encoding
    end

    if attachment.base64 then
        return attachment -- Already encoded
    end

    local path = attachment.path
    local ok, err = validate_attachment(path)
    if not ok then
        return assert(err, "validate_attachment must return error message when ok is false")
    end

    -- Read and encode file
    local b64_content, b64_err = base64_encode_file(path)
    if b64_err then
        return b64_err
    end

    attachment.base64 = assert(b64_content, "base64_encode_file must return content when no error")

    -- Get MIME type
    if not attachment.mimetype then
        attachment.mimetype = M.get_mimetype(path)
    end

    attachment.source = "base64"
    return attachment
end

---Load attachment from file path
---@param path string
---@param ctx? table
---@param cb? function
---@return string|CodeCompanion.Attachment
function M.from_path(path, ctx, cb)
    -- Validate the attachment
    local ok, err = validate_attachment(path)
    if not ok then
        local error_msg = assert(err, "validate_attachment must return error message when ok is false")
        if type(cb) == "function" then
            return vim.schedule(function()
                cb(error_msg)
            end)
        end
        return error_msg
    end

    -- Expand to full path
    local full_path = vim.fn.expand(path)

    -- Determine attachment type
    local attachment_type = detect_attachment_type(full_path)

    -- Get MIME type
    local mimetype = M.get_mimetype(full_path)

    -- Create attachment object
    ---@type CodeCompanion.Attachment
    local attachment = {
        path = full_path,
        id = full_path,
        mimetype = mimetype,
        source = "base64",
        attachment_type = attachment_type,
    }

    if type(cb) == "function" then
        return vim.schedule(function()
            cb(attachment)
        end)
    end
    return attachment
end

---Load attachment from URL
---@param url string
---@param ctx? table
---@param cb? function
---@return string|CodeCompanion.Attachment
function M.from_url(url, ctx, cb)
    ctx = ctx or {}

    -- Try to detect attachment type from URL
    local attachment_type = detect_attachment_type(url)

    -- If it's an image, we need to download it
    if attachment_type == "image" then
        local Curl = require("plenary.curl")
        local loc = vim.fn.tempname()
        temp_files[#temp_files + 1] = loc

        ---@type string|CodeCompanion.Attachment
        local result = string.format("Could not get the image from %s.", url)

        local job = Curl.get(url, {
            output = loc,
            callback = function(response)
                if response.status < 200 or response.status >= 300 then
                    result = string.format("Could not get the image from %s. Status code: %d", url, response.status)
                else
                    result = M.from_path(loc)
                end
                if type(cb) == "function" then
                    vim.schedule(function()
                        cb(result)
                    end)
                end
            end,
        })
        if type(cb) ~= "function" then
            job:sync()
            return result
        end
    else
        -- For documents, validate URL points to a supported type
        local has_supported_ext = false
        for type_name, type_info in pairs(ATTACHMENT_TYPES) do
            for _, ext in ipairs(type_info.extensions) do
                if url:match("%." .. ext .. "$") or url:match("%." .. ext .. "%?") then
                    has_supported_ext = true
                    attachment_type = type_name
                    break
                end
            end
            if has_supported_ext then
                break
            end
        end

        if not has_supported_ext then
            local supported_exts = {}
            for _, type_info in pairs(ATTACHMENT_TYPES) do
                vim.list_extend(supported_exts, type_info.extensions)
            end
            local err_msg = string.format("URL must point to a supported attachment type (%s)", table.concat(supported_exts, ", "))
            if type(cb) == "function" then
                return vim.schedule(function()
                    cb(err_msg)
                end)
            end
            return err_msg
        end

        -- For URLs to documents, we can pass directly to the API without downloading
        ---@type CodeCompanion.Attachment
        local attachment = {
            source = "url",
            url = url,
            id = url,
            path = "",
            attachment_type = attachment_type,
        }

        if type(cb) == "function" then
            return vim.schedule(function()
                cb(attachment)
            end)
        end
        return attachment
    end
end

---Get attachment info for display
---@param attachment CodeCompanion.Attachment
---@return string
function M.get_attachment_info(attachment)
    local type_label = attachment.attachment_type or "Attachment"
    if attachment.source == "url" then
        return string.format("%s: %s", type_label, attachment.url)
    elseif attachment.source == "file" then
        return string.format("%s: file_id=%s", type_label, attachment.file_id)
    else
        local filename = vim.fn.fnamemodify(attachment.path, ":t")
        return string.format("%s: %s", type_label, filename)
    end
end

return M
