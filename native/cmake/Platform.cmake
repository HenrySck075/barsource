# -----------------------------------------------------------------------------
# Platform Detection Module
# -----------------------------------------------------------------------------

# Initialize custom helper variables to FALSE
set(PLATFORM_WINDOWS FALSE)
set(PLATFORM_MACOS   FALSE)
set(PLATFORM_LINUX   FALSE)
set(PLATFORM_TERMUX  FALSE)

# 2. Detect Windows
if(WIN32)
    set(PLATFORM_WINDOWS TRUE)
    add_definitions(-DTENNOJI_IS_WINDOWS)
    message(STATUS "Platform: Windows")

# 3. Detect macOS
elseif(APPLE)
    set(PLATFORM_MACOS TRUE)
    add_definitions(-DTENNOJI_IS_MACOS)
    message(STATUS "Platform: macOS")

# 4. Detect Linux & Termux
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(PLATFORM_LINUX TRUE)
    
    # Check for Termux specifically
    # Termux usually sets the prefix to its internal data directory
    if(DEFINED ENV{TERMUX_VERSION} OR EXISTS "/data/data/com.termux")
        set(PLATFORM_TERMUX TRUE)
        add_definitions(-DTENNOJI_IS_TERMUX)
        message(STATUS "Platform: Linux (Termux Environment detected)")
    else()
        add_definitions(-DTENNOJI_IS_LINUX)
        message(STATUS "Platform: Linux")
    endif()

# 5. Fallback for everything else
else()
    message(WARNING "Platform: Unknown (${CMAKE_SYSTEM_NAME})")
endif()

# -----------------------------------------------------------------------------
# Global Definitions (Optional)
# -----------------------------------------------------------------------------
# You can uncomment these to pass them as macros to your C++ code:
# add_definitions(-DPLATFORM_STR="${CMAKE_SYSTEM_NAME}")
