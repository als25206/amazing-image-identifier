#!/bin/bash
# Automated Setup for Raspberry Pi 4 (ARM64)
# Amazing Image Identifier with PyTorch
# Updated for Raspberry Pi OS 2025 release

set -e  # Exit on error

echo "================================================================"
echo "   Amazing Image Identifier - Raspberry Pi Setup"
echo "   Optimized for: Raspberry Pi 4 (ARM v8 64-bit)"
echo "   Updated for: Raspberry Pi OS 2025 release"
echo "================================================================"
echo ""

# Check if running on Raspberry Pi
if [ ! -f /proc/device-tree/model ]; then
    echo "⚠ Warning: This script is optimized for Raspberry Pi"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    PI_MODEL=$(cat /proc/device-tree/model)
    echo "Detected: $PI_MODEL"
fi

echo ""
echo "Step 1: Checking system requirements..."
echo "========================================="

# Check Python version
if command -v python3 &> /dev/null; then
    PYTHON_CMD=python3
else
    echo "❌ Python 3 not found. Please install Python 3.8+."
    exit 1
fi

PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | awk '{print $2}')
echo "✓ Python $PYTHON_VERSION found"

# Check memory
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
echo "✓ Total RAM: ${TOTAL_MEM}MB"

if [ $TOTAL_MEM -lt 2000 ]; then
    echo "⚠ Warning: Less than 2GB RAM detected. Models may run slowly."
fi

# Check disk space
AVAILABLE_SPACE=$(df -m . | awk 'NR==2 {print $4}')
echo "✓ Available disk space: ${AVAILABLE_SPACE}MB"

if [ $AVAILABLE_SPACE -lt 5000 ]; then
    echo "⚠ Warning: Less than 5GB available. Models need ~3GB."
fi

echo ""
echo "Step 2: Installing system dependencies..."
echo "========================================="
echo "Updating package lists..."

sudo apt-get update -qq

echo "Installing required packages..."
# Updated package names for Raspberry Pi OS 2025
sudo apt-get install -y -qq \
    python3-pip \
    python3-dev \
    python3-venv \
    libopenblas-dev \
    libjpeg-dev \
    libpng-dev \
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    gfortran \
    libhdf5-dev \
    libopenjp2-7 \
    libtiff6 \
    libmagic1 \
    libffi-dev \
    libssl-dev \
    build-essential \
    cmake \
    pkg-config

echo "✓ System dependencies installed"

echo ""
echo "Step 3: Configuring swap space..."
echo "========================================="

CURRENT_SWAP=$(free -m | awk '/^Swap:/{print $2}')
echo "Current swap: ${CURRENT_SWAP}MB"

if [ $CURRENT_SWAP -lt 2000 ]; then
    echo "Increasing swap to 2GB (required for model loading)..."
    
    # Check if dphys-swapfile exists
    if command -v dphys-swapfile &> /dev/null; then
        sudo dphys-swapfile swapoff 2>/dev/null || true
        
        # Backup existing config
        sudo cp /etc/dphys-swapfile /etc/dphys-swapfile.backup 2>/dev/null || true
        
        # Update swap size
        sudo sed -i 's/^CONF_SWAPSIZE=.*/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile
        
        sudo dphys-swapfile setup
        sudo dphys-swapfile swapon
        
        NEW_SWAP=$(free -m | awk '/^Swap:/{print $2}')
        echo "✓ Swap increased to ${NEW_SWAP}MB"
    else
        echo "⚠ dphys-swapfile not found. Using alternative method..."
        # Create swap file manually
        sudo fallocate -l 2G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo "✓ Swap file created"
    fi
else
    echo "✓ Swap space adequate"
fi

echo ""
echo "Step 4: Creating virtual environment..."
echo "========================================="

if [ -d "venv" ]; then
    echo "Virtual environment exists. Removing old one..."
    rm -rf venv
fi

$PYTHON_CMD -m venv venv
source venv/bin/activate

echo "✓ Virtual environment created and activated"

echo ""
echo "Step 5: Upgrading pip..."
echo "========================================="

pip install --upgrade pip --quiet
echo "✓ pip upgraded"

echo ""
echo "Step 6: Installing PyTorch for ARM64..."
echo "========================================="
echo "This may take 5-10 minutes. Please be patient..."

# Install wheel and setuptools first
pip install wheel setuptools --quiet

# Try official PyTorch ARM build first
echo "Attempting official PyTorch ARM64 installation..."
pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu 2>&1 | grep -v "Requirement already satisfied" || true

# Verify PyTorch installation
if python -c "import torch" 2>/dev/null; then
    TORCH_VERSION=$(python -c "import torch; print(torch.__version__)")
    echo "✓ PyTorch $TORCH_VERSION installed successfully!"
else
    echo "⚠ First method failed. Trying alternative..."
    pip install torch torchvision 2>&1 | grep -v "Requirement already satisfied" || true
    
    if python -c "import torch" 2>/dev/null; then
        TORCH_VERSION=$(python -c "import torch; print(torch.__version__)")
        echo "✓ PyTorch $TORCH_VERSION installed successfully (alternative method)!"
    else
        echo "❌ Could not install PyTorch. Please check RASPBERRY_PI_SETUP.md for manual installation."
        exit 1
    fi
fi

echo ""
echo "Step 7: Installing other Python packages..."
echo "========================================="
echo "This will take 10-20 minutes. Please be patient..."

# Install packages one by one to avoid timeout issues
echo "Installing Flask and web framework..."
pip install Flask>=3.0.0 flask-cors gunicorn Werkzeug requests --quiet

