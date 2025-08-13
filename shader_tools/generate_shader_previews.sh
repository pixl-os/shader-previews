#!/bin/bash

# ==============================================================================
# SCRIPT CONFIGURATION
# ==============================================================================

# Define the paths to your RetroArch executable and core
RETROARCH_BIN="/usr/bin/retroarch"
IMAGE_VIEWER_CORE="/usr/lib/libretro/imageviewer_libretro.so"

# Define the path to the temporary configuration file
CONFIG_DIR="/tmp"
# Note: The temporary config filename will now be generated dynamically inside the loop.

# Define the content to be loaded and the shader root directory
# The input image for a 512x512 pixel screenshot with video_scale=8 must be 64x64 pixels.
CONTENT_PATH="/recalbox/scripts/shader_tools/upscale-test-64x64.png"
# with screen set at 512p (or near as 480) with video_scale at 8

#content after is not well adapted finally
#CONTENT_PATH="/recalbox/scripts/shader_tools/upscale-test-240x240.png"
#with screen set at 480p with video_scale at 2

SHADER_DIR="/recalbox/share/shaders/"

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

# Function to process a single shader file
process_shader_file() {
    local SHADER_FILE=$1

    # Check if the file exists and is a regular file
    if [[ ! -f "$SHADER_FILE" ]]; then
        echo "Error: Shader file not found at $SHADER_FILE"
        return 1
    fi

    # Determine the video driver and output directory based on file extension
    EXTENSION="${SHADER_FILE##*.}"
    if [[ "$EXTENSION" == "slangp" ]]; then
        VIDEO_DRIVER="vulkan"
        SCREENSHOT_DIR="/recalbox/share/screenshots/shader-previews-vulkan/"
    elif [[ "$EXTENSION" == "glslp" ]]; then
        VIDEO_DRIVER="gl"
        SCREENSHOT_DIR="/recalbox/share/screenshots/shader-previews-opengl/"
    else
        echo "Error: Skipping file with unknown or unsupported extension: $SHADER_FILE"
        return 1
    fi

    echo "Processing shader: $SHADER_FILE"
    echo "Using driver: $VIDEO_DRIVER"
    echo "Saving screenshots to: $SCREENSHOT_DIR"

    # Determine the new screenshot path to replicate the directory structure
    RELATIVE_PATH=${SHADER_FILE#$SHADER_DIR}
    OUTPUT_DIR="$SCREENSHOT_DIR$(dirname "$RELATIVE_PATH")"
    FILENAME=$(basename "$SHADER_FILE" .$EXTENSION)
    FINAL_SCREENSHOT_PATH="$OUTPUT_DIR/$FILENAME.png"
    
    # Ensure the output directory exists
    echo "Creating output directory if it doesn't exist: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"

    # Generate a temporary config file for the current shader type
    TEMP_CONFIG_FILE="$CONFIG_DIR/retroarch_temp.cfg"
    echo "Creating temporary config file: $TEMP_CONFIG_FILE"
    cat > "$TEMP_CONFIG_FILE" << EOF
auto_shaders_enable = "true"
video_shader_dir = "$SHADER_DIR"
video_shader_enable = "true"
video_driver = "$VIDEO_DRIVER"
vulkan_gpu_index = "0"
# Set the video scale directly in the config file to 8
video_scale = "8"
# --- Explicitly set video and viewport resolution to force 512x512 output ---
video_fullscreen = "false"
video_windowed_fullscreen = "false"
video_width = "512"
video_height = "512"
viewport_width = "512"
viewport_height = "512"
# --- Add network command configuration ---
network_cmd_enable = "true"
network_cmd_port = "$NETWORK_PORT"
# Set the base directory for all screenshots
screenshot_directory = "$SCREENSHOT_DIR"
EOF

    # Launch RetroArch in the background with the current shader
    "$RETROARCH_BIN" -L "$IMAGE_VIEWER_CORE" "$CONTENT_PATH" \
        --set-shader "$SHADER_FILE" \
        --appendconfig "$TEMP_CONFIG_FILE" &

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

    # Remove the temporary config file
    rm "$TEMP_CONFIG_FILE"
}

# Check if a command-line argument (a specific shader path) is provided
if [[ -n "$1" ]]; then
    echo "Single shader file provided. Processing: $1"
    process_shader_file "$1"
else
    # 1. Loop through all shaders and take a screenshot for each
    echo "No shader file provided. Scanning all .slangp and .glslp shaders..."
    
    # We find files with either .slangp or .glslp extension, up to one level deep.
    for SHADER_FILE in $( (find "$SHADER_DIR" -maxdepth 1 -type f -name "*.slangp" -o -name "*.glslp" && find "$SHADER_DIR" -mindepth 2 -maxdepth 2 -type f -name "*.slangp" -o -name "*.glslp") | sort); do
        process_shader_file "$SHADER_FILE"
    done
fi

echo "All shaders processed. Script finished."
