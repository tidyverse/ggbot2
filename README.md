# ggbot2

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)

<!-- badges: end -->

ggbot2 is a voice assistant for ggplot2. It helps you create and customize ggplot2 visualizations using voice commands.

## Prerequisites

In order to use ggbot2, you will need an OpenAI API key. You can obtain one from the [OpenAI dashboard](https://platform.openai.com/api-keys). You'll also need to put at least a few dollars on your account to use the API.

Once you have an API key, you will need to set it as an environment variable named `OPENAI_API_KEY`. You can do this by adding the following line to an `.Renviron` file in your project directory:

```
OPENAI_API_KEY=your_api_key_here
```

Then restart your R session.

## Installation

```r
pak::pak("tidyverse/ggbot2")
```

## Usage

To launch ggbot2, simply call the `ggbot()` function, passing in the name of a data frame variable:

```r
ggbot2::ggbot(penguins)
```

If you don't have a specific data frame in mind, you can call ggbot2 without any arguments, and ask it to plot "mtcars", "diamonds", "economics", or "iris".

## Suggested prompts

Here are the kinds of things you can say to databot:

- "Create a scatter plot of mpg vs weight"
- "Color by cylinder"
- "Make the points blue and larger"
- "Add a title to the plot"
- "There are too many x-axis labels"
