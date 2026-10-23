// SPDX-License-Identifier: MPL-2.0
#ifndef MGBA_IOS_AUDIO_RING_H
#define MGBA_IOS_AUDIO_RING_H
#include <stdatomic.h>
#include <stddef.h>
#include <stdint.h>
#define MGBA_AUDIO_CAPACITY 8192u
typedef struct {
    _Atomic uint32_t readIndex;
    _Atomic uint32_t writeIndex;
    int16_t samples[MGBA_AUDIO_CAPACITY * 2];
} MGBAAudioRing;
void MGBAAudioInit(MGBAAudioRing *ring);
size_t MGBAAudioWrite(MGBAAudioRing *ring, const int16_t *stereo, size_t frames);
void MGBAAudioRead(MGBAAudioRing *ring, float *left, float *right, size_t frames);
// Call only while BOTH producer and consumer are stopped.
void MGBAAudioReset(MGBAAudioRing *ring);
#endif
