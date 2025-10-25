# Quick Start Guide: diagrambot_chat

## Installation
```r
pak::pak("parmsam/diagrambot")
```

## Prerequisites
Set your OpenAI API key:
```r
# In .Renviron file:
OPENAI_API_KEY=your_api_key_here

# Or in R session:
Sys.setenv(OPENAI_API_KEY = "your_api_key_here")
```

## Basic Usage

### Launch the chat interface
```r
library(diagrambot)
diagrambot_chat()
```

This interface uses `ellmer` and `shinychat` to provide a traditional text chat experience for creating diagrams.

## Example Prompts

### Mermaid Diagrams
- "Create a flowchart for user authentication"
- "Make a sequence diagram for an API call"
- "Draw a Gantt chart for a 2-week sprint"
- "Show me a state diagram for an order process"

### Graphviz Diagrams  
- "Create a network topology using Graphviz"
- "Make an organizational chart with Graphviz"
- "Draw a dependency graph"
- "Show a hierarchical structure using DOT syntax"

### Iterative Refinement
- "Make the nodes bigger"
- "Add more colors"
- "Can you add labels to the connections?"
- "Make it more detailed"
- "Simplify this diagram"

## Features

✅ **Text-based chat interface** - Type naturally instead of using voice  
✅ **Streaming responses** - See AI responses as they're generated  
✅ **Tool calling** - AI automatically calls the diagram generation function  
✅ **Code display** - See the Mermaid/Graphviz code  
✅ **Copy to clipboard** - One-click code copying  
✅ **Real-time preview** - See diagrams update as they're generated  
✅ **Both formats** - Supports Mermaid and Graphviz/DOT syntax  

## Debug Mode
Enable verbose logging:
```r
diagrambot_chat(debug = TRUE)
```

## Comparison with Voice Interface

| Feature | `diagrambot_chat()` | `diagrambot_voice()` |
|---------|---------------------|----------------------|
| Input method | Typing | Voice |
| Best for | Precise requests | Quick iterations |
| AI model | GPT-4o | GPT-4o Realtime |
| Conversation history | Yes | Yes |
| Cost tracking | Via ellmer | Built-in UI |

## Tips

1. **Be conversational** - The AI understands natural language
2. **Iterate** - Start simple, then refine with follow-up messages
3. **Specify format** - Mention "Mermaid" or "Graphviz" if you have a preference
4. **Copy the code** - Use the copy button to save the diagram code

## Troubleshooting

**App doesn't launch:**
- Check that OPENAI_API_KEY is set
- Restart R session after adding to .Renviron

**Diagram doesn't render:**
- Check browser console for errors
- Verify the diagram syntax is valid
- Try simplifying the diagram

**AI doesn't understand:**
- Be more specific about what you want
- Mention the diagram type explicitly
- Start with a simple request and iterate

## More Information
- Full documentation: `?diagrambot_chat`
- Voice interface: `?diagrambot_voice`
- Package repo: https://github.com/parmsam/diagrambot
