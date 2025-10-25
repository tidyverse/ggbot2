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
  "div"
))

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
      br(),
      output_markdown_stream("response_text")
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
      ))
    )
  )

  server <- function(input, output, session) {
    # Clean up resource path when session ends
    session$onSessionEnded(function() {
      shiny::removeResourcePath("diagrambot")
    })

    last_code <- reactiveVal()
    last_diagram_type <- reactiveVal("mermaid")
    running_cost <- reactiveVal(0) # Cost of tokens used in the session, in dollars

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

    generate_diagram <- function(code, diagram_type) {
      attr(code, "rnd") <- stats::runif(1) # Force re-evaluation even if code is the same
      last_code(code)
      last_diagram_type(diagram_type)
      NULL
    }

    generate_diagram_tool <- ellmer::tool(
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

    # Rendering function for Mermaid diagrams
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

    # Rendering function for Graphviz diagrams
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

    realtime_controls <- realtime_server(
      "realtime1",
      voice = "cedar",
      instructions = prompt,
      tools = list(generate_diagram_tool),
      speed = 1.1,
      debug = debug
    )

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

    output$diagram_output <- renderUI({
      req(last_code())
      code <- last_code()
      diagram_type <- last_diagram_type()

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
    })

    output$code_text <- renderText({
      req(last_code())
      last_code()
    })

    output$session_cost <- renderText({
      paste0(sprintf("$%.4f", running_cost()))
    })

    # Handle copy to clipboard button
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
    # Clean up resource path when session ends
    session$onSessionEnded(function() {
      shiny::removeResourcePath("diagrambot")
    })

    last_code <- reactiveVal()
    last_diagram_type <- reactiveVal("mermaid")

    # Initialize ellmer chat with system prompt
    chat <- ellmer::chat_openai(
      system_prompt = prompt,
      model = "gpt-4o"
    )

    # Define the generate_diagram tool
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

    generate_diagram_tool <- ellmer::tool(
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

    # Register the tool with the chat
    chat$register_tool(generate_diagram_tool)

    # Rendering function for Mermaid diagrams
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

    # Rendering function for Graphviz diagrams
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
    })

    # Show the diagram code
    output$code_text <- renderText({
      req(last_code())
      last_code()
    })

    # Handle copy to clipboard button
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

  shinyApp(ui, server)
}
