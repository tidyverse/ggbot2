#' @import shiny
#' @import bslib
#' @import ellmer
#' @importFrom shinychat markdown_stream output_markdown_stream
#' @importFrom shinyrealtime realtime_ui realtime_server
NULL

#' Interactive Shiny app that generates ggplot2 plots from voice commands using
#' GPT-4o Realtime.
#'
#' @param df Optional data frame to ask the assistant to use; must be a simple
#' variable name, not an expression. If NULL, example datasets from ggplot2 and
#' base R are provided.
#'
#' @return A Shiny app object. If this function is called from the R console,
#' the app will launch automatically.
#'
#' @export
ggbot2 <- function(df = NULL, language = "English") {
  # Read prompt file
  prompt <- paste(
    collapse = "\n",
    readLines(system.file("prompt.md", package = "ggbot2"))
  )

  if (!missing(df)) {
    df_name <- deparse(substitute(df))

    if (!is.data.frame(df)) {
      stop("df must be a data frame or NULL")
    }

    df_preview <- paste(
      collapse = "\n",
      capture.output(write.csv(head(df), ""))
    )

    withr::with_options(list(width = 1000), {
      df_structure <- paste(
        collapse = "\n",
        capture.output(str(df))
      )

      df_summary <- paste(
        collapse = "\n",
        capture.output(summary(df))
      )
    })

    # Include the first few rows of the provided dataset in the prompt
    prompt <- paste0(
      prompt,
      interpolate(
        "\n\nThe user has provided a data frame with the variable name `{{df_name}}`. Its first few rows look like this:\n\n{{df_preview}}\n\nIts summary looks like this:\n\n{{df_summary}}\n\nUnless explicitly told otherwise, assume the user wants you to use this data frame for plotting.",
      )
    )
  } else {
    # Load example datasets
    samples <- list()
    for (dataset in c("mpg", "diamonds", "economics", "iris", "mtcars")) {
      df <- eval(parse(text = dataset))
      if (is.data.frame(df)) {
        samples <- c(
          samples,
          paste0(
            "## ",
            dataset,
            "\n\n",
            capture.output(write.csv(head(df), "")),
            collapse = "\n"
          )
        )
      }
    }

    prompt <- paste0(
      prompt,
      "\n\n# Available Datasets\n\n",
      paste(samples, collapse = "\n\n")
    )
  }

  prompt <- paste0(
    prompt,
    "\n\nImportant: Respond only in ",
    language,
    "."
  )

  ui <- page_sidebar(
    title = "VoicePlot",
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
      last_code(code)
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
      speed = 1.1
    )

    # Handle function call start - show notification
    realtime_controls$on("conversation.item.added", \(event) {
      if (event$item$type == "function_call") {
        shiny::showNotification(
          "Generating code, please wait...",
          id = event$item$id,
          closeButton = FALSE
        )
      }
    })

    # Handle function call completion - remove notification
    realtime_controls$on("conversation.item.done", \(event) {
      if (event$item$type == "function_call") {
        shiny::removeNotification(id = event$item$id)
      }
    })

    # Handle new messages - clear transcript
    realtime_controls$on("response.created", \(event) {
      append_transcript("", clear = TRUE)
    })

    # Handle text streaming
    realtime_controls$on("response.output_audio_transcript.delta", \(event) {
      append_transcript(event$delta)
    })

    realtime_controls$on("response.done", \(event) {
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
      result <- withVisible(eval(parse(text = last_code())))
      session$sendCustomMessage("play_audio", list(selector = "#shutter"))
      if (result$visible) {
        result$value
      } else {
        invisible(result$value)
      }
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
