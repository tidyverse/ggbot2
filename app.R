# Install diagrambot from GitHub if not already installed
if (!require("diagrambot", quietly = TRUE)) {
    remotes::install_github("parmsam/canvasbot", dependencies = TRUE)
}

# Explicitly load required packages
library(shiny)
library(bslib)
library(ellmer)
library(shinyrealtime)
library(shinychat)

# Load the diagrambot package
library(diagrambot)

# Launch the voice interface
diagrambot_voice()
