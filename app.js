/**
 * Amazing Image Identifier - Frontend JavaScript
 * Handles file upload, drag-drop, image analysis, and results display
 */

// DOM Elements
const dropArea = document.getElementById('dropArea');
const fileInput = document.getElementById('fileInput');
const analyzeBtn = document.getElementById('analyzeBtn');
const clearBtn = document.getElementById('clearBtn');
const loadingState = document.getElementById('loadingState');
const resultsSection = document.getElementById('resultsSection');
const errorMessage = document.getElementById('errorMessage');
const errorText = document.getElementById('errorText');

// Results elements
const processingTime = document.getElementById('processingTime');
const originalImage = document.getElementById('originalImage');
const annotatedImage = document.getElementById('annotatedImage');
const captionText = document.getElementById('captionText');
const objectsList = document.getElementById('objectsList');
const colorsList = document.getElementById('colorsList');
const ocrSection = document.getElementById('ocrSection');
const ocrText = document.getElementById('ocrText');
const audioBtn = document.getElementById('audioBtn');

// History elements
const clearHistoryBtn = document.getElementById('clearHistoryBtn');
const historyGrid = document.getElementById('historyGrid');

// State
let selectedFile = null;
let currentResults = null;

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    setupEventListeners();
    loadHistory();
});

/**
 * Setup all event listeners
 */
function setupEventListeners() {
    // Upload area click
    dropArea.addEventListener('click', () => fileInput.click());
    
    // File selection
    fileInput.addEventListener('change', (e) => {
        if (e.target.files.length > 0) {
            handleFile(e.target.files[0]);
        }
    });
    
    // Drag and drop events (DR-41)
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
        dropArea.addEventListener(eventName, preventDefaults, false);
        document.body.addEventListener(eventName, preventDefaults, false);
    });
    
    ['dragenter', 'dragover'].forEach(eventName => {
        dropArea.addEventListener(eventName, () => {
            dropArea.classList.add('dragging');
        });
    });
    
    ['dragleave', 'drop'].forEach(eventName => {
        dropArea.addEventListener(eventName, () => {
            dropArea.classList.remove('dragging');
        });
    });
    
    dropArea.addEventListener('drop', (e) => {
        const files = e.dataTransfer.files;
        if (files.length > 0) {
            handleFile(files[0]);
        }
    });
    
    // Keyboard support for accessibility
    dropArea.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault();
            fileInput.click();
        }
    });
    
    // Analyze button
    analyzeBtn.addEventListener('click', analyzeImage);
    
    // Clear button
    clearBtn.addEventListener('click', clearSelection);
    
    // Audio button (FR-10)
    if (audioBtn) {
        audioBtn.addEventListener('click', playAudioReadout);
    }
    
    // Clear history button (FR-12)
    if (clearHistoryBtn) {
        clearHistoryBtn.addEventListener('click', clearHistory);
    }
}

/**
 * Prevent default drag behaviors
 */
function preventDefaults(e) {
    e.preventDefault();
    e.stopPropagation();
}

/**
 * Handle file selection (FR-01, SR-47, SR-48)
 */
function handleFile(file) {
    // Validate file type (FR-01)
    const validTypes = ['image/jpeg', 'image/jpg', 'image/png'];
    if (!validTypes.includes(file.type)) {
        showError('Invalid file type. Please upload a JPG or PNG image.');
        return;
    }
    
    // Validate file size (SR-47) - 10MB limit
    const maxSize = 10 * 1024 * 1024; // 10MB
    if (file.size > maxSize) {
        showError('File is too large. Maximum size is 10MB.');
        return;
    }
    
    selectedFile = file;
    
    // Update UI
    const uploadText = dropArea.querySelector('.upload-text');
    const uploadIcon = dropArea.querySelector('.upload-icon');
    uploadText.textContent = `Selected: ${file.name}`;
    uploadText.style.color = 'var(--accent)';
    uploadIcon.textContent = '✓';
    
    // Enable buttons
    analyzeBtn.disabled = false;
    clearBtn.disabled = false;
    
    // Hide previous results and errors
    hideResults();
    hideError();
}

/**
 * Clear file selection
 */
