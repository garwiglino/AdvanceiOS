// SPDX-License-Identifier: MPL-2.0
#pragma once
#include <stdint.h>
// x/y relative to the centre, with one unit equal to half the D-pad width/height.
// Eight equal 45-degree sectors; centre is neutral. y grows downwards.
uint32_t MGBADirectionForPoint(double x, double y);
uint32_t MGBACancelOpposingDirections(uint32_t keys);
