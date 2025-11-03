#!/bin/bash

# ================================================================
# Intel GPU & NPU Driver Installation Script for Ubuntu 24.04
# ================================================================
# This script automates the installation of Intel GPU and NPU 
# drivers for enhanced graphics and AI acceleration performance.
# 
# Usage: ./install_gpu_npu_drivers.sh
# ================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
NPU_DRIVER_URL="https://af01p-ir.devtools.intel.com/artifactory/drivers_vpu_linux_client-ir-local/engineering-drops/driver/main/release/25ww44.1.1/npu-linux-driver-ci-1.27.0.20251024-18786122221-ubuntu2404-release.tar.gz"
NPU_DRIVER_FILENAME="npu-linux-driver-ci-1.27.0.20251024-18786122221-ubuntu2404-release.tar.gz"
NPU_DRIVER_DIR="npu-linux-driver-ci-1.27.0.20251024-18786122221-ubuntu2404-release"
TEMP_DIR="/tmp/intel_drivers"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}$1${NC}"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root for safety reasons."
        print_error "It will prompt for sudo when needed."
        exit 1
    fi
}

# Function to check system compatibility
check_system() {
    print_header "🔍 Checking system compatibility..."
    
    # Check Ubuntu version
    if ! grep -q "24.04" /etc/lsb-release 2>/dev/null; then
        print_warning "This script is designed for Ubuntu 24.04. Proceeding anyway..."
    fi
    
    # Check for Intel GPU
    if lspci | grep -i "vga\|3d\|display" | grep -qi intel; then
        print_success "Intel GPU detected"
    else
        print_warning "Intel GPU not clearly detected. Installation will continue but may not be effective."
    fi
    
    # Check for Intel NPU (if available in lspci)
    if lspci | grep -qi "processing.*intel\|ai.*intel\|npu"; then
        print_success "Intel NPU-compatible hardware detected"
    else
        print_status "NPU hardware detection inconclusive - proceeding with installation"
    fi
    
    print_success "System compatibility check completed"
}

# Function to prepare environment
prepare_environment() {
    print_header "🛠️  Preparing installation environment..."
    
    # Create temporary directory
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Update package lists
    print_status "Updating package lists..."
    sudo apt-get update
    
    print_success "Environment preparation completed"
}

# Function to install GPU drivers
install_gpu_drivers() {
    print_header "🎮 Installing Intel GPU drivers..."
    
    # Install software-properties-common
    print_status "Installing prerequisite packages..."
    sudo apt-get install -y software-properties-common
    
    # Add Intel graphics PPA
    print_status "Adding Intel graphics PPA repository..."
    sudo add-apt-repository -y ppa:kobuk-team/intel-graphics
    
    # Update package lists after adding PPA
    print_status "Updating package lists..."
    sudo apt-get update
    
    # Install Intel GPU libraries and tools
    print_status "Installing Intel GPU libraries and OpenCL support..."
    sudo apt-get install -y \
        libze-intel-gpu1 \
        libze1 \
        intel-metrics-discovery \
        intel-opencl-icd \
        clinfo \
        intel-gsc
    
    # Install Intel media drivers
    print_status "Installing Intel media acceleration drivers..."
    sudo apt-get install -y \
        intel-media-va-driver-non-free \
        libmfx-gen1 \
        libvpl2 \
        libvpl-tools \
        libva-glx2 \
        va-driver-all \
        vainfo
    
    # Add user to render group
    print_status "Adding user ${USER} to render group..."
    sudo gpasswd -a "${USER}" render
    
    print_success "Intel GPU drivers installation completed"
}

# Function to install NPU drivers
install_npu_drivers() {
    print_header "🧠 Installing Intel NPU drivers..."
    
    # Install NPU dependencies
    print_status "Installing NPU driver dependencies..."
    sudo apt update
    sudo apt install -y libtbb12 ocl-icd-libopencl1 dkms
    
    # Download NPU driver
    print_status "Downloading Intel NPU driver..."
    if [[ -f "$NPU_DRIVER_FILENAME" ]]; then
        print_status "NPU driver archive already exists, using existing file"
    else
        wget "$NPU_DRIVER_URL"
    fi
    
    # Extract NPU driver
    print_status "Extracting NPU driver archive..."
    if [[ -d "$NPU_DRIVER_DIR" ]]; then
        print_status "Removing existing extraction directory..."
        rm -rf "$NPU_DRIVER_DIR"
    fi
    tar xf "$NPU_DRIVER_FILENAME"
    
    # Install NPU driver
    print_status "Installing Intel NPU driver..."
    cd "$NPU_DRIVER_DIR"
    chmod a+x ./npu-drv-installer
    sudo ./npu-drv-installer
    
    print_success "Intel NPU drivers installation completed"
}