function clearSelection() {
    selectedFile = null;
    fileInput.value = '';
    
    // Reset UI
    const uploadText = dropArea.querySelector('.upload-text');
    const uploadIcon = dropArea.querySelector('.upload-icon');
    uploadText.textContent = 'Drop Image or Click to Upload';
    uploadText.style.color = '';
    uploadIcon.textContent = '📸';
    
    // Disable buttons
    analyzeBtn.disabled = true;
    clearBtn.disabled = true;
    
    // Hide results and errors
    hideResults();
    hideError();
}

/**
 * Analyze selected image (FR-02, FR-03, FR-04, FR-08, FR-09, FR-13, FR-15)
 */
async function analyzeImage() {
    if (!selectedFile) return;
    
    // Show loading state (TR-34)
    showLoading();
    hideResults();
    hideError();
    
    // Prepare form data
    const formData = new FormData();
    formData.append('file', selectedFile);
    
    try {
        // Send to backend
        const response = await fetch('/upload', {
            method: 'POST',
            body: formData
        });
        
        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.error || `Server error: ${response.status}`);
        }
        
        const data = await response.json();
        
        if (data.success) {
            currentResults = data;
            displayResults(data);
            loadHistory(); // Refresh history (FR-11)
        } else {
            throw new Error(data.error || 'Analysis failed');
        }
        
    } catch (error) {
        console.error('Error analyzing image:', error);
        showError(error.message || 'An error occurred while analyzing the image. Please try again.');
    } finally {
        hideLoading();
    }
}

/**
 * Display analysis results (FR-02, FR-03, FR-04, FR-08, FR-09, FR-13, FR-15)
 */
