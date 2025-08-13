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

# Define the content to be loaded and the shader root directory
# For a 512x512 pixel screenshot with video_scale=8, the input image must be 64x64 pixels.
# The path below is a placeholder. You must ensure a 64x64 image exists at this location.
CONTENT_PATH="/recalbox/share/screenshots/shader-previews/upscale-test-64x64.png"
#with screen set at 512p (or near as 480) with video_scale at 8

#CONTENT_PATH="/recalbox/share/screenshots/shader-previews/upscale-test-240x240.png"
#with screen set at 480p with video_scale at 2

#CONTENT_PATH="/recalbox/share/screenshots/shader-previews/upscale-test-240x240.png"
#screen set at 480p with video_scale at 2
SHADER_DIR="/recalbox/share/shaders/"

# Define the directory where screenshots will be saved
# Make sure this directory exists or the script will create it.
SCREENSHOT_DIR="/recalbox/share/screenshots/shader-previews/"

# Define the network command settings
NETWORK_IP="127.0.0.1"
NETWORK_PORT="55355"

# We will use the simple "SCREENSHOT" command which saves to the specified directory.
SCREENSHOT_COMMAND="SCREENSHOT"

# ==============================================================================
# SCRIPT LOGIC
# ==============================================================================

# Unlock file system
mount -o remount,rw /

# 1. Generate the temporary config file with network command and screenshot directory support
echo "Creating temporary config file: $CONFIG_FILE"
cat > "$CONFIG_FILE" << EOF
auto_shaders_enable = "true"
video_shader_dir = "$SHADER_DIR"
video_shader_enable = "true"
video_driver = "vulkan"
vulkan_gpu_index = "0"
# Set the video scale directly in the config file to 8
video_scale = "8"
# --- Add new parameters to force a specific window resolution and prevent fullscreen ---
video_fullscreen = "true"
video_windowed_fullscreen = "false"
video_force_aspect = "true"
video_fullscreen_x = "720"
video_fullscreen_y = "512"
video_use_native_resolution = "false"
# --- Add network command configuration ---
network_cmd_enable = "true"
network_cmd_port = "$NETWORK_PORT"
# Set the base directory for all screenshots
screenshot_directory = "$SCREENSHOT_DIR"
EOF

# 2. Loop through all shaders and take a screenshot for each
echo "Searching for .slangp shaders in $SHADER_DIR and first level subdirectories..."

# We find files in the root directory first, then in subdirectories,
# ensuring the entire list is sorted alphabetically.
# -maxdepth 1 finds files in the root directory only.
# -mindepth 2 -maxdepth 2 finds files only in the first level of subdirectories.
# This ensures we don't go deeper than one level of subdirectories.
for SHADER_FILE in $( (find "$SHADER_DIR" -maxdepth 1 -type f -name "*.slangp" && find "$SHADER_DIR" -mindepth 2 -maxdepth 2 -type f -name "*.slangp") | sort); do
    echo "Processing shader: $SHADER_FILE"

    # Determine the new screenshot path to replicate the directory structure
    # This removes the SHADER_DIR prefix from the full path.
    RELATIVE_PATH=${SHADER_FILE#$SHADER_DIR}
    # This gets the directory path for the new screenshot location.
    OUTPUT_DIR="$SCREENSHOT_DIR$(dirname "$RELATIVE_PATH")"
    # This gets the filename without the .slangp extension.
    FILENAME=$(basename "$SHADER_FILE" .slangp)
    # This combines the new directory and filename.
    FINAL_SCREENSHOT_PATH="$OUTPUT_DIR/$FILENAME.png"
    
    # Ensure the output directory exists
    echo "Creating output directory if it doesn't exist: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"

    # Launch RetroArch in the background with the current shader
    # The video scale is now set in the config file, so we don't need the command-line flag.
    "$RETROARCH_BIN" -L "$IMAGE_VIEWER_CORE" "$CONTENT_PATH" \
        --set-shader "$SHADER_FILE" \
        --appendconfig "$CONFIG_FILE" &

    # Store the Process ID (PID) of RetroArch
    RETROARCH_PID=$!

    # 3. Give RetroArch a few seconds to load the image and shader
    echo "Waiting for RetroArch to load the content..."
    sleep 5

    # 4. Send the screenshot command to RetroArch via UDP
    echo "Sending screenshot command..."
    COMMAND_STRING="$SCREENSHOT_COMMAND"
    python3 -c 'import socket; s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.sendto(b"'"$COMMAND_STRING"'", ("'"$NETWORK_IP"'", '"$NETWORK_PORT"'))'

    # 5. Wait for the screenshot to be saved
    echo "Waiting for screenshot to be saved..."
    sleep 3

    # 6. Find the newly created screenshot and rename it
    # RetroArch saves files with a timestamp, we find the newest file in the base screenshot directory
    # and rename it to the desired path.
    LAST_SCREENSHOT_NAME=$(ls -t "$SCREENSHOT_DIR" | head -n 1)
    if [[ "$LAST_SCREENSHOT_NAME" == *.png ]]; then
        echo "Renaming '$SCREENSHOT_DIR/$LAST_SCREENSHOT_NAME' to '$FINAL_SCREENSHOT_PATH'"
        mv "$SCREENSHOT_DIR/$LAST_SCREENSHOT_NAME" "$FINAL_SCREENSHOT_PATH"
    else
        echo "Error: Could not find a new screenshot file in '$SCREENSHOT_DIR'"
    fi

    # 7. Clean up by terminating the RetroArch process
    echo "Exiting RetroArch..."
    kill $RETROARCH_PID
    wait $RETROARCH_PID 2>/dev/null

    echo "Finished with $SHADER_FILE"
    echo "--------------------------------------------------------"
done

# 8. Final cleanup after the loop
echo "All shaders processed. Final cleanup..."
rm "$CONFIG_FILE"

echo "Script finished."
echo "Screenshots should be saved in: $SCREENSHOT_DIR"
