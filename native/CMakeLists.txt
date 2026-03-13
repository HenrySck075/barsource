cmake_minimum_required(VERSION 3.20)
project(tennoji_native CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(PkgConfig REQUIRED)
pkg_check_modules(FFMPEG REQUIRED libavcodec libavformat libavutil libswresample)

set(SKIA_DIR "${CMAKE_SOURCE_DIR}/third_party/skia" CACHE PATH "Skia path")

# Auto-download Skia if not present
if(NOT EXISTS "${SKIA_DIR}/include")
  message(STATUS "Skia not found at ${SKIA_DIR}, downloading from geode-skia...")
  
  # Determine platform
  if(WIN32)
    set(SKIA_PLATFORM "Windows")
    set(SKIA_LIB_EXT "zip")
  elseif(APPLE)
    set(SKIA_PLATFORM "macOS")
    set(SKIA_LIB_EXT "tar.gz")
  else()
    if(DEFINED ENV{TERMUX_VERSION} OR 
       DEFINED ENV{TERMUX_APP_PID} OR
       EXISTS "/data/data/com.termux/files" OR
       (ANDROID AND CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64"))
      set(SKIA_PLATFORM "Android64")
      set(SKIA_LIB_EXT "tar.gz")
    else()
      set(SKIA_PLATFORM "Linux")
      set(SKIA_LIB_EXT "tar.gz")
    endif()
  endif()
  
  # Fetch latest release info
  file(DOWNLOAD 
    "https://api.github.com/repos/HenrySck075/geode-skia/releases/latest"
    "${CMAKE_BINARY_DIR}/latest_release.json"
  )
  
  file(READ "${CMAKE_BINARY_DIR}/latest_release.json" RELEASE_JSON)
  string(JSON LATEST_TAG GET "${RELEASE_JSON}" "tag_name")
  message(STATUS "Latest geode-skia release: ${LATEST_TAG}")
  
  # Download URLs
  set(SKIA_LIB_URL "https://github.com/HenrySck075/geode-skia/releases/download/${LATEST_TAG}/skia-${SKIA_PLATFORM}-bin.${SKIA_LIB_EXT}")
  set(SKIA_HEADERS_URL "https://github.com/HenrySck075/geode-skia/releases/download/${LATEST_TAG}/skia-headers.tar.gz")
  
  # Create Skia directory
  file(MAKE_DIRECTORY "${SKIA_DIR}")
  
  # Download library archive
  message(STATUS "Downloading ${SKIA_LIB_URL}...")
  file(DOWNLOAD "${SKIA_LIB_URL}" "${CMAKE_BINARY_DIR}/skia-lib.${SKIA_LIB_EXT}" SHOW_PROGRESS)
  
  # Download headers archive
  message(STATUS "Downloading ${SKIA_HEADERS_URL}...")
  file(DOWNLOAD "${SKIA_HEADERS_URL}" "${CMAKE_BINARY_DIR}/skia-headers.tar.gz" SHOW_PROGRESS)
  
  # Extract library archive
  message(STATUS "Extracting library archive...")
  file(ARCHIVE_EXTRACT INPUT "${CMAKE_BINARY_DIR}/skia-lib.${SKIA_LIB_EXT}" DESTINATION "${SKIA_DIR}")
  
  # Rename lib folder to out/Release
  if(EXISTS "${SKIA_DIR}/lib")
    file(MAKE_DIRECTORY "${SKIA_DIR}/out")
    file(RENAME "${SKIA_DIR}/lib" "${SKIA_DIR}/out/Release")
  endif()
  
  # Extract headers archive
  message(STATUS "Extracting headers archive...")
  file(ARCHIVE_EXTRACT INPUT "${CMAKE_BINARY_DIR}/skia-headers.tar.gz" DESTINATION "${SKIA_DIR}")
  
  message(STATUS "Skia download and extraction complete!")
endif()

add_library(tennoji SHARED
  src/engine.cpp
  src/renderer/skia_surface.cpp
  src/renderer/canvas.cpp
  src/renderer/compositor.cpp
  src/media/decoder.cpp
  src/media/encoder.cpp
  src/media/demuxer.cpp
  src/media/muxer.cpp
  src/media/frame_pool.cpp
  src/media/audio_mixer.cpp
  src/util/gpu_context.cpp
  src/util/thread_pool.cpp
)

target_compile_definitions(tennoji PRIVATE TENNOJI_BUILD)
target_include_directories(tennoji PUBLIC include PRIVATE ${SKIA_DIR} ${FFMPEG_INCLUDE_DIRS})
target_link_libraries(tennoji PRIVATE ${FFMPEG_LIBRARIES} ${SKIA_DIR}/out/Release/libskia.a)

if(WIN32)
  target_link_libraries(tennoji PRIVATE d3d11 dxgi)
elseif(APPLE)
  target_link_libraries(tennoji PRIVATE "-framework Metal" "-framework VideoToolbox")
else()
  find_package(Vulkan REQUIRED)
  target_link_libraries(tennoji PRIVATE Vulkan::Vulkan)
endif()
