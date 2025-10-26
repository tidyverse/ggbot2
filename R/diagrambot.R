#' @import shiny
#' @import bslib
#' @import ellmer
#' @importFrom shinychat markdown_stream output_markdown_stream chat_ui chat_append
#' @importFrom shinyrealtime realtime_ui realtime_server
#' @importFrom htmltools tags HTML
#' @importFrom jsonlite toJSON
#' @importFrom shiny addResourcePath includeScript
NULL

globalVariables(c(
  "yield",
  "tags",
  "isolate",
  "req",
  "renderUI",
  "renderText",
  "shinyApp",
  "HTML",
  "realtime_server",
  "showNotification",
  "removeNotification",
  "observeEvent",
  "actionButton",
  "icon",
  "div",
  "showModal",
  "modalDialog",
  "textAreaInput",
  "helpText",
  "modalButton",
  "tagList",
  "removeModal"
))

# Helper Functions --------------------------------------------------------

#' Render a Mermaid diagram
#'
#' @param code The Mermaid diagram code
#' @return HTML tags for rendering the diagram
#' @keywords internal
render_mermaid <- function(code) {
  diagram_id <- paste0("mermaid-", sample(10000:99999, 1))
  tags$div(
    id = diagram_id,
    style = "width: 100%; height: 100%; min-height: 400px;",
    tags$script(HTML(paste0(
      "setTimeout(function() { renderMermaidDiagram('",
      diagram_id,
      "', `",
      gsub("`", "\\`", code),
      "`); }, 500);"
    )))
  )
}

#' Render a Graphviz diagram
#'
#' @param code The Graphviz DOT code
#' @return HTML tags for rendering the diagram
#' @keywords internal
render_graphviz <- function(code) {
  diagram_id <- paste0("graphviz-", sample(10000:99999, 1))
  tags$div(
    id = diagram_id,
    style = "width: 100%; height: 100%; min-height: 400px;",
    tags$script(HTML(paste0(
      "setTimeout(function() { renderGraphvizDiagram('",
      diagram_id,
      "', `",
      gsub("`", "\\`", code),
      "`); }, 500);"
    )))
  )
}

#' Render diagram output with error handling
#'
#' @param code The diagram code
#' @param diagram_type The type of diagram ("mermaid" or "graphviz")
#' @param session The Shiny session object
#' @return Rendered diagram UI or error message
#' @keywords internal
render_diagram_output <- function(code, diagram_type, session) {
  on.exit(session$sendCustomMessage(
    "play_audio",
    list(selector = "#shutter")
  ))

  tryCatch(
    {
      if (diagram_type == "graphviz") {
        render_graphviz(code)
      } else {
        render_mermaid(code)
      }
    },
    error = function(e) {
      tags$div(
        style = "color: red; padding: 20px;",
        "Error rendering diagram: ",
        conditionMessage(e)
      )
    }
  )
}

#' Setup copy to clipboard button handler
#'
#' @param input The Shiny input object
#' @param session The Shiny session object
#' @param last_code Reactive value containing the diagram code
#' @keywords internal
setup_copy_button_handler <- function(input, session, last_code) {
  observeEvent(input$copy_code, {
    req(last_code())
    code_to_copy <- last_code()

    # Send the code to the browser for copying
    session$sendCustomMessage(
      "copy_to_clipboard",
      list(text = code_to_copy)
    )

    # Show a temporary notification
    showNotification(
      "Code copied to clipboard!",
      type = "message",
      duration = 2
    )
  })
}

