// SPDX-License-Identifier: MPL-2.0
#ifndef MGBA_IOS_LAUNCHER_H
#define MGBA_IOS_LAUNCHER_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

enum { MGBALauncherWidth = 240, MGBALauncherHeight = 160, MGBALauncherRows = 5 };
typedef struct {
    size_t gameCount;
    size_t selected; // gameCount is the permanent Import entry.
    size_t firstVisible;
    uint32_t previousKeys;
    int repeatingDirection;
    double nextRepeat;
    bool requireRelease;
} MGBALauncher;
typedef struct {
    const char *title; // UTF-8; non-ASCII glyphs fall back to '?'.
    const char *system;
    bool canResume;
} MGBALauncherItem;
typedef enum {
    MGBALauncherNoAction,
    MGBALauncherSelectionChanged,
    MGBALauncherOpenGame,
    MGBALauncherImport
} MGBALauncherAction;

void MGBALauncherInit(MGBALauncher *launcher);
void MGBALauncherSetGameCount(MGBALauncher *launcher, size_t count);
void MGBALauncherSelect(MGBALauncher *launcher, size_t index);
void MGBALauncherMove(MGBALauncher *launcher, int direction);
void MGBALauncherReleaseBeforeInput(MGBALauncher *launcher);
MGBALauncherAction MGBALauncherUpdate(MGBALauncher *launcher, uint32_t keys, double time);
MGBALauncherAction MGBALauncherConfirm(const MGBALauncher *launcher);
// Returns SIZE_MAX outside a row or when the displayed row does not exist.
size_t MGBALauncherHitRow(const MGBALauncher *launcher, int x, int y);
// RGBX bytes, identical to the display format consumed by the iOS frontend.
void MGBALauncherRender(const MGBALauncher *launcher, const MGBALauncherItem *items,
                       const char *status, bool busy, uint32_t pixels[240 * 160]);
#endif
