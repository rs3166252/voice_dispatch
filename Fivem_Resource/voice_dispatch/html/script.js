// Check if speech recognition is available
console.log("[Voice Dispatch] ========== ENVIRONMENT CHECK ==========");
console.log("[Voice Dispatch] User Agent:", navigator.userAgent);
console.log("[Voice Dispatch] Location:", window.location.href);
console.log("[Voice Dispatch] ======================================");

let isListening = false;
let isStarting = false;

// UI Elements
const statusDiv = document.getElementById('voiceStatus');
const statusText = document.getElementById('statusText');
const statusIcon = document.getElementById('voiceIcon');
const transcriptText = document.getElementById('transcriptText');

function showStatus(text, icon = '🎤', className = '', transcript = '') {
    statusText.textContent = text;
    statusIcon.textContent = icon;
    transcriptText.textContent = transcript;
    statusDiv.className = className;
    statusDiv.style.display = 'block';
    console.log("[Voice Dispatch UI]", text, transcript);
}

function hideStatus() {
    statusDiv.style.display = 'none';
    transcriptText.textContent = '';
}

// Initialization
console.log("[Voice Dispatch] ========================================");
console.log("[Voice Dispatch] Voice Dispatch Ready!");
console.log("[Voice Dispatch] Waiting for C# program connection...");
console.log("[Voice Dispatch] ========================================");

window.addEventListener("message", function(event) {
    if (event.data.action === "start") {
        console.log("[Voice Dispatch] Key pressed - starting");
        
        // If already active, ignore (wait for release first)
        if (isListening || isStarting) {
            console.log("[Voice Dispatch] Already active, ignoring press");
            return;
        }
        
        // Reset flag and start new recognition
        shouldStopWhenReady = false;
        
        // Get player server ID from event data
        const playerId = event.data.playerId || 0;
        startRecognition(playerId);
    }

    if (event.data.action === "stop") {
        console.log("[Voice Dispatch] Key released - stopping");
        
        // Send stop to C# program
        sendToLocalhost('stop', {})
            .then(() => {
                console.log("[Voice Dispatch] Stop sent, now getting result...");
                // Small delay to let C# finish processing
                return new Promise(resolve => setTimeout(resolve, 200));
            })
            .then(() => {
                // After stopping, get the result
                console.log("[Voice Dispatch] Fetching result from C# program...");
                return fetch('http://localhost:8765/result');
            })
            .then(response => {
                console.log("[Voice Dispatch] Got response from /result");
                return response.json();
            })
            .then(data => {
                console.log("[Voice Dispatch] Result data:", JSON.stringify(data));
                console.log("[Voice Dispatch] Text:", data.text);
                console.log("[Voice Dispatch] Text length:", data.text ? data.text.length : 0);
                
                if (data.text && data.text.trim().length > 0) {
                    console.log("[Voice Dispatch] ✅ Got result from C#:", data.text);
                    showStatus('Sending...', '📤', 'processing', `"${data.text}"`);
                    
                    // Send to client.lua
                    fetch(`https://${GetParentResourceName()}/speechResult`, {
                        method: "POST",
                        headers: { "Content-Type": "application/json" },
                        body: JSON.stringify({ text: data.text })
                    }).then(() => {
                        console.log("[Voice Dispatch] Sent to server successfully");
                        showStatus('Sent!', '✅', 'processing', `"${data.text}"`);
                        setTimeout(() => hideStatus(), 2000);
                    }).catch(err => {
                        console.error("[Voice Dispatch] Error sending to server:", err);
                        showStatus('Error sending', '❌', 'error');
                        setTimeout(() => hideStatus(), 2000);
                    });
                } else {
                    console.log("[Voice Dispatch] ⚠️ No speech recognized (empty result)");
                    showStatus('No speech detected', '🔇', 'error');
                    setTimeout(() => hideStatus(), 2000);
                }
            })
            .catch(error => {
                console.error("[Voice Dispatch] ❌ Error getting result:", error);
                showStatus('Connection error', '❌', 'error');
                setTimeout(() => hideStatus(), 2000);
            });
        
        // Reset states
        isListening = false;
        isStarting = false;
    }

    // Show dispatch messages (follow-up questions)
    if (event.data.action === "showDispatchMessage") {
        console.log("[Voice Dispatch] 📞 Dispatch Message:", event.data.message);
        showDispatchMessage(event.data.message);
    }
});

// Send HTTP request to player's local C# program
function sendToLocalhost(endpoint, data) {
    return fetch(`http://localhost:8765/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    })
    .then(response => {
        if (response.ok) {
            console.log(`[Voice Dispatch] Sent ${endpoint} to C# program`);
            return response;
        } else {
            console.error(`[Voice Dispatch] C# program returned: ${response.status}`);
            throw new Error(`C# program error: ${response.status}`);
        }
    })
    .catch(error => {
        console.error(`[Voice Dispatch] Failed to reach C# program:`, error.message);
        showStatus('C# program not running!', '❌', 'error');
        setTimeout(() => hideStatus(), 3000);
        throw error;
    });
}

function startRecognition(playerId) {
    showStatus('🎤 Listening... Speak now!', '🎤', 'listening');
    
    isStarting = true;
    console.log("[Voice Dispatch] Sending start command to C# program...");
    console.log("[Voice Dispatch] Player ID:", playerId);
    
    // Send start command with player ID to C# program
    sendToLocalhost('start', { playerId: playerId })
        .then(() => {
            isStarting = false;
            isListening = true;
            console.log("[Voice Dispatch] ✅ C# program started listening");
        })
        .catch(() => {
            isStarting = false;
            isListening = false;
        });
}

// Show dispatch message overlay
function showDispatchMessage(message) {
    const dispatchDiv = document.createElement('div');
    dispatchDiv.className = 'dispatch-message';
    dispatchDiv.innerHTML = `
        <div class="dispatch-icon">📞</div>
        <div class="dispatch-text">
            <div class="dispatch-header">DISPATCH</div>
            <div class="dispatch-content">${message}</div>
        </div>
    `;
    document.body.appendChild(dispatchDiv);
    
    // Play sound effect (beep)
    const beep = new Audio('data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1vc=');
    beep.play().catch(() => {});
    
    // Auto-hide after 5 seconds
    setTimeout(() => {
        dispatchDiv.style.opacity = '0';
        setTimeout(() => dispatchDiv.remove(), 500);
    }, 5000);
}