#' Create diagram generation tool for ellmer
#'
#' @param last_code Reactive value to store the diagram code
#' @param last_diagram_type Reactive value to store the diagram type
#' @param debug Logical; if TRUE, enables debug logging
#' @return An ellmer tool object
#' @keywords internal
create_diagram_tool <- function(last_code, last_diagram_type, debug = FALSE) {
  generate_diagram <- function(code, diagram_type) {
    attr(code, "rnd") <- stats::runif(1) # Force re-evaluation even if code is the same
    last_code(code)
    last_diagram_type(diagram_type)

    if (debug) {
      message(sprintf(
        "Generating %s diagram with code:\n%s",
        diagram_type,
        code
      ))
    }

    NULL
  }

  ellmer::tool(
    generate_diagram,
    "Generate a diagram",
    arguments = list(
      code = type_string(
        "The diagram code (Mermaid or Graphviz DOT syntax)"
      ),
      diagram_type = type_string(
        "The type of diagram: 'mermaid' for Mermaid diagrams, 'graphviz' for Graphviz/DOT diagrams"
      )
    )
  )
}

# Exported Functions ------------------------------------------------------

#' Interactive Shiny app that generates Mermaid and Graphviz diagrams from voice commands using
#' GPT-4o Realtime.
#'
#' @param debug Logical; if TRUE, enables debug mode in shinyrealtime for
#' (extremely) verbose logging.
#'
#' @return A Shiny app object. If this function is called from the R console,
#' the app will launch automatically.
#'
#' @export
diagrambot <- function(debug = FALSE) {
  ensure_openai_api_key()

  prompt <- build_prompt()

  # Add resource path for the package's www directory
  shiny::addResourcePath(
    "diagrambot",
    system.file("www", package = "diagrambot")
  )

  ui <- page_sidebar(
    title = "diagrambot",
    fillable = TRUE,
    style = "--bslib-spacer: 1rem; padding-bottom: 0;",
    sidebar = sidebar(
      helpText("Session cost:", textOutput("session_cost", inline = TRUE)),
      output_markdown_stream("response_text")
    ),
    # Settings button in top right corner
    tags$div(
      style = "position: fixed; top: 10px; right: 20px; z-index: 100001;",
      actionButton(
        "settings_btn",
        label = NULL,
        icon = shiny::icon("gear"),
        class = "btn-default",
        style = "margin-left: auto; padding: 0.2rem 0.4rem; font-size: 1.1rem; height: 2rem; width: 2rem; min-width: 2rem; border: none; background: transparent; color: #495057; border-radius: 50%; display: flex; align-items: center; justify-content: center; box-shadow: none;",
        title = "Personal Instructions"
      )
    ),
    card(
      full_screen = TRUE,
      card_header("Diagram"),
      card_body(padding = 0, uiOutput("diagram_output", fill = TRUE)),
      height = "66%"
    ),
    layout_columns(
      height = "34%",
      card(
        full_screen = TRUE,
        card_header(
          "Code",
          div(
            style = "float: right;",
            actionButton(
              "copy_code",
              "Copy to Clipboard",
              icon = icon("copy"),
              style = "padding: 2px 8px; font-size: 12px; margin-top: -2px;",
              class = "btn-outline-secondary btn-sm"
            )
          )
        ),
        verbatimTextOutput("code_text")
      )
    ),
    realtime_ui(
      "realtime1",
      style = "z-index: 100000; margin-left: auto; margin-right: auto;",
      right = NULL
    ),
    hidden_audio_el(
      "shutter",
      system.file("shutter.mp3", package = "diagrambot")
    ),
    # Include the JavaScript file from the package www directory
    tags$head(
      includeScript(system.file(
        "www",
        "diagram-renderers.js",
        package = "diagrambot"
      )),
      includeScript(system.file(
        "www",
        "personal-instructions.js",
        package = "diagrambot"
      ))
    )
  )

  server <- function(input, output, session) {
    last_code <- reactiveVal()
    last_diagram_type <- reactiveVal("mermaid")
    running_cost <- reactiveVal(0) # Cost of tokens used in the session, in dollars
    user_instructions <- reactiveVal("") # Store user's personal instructions
    instructions_loaded <- reactiveVal(FALSE) # Track if instructions have been loaded

    # Load instructions from localStorage when app starts
    observeEvent(
      input$initial_instructions,
      {
        message(
          "observeEvent fired: initial_instructions = '",
          input$initial_instructions,
          "'"
        )
        if (
          !is.null(input$initial_instructions) &&
            nchar(input$initial_instructions) > 0
        ) {
          user_instructions(input$initial_instructions)
          message(
            "Loaded instructions from localStorage: ",
            input$initial_instructions
          )
        } else {
          message("No instructions found in localStorage (empty or NULL)")
        }
        instructions_loaded(TRUE)
        message("instructions_loaded set to TRUE")
      },
      once = TRUE,
      ignoreNULL = FALSE,
      priority = 1000
    ) # High priority to run first

    greeting <- "Welcome to diagrambot!\n\nYou're currently muted; click the mic button to unmute, click-and-hold the mic for push-to-talk, or hold the spacebar key for push-to-talk."

    append_transcript <- function(text, clear = FALSE) {
      markdown_stream(
        "response_text",
        coro::gen(yield(text)),
        operation = if (clear) "replace" else "append",
        session = session
      )
    }

    append_transcript(greeting, clear = TRUE)

    generate_diagram_tool <- create_diagram_tool(
      last_code,
      last_diagram_type,
      debug = FALSE
    )

    # Pricing for GPT-4 Realtime API
    pricing_gpt4_realtime <- c(
      input_text = 4 / 1e6,
      input_audio = 32 / 1e6,
      input_image = 5 / 1e6,
      input_text_cached = 0.4 / 1e6,
      input_audio_cached = 0.4 / 1e6,
      input_image_cached = 0.5 / 1e6,
      output_text = 16 / 1e6,
      output_audio = 64 / 1e6
    )

    # Build the complete prompt with user instructions
    build_complete_prompt <- function() {
      base_prompt <- prompt
      user_instr <- user_instructions()

      if (nchar(user_instr) > 0) {
        paste0(
          base_prompt,
          "\n\n## Additional User Context\n\n",
          user_instr
        )
      } else {
        base_prompt
      }
    }

    # Create realtime server after instructions are loaded
    observeEvent(
      instructions_loaded(),
      {
        req(instructions_loaded())

        message("Creating realtime server...")
        message("User instructions: '", user_instructions(), "'")
        complete_prompt <- build_complete_prompt()
        message(
          "Complete prompt length: ",
          nchar(complete_prompt),
          " characters"
        )
        if (debug) {
          message("Full prompt: ", complete_prompt)
        }

        # Create realtime server with current prompt (only called once on startup)
        realtime_controls <- realtime_server(
          "realtime1",
          voice = "cedar",
          instructions = build_complete_prompt(),
          tools = list(generate_diagram_tool),
          speed = 1.1,
          debug = debug
        )

        # Set up event handlers
        # Handle function call start - show notification
        realtime_controls$on("conversation.item.added", function(event) {
          if (event$item$type == "function_call") {
            shiny::showNotification(
              "Generating diagram, please wait...",
              id = event$item$id,
              closeButton = FALSE
            )
          }
        })

        # Handle function call completion - remove notification
        realtime_controls$on("conversation.item.done", function(event) {
          if (event$item$type == "function_call") {
            shiny::removeNotification(id = event$item$id)
          }
        })

        # Handle new messages - clear transcript
        realtime_controls$on("response.created", function(event) {
          append_transcript("", clear = TRUE)
        })

        # Handle text streaming
        realtime_controls$on(
          "response.output_audio_transcript.delta",
          function(event) {
            append_transcript(event$delta)
          }
        )

        realtime_controls$on("response.done", function(event) {
          usage <- event$response$usage
          current_response <- c(
            input_text = usage$input_token_details$text_tokens,
            input_audio = usage$input_token_details$audio_tokens,
            input_image = usage$input_token_details$image_tokens,
            input_text_cached = usage$input_token_details$cached_tokens_details$text_tokens,
            input_audio_cached = usage$input_token_details$cached_tokens_details$audio_tokens,
            input_image_cached = usage$input_token_details$cached_tokens_details$image_tokens,
            output_text = usage$output_token_details$text_tokens,
            output_audio = usage$output_token_details$audio_tokens
          )

          cost <- sum(current_response * pricing_gpt4_realtime)
          running_cost(isolate(running_cost()) + cost)
        })
      },
      once = TRUE
    )

    # Show settings modal
    observeEvent(input$settings_btn, {
      showModal(modalDialog(
        title = "Personal Instructions",
        textAreaInput(
          "user_instructions_input",
          "Add your personal context or instructions:",
          value = user_instructions(),
          placeholder = "e.g., I work in healthcare and prefer medical terminology...",
          rows = 8,
          width = "100%"
        ),
        helpText(
          "These instructions will be added to the AI's system prompt. ",
          "You'll need to refresh the page to apply the changes."
        ),
        footer = tagList(
          modalButton("Cancel"),
          actionButton(
            "save_instructions",
            "Save & Apply",
            class = "btn-primary"
          )
        ),
        size = "m",
        easyClose = TRUE
      ))
    })

    # Handle saving instructions
    observeEvent(input$save_instructions, {
      new_instructions <- input$user_instructions_input

      # Update instructions in R
      user_instructions(new_instructions)

      # Save to localStorage via JavaScript
      session$sendCustomMessage(
        "save_instructions",
        list(instructions = new_instructions)
      )

      # Close modal
      removeModal()

      # Show notification that refresh is needed
      showNotification(
        HTML(
          paste0(
            "Personal instructions saved! ",
            "<strong>Please refresh the page</strong> to apply the changes. ",
            "(The instructions will be used on the next session.)"
          )
        ),
        type = "message",
        duration = NULL, # Don't auto-dismiss
        closeButton = TRUE
      )
    })

    output$diagram_output <- renderUI({
      req(last_code())
      code <- last_code()
      diagram_type <- last_diagram_type()

      render_diagram_output(code, diagram_type, session)
    })

    output$code_text <- renderText({
      req(last_code())
      last_code()
    })

    output$session_cost <- renderText({
      paste0(sprintf("$%.4f", running_cost()))
    })

    # Handle copy to clipboard button
    setup_copy_button_handler(input, session, last_code)
  }

  shinyApp(ui, server)
}

