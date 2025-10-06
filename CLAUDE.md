# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

ggbot2 is a voice assistant for ggplot2 that uses OpenAI's GPT-4o Realtime API through Shiny. Users speak commands, and the assistant generates R plotting code that executes in real-time.

## Prerequisites

- OpenAI API key with paid account (a few dollars minimum)
- Set `OPENAI_API_KEY` in `.Renviron` or `.env` file

## Development Commands

### Installation
```r
# Install from GitHub
pak::pak("tidyverse/ggbot2")

# Install with dependencies for local development
pak::pak(".")
```

### Running the App
```r
# Launch with a data frame
ggbot2::ggbot(mtcars)

# Enable debug mode for verbose logging
ggbot2::ggbot(mtcars, debug = TRUE)
```

### Documentation
```r
# Generate/update documentation
devtools::document()
```

## Architecture

### Core Components

**Main Function: `ggbot()` (R/ggbot2.R:24-236)**
- Entry point that validates data frame input and launches Shiny app
- Validates OPENAI_API_KEY via `ensure_openai_api_key()`
- Builds prompt with data frame metadata via `build_prompt()`
- Creates 3-panel UI: sidebar (transcript), plot viewer, code viewer

**Realtime Integration**
- Uses `shinyrealtime` package for WebSocket connection to OpenAI Realtime API
- Voice input → GPT-4o Realtime → R code generation → immediate plot execution
- Event-driven architecture with listeners for conversation items, responses, and usage tracking

**Tool System**
- Two tools exposed to AI:
  - `run_r_plot_code_tool`: Generates static ggplot2 plots
  - `run_r_plotly_code_tool`: Generates interactive plotly plots
- Tools receive R code string and store in reactive values (`last_code` or `last_plotly_code`)
- Code executes in isolated environment via `renderPlot()` or `plotly::renderPlotly()`
- Each execution is a fresh environment; no state persists between calls
- AI intelligently chooses tool based on user request and data characteristics

**Prompt Construction: `build_prompt()` (R/ggbot2.R:305-336)**
- Loads base instructions from inst/prompts/prompt.md
- Appends data frame preview (first 6 rows), structure, and summary
- Uses string interpolation to inject df_name and metadata

**System Prompt (inst/prompts/prompt.md)**
- Defines AI personality: warm, engaging, playful, quick-talking
- Constrains AI to plotting tasks only
- Assumes ggplot2 and dplyr are pre-loaded
- Emphasizes fresh R session per function call

### Key Technical Details

**Plot History System**
- All generated plots stored in reactive list `plot_history`
- Each history item contains: code, plot_type ("static" or "plotly"), timestamp
- `history_position` tracks current position (0 = latest, incrementing for older plots)
- Prev/next navigation buttons in plot card header
- Seamlessly handles transitions between static and interactive plots
- History info displays "1/5", "2/5", etc. showing current position

**Dark Mode**
- Uses bslib's `input_dark_mode()` for light/dark theme toggle
- Toggle button in sidebar next to session cost
- Automatically applies to all UI components (cards, sidebar, buttons)
- Leverages Bootstrap 5.3 color mode system

**Download Functionality**
- Static plots: Download as high-resolution PNG (3000×2400px at 300 DPI)
- Interactive plots: Download as self-contained HTML with full interactivity
- Filename includes timestamp for easy organization
- Uses `htmlwidgets::saveWidget()` for plotly exports

**Cost Tracking**
- Tracks token usage per response (text, audio, cached) at R/ggbot2.R:168-181
- Pricing matrix at R/ggbot2.R:183-200 for GPT-4o Realtime
- Running cost displayed in sidebar via `running_cost` reactive value

**Error Handling**
- Plot code errors caught in tryCatch at R/ggbot2.R:208-222
- Errors displayed but not sent back to AI (see comment at R/ggbot2.R:212-219)
- API key validation with helpful error messages at R/ggbot2.R:257-293

**Audio Feedback**
- Shutter sound effect (inst/shutter.mp3) plays after each plot render
- Embedded as base64 data URI via `hidden_audio_el()` at R/ggbot2.R:238-248

**Notifications**
- Shows "Generating code..." when function call starts
- Auto-removes notification when function call completes
- Event handlers at R/ggbot2.R:119-134

### Dependencies

**Critical Packages**
- `shinyrealtime` (>= 0.1.0.9000): WebSocket bridge to OpenAI Realtime API
- `ellmer` (>= 0.3.0): Tool definition system for AI function calling
- `shinychat`: Markdown streaming for transcript display
- `bslib`: Modern UI components (sidebar, cards, layouts, dark mode)
- `shinyjs`: UI element manipulation (button enable/disable for history navigation)

**Optional Packages**
- `plotly`: Interactive plot rendering
- `htmlwidgets`: Export interactive plots to HTML
- `dplyr`: Data manipulation in generated code

**Data Handling**
- Assumes user provides actual data frame variable (not NULL)
- Variable name captured via `deparse(substitute(df))` at R/ggbot2.R:31
- Data frame must be in-memory; no lazy evaluation support

## Common Modifications

### Changing AI Behavior
Edit `inst/prompts/prompt.md` to modify:
- Personality and tone
- Plotting constraints
- Default assumptions (e.g., pre-loaded packages)

### Adding New Tools
Add tool definitions in `ggbot()` server function:
1. Create tool function
2. Wrap with `ellmer::tool()`
3. Add to `tools` list in `realtime_server()` call at R/ggbot2.R:113

### Modifying UI Layout
Edit `ui` definition in `ggbot()`:
- Sidebar: transcript, cost tracker, and dark mode toggle
- Plot card header: history navigation (prev/next), history info, download button
- Main area: 66% plot card, 34% code card
- Realtime UI: floating mic button

### Working with Plot History
History is stored as a list where position 0 is the latest plot:
- New plots are prepended to `plot_history()` list
- `history_position(0)` represents the live/latest plot
- Navigation increments/decrements position to load older/newer plots
- Buttons auto-disable when at boundaries (oldest or newest)

### Cost Calculation
Update pricing matrix at R/ggbot2.R:183-200 if OpenAI changes rates.