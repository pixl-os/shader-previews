#!/bin/bash

# ==============================================================================
# SCRIPT CONFIGURATION
# ==============================================================================

# Define the paths to your RetroArch executable and core
RETROARCH_BIN="/usr/bin/retroarch"
IMAGE_VIEWER_CORE="/usr/lib/libretro/imageviewer_libretro.so"

# Define the path to the temporary configuration file
CONFIG_DIR="/tmp"
CONFIG_FILE="$CONFIG_DIR/retroarch_vulkan.cfg"

# Define the content to be loaded and the shader to be applied
CONTENT_PATH="/recalbox/share_init/roms/nes/media/screenshot/Broke Studio/Micro Mages/Micro Mages Demo.png"
SHADER_PATH="/recalbox/share/shaders/crt/crt-mattias.slangp"

# Define the directory where screenshots will be saved
# Make sure this directory exists or the script will create it.
SCREENSHOT_DIR="/recalbox/share/screenshots/shader-previews"

# Define the network command settings
NETWORK_IP="127.0.0.1"
NETWORK_PORT="55355"
SCREENSHOT_COMMAND="SCREENSHOT"

# ==============================================================================
# SCRIPT LOGIC
# ==============================================================================

# Unlock file system
mount -o remount,rw /

# 1. Ensure the screenshot directory exists
echo "Ensuring screenshot directory exists: $SCREENSHOT_DIR"
mkdir -p "$SCREENSHOT_DIR"

# 2. Generate the temporary config file with network command and screenshot directory support
echo "Creating temporary config file: $CONFIG_FILE"
cat > "$CONFIG_FILE" << EOF
auto_shaders_enable = "true"
video_shader_dir = "/recalbox/share/shaders"
video_shader_enable = "true"
video_driver = "vulkan"
vulkan_gpu_index = "0"
# --- Add network command configuration ---
network_cmd_enable = "true"
network_cmd_port = "$NETWORK_PORT"
# --- Define the screenshot directory ---
screenshot_directory = "$SCREENSHOT_DIR"
EOF

# 3. Launch RetroArch in the background using the temporary config
echo "Starting RetroArch..."
"$RETROARCH_BIN" -L "$IMAGE_VIEWER_CORE" "$CONTENT_PATH" \
    --set-shader "$SHADER_PATH" \
    --appendconfig "$CONFIG_FILE" &

# Store the Process ID (PID) of RetroArch
RETROARCH_PID=$!

# 4. Give RetroArch a few seconds to load the image and shader
echo "Waiting for RetroArch to load the content..."
sleep 5

# 5. Send the screenshot command to RetroArch via UDP using a Python one-liner
echo "Sending screenshot command via UDP..."
python3 -c 'import socket; s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.sendto(b"'"$SCREENSHOT_COMMAND"'", ("'"$NETWORK_IP"'", '"$NETWORK_PORT"'))'

# 6. Wait a couple of seconds for the screenshot to be saved
sleep 4

# 7. Clean up by terminating the RetroArch process and removing the temporary config
echo "Exiting RetroArch and cleaning up..."
kill $RETROARCH_PID
wait $RETROARCH_PID 2>/dev/null

rm "$CONFIG_FILE"

echo "Script finished."
echo "Screenshot should be saved in: $SCREENSHOT_DIR"