#' Interactive Shiny app that generates Mermaid and Graphviz diagrams from voice commands using
#' GPT-4o Realtime.
#'
#' @param debug Logical; if TRUE, enables debug mode in shinyrealtime for
#' (extremely) verbose logging.
#'
#' @return A Shiny app object. If this function is called from the R console,
#' the app will launch automatically.
#'
#' @export
diagrambot_voice <- function(debug = FALSE) {
  diagrambot(debug = debug)
}

hidden_audio_el <- function(id, file_path, media_type = "audio/mp3") {
  raw_data <- readBin(file_path, "raw", file.info(file_path)$size)
  base64_data <- base64enc::base64encode(raw_data)
  data_uri <- paste0("data:", media_type, ";base64,", base64_data)
  tags$audio(
    id = id,
    src = data_uri,
    style = "display:none;",
    preload = "auto"
  )
}

#' Ensure OPENAI_API_KEY is available in the environment
#'
#' Checks for OPENAI_API_KEY environment variable and attempts to load it
#' from .Renviron or .env files if not found.
#'
#' @return Invisibly returns TRUE if API key is available
#' @keywords internal
ensure_openai_api_key <- function() {
  if (Sys.getenv("OPENAI_API_KEY") == "") {
    if (
      file.exists(".Renviron") &&
        length(grep("^OPENAI_API_KEY=", readLines(".Renviron"))) > 0
    ) {
      cli::cli_abort(
        c(
          "OPENAI_API_KEY found in .Renviron but not in environment.",
          "i" = "Please restart your R session to load environment variables from .Renviron."
        )
      )
    }
    if (
      file.exists(".env") &&
        length(grep("^OPENAI_API_KEY=", readLines(".env"))) > 0
    ) {
      dotenv::load_dot_env(".env")
      cli::cli_inform(
        c(
          "Found .env file; loading environment variables from .env.",
          "i" = "You can avoid this message by calling library(dotenv) before ggbot()."
        )
      )
    }
    if (Sys.getenv("OPENAI_API_KEY") == "") {
      cli::cli_abort(
        c(
          "OPENAI_API_KEY environment variable is not set.",
          "i" = "You can set it with Sys.setenv(OPENAI_API_KEY = 'your_api_key') or by adding it to a .Renviron or .env file."
        )
      )
    }
  }

  invisible(TRUE)
}

