local adapter_utils = require("codecompanion.utils.adapters")
local log = require("codecompanion.utils.log")

local M = {}
---Patch Anthropic adapter to handle attachments
---@param adapter table The adapter to patch
---@return table The patched adapter
local function patch_anthropic_adapter(adapter)
	local original_form_messages = adapter.handlers.form_messages

	adapter.handlers.form_messages = function(self, messages)
		log:debug("=== PATCHED ANTHROPIC FORM_MESSAGES CALLED ===")
		log:debug("Input: %d messages", #messages)
		log:debug("Adapter opts: attachment_upload=%s", tostring(self.opts and self.opts.attachment_upload))

		-- Separate attachment messages from regular messages
		local attachment_messages = {}
		local regular_messages = {}
		local attachment_indices = {}

		for i, m in ipairs(messages) do
			if m._meta and m._meta.tag == "attachment" then
				log:debug("Found attachment message at index %d", i)
				table.insert(attachment_messages, m)
				attachment_indices[i] = #attachment_messages -- Track original position
			else
				table.insert(regular_messages, m)
			end
		end

		log:debug("Separated: %d attachments, %d regular messages", #attachment_messages, #regular_messages)

		-- Process regular messages through original form_messages
		local result = original_form_messages(self, regular_messages)
		log:debug("Original form_messages returned: %s", vim.inspect(result and vim.tbl_keys(result) or {}))

		-- Process attachment messages ourselves
		local processed_attachments = {}
		for i, m in ipairs(attachment_messages) do
			log:debug("Processing attachment %d/%d", i, #attachment_messages)

			-- Check if attachment_upload is enabled
			if not (self.opts and self.opts.attachment_upload) then
				log:warn("Attachment %d skipped: attachment_upload not enabled", i)
				goto continue
			end

			-- Build the document content block
			local attachment_msg = {
				role = m.role or "user",
				content = {},
			}

			if m.context and m.context.source == "base64" then
				log:debug("Creating document block for attachment %d", i)
				table.insert(attachment_msg.content, {
					type = "document",
					source = {
						type = "base64",
						media_type = m.context.mimetype or "application/pdf",
						data = m.content,
					},
				})
			else
				log:warn("Attachment %d has unsupported source type: %s", i, m.context and m.context.source or "nil")
				goto continue
			end

			table.insert(processed_attachments, attachment_msg)
			log:debug("Successfully processed attachment %d", i)

			::continue::
		end

		log:debug("Processed %d/%d attachments successfully", #processed_attachments, #attachment_messages)

		-- Merge attachment messages into the result
		if #processed_attachments > 0 then
			-- Ensure result.messages exists
			if not result.messages then
				result.messages = {}
			end

			-- Append all processed attachments to the messages array
			for _, att_msg in ipairs(processed_attachments) do
				table.insert(result.messages, att_msg)
			end

			log:debug(
				"Final result: %d total messages (%d attachments merged)",
				#result.messages,
				#processed_attachments
			)
		end

		return result
	end

	log:info("Patched Anthropic adapter for attachment support")
	return adapter
end

---Transform attachment messages for Gemini adapter
---@param messages table List of messages
---@param adapter table The adapter instance
---@return table Transformed messages
local function transform_gemini_attachments(messages, adapter)
	local transformed = {}

	for _, m in ipairs(messages) do
		-- Handle attachment messages
		if m._meta and m._meta.tag == "attachment" and m.context then
			if adapter.opts and adapter.opts.attachment_upload then
				-- Gemini uses inline_data format
				if m.context.source ~= "file" then
					local content_data = m.content
					m.content = {
						{
							inline_data = {
								mime_type = m.context.mimetype or "application/pdf",
								data = content_data,
							},
						},
					}
				else
					-- Files API references not supported in initial version
					m = nil
				end
			else
				-- Remove the message if document upload support is not enabled
				m = nil
			end
		end

		if m then
			table.insert(transformed, m)
		end
	end

	return transformed
end

---Adapter-specific transformation functions
local transformers = {
	gemini = transform_gemini_attachments,
	gemini_cli = transform_gemini_attachments,
}

---Patch an adapter's form_messages handler to support attachments
---@param adapter table The adapter to patch
---@param adapter_name string The name of the adapter
---@return table The patched adapter
local function patch_adapter(adapter, adapter_name)
	if adapter_name == "anthropic" then
		return patch_anthropic_adapter(adapter)
	end

	-- For other adapters, use the simple transformer approach
	local transformer = transformers[adapter_name]
	if not transformer then
		return adapter
	end

	local original_form_messages = adapter.handlers.form_messages
	adapter.handlers.form_messages = function(self, messages)
		local transformed = transformer(messages, self)
		return original_form_messages(self, transformed)
	end

	log:info("Patched adapter '%s' for attachment support", adapter_name)
	return adapter
end

---Install adapter patches into CodeCompanion
---@return nil
function M.install()
	local adapters = require("codecompanion.adapters")
	local original_resolve = adapters.resolve
	local original_extend = adapters.extend

	log:info("=== INSTALLING ADAPTER PATCHES ===")
	log:debug("Original adapters.resolve: %s", tostring(original_resolve))
	log:debug("Original adapters.extend: %s", tostring(original_extend))

	-- Wrap the resolve function to patch adapters
	adapters.resolve = function(adapter_name, adapter_opts)
		log:debug("adapters.resolve called: adapter_name=%s", adapter_name or "nil")
		local adapter = original_resolve(adapter_name, adapter_opts)

		-- Patch if this adapter has support
		if adapter_name == "anthropic" or transformers[adapter_name] then
			log:debug("Patching adapter '%s' via resolve", adapter_name)
			adapter = patch_adapter(adapter, adapter_name)
		else
			log:debug("Skipping adapter '%s' (no transformer)", adapter_name)
		end

		return adapter
	end

	-- ALSO wrap the extend function (used in config functions)
	adapters.extend = function(adapter_name, adapter_opts)
		log:debug("adapters.extend called: adapter_name=%s", adapter_name or "nil")
		local adapter = original_extend(adapter_name, adapter_opts)

		-- Patch if this adapter has support
		if adapter_name == "anthropic" or transformers[adapter_name] then
			log:debug("Patching adapter '%s' via extend", adapter_name)
			adapter = patch_adapter(adapter, adapter_name)
		else
			log:debug("Skipping adapter '%s' (no transformer)", adapter_name)
		end

		return adapter
	end

	log:info("Installed attachments adapter patches (wrapped adapters.resolve and adapters.extend)")
end

---Register a custom transformer for an adapter
---@param adapter_name string The name of the adapter
---@param transformer function The transformation function
---@return nil
function M.register_transformer(adapter_name, transformer)
	transformers[adapter_name] = transformer
	log:info("Registered attachment transformer for adapter '%s'", adapter_name)
end

return M
