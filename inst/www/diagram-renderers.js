// Mermaid and Graphviz diagram rendering for diagrambot

// Global variables to track loading state
window.mermaidReady = false;
window.graphvizReady = false;

// Initialize libraries when the page loads
$(document).ready(function() {
  // Set up Shiny custom message handler for copy to clipboard
  Shiny.addCustomMessageHandler('copy_to_clipboard', function(message) {
    copyToClipboard(message.text);
  });
  
  // Load Mermaid if not already loaded
  if (typeof mermaid === 'undefined') {
    $.getScript('https://cdn.jsdelivr.net/npm/mermaid@10.6.1/dist/mermaid.min.js')
      .done(function() {
        mermaid.initialize({ 
          startOnLoad: false, // Important: set to false for manual rendering
          theme: 'default',
          securityLevel: 'loose',
          fontFamily: 'inherit'
        });
        window.mermaidReady = true;
        console.log('Mermaid initialized successfully');
      })
      .fail(function() {
        console.error('Failed to load Mermaid library');
      });
  } else {
    // Reinitialize if already loaded
    mermaid.initialize({ 
      startOnLoad: false,
      theme: 'default',
      securityLevel: 'loose',
      fontFamily: 'inherit'
    });
    window.mermaidReady = true;
  }

  // Load Graphviz (viz.js) if not already loaded
  if (typeof Viz === 'undefined') {
    $.getScript('https://cdn.jsdelivr.net/npm/@viz-js/viz@3.2.4/lib/viz-standalone.js')
      .done(function() {
        window.graphvizReady = true;
        console.log('Graphviz (viz.js) initialized successfully');
      })
      .fail(function() {
        console.error('Failed to load Graphviz library');
      });
  } else {
    window.graphvizReady = true;
  }
  
  // Load svg-pan-zoom for better diagram interaction
  if (typeof svgPanZoom === 'undefined') {
    $.getScript('https://cdn.jsdelivr.net/npm/svg-pan-zoom@3.6.1/dist/svg-pan-zoom.min.js')
      .done(function() {
        console.log('svg-pan-zoom loaded successfully');
      })
      .fail(function() {
        console.warn('Failed to load svg-pan-zoom library');
      });
  }
});

// Function to render Mermaid diagrams with retry logic
function renderMermaidDiagram(elementId, code, retryCount = 0) {
  console.log('Attempting to render Mermaid diagram:', elementId, code);
  
  const element = document.getElementById(elementId);
  if (!element) {
    console.error('Element not found:', elementId);
    return;
  }

  // Check if Mermaid is ready
  if (typeof mermaid === 'undefined' || !window.mermaidReady) {
    if (retryCount < 10) { // Retry up to 10 times
      element.innerHTML = '<div class="alert alert-info">Loading Mermaid library... (attempt ' + (retryCount + 1) + ')</div>';
      setTimeout(function() {
        renderMermaidDiagram(elementId, code, retryCount + 1);
      }, 1000);
      return;
    } else {
      element.innerHTML = '<div class="alert alert-warning">Mermaid library failed to load after multiple attempts.</div>';
      return;
    }
  }

  try {
    // Clear the element first
    element.innerHTML = '';
    
    // Create a unique ID for this diagram
    const diagramId = 'mermaid-diagram-' + Date.now() + '-' + Math.random().toString(36).substr(2, 9);
    
    // Create the mermaid container
    const mermaidDiv = document.createElement('div');
    mermaidDiv.className = 'mermaid';
    mermaidDiv.id = diagramId;
    mermaidDiv.textContent = code;
    mermaidDiv.style.cssText = 'width: 100%; height: 100%; min-height: 400px; display: flex; align-items: center; justify-content: center;';
    
    element.appendChild(mermaidDiv);
    
    // Use the modern mermaid.run() method for v10+
    mermaid.run({
      nodes: [mermaidDiv]
    }).then(() => {
      console.log('Mermaid diagram rendered successfully');
      
      // Add pan and zoom capabilities if svg-pan-zoom is available
      setTimeout(() => {
        const svg = mermaidDiv.querySelector('svg');
        if (svg && typeof svgPanZoom !== 'undefined') {
          // Make sure SVG has proper dimensions
          svg.style.width = '100%';
          svg.style.height = '100%';
          
          svgPanZoom(svg, {
            zoomEnabled: true,
            controlIconsEnabled: true,
            fit: true,
            center: true,
            minZoom: 0.1,
            maxZoom: 10,
            zoomScaleSensitivity: 0.3
          });
        }
      }, 100);
    }).catch((error) => {
      console.error('Mermaid rendering error:', error);
      let errorMsg = 'Error rendering Mermaid diagram: ' + error.message;
      
      // Provide helpful hints based on common errors
      if (error.message.includes('Parse error')) {
        errorMsg += '<br><br><strong>Common fixes:</strong><ul>' +
          '<li>Make sure each node and connection is on a separate line</li>' +
          '<li>Quote labels with special characters: A["Label (text)"]</li>' +
          '<li>Avoid chaining statements like A-->B.B-->C</li>' +
          '<li>Try asking the AI to "fix the syntax errors" or "regenerate with proper line breaks"</li></ul>';
      }
      
      element.innerHTML = '<div class="alert alert-danger" style="padding: 15px;">' + errorMsg + '</div>';
    });
    
  } catch (error) {
    console.error('Mermaid rendering error:', error);
    element.innerHTML = '<div class="alert alert-danger">Error rendering Mermaid diagram: ' + error.message + '</div>';
  }
}