#' Build prompt for the diagrambot
#'
#' Reads the base prompt from the package for diagram generation.
#'
#' @return Character string containing the complete prompt
#' @keywords internal
build_prompt <- function() {
  # Read prompt file
  prompt <- paste(
    collapse = "\n",
    readLines(system.file("prompts/prompt.md", package = "diagrambot"))
  )

  prompt
}

#' Interactive Shiny app that generates Mermaid and Graphviz diagrams from text chat using
#' ellmer and shinychat.
#'
#' @param debug Logical; if TRUE, enables verbose logging.
#'
#' @return A Shiny app object. If this function is called from the R console,
#' the app will launch automatically.
#'
#' @export
diagrambot_chat <- function(debug = FALSE) {
  ensure_openai_api_key()

  prompt <- build_prompt()

  # Add resource path for the package's www directory
  shiny::addResourcePath(
    "diagrambot",
    system.file("www", package = "diagrambot")
  )

  ui <- page_fillable(
    title = "diagrambot chat",
    style = "--bslib-spacer: 1rem;",
    layout_sidebar(
      fillable = TRUE,
      sidebar = sidebar(
        width = 350,
        card(
          full_screen = TRUE,
          card_header("Diagram"),
          card_body(padding = 0, uiOutput("diagram_output", fill = TRUE)),
          height = "50vh"
        ),
        card(
          full_screen = TRUE,
          card_header(
            "Code",
            div(
              style = "float: right;",
              actionButton(
                "copy_code",
                "Copy to Clipboard",
                icon = icon("copy"),
                style = "padding: 2px 8px; font-size: 12px; margin-top: -2px;",
                class = "btn-outline-secondary btn-sm"
              )
            )
          ),
          verbatimTextOutput("code_text"),
          height = "40vh"
        )
      ),
      chat_ui(
        id = "chat",
        messages = "**Welcome to diagrambot!** \U0001F916\n\nI can help you create diagrams using Mermaid or Graphviz. Just describe what you'd like to visualize!"
      )
    ),
    hidden_audio_el(
      "shutter",
      system.file("shutter.mp3", package = "diagrambot")
    ),
    # Include the JavaScript file from the package www directory
    tags$head(
      includeScript(system.file(
        "www",
        "diagram-renderers.js",
        package = "diagrambot"
      ))
    )
  )

  server <- function(input, output, session) {
    last_code <- reactiveVal()
    last_diagram_type <- reactiveVal("mermaid")

    # Initialize ellmer chat with system prompt
    chat <- ellmer::chat_openai(
      system_prompt = prompt,
      model = "gpt-4o"
    )

    # Define and register the generate_diagram tool
    generate_diagram_tool <- create_diagram_tool(
      last_code,
      last_diagram_type,
      debug = debug
    )
    chat$register_tool(generate_diagram_tool)

    # Handle user input from chat
    observeEvent(input$chat_user_input, {
      if (debug) {
        message(sprintf("User input: %s", input$chat_user_input))
      }

      # Stream the response to the chat UI
      stream <- chat$stream_async(input$chat_user_input)
      chat_append("chat", stream)
    })

    # Render the diagram
    output$diagram_output <- renderUI({
      req(last_code())
      code <- last_code()
      diagram_type <- last_diagram_type()

      render_diagram_output(code, diagram_type, session)
    })

    # Show the diagram code
    output$code_text <- renderText({
      req(last_code())
      last_code()
    })

    # Handle copy to clipboard button
    setup_copy_button_handler(input, session, last_code)
  }

  shinyApp(ui, server)
}
