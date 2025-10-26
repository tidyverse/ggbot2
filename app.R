# Install diagrambot from GitHub if not already installed
if (!require("diagrambot", quietly = TRUE)) {
    remotes::install_github("parmsam/canvasbot")
}

# Load the diagrambot package
library(diagrambot)

# Launch the voice interface
diagrambot_voice()
