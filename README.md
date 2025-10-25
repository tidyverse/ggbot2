# diagrambot

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)

<!-- badges: end -->

diagrambot is a voice assistant for creating Mermaid and Graphviz diagrams. It helps you generate flowcharts, sequence diagrams, network graphs, organizational charts, and more using voice commands and AI. diagrambot supports both Mermaid syntax for a wide variety of structured diagrams and Graphviz/DOT syntax for complex network and hierarchical visualizations. diagrambot is a fork of [ggbot2](https://github.com/tidyverse/ggbot2/) from [Posit](https://posit.co/).

## Prerequisites

In order to use diagrambot, you will need an OpenAI API key. You can obtain one from the [OpenAI dashboard](https://platform.openai.com/api-keys). You'll also need to put at least a few dollars on your account to use the API.

Once you have an API key, you will need to set it as an environment variable named `OPENAI_API_KEY`. You can do this by adding the following line to an `.Renviron` file in your project directory:

```
OPENAI_API_KEY=your_api_key_here
```

Then restart your R session.

## Installation

```r
pak::pak("parmsam/diagrambot")
```

## Usage

diagrambot provides two interfaces for creating diagrams:

### Voice Interface

To launch diagrambot with voice control, call the `diagrambot_voice()` function:

```r
diagrambot::diagrambot_voice()
```

This interface uses GPT-4o Realtime for voice interactions. Click the microphone button to speak, or use push-to-talk by clicking and holding the mic or holding the spacebar key.

### Chat Interface

For a text-based chat interface, use `diagrambot_chat()`:

```r
diagrambot::diagrambot_chat()
```

This interface uses `ellmer` and `shinychat` to provide a traditional text chat experience. It's great for when you want to type your requests or when voice isn't convenient.

### Diagram Types

diagrambot supports two powerful diagram formats:

#### Mermaid Diagrams
Perfect for structured, process-oriented visualizations:

- **Flowcharts**: Process flows, decision trees, and workflows
- **Sequence diagrams**: Interactions between different actors over time
- **Class diagrams**: Object-oriented system structures and relationships
- **State diagrams**: State machines and transitions
- **User journey maps**: User experience flows and touchpoints
- **Gantt charts**: Project timelines and scheduling
- **Pie charts**: Data visualization and proportions
- **Git graphs**: Repository branching and merging visualizations
- **Entity relationship diagrams**: Database schema and relationships
- **Mind maps**: Hierarchical information and brainstorming

#### Graphviz Diagrams
Excellent for network structures and complex relationships:

- **Network graphs**: System architectures, network topologies
- **Dependency graphs**: Software dependencies, build systems
- **Organizational charts**: Company hierarchies, team structures
- **Data flow diagrams**: Information flow between systems
- **Graph algorithms**: Shortest paths, spanning trees
- **Finite state machines**: Complex state transitions
- **Database schemas**: Advanced entity relationships
- **Call graphs**: Function call hierarchies in code

## Act natural

### Voice Interface (`diagrambot_voice()`)

There's no need to speak clearly, slowly, or formally to diagrambot. Try speaking like you would to a person sitting across from you.

You don't ever have to wait for diagrambot to finish talking; you can just start speaking and diagrambot will quickly notice you are interrupting.

You don't have to be precise with your commands to diagrambot. For example, give it a general sense of what kind of diagram you want to create, and it will generate the appropriate code.

### Chat Interface (`diagrambot_chat()`)

With the chat interface, simply type your requests naturally as if you're chatting with a colleague. You can be as detailed or as high-level as you like—the AI will interpret your intent and create the appropriate diagram. The chat history is preserved, so you can iteratively refine your diagrams through conversation.

## Suggested prompts

Here are the kinds of things you can say to diagrambot:

### Mermaid Examples
- "Create a flowchart showing the software development process"
- "Make a sequence diagram for a user login flow"
- "Draw a class diagram for a simple e-commerce system"
- "Show me a Gantt chart for a 3-month project timeline"
- "Create a state diagram for a traffic light system"
- "Make a user journey map for an online shopping experience"
- "Draw an entity relationship diagram for a blog database"
- "Show me a pie chart of budget allocation"
- "Create a git graph showing feature branch workflow"
- "Make a mind map about machine learning concepts"

### Graphviz Examples
- "Create a network topology diagram for our data center"
- "Draw an organizational chart for our engineering team"
- "Show the dependency graph for our microservices"
- "Make a system architecture diagram with servers and databases"
- "Create a call graph for this algorithm"
- "Draw a decision tree using Graphviz"
- "Show the data flow between our applications"
- "Create a graph showing shortest path algorithms"
- "Make a hierarchical clustering diagram"
- "Draw a finite state machine with complex transitions"

### General Commands
- "Make the nodes larger and more colorful"
- "Add more detail to the current diagram"
- "Simplify this diagram"
- "Let's start over with a new diagram"
- "Change the layout to be more vertical"
- "Add labels to all the connections"
- "Switch to Graphviz format"
- "Convert this to a Mermaid diagram"

## Guide

See the [guide](GUIDE.md) for more detailed instructions and tips, including a comparison and troubleshooting section.
