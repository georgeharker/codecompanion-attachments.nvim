# Testing Guide for codecompanion-attachments.nvim

## Quick Start

### 1. **Restart Neovim**
The latest fix changes the order of operations in the adapter patch. You MUST restart Neovim to load the updated code.

### 2. **Verify Configuration**
Ensure your Anthropic adapter has `attachment_upload` enabled:

```lua
adapters = {
    anthropic = function()
        return require("codecompanion.adapters").extend("anthropic", {
            env = { ANTHROPIC_API_KEY = "ANTHROPIC_API_KEY" },
            opts = {
                attachment_upload = true,  -- Enable document upload
            },
        })
    end,
},
```

### 3. **Enable Debug Logging** (Recommended)
Add to your CodeCompanion config:

```lua
opts = {
    log_level = "DEBUG",
}
```

### 4. **Test Attachment Upload**

1. Open a CodeCompanion chat: `:CodeCompanionChat`
2. Type `/attachment` and press `<Tab>` or `<CR>`
3. Select a document (PDF, markdown, text file, etc.)
4. Send a message asking about the document
5. Check if the request succeeds (should NOT see "prompt is too long" error)

### 5. **Check Logs**

Open the log file: `:CodeCompanionLog`

**Look for these SUCCESS indicators:**
```
[INFO] Installed attachments adapter patches
[INFO] Patched adapter 'anthropic' for attachment support
[DEBUG] Patched form_messages called for anthropic with X messages
[DEBUG] Anthropic transformer: Processing X messages
[DEBUG] Found attachment message: source=base64, mimetype=application/pdf
[DEBUG] Transforming base64 attachment: type=document, size=XXXX bytes
[DEBUG] Transformed to document content block
```

**FAILURE indicators (what we're fixing):**
- No "Patched adapter" message → Patch not applied
- No "Found attachment message" → Attachment not detected
- No "Transformed to document content block" → Transformation not happening
- "prompt is too long: XXXXX tokens" → Transformation failed, still sending as text

## What Changed in the Latest Fix

**Problem:** Attachments were sent as massive base64 text strings instead of Anthropic's document format.

**Root Cause:** The monkey patch was transforming messages AFTER the original `form_messages` function, which strips `_meta` tags. Without `_meta.tag = "attachment"`, the transformer couldn't identify attachment messages.

**Solution:** Transform messages BEFORE calling original `form_messages`:

```lua
-- adapter_patches.lua:163-177

-- OLD (WRONG):
local formed = original_form_messages(self, messages)
return transformer(formed, self)

-- NEW (CORRECT):
local transformed = transformer(messages, self)  -- Transform FIRST
return original_form_messages(self, transformed) -- Then process
```

This preserves the `_meta` tags during transformation so attachments are properly converted to Anthropic's document format.

## Expected Behavior

### Before Fix
- Attachment sent as 210k+ tokens of base64 text
- API rejects with "prompt is too long" error
- Logs show no transformation happening

### After Fix
- Attachment sent as Anthropic document block (much smaller)
- API accepts request
- Logs show:
  - "Found attachment message"
  - "Transformed to document content block"
  - Normal response from Claude

## Troubleshooting

### Slash command not appearing
- Check `:messages` for extension loading errors
- Verify extension is in `lua/codecompanion/_extensions/attachments/`
- Ensure `setup()` is called in your config

### Transformation not happening
1. Check logs for "Patched adapter 'anthropic'" message
2. Verify `attachment_upload = true` in adapter config
3. Look for "Found attachment message" in logs
4. If missing, the `_meta.tag` might not be set correctly

### Still getting "prompt is too long"
- Restart Neovim (patch might not be loaded)
- Check logs show transformation is running
- Verify the content is actually being transformed (should see "Transformed to document content block")

## Reference Files

- **Latest implementation:** `lua/codecompanion/_extensions/attachments/adapter_patches.lua:148-177`
- **Old working version:** `~/Development/ext/codecompanion.nvim/lua/codecompanion/adapters/http/anthropic.lua:209-257`
- **Slash command:** `lua/codecompanion/_extensions/attachments/slash_command.lua`
- **Chat integration:** `lua/codecompanion/_extensions/attachments/chat_integration.lua`

## Next Steps After Testing

1. If successful, consider disabling debug logging (can be verbose)
2. Test with different file types (PDF, markdown, images, etc.)
3. Test with Gemini adapter if you use it (same pattern applies)
4. Report any remaining issues with log excerpts

## Known Limitations

- **Files API:** Not yet implemented (requires `file_api` capability)
- **URL sources:** Implemented but untested
- **Preview display:** User reported issues with previews, deferred for now
- **Large files:** Still subject to Anthropic's size limits (even with proper format)