function displayResults(data) {
    // Show results section
    resultsSection.classList.add('active');
    
    // Processing time (FR-13)
    processingTime.textContent = `${data.processing_time}s`;
    
    // Display images (FR-08)
    originalImage.src = data.original_image;
    if (data.annotated_image) {
        annotatedImage.src = data.annotated_image;
    } else {
        annotatedImage.src = data.original_image;
    }
    
    // Caption (FR-03)
    captionText.textContent = data.caption || 'No description available.';
    
    // Objects list (FR-02, FR-04, DR-42)
    objectsList.innerHTML = '';
    if (data.objects && data.objects.length > 0) {
        data.objects.forEach(obj => {
            const item = document.createElement('div');
            item.className = 'object-item';
            
            const confidence = Math.round(obj.confidence * 100);
            const boxInfo = obj.box ? `[${obj.box.join(', ')}]` : '';
            
            item.innerHTML = `
                <div class="object-header">
                    <div class="object-name">${obj.label}</div>
                    <div class="object-confidence">${confidence}%</div>
                </div>
                ${boxInfo ? `<div class="object-coords">${boxInfo}</div>` : ''}
            `;
            
            objectsList.appendChild(item);
        });
    } else {
        objectsList.innerHTML = '<p style="color: rgba(242, 242, 242, 0.5);">No objects detected</p>';
    }
    
    // Colors (FR-15)
    colorsList.innerHTML = '';
    if (data.colors && data.colors.length > 0) {
        data.colors.forEach(color => {
            const chip = document.createElement('div');
            chip.className = 'color-chip';
            chip.textContent = color;
            colorsList.appendChild(chip);
        });
    } else {
        colorsList.innerHTML = '<div class="color-chip">No colors detected</div>';
    }
    
    // OCR results (FR-09)
    if (data.ocr && data.ocr.has_text) {
        ocrSection.style.display = 'block';
        ocrText.textContent = data.ocr.text || 'Text detected but could not be extracted.';
    } else {
        ocrSection.style.display = 'none';
    }
    
    // Scroll to results
    resultsSection.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

/**
 * Download results as TXT or JSON (FR-07)
 */
function downloadResults(format) {
    if (!currentResults) {
        showError('No results to download. Please analyze an image first.');
        return;
    }
    
    fetch(`/download/${format}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(currentResults)
    })
    .then(response => {
        if (!response.ok) {
            throw new Error('Download failed');
        }
        return response.blob();
    })
    .then(blob => {
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `analysis.${format}`;
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(url);
        document.body.removeChild(a);
    })
    .catch(error => {
        console.error('Download error:', error);
        showError('Failed to download results. Please try again.');
    });
}

/**
 * Play audio readout of results (FR-10)
 */
function playAudioReadout() {
    if (!currentResults) {
        showError('No results to read. Please analyze an image first.');
        return;
    }
    
    // Build text to speak
    let text = `Analysis results. ${currentResults.caption}. `;
    
    if (currentResults.objects && currentResults.objects.length > 0) {
        text += `Detected ${currentResults.objects.length} objects: `;
        currentResults.objects.slice(0, 5).forEach((obj, i) => {
            const confidence = Math.round(obj.confidence * 100);
            text += `${obj.label} with ${confidence} percent confidence. `;
        });
    }
    
    if (currentResults.colors && currentResults.colors.length > 0) {
        text += `Primary colors: ${currentResults.colors.join(', ')}. `;
    }
    
    if (currentResults.ocr && currentResults.ocr.has_text) {
        text += `Text detected: ${currentResults.ocr.text}`;
    }
    
    // Use Web Speech API
    if ('speechSynthesis' in window) {
        const utterance = new SpeechSynthesisUtterance(text);
        utterance.rate = 0.9;
        utterance.pitch = 1.0;
        speechSynthesis.speak(utterance);
    } else {
        showError('Audio readout is not supported in your browser.');
    }
}

/**
 * Load processing history (FR-11)
 */
function loadHistory() {
    fetch('/history?limit=10')
        .then(response => response.json())
        .then(data => {
            if (data.success && data.history) {
                displayHistory(data.history);
            }
        })
        .catch(error => {
            console.error('Error loading history:', error);
        });
}

/**
 * Display history items
 */
function displayHistory(history) {
    historyGrid.innerHTML = '';
    
    if (history.length === 0) {
        historyGrid.innerHTML = '<p style="color: rgba(242, 242, 242, 0.5);">No history yet. Analyze an image to get started!</p>';
        return;
    }
    
    history.forEach(item => {
        const historyItem = document.createElement('div');
        historyItem.className = 'history-item';
        
        const date = new Date(item.upload_time);
        const timeStr = date.toLocaleString();
        
        historyItem.innerHTML = `
            <div class="history-filename">${item.filename}</div>
            <div class="history-time">${timeStr}</div>
            <div style="margin-top: calc(var(--unit)); font-size: 0.8rem; color: rgba(242, 242, 242, 0.7);">
                ${item.caption ? item.caption.substring(0, 60) + '...' : 'No caption'}
            </div>
        `;
        
        historyGrid.appendChild(historyItem);
    });
}

/**
 * Clear processing history (FR-12)
 */
function clearHistory() {
    if (!confirm('Are you sure you want to clear all history? This cannot be undone.')) {
        return;
    }
    
    fetch('/history/clear', {
        method: 'POST'
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            loadHistory();
            showTemporaryMessage('History cleared successfully!');
        } else {
            showError('Failed to clear history. Please try again.');
        }
    })
    .catch(error => {
        console.error('Error clearing history:', error);
        showError('Failed to clear history. Please try again.');
    });
}

/**
 * Show loading state (TR-34)
 */
function showLoading() {
    loadingState.classList.add('active');
    analyzeBtn.disabled = true;
}

/**
 * Hide loading state
 */
function hideLoading() {
    loadingState.classList.remove('active');
    analyzeBtn.disabled = false;
}

/**
 * Show results section
 */
function showResults() {
    resultsSection.classList.add('active');
}

/**
 * Hide results section
 */
function hideResults() {
    resultsSection.classList.remove('active');
}

/**
 * Show error message (NR-20)
 */
function showError(message) {
    errorText.textContent = message;
    errorMessage.classList.add('active');
    errorMessage.scrollIntoView({ behavior: 'smooth', block: 'center' });
}

/**
 * Hide error message
 */
function hideError() {
    errorMessage.classList.remove('active');
}

/**
 * Show temporary success message
 */
function showTemporaryMessage(message) {
    const msgDiv = document.createElement('div');
    msgDiv.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: var(--accent);
        color: var(--primary);
        padding: 16px 24px;
        border-radius: 4px;
        font-weight: 600;
        z-index: 1000;
        animation: slideInRight 0.3s ease-out;
    `;
    msgDiv.textContent = message;
    document.body.appendChild(msgDiv);
    
    setTimeout(() => {
        msgDiv.style.animation = 'slideInRight 0.3s ease-out reverse';
        setTimeout(() => {
            document.body.removeChild(msgDiv);
        }, 300);
    }, 3000);
}

/**
 * Utility: Format file size
 */
function formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
}

// Make download function available globally
window.downloadResults = downloadResults;
