// SPDX-License-Identifier: MPL-2.0
#ifndef MGBA_IOS_SESSION_H
#define MGBA_IOS_SESSION_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// All session calls belong to one serial emulation queue. Returned blobs are
// owned by the caller and must be released with MGBAFree.
typedef struct MGBASession MGBASession;
enum MGBAKey {
    MGBAKeyA = 1 << 0, MGBAKeyB = 1 << 1, MGBAKeySelect = 1 << 2,
    MGBAKeyStart = 1 << 3, MGBAKeyRight = 1 << 4, MGBAKeyLeft = 1 << 5,
    MGBAKeyUp = 1 << 6, MGBAKeyDown = 1 << 7, MGBAKeyR = 1 << 8, MGBAKeyL = 1 << 9
};
MGBASession *MGBACreate(const void *rom, size_t length, const void *save, size_t saveLength);
void MGBADestroy(MGBASession *session);
void MGBAReset(MGBASession *session);
void MGBARunFrame(MGBASession *session, uint32_t keys);
const uint32_t *MGBAPixels(const MGBASession *session);
unsigned MGBAWidth(const MGBASession *session);
unsigned MGBAHeight(const MGBASession *session);
uint32_t MGBAFrameNumber(const MGBASession *session);
double MGBAFrameDuration(const MGBASession *session);
size_t MGBAReadAudio(MGBASession *session, int16_t *stereo, size_t capacityFrames);
bool MGBACopyBattery(MGBASession *session, void **bytes, size_t *length);
bool MGBACopyState(MGBASession *session, void **bytes, size_t *length);
bool MGBALoadState(MGBASession *session, const void *bytes, size_t length);
void MGBAFree(void *bytes);
#endif