// Function to render Graphviz diagrams with retry logic
function renderGraphvizDiagram(elementId, code, retryCount = 0) {
  console.log('Attempting to render Graphviz diagram:', elementId, code);
  
  const element = document.getElementById(elementId);
  if (!element) {
    console.error('Element not found:', elementId);
    return;
  }

  // Check if Graphviz is ready
  if (typeof Viz === 'undefined' || !window.graphvizReady) {
    if (retryCount < 10) { // Retry up to 10 times
      element.innerHTML = '<div class="alert alert-info">Loading Graphviz library... (attempt ' + (retryCount + 1) + ')</div>';
      setTimeout(function() {
        renderGraphvizDiagram(elementId, code, retryCount + 1);
      }, 1000);
      return;
    } else {
      element.innerHTML = '<div class="alert alert-warning">Graphviz library failed to load after multiple attempts.</div>';
      return;
    }
  }

  try {
    // Clear the element first
    element.innerHTML = '';
    
    // Create a container for the Graphviz diagram
    const graphvizDiv = document.createElement('div');
    graphvizDiv.style.cssText = 'width: 100%; height: 100%; min-height: 400px; display: flex; align-items: center; justify-content: center; overflow: auto;';
    
    element.appendChild(graphvizDiv);
    
    // Render the Graphviz diagram
    Viz.instance().then(function(viz) {
      try {
        const svg = viz.renderSVGElement(code);
        // Style the SVG to fit the container
        svg.style.width = '100%';
        svg.style.height = '100%';
        graphvizDiv.appendChild(svg);
        console.log('Graphviz diagram rendered successfully');
        
        // Add pan and zoom capabilities if svg-pan-zoom is available
        setTimeout(() => {
          if (typeof svgPanZoom !== 'undefined') {
            svgPanZoom(svg, {
              zoomEnabled: true,
              controlIconsEnabled: true,
              fit: true,
              center: true,
              minZoom: 0.1,
              maxZoom: 10,
              zoomScaleSensitivity: 0.3
            });
          }
        }, 100);
      } catch (error) {
        console.error('Graphviz rendering error:', error);
        let errorMsg = 'Error rendering Graphviz diagram: ' + error.message;
        
        // Provide helpful hints based on common errors
        if (error.message.includes('syntax error')) {
          errorMsg += '<br><br><strong>Common fixes:</strong><ul>' +
            '<li>Check for missing semicolons after node/edge declarations</li>' +
            '<li>Ensure proper DOT syntax: node1 -> node2;</li>' +
            '<li>Quote labels with special characters: [label="Text (with parens)"]</li>' +
            '<li>Try asking the AI to "fix the Graphviz syntax" or "regenerate"</li></ul>';
        }
        
        element.innerHTML = '<div class="alert alert-danger" style="padding: 15px;">' + errorMsg + '</div>';
      }
    }).catch(function(error) {
      console.error('Graphviz initialization error:', error);
      element.innerHTML = '<div class="alert alert-danger">Error initializing Graphviz: ' + error.message + '</div>';
    });
    
  } catch (error) {
    console.error('Graphviz rendering error:', error);
    element.innerHTML = '<div class="alert alert-danger">Error rendering Graphviz diagram: ' + error.message + '</div>';
  }
}

// Function to copy text to clipboard
function copyToClipboard(text) {
  // Try using the modern Clipboard API first
  if (navigator.clipboard && window.isSecureContext) {
    navigator.clipboard.writeText(text).then(function() {
      console.log('Text copied to clipboard using Clipboard API');
    }).catch(function(err) {
      console.error('Failed to copy text using Clipboard API:', err);
      // Fallback to the older method
      fallbackCopyToClipboard(text);
    });
  } else {
    // Fallback for older browsers or non-secure contexts
    fallbackCopyToClipboard(text);
  }
}

// Fallback copy function for older browsers
function fallbackCopyToClipboard(text) {
  try {
    // Create a temporary textarea element
    const textArea = document.createElement('textarea');
    textArea.value = text;
    textArea.style.position = 'fixed';
    textArea.style.left = '-999999px';
    textArea.style.top = '-999999px';
    document.body.appendChild(textArea);
    
    // Select and copy the text
    textArea.focus();
    textArea.select();
    document.execCommand('copy');
    
    // Clean up
    document.body.removeChild(textArea);
    console.log('Text copied to clipboard using fallback method');
  } catch (err) {
    console.error('Failed to copy text using fallback method:', err);
  }
}
