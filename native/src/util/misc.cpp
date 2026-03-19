#include "tennoji/engine.h"
#include <cmath>


extern "C" {
bool rina_rsuperellipse_contains(
    double px, double py,            // The point to test
    double left, double top, 
    double right, double bottom,
    double tlRx, double tlRy,        // Top-Left Radii
    double trRx, double trRy,        // Top-Right Radii
    double blRx, double blRy,        // Bottom-Left Radii
    double brRx, double brRy         // Bottom-Right Radii
) {
    // 1. Basic Bounds Check
    if (px < left || px > right || py < top || py > bottom) {
        return false;
    }

    double dx = 0, dy = 0, rx = 0, ry = 0;
    double n = 2.4; // The "smoothness" exponent

    // 2. Identify which corner zone the point is in
    // Top-Left
    if (px < left + tlRx && py < top + tlRy) {
        dx = (left + tlRx) - px;
        dy = (top + tlRy) - py;
        rx = tlRx; ry = tlRy;
    } 
    // Top-Right
    else if (px > right - trRx && py < top + trRy) {
        dx = px - (right - trRx);
        dy = (top + trRy) - py;
        rx = trRx; ry = trRy;
    }
    // Bottom-Right
    else if (px > right - brRx && py > bottom - brRy) {
        dx = px - (right - brRx);
        dy = py - (bottom - brRy);
        rx = brRx; ry = brRy;
    }
    // Bottom-Left
    else if (px < left + blRx && py > bottom - blRy) {
        dx = (left + blRx) - px;
        dy = py - (bottom - blRy);
        rx = blRx; ry = blRy;
    }
    // 3. If not in a corner zone, it's in the central cross (always inside)
    else {
        return true;
    }

    // 4. Solve the superellipse inequality for the specific corner
    // Formula: (dx/rx)^n + (dy/ry)^n <= 1
    if (rx <= 0 || ry <= 0) return true; // Edge case for zero radius
    
    double val = pow(dx / rx, n) + pow(dy / ry, n);
    return val <= 1.0;
}
}