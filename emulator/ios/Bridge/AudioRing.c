// SPDX-License-Identifier: MPL-2.0
#include "AudioRing.h"
void MGBAAudioInit(MGBAAudioRing *r) {
    atomic_init(&r->readIndex, 0);
    atomic_init(&r->writeIndex, 0);
}
size_t MGBAAudioWrite(MGBAAudioRing *r, const int16_t *stereo, size_t frames) {
    uint32_t w = atomic_load_explicit(&r->writeIndex, memory_order_relaxed);
    uint32_t read = atomic_load_explicit(&r->readIndex, memory_order_acquire);
    size_t freeFrames = MGBA_AUDIO_CAPACITY - (uint32_t)(w - read);
    if (frames > freeFrames) frames = freeFrames;
    for (size_t i = 0; i < frames; ++i) {
        uint32_t index = ((w + (uint32_t)i) & (MGBA_AUDIO_CAPACITY - 1)) * 2;
        r->samples[index] = stereo[2 * i];
        r->samples[index + 1] = stereo[2 * i + 1];
    }
    atomic_store_explicit(&r->writeIndex, w + (uint32_t)frames, memory_order_release);
    return frames;
}
void MGBAAudioRead(MGBAAudioRing *r, float *left, float *right, size_t frames) {
    uint32_t read = atomic_load_explicit(&r->readIndex, memory_order_relaxed);
    uint32_t w = atomic_load_explicit(&r->writeIndex, memory_order_acquire);
    // Only the consumer advances readIndex. Trim accumulated latency after a
    // route stall without ever blocking or allocating on the audio thread.
    if ((uint32_t)(w - read) > 4096) read = w - 2048;
    size_t available = (uint32_t)(w - read);
    size_t n = frames < available ? frames : available;
    for (size_t i = 0; i < n; ++i) {
        uint32_t index = ((read + (uint32_t)i) & (MGBA_AUDIO_CAPACITY - 1)) * 2;
        left[i] = r->samples[index] / 32768.0f;
        right[i] = r->samples[index + 1] / 32768.0f;
    }
    for (size_t i = n; i < frames; ++i) { left[i] = 0; right[i] = 0; }
    atomic_store_explicit(&r->readIndex, read + (uint32_t)n, memory_order_release);
}
void MGBAAudioReset(MGBAAudioRing *r) {
    atomic_store(&r->readIndex, 0);
    atomic_store(&r->writeIndex, 0);
}
