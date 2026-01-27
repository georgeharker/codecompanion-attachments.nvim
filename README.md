# codecompanion-attachments.nvim

Document and image attachment support for [CodeCompanion.nvim](https://codecompanion.olimorris.dev/).

Send PDFs and documents to Claude using Anthropic's efficient document block format - which is both more efficient and enabled pdf / docx digestion.

## Features

- 📎 **Document Attachments**: Upload PDFs, DOCX, XLSX, CSV, and more
- 🖼️ **Image Support**: Attach PNG, JPEG, GIF, WebP images
- 🔍 **File Picker**: Browse and select files using your preferred picker (Telescope, fzf-lua, etc.)
- ⚡ **Token Efficient**: Uses Anthropic's document blocks (~99.5% token reduction)
- 🎯 **Multiple Adapters**: Works with Anthropic (Claude) and Gemini
- 🔧 **Seamless Integration**: `/attachment` slash command integrates naturally with CodeCompanion

## Requirements

- Neovim >= 0.8.0
- [codecompanion.nvim](https://codecompanion.olimorris.dev/)
- A file picker plugin (Telescope, fzf-lua, or CodeCompanion's default picker)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
	"olimorris/codecompanion.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
		"georgeharker/codecompanion-attachments.nvim",
	},
	config = function()
		require("codecompanion").setup({
			adapters = {
				anthropic = function()
					return require("codecompanion.adapters").extend("anthropic", {
						env = { api_key = "ANTHROPIC_API_KEY" },
						opts = {
							attachment_upload = true, -- REQUIRED
						},
					})
				end,
			},
			extensions = {
				attachments = {
					callback = "codecompanion._extensions.attachments", -- REQUIRED
					enabled = true,
					opts = {
						adapters = {}, -- Custom adapter transformers (optional)
					},
				},
			},
		})
	end,
}
```

### Local Development

If you're developing the plugin locally:

```lua
{
	"olimorris/codecompanion.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
		{
			dir = "~/Development/neovim-plugins/codecompanion-attachments.nvim",
			name = "codecompanion-attachments.nvim",
		},
	},
	config = function()
		-- Same config as above
	end,
}
```

## Configuration

### Required Settings

Two settings are **required** for the extension to work:

1. **Adapter configuration** - Enable `attachment_upload`:

```lua
adapters = {
	anthropic = function()
		return require("codecompanion.adapters").extend("anthropic", {
			opts = {
				attachment_upload = true, -- REQUIRED
			},
		})
	end,
}
```

2. **Extension callback** - Tell CodeCompanion where to load the extension:

```lua
extensions = {
	attachments = {
		callback = "codecompanion._extensions.attachments", -- REQUIRED
		enabled = true,
	},
}
```

### Supported Adapters

#### Anthropic (Claude)

```lua
adapters = {
	anthropic = function()
		return require("codecompanion.adapters").extend("anthropic", {
			env = { api_key = "ANTHROPIC_API_KEY" },
			opts = {
				attachment_upload = true,
			},
		})
	end,
}
```

#### Gemini

```lua
adapters = {
	gemini = function()
		return require("codecompanion.adapters").extend("gemini", {
			env = { api_key = "GEMINI_API_KEY" },
			opts = {
				attachment_upload = true,
			},
		})
	end,
}
```

## Usage

1. Open a CodeCompanion chat: `:CodeCompanionChat`
2. Type `/attachment` and press `<Tab>` or `<CR>`
3. Select your file using the picker
4. Ask questions about the content!

### Example

```
:CodeCompanionChat

> /attachment
[Select report.pdf]

> Summarize the key findings in this report

[Claude reads the document and provides a summary]
```

### Supported File Types

**Documents** (max 32MB):
- PDF (`.pdf`)
- Rich Text Format (`.rtf`)
- Microsoft Word (`.docx`)
- Microsoft Excel (`.xlsx`)
- Microsoft PowerPoint (`.pptx`)
- CSV (`.csv`)

**Images** (max 10MB):
- PNG (`.png`)
- JPEG (`.jpg`, `.jpeg`)
- GIF (`.gif`)
- WebP (`.webp`)
- BMP (`.bmp`)
- TIFF (`.tiff`)
- SVG (`.svg`)

## How It Works

The extension uses Anthropic's [document block format](https://docs.anthropic.com/en/docs/build-with-claude/pdf-support) to efficiently send document contents:

### Technical Implementation

1. Registers `/attachment` slash command in CodeCompanion
2. Patches adapter's `form_messages` handler to intercept attachment messages
3. Transforms attachments to proper API format:
   - **Anthropic**: document blocks (`type: "document"`)
   - **Gemini**: inline_data format
4. Preserves metadata throughout the transformation pipeline

## Debugging

### Enable Debug Logging

```lua
require("codecompanion").setup({
	log_level = "DEBUG",
	-- ... rest of config
})
```

Then check logs:
- `:AttachmentDebugLog` - View log in a split
- `:AttachmentClearLog` - Clear the log
- `:AttachmentLogPath` - Show log file location

### What to Look For

Successful operation shows:
```
[INFO] attachments extension loaded
[DEBUG] adapters.extend called: adapter_name=anthropic
[DEBUG] Patching adapter 'anthropic' via extend
[DEBUG] === PATCHED ANTHROPIC FORM_MESSAGES CALLED ===
[DEBUG] Found attachment message at index 1
[DEBUG] Creating document block for attachment 1
[DEBUG] Successfully processed attachment 1
```

### Common Issues

**"Prompt too long" error**:
- Check that `attachment_upload = true` is set in your adapter config
- Verify the extension loaded: Look for "attachments extension loaded" in logs
- Ensure `callback = "codecompanion._extensions.attachments"` is present in extensions config

**Slash command not appearing**:
- Restart Neovim completely
- Run `:Lazy sync` to ensure plugin is loaded
- Check that `enabled = true` in extensions config

**Extension not loading**:
- Make sure the `callback` parameter is set (see Configuration section)
- Without it, CodeCompanion can't find the extension module

## Development

### Project Structure

```
lua/codecompanion/_extensions/attachments/
├── init.lua              # Extension entry point (74 lines)
├── adapter_patches.lua   # Adapter patching logic (229 lines)
├── chat_integration.lua  # Chat class integration (74 lines)
├── slash_command.lua     # /attachment command (320 lines)
├── utils.lua            # Base64 encoding, MIME detection (400 lines)
└── debug_helpers.lua    # Debug commands (48 lines)
```

### Testing

1. Make changes in the plugin directory
2. Restart Neovim (or `:Lazy reload codecompanion-attachments.nvim`)
3. Test with `:CodeCompanionChat` → `/attachment`
4. Check logs with `:AttachmentDebugLog`

### Running Type Checks

```bash
# Format code
stylua lua/

# Type check
lua-language-server --check . --checklevel=Warning
```

## Contributing

Contributions welcome! Please:

1. Run `stylua lua/` before committing
2. Ensure no type errors with `lua-language-server --check .`
3. Test with a real attachment in CodeCompanion
4. Include debug logs if reporting issues

## License

MIT

## Credits

- Built for [CodeCompanion.nvim](https://codecompanion.olimorris.dev/) by [@olimorris](https://github.com/olimorris)
- Implements Anthropic's [PDF and document support](https://docs.anthropic.com/en/docs/build-with-claude/pdf-support)
