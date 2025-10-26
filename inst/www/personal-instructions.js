// Local storage helper functions
function saveInstructionsToLocalStorage(instructions) {
  console.log('Saving to localStorage:', instructions);
  localStorage.setItem('diagrambot_instructions', instructions);
  console.log('Saved. Verifying:', localStorage.getItem('diagrambot_instructions'));
}

function getInstructionsFromLocalStorage() {
  var instructions = localStorage.getItem('diagrambot_instructions') || '';
  console.log('Loading from localStorage:', instructions);
  return instructions;
}

// Send initial instructions from localStorage to Shiny after Shiny is ready
$(document).on('shiny:connected', function() {
  console.log('Shiny connected, loading instructions...');
  var storedInstructions = getInstructionsFromLocalStorage();
  console.log('Sending to Shiny:', storedInstructions);
  Shiny.setInputValue('initial_instructions', storedInstructions, {priority: 'event'});
});

// Handle save_instructions message from Shiny
Shiny.addCustomMessageHandler('save_instructions', function(data) {
  console.log('Received save_instructions message:', data);
  saveInstructionsToLocalStorage(data.instructions);
});

// Disable spacebar keyboard shortcut when modal is open
$(document).on('shown.bs.modal', '.modal', function() {
  console.log('Modal opened - disabling spacebar shortcut');
  
  // Add high-priority handler to block spacebar from triggering mic
  $(document).on('keydown.modal-block-spacebar keyup.modal-block-spacebar', function(e) {
    if (e.which === 32 || e.keyCode === 32) {
      // Check if we're in a text input area
      if ($(e.target).is('textarea, input[type=text], input[type="text"]')) {
        // Allow spacebar in text inputs - stop it from bubbling
        e.stopImmediatePropagation();
        return true;
      } else {
        // Block spacebar completely outside text inputs
        e.preventDefault();
        e.stopImmediatePropagation();
        return false;
      }
    }
  });
});

// Re-enable spacebar keyboard shortcut when modal is closed
$(document).on('hidden.bs.modal', '.modal', function() {
  console.log('Modal closed - re-enabling spacebar shortcut');
  $(document).off('keydown.modal-block-spacebar keyup.modal-block-spacebar');
});