# Function to verify installations
verify_installations() {
    print_header "✅ Verifying driver installations..."
    
    # Verify GPU drivers
    print_status "Checking GPU driver installation..."
    if command -v clinfo >/dev/null 2>&1; then
        print_success "OpenCL tools (clinfo) installed successfully"
        print_status "OpenCL devices detected:"
        clinfo -l 2>/dev/null || print_warning "No OpenCL devices found or error querying devices"
    else
        print_warning "clinfo not found - GPU drivers may not be properly installed"
    fi
    
    # Verify VA-API support
    if command -v vainfo >/dev/null 2>&1; then
        print_success "VA-API tools (vainfo) installed successfully"
        print_status "VA-API information:"
        vainfo 2>/dev/null || print_warning "VA-API driver issues detected"
    else
        print_warning "vainfo not found - media acceleration may not work"
    fi
    
    # Check render group membership
    if groups "${USER}" | grep -q render; then
        print_success "User ${USER} is member of render group"
    else
        print_warning "User ${USER} is not in render group - this may affect GPU access"
    fi
    
    # Verify NPU driver
    print_status "Checking NPU driver installation..."
    if lsmod | grep -q intel_vpu; then
        print_success "Intel VPU/NPU kernel module loaded"
    else
        print_warning "Intel VPU/NPU kernel module not loaded - may require reboot or unsupported hardware"
    fi
    
    # Check for NPU device nodes
    if ls /dev/accel* >/dev/null 2>&1; then
        print_success "NPU device nodes found: $(ls /dev/accel*)"
    else
        print_warning "No NPU device nodes found - may require reboot or unsupported hardware"
    fi
}

# Function to cleanup
cleanup() {
    print_header "🧹 Cleaning up temporary files..."
    
    # Return to home directory
    cd "$HOME"
    
    # Remove temporary directory (optional - keep for debugging)
    read -p "Remove temporary installation files? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$TEMP_DIR"
        print_success "Temporary files cleaned up"
    else
        print_status "Temporary files kept at: $TEMP_DIR"
    fi
}

# Function to display completion message
display_completion() {
    print_header "🎉 Driver Installation Complete!"
    echo
    print_success "Intel GPU and NPU drivers have been successfully installed."
    echo
    print_status "Next steps:"
    echo "  • Log out and log back in to apply group membership changes"
    echo "  • Or reboot your system for full driver activation"
    echo "  • Test GPU acceleration with: clinfo"
    echo "  • Test media acceleration with: vainfo"
    echo "  • Check NPU status with: lsmod | grep intel_vpu"
    echo
    print_warning "Some features may require a system reboot to function properly."
    echo
    
    read -p "Do you want to reboot now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Rebooting system..."
        sudo reboot
    else
        print_status "Remember to reboot or re-login when convenient."
        print_status "You can apply group changes immediately with: newgrp render"
    fi
}

# Main function
main() {
    # Display welcome message
    clear
    echo "================================================================"
    print_header "🚀 Intel GPU & NPU Driver Installation Script"
    print_header "📋 For Ubuntu 24.04 LTS"
    echo "================================================================"
    echo
    print_status "This script will install:"
    echo "  • Intel GPU drivers and OpenCL support"
    echo "  • Intel media acceleration drivers (VA-API)"
    echo "  • Intel NPU (Neural Processing Unit) drivers"
    echo "  • Required libraries and tools"
    echo
    
    # Check if running as root
    check_root
    
    # Start the installation process
    print_header "🚀 Starting driver installation process..."
    echo
    
    # Step 1: Check system compatibility
    check_system
    echo
    
    # Step 2: Prepare environment
    prepare_environment
    echo
    
    # Step 3: Install GPU drivers
    install_gpu_drivers
    echo
    
    # Step 4: Install NPU drivers
    install_npu_drivers
    echo
    
    # Step 5: Verify installations
    verify_installations
    echo
    
    # Step 6: Cleanup
    cleanup
    echo
    
    # Step 7: Display completion message
    display_completion
}

# Trap to handle script interruption
trap 'print_error "Script interrupted by user"; exit 1' INT

# Run main function
main "$@"