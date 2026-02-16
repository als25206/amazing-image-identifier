#!/bin/bash
# Automated Conda + PyTorch Setup for Raspberry Pi
# This method has much better ARM compatibility than pip

set -e

echo "================================================================"
echo "   PyTorch via Conda - Raspberry Pi Setup"
echo "   (Better ARM compatibility than pip)"
echo "================================================================"
echo ""

# Check if Miniforge is already installed
if [ -d "$HOME/miniforge3" ]; then
    echo "✓ Miniforge already installed"
    source "$HOME/miniforge3/bin/activate"
else
    echo "Step 1: Installing Miniforge (Conda for ARM)..."
    echo "========================================="
    
    cd ~
    wget -q --show-progress https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-aarch64.sh
    
    # Install in batch mode
    bash Miniforge3-Linux-aarch64.sh -b -p $HOME/miniforge3
    
    # Initialize conda
    $HOME/miniforge3/bin/conda init bash
    
    # Source it for this session
    source "$HOME/miniforge3/bin/activate"
    
    echo "✓ Miniforge installed"
fi

echo ""
echo "Step 2: Creating conda environment..."
echo "========================================="

# Remove old environment if it exists
conda env remove -n imageai -y 2>/dev/null || true

# Create new environment
conda create -n imageai python=3.11 -y

# Activate it
conda activate imageai

echo "✓ Environment 'imageai' created and activated"

echo ""
echo "Step 3: Installing PyTorch from conda-forge..."
echo "========================================="
echo "This may take 10-15 minutes..."

# Install PyTorch from conda-forge (better ARM support)
conda install pytorch torchvision cpuonly -c pytorch -c conda-forge -y

echo ""
echo "Step 4: Testing PyTorch..."
echo "========================================="

if python -c "import torch; print(f'PyTorch {torch.__version__} works!')" 2>/dev/null; then
    echo "✓ PyTorch installed and working!"
else
    echo "❌ PyTorch test failed. Trying alternative channel..."
    conda install pytorch torchvision -c conda-forge -y
    
    if python -c "import torch; print('PyTorch works!')" 2>/dev/null; then
        echo "✓ PyTorch working with alternative method!"
    else
        echo "❌ PyTorch still failing. See PYTORCH_FIX_OPTIONS.md for alternatives."
        exit 1
    fi
fi

echo ""
echo "Step 5: Installing other Python packages..."
echo "========================================="

pip install Flask flask-cors gunicorn Werkzeug --quiet
echo "  ✓ Flask"

pip install transformers --quiet
echo "  ✓ Transformers"

pip install opencv-python-headless --quiet
echo "  ✓ OpenCV"

pip install Pillow --quiet
echo "  ✓ Pillow"

pip install "numpy<2.0" --quiet
echo "  ✓ NumPy"

pip install requests gTTS python-magic --quiet
echo "  ✓ Utilities"

pip install easyocr --quiet 2>&1 | head -1 || echo "  ⚠ EasyOCR skipped (optional)"

echo ""
echo "Step 6: Setting up project..."
echo "========================================="

# Go to project directory
cd ~/amazing-image-identifier || cd amazing-image-identifier || {
    echo "❌ Project directory not found"
    echo "Please run this from the project directory"
    exit 1
}

# Create .env if needed
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        SECRET_KEY=$(python -c "import secrets; print(secrets.token_hex(32))")
        sed -i "s/your-secret-key-here-change-this/$SECRET_KEY/" .env
    else
        echo "SECRET_KEY=$(python -c 'import secrets; print(secrets.token_hex(32))')" > .env
    fi
    echo "✓ .env file created"
else
    echo "✓ .env file exists"
fi

# Create directories
mkdir -p uploads history static/css static/js
echo "✓ Directories created"

echo ""
echo "Step 7: Final verification..."
echo "========================================="

python << 'EOF'
import sys

tests = [
    ('torch', 'PyTorch'),
    ('transformers', 'Transformers'),
    ('flask', 'Flask'),
    ('PIL', 'Pillow'),
    ('cv2', 'OpenCV'),
]

print("Checking installed packages:")
for module, name in tests:
    try:
        __import__(module)
        print(f"  ✓ {name}")
    except ImportError:
        print(f"  ❌ {name} (optional)" if module == 'cv2' else f"  ❌ {name}")

print("\nPyTorch details:")
import torch
print(f"  Version: {torch.__version__}")
print(f"  CPU support: {torch.backends.cpu.is_available()}")
EOF

echo ""
echo "================================================================"
echo "   ✅ Installation Complete!"
echo "================================================================"
echo ""
echo "🎉 PyTorch is now installed and working via Conda!"
echo ""
echo "To use your environment:"
echo ""
echo "  1. Activate conda environment:"
echo "     conda activate imageai"
echo ""
echo "  2. Run the application:"
echo "     cd ~/amazing-image-identifier"
echo "     python production_app.py"
echo ""
echo "  3. Access at:"
echo "     http://localhost:5000"

if command -v hostname &> /dev/null; then
    IP=$(hostname -I | awk '{print $1}')
    [ ! -z "$IP" ] && echo "     http://${IP}:5000"
fi

echo ""
echo "================================================================"
echo ""
echo "📝 Important Notes:"
echo ""
echo "  • Always activate the environment first: conda activate imageai"
echo "  • First run downloads ML models (~3GB, one-time)"
echo "  • Processing: 30-60 seconds per image on Pi 4"
echo "  • To use in new terminal: conda activate imageai"
echo ""
echo "🔄 To activate in future sessions:"
echo "     conda activate imageai"
echo "     python production_app.py"
echo ""
