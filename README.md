# shader-previews
A repo to store thumbnail previews for RetroArch's many shaders. 
(upgraded for pixL, including splitting in 2 directories for OpenGL and Vulkan previews)

Its directory structure mirrors the common-shaders and slang-shaders repos and it includes previews of the shader presets (i.e., not individual shaders unless they have an accompanying preset).

Preview shots were created automatically by opening the upscale-test image(s) in RetroArch's built-in image-viewer core at differents scales. 
It's not perfect because some shaders require additional settings or images to capture their effects and those are handled on a case-by-case basis.
When additional settings are required, notes should be added to the preview.

For pixL, tooling is in /shader_tools directory
and vulkan/opengl previews will be separated as after:
- /shader-previews-vulkan-xxx for .slangp Vulkan shader presets
- /shader-previews-opengl-xxx for .glslp OpenGL shader presets
  where xxx could be a date/type of upscale-test image used

For Legacy ones, we kept in /shader-previews-legacy and from several sources
