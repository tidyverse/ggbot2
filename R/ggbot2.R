#' @import shiny
#' @import bslib
#' @import ellmer
#' @import ggplot2
#' @importFrom shinychat markdown_stream output_markdown_stream
#' @importFrom shinyrealtime realtime_ui realtime_server
NULL

globalVariables("yield")

#' Interactive Shiny app that generates ggplot2 plots from voice commands using
#' GPT-4o Realtime.
#'
#' @param df Optional data frame to ask the assistant to use; must be a simple
#' variable name, not an expression. If NULL, example datasets from ggplot2 and
#' base R are provided.
#' @param debug Logical; if TRUE, enables debug mode in shinyrealtime for
#' (extremely) verbose logging.
#'
#' @return A Shiny app object. If this function is called from the R console,
#' the app will launch automatically.
#'
#' @export
ggbot <- function(df, debug = FALSE) {
  if (missing(df)) {
    cli::cli_abort(
      "ggbot() requires a data frame variable to be provided as the `df` argument."
    )
  }

  df_name <- deparse(substitute(df))

  if (!is.data.frame(df)) {
    cli::cli_abort("df must be a data frame or NULL")
  }

  ensure_openai_api_key()

  prompt <- build_prompt(df, df_name)

  ui <- page_sidebar(
    title = "ggbot2",
    fillable = TRUE,
    style = "--bslib-spacer: 1rem; padding-bottom: 0;",
    sidebar = sidebar(
      helpText("Session cost:", textOutput("session_cost", inline = TRUE)),
      output_markdown_stream("response_text")
    ),
    card(
      full_screen = TRUE,
      card_header("Plot"),
      card_body(padding = 0, plotOutput("plot", fill = TRUE)),
      height = "66%"
    ),
    layout_columns(
      height = "34%",
      card(
        full_screen = TRUE,
        card_header("Code"),
        verbatimTextOutput("code_text")
      )
    ),
    realtime_ui(
      "realtime1",
      style = "z-index: 100000; margin-left: auto; margin-right: auto;",
      right = NULL
    ),
    hidden_audio_el("shutter", system.file("shutter.mp3", package = "ggbot2"))
  )

  server <- function(input, output, session) {
    last_code <- reactiveVal()
    running_cost <- reactiveVal(0) # Cost of tokens used in the session, in dollars

    greeting <- "Welcome to Shiny Realtime!\n\nYou're currently muted; click the mic button to unmute, click-and-hold the mic for push-to-talk, or hold the spacebar key for push-to-talk."

    append_transcript <- function(text, clear = FALSE) {
      markdown_stream(
        "response_text",
        coro::gen(yield(text)),
        operation = if (clear) "replace" else "append",
        session = session
      )
    }

    append_transcript(greeting, clear = TRUE)

    run_r_plot_code <- function(code) {
      attr(code, "rnd") <- stats::runif(1) # Force re-evaluation even if code is the same
      last_code(code)

      # Ideally we'd run the code here to check for errors and let the model
      # know about success/failure in a tool response. But we only want to run
      # this code once, and with the environment set up correctly as renderPlot
      # does.
      NULL
    }

    run_r_plot_code_tool <- ellmer::tool(
      run_r_plot_code,
      "Run R code that generates a static plot",
      arguments = list(
        code = type_string(
          "The R code to run that generates a plot. If using ggplot2, the last expression in the code should be the plot object, e.g. `p`."
        )
      )
    )

    realtime_controls <- realtime_server(
      "realtime1",
      voice = "cedar",
      instructions = prompt,
      tools = list(run_r_plot_code_tool),
      speed = 1.1,
      debug = debug
    )

    # Handle function call start - show notification
    realtime_controls$on("conversation.item.added", function(event) {
      if (event$item$type == "function_call") {
        shiny::showNotification(
          "Generating code, please wait...",
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
      # "usage": {
      #   "total_tokens": 1977,
      #   "input_tokens": 1687,
      #   "output_tokens": 290,
      #   "input_token_details": {
      #     "text_tokens": 1636,
      #     "audio_tokens": 51,
      #     "image_tokens": 0,
      #     "cached_tokens": 1600,
      #     "cached_tokens_details": {
      #       "text_tokens": 1600,
      #       "audio_tokens": 0,
      #       "image_tokens": 0
      #     }
      #   },
      #   "output_token_details": { "text_tokens": 68, "audio_tokens": 222 }
      # }
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
    pricing_gpt_4o_mini <- c(
      input_text = 0.6 / 1e6,
      input_audio = 10 / 1e6,
      input_text_cached = 0.3 / 1e6,
      input_audio_cached = 0.3 / 1e6,
      output_text = 2.4 / 1e6,
      output_audio = 20 / 1e6
    )

    output$plot <- renderPlot(res = 96, {
      req(last_code())
      on.exit(session$sendCustomMessage(
        "play_audio",
        list(selector = "#shutter")
      ))
      tryCatch(
        eval(parse(text = last_code()), envir = new.env(parent = globalenv())),
        error = function(e) {
          # This seems like it would be helpful, but when we send this, it seems
          # to effectively end the conversation.
          #
          # realtime_controls$send_text(
          #   paste0(
          #     "The R code you provided resulted in an error: ",
          #     paste(collapse = "\n", conditionMessage(e))
          #   )
          # )
          stop(e)
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
  }

  shinyApp(ui, server)
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

#' Build prompt with data frame information
#'
#' Reads the base prompt from the package and incorporates data frame preview,
#' structure, and summary information.
#'
#' @param df Data frame to analyze and include in the prompt
#' @param df_name Character string with the variable name of the data frame
#'
#' @return Character string containing the complete prompt
#' @keywords internal
build_prompt <- function(df, df_name) {
  # Read prompt file
  prompt <- paste(
    collapse = "\n",
    readLines(system.file("prompts/prompt.md", package = "ggbot2"))
  )

  df_preview <- paste(
    collapse = "\n",
    utils::capture.output(utils::write.csv(utils::head(df), ""))
  )

  withr::with_options(list(width = 1000), {
    df_structure <- paste(
      collapse = "\n",
      utils::capture.output(utils::str(df))
    )

    df_summary <- paste(
      collapse = "\n",
      utils::capture.output(summary(df))
    )
  })

  # Include the first few rows of the provided dataset in the prompt
  paste0(
    prompt,
    interpolate(
      "\n\nThe user has provided a data frame with the variable name `{{df_name}}`. Its first few rows look like this:\n\n{{df_preview}}\n\nIts summary looks like this:\n\n{{df_summary}}\n\nUnless explicitly told otherwise, assume the user wants you to use this data frame for plotting.",
    )
  )
}
