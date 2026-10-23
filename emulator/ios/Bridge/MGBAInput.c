// SPDX-License-Identifier: MPL-2.0
#include "MGBAInput.h"
#include "MGBASession.h"
#include <math.h>
uint32_t MGBADirectionForPoint(double x, double y) {
    if (!isfinite(x) || !isfinite(y) || x*x + y*y < 0.25*0.25) return 0;
    static const uint32_t directions[] = {
        MGBAKeyRight, MGBAKeyRight | MGBAKeyDown, MGBAKeyDown, MGBAKeyDown | MGBAKeyLeft,
        MGBAKeyLeft, MGBAKeyLeft | MGBAKeyUp, MGBAKeyUp, MGBAKeyUp | MGBAKeyRight
    };
    int sector = (int)floor(atan2(y, x) / (3.14159265358979323846 / 4.0) + 0.5);
    return directions[(sector + 8) % 8];
}
uint32_t MGBACancelOpposingDirections(uint32_t keys) {
    if ((keys & (MGBAKeyLeft | MGBAKeyRight)) == (MGBAKeyLeft | MGBAKeyRight)) keys &= ~(MGBAKeyLeft | MGBAKeyRight);
    if ((keys & (MGBAKeyUp | MGBAKeyDown)) == (MGBAKeyUp | MGBAKeyDown)) keys &= ~(MGBAKeyUp | MGBAKeyDown);
    return keys;
}