echo "Installing Transformers (this takes a while)..."
pip install transformers --quiet

echo "Installing OpenCV..."
pip install opencv-python-headless --quiet

echo "Installing image libraries..."
pip install Pillow --quiet

echo "Installing NumPy..."
pip install "numpy<2.0" --quiet

echo "Installing EasyOCR (this takes a while)..."
pip install easyocr --quiet 2>&1 | grep -v "Requirement already satisfied" || {
    echo "⚠ EasyOCR installation failed. OCR features may not work."
    echo "  This is okay - other features will still work."
}

echo "Installing other utilities..."
pip install gTTS python-magic --quiet 2>&1 | grep -v "Requirement already satisfied" || true

echo "✓ Python packages installed"

echo ""
echo "Step 8: Creating configuration files..."
echo "========================================="

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        
        # Generate secret key
        SECRET_KEY=$(python -c "import secrets; print(secrets.token_hex(32))")
        
        # Update .env file
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/your-secret-key-here-change-this/$SECRET_KEY/" .env
        else
            sed -i "s/your-secret-key-here-change-this/$SECRET_KEY/" .env
        fi
        
        echo "✓ .env file created with generated SECRET_KEY"
    else
        echo "⚠ .env.example not found. Creating basic .env file..."
        cat > .env << EOF
SECRET_KEY=$(python -c "import secrets; print(secrets.token_hex(32))")
FLASK_ENV=production
DEBUG=False
EOF
        echo "✓ Basic .env file created"
    fi
else
    echo "✓ .env file already exists"
fi

# Create Raspberry Pi optimization config
cat > config_rpi.py << 'EOF'
"""
Raspberry Pi 4 Optimizations
Import this at the top of production_app.py if needed:
from config_rpi import *
"""
import os
import torch

# Limit threads to prevent CPU overload
os.environ['OMP_NUM_THREADS'] = '2'
os.environ['MKL_NUM_THREADS'] = '2'

# Optimize PyTorch for ARM
torch.set_num_threads(2)
torch.set_num_interop_threads(1)

print("Raspberry Pi optimizations loaded")
EOF

echo "✓ Raspberry Pi optimization config created"

# Create necessary directories
mkdir -p uploads history static/css static/js tests
echo "✓ Directories created"

echo ""
echo "Step 9: Verifying installation..."
echo "========================================="

echo "Checking installed packages..."
python -c "import torch; print(f'  ✓ PyTorch {torch.__version__}')" 2>/dev/null || echo "  ❌ PyTorch import failed"
python -c "import transformers; print('  ✓ Transformers OK')" 2>/dev/null || echo "  ❌ Transformers import failed"
python -c "import flask; print('  ✓ Flask OK')" 2>/dev/null || echo "  ❌ Flask import failed"
python -c "import cv2; print('  ✓ OpenCV OK')" 2>/dev/null || echo "  ⚠ OpenCV not available (optional)"
python -c "import PIL; print('  ✓ Pillow OK')" 2>/dev/null || echo "  ❌ Pillow import failed"
python -c "import numpy; print('  ✓ NumPy OK')" 2>/dev/null || echo "  ❌ NumPy import failed"

echo ""
echo "Step 10: System information..."
echo "========================================="

# Temperature
if command -v vcgencmd &> /dev/null; then
    TEMP=$(vcgencmd measure_temp 2>/dev/null | cut -d= -f2)
    echo "CPU Temperature: $TEMP"
    
    # Throttling check
    THROTTLED=$(vcgencmd get_throttled 2>/dev/null)
    echo "Throttle Status: $THROTTLED"
    if [ "$THROTTLED" != "throttled=0x0" ]; then
        echo "⚠ Warning: System throttling detected. Check power supply."
    fi
fi

# Memory after installation
echo ""
echo "Memory Status:"
free -h

echo ""
echo "================================================================"
echo "   ✅ Setup Complete!"
echo "================================================================"
echo ""
echo "🎉 Your Raspberry Pi is ready to run the Amazing Image Identifier!"
echo ""
echo "To start the application:"
echo ""
echo "  1. Activate the virtual environment:"
echo "     source venv/bin/activate"
echo ""
echo "  2. Run the application:"
echo "     python production_app.py"
echo ""
echo "  3. Access from:"
echo "     - This Pi: http://localhost:5000"

# Get IP address
if command -v hostname &> /dev/null; then
    PI_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [ ! -z "$PI_IP" ]; then
        echo "     - Other devices: http://${PI_IP}:5000"
    fi
fi

echo ""
echo "================================================================"
echo ""
echo "📝 Important Notes:"
echo ""
echo "  • First run will download models (~2-3GB) - takes 5-10 minutes"
echo "  • Processing takes 30-60 seconds per image on Raspberry Pi 4"
echo "  • Keep your Pi cool - models generate heat"
echo "  • Use official 15W power supply for stable operation"
echo ""
echo "📚 Documentation:"
echo "  • Full guide: RASPBERRY_PI_SETUP.md"
echo "  • Troubleshooting: FIX_ILLEGAL_INSTRUCTION.md"
echo "  • Deployment: DEPLOYMENT.md"
echo ""
echo "🔥 Performance Tips:"
echo "  • Close other applications while running"
echo "  • Add heatsink or fan if temperature > 80°C"
echo "  • Process images during cooler times of day"
echo ""
echo "⚡ Quick Test:"
echo "  source venv/bin/activate"
echo "  python -c 'from production_app import app; print(\"App OK!\")'"
echo ""
echo "================================================================"
