// SPDX-License-Identifier: MPL-2.0
#include "MGBASession.h"
#include <mgba/core/core.h>
#include <mgba/core/blip_buf.h>
#include <mgba/core/serialize.h>
#include <mgba-util/vfs.h>

struct MGBASession {
    struct mCore *core;
    uint32_t *pixels;
    unsigned width, height;
};

MGBASession *MGBACreate(const void *rom, size_t length, const void *save, size_t saveLength) {
    if (!rom || length < 192 || length > 32 * 1024 * 1024 || saveLength > 1024 * 1024) return NULL;
    struct VFile *vf = VFileMemChunk(rom, length);
    if (!vf) return NULL;
    struct mCore *core = mCoreFindVF(vf);
    if (!core) { vf->close(vf); return NULL; }
    mCoreInitConfig(core, NULL);
    if (!core->init(core)) {
        mCoreConfigDeinit(&core->config);
        free(core);
        vf->close(vf);
        return NULL;
    }
    MGBASession *s = calloc(1, sizeof(*s));
    if (!s) {
        vf->close(vf);
        mCoreConfigDeinit(&core->config);
        core->deinit(core);
        return NULL;
    }
    s->core = core;
    mCoreConfigSetDefaultIntValue(&core->config, "volume", 0x100);
    mCoreConfigSetDefaultIntValue(&core->config, "useBios", 0);
    mCoreConfigSetDefaultIntValue(&core->config, "skipBios", 1);
    mCoreConfigSetDefaultIntValue(&core->config, "sgb.borders", 0);
    mCoreConfigSetDefaultValue(&core->config, "idleOptimization", "detect");
    mCoreLoadConfig(core);
    core->desiredVideoDimensions(core, &s->width, &s->height);
    s->pixels = calloc(s->width * s->height, sizeof(uint32_t));
    if (!s->pixels) { vf->close(vf); MGBADestroy(s); return NULL; }
    core->setVideoBuffer(core, s->pixels, s->width);
    core->setAudioBufferSize(core, 4096);
    if (!core->loadROM(core, vf)) { vf->close(vf); MGBADestroy(s); return NULL; }
    // loadROM and loadSave take ownership on success. Battery RAM remains in
    // memory; the iOS layer writes snapshots atomically in the app container.
    if (save && saveLength) {
        struct VFile *battery = VFileMemChunk(save, saveLength);
        if (!battery || !core->loadSave(core, battery)) {
            if (battery) battery->close(battery);
            MGBADestroy(s);
            return NULL;
        }
    }
    MGBAReset(s);
    return s;
}

void MGBADestroy(MGBASession *s) {
    if (!s) return;
    if (s->core) {
        mCoreConfigDeinit(&s->core->config);
        s->core->deinit(s->core);
    }
    free(s->pixels);
    free(s);
}

void MGBAReset(MGBASession *s) {
    if (!s) return;
    s->core->reset(s->core);
    for (int ch = 0; ch < 2; ++ch)
        blip_set_rates(s->core->getAudioChannel(s->core, ch), s->core->frequency(s->core), 48000);
}
void MGBARunFrame(MGBASession *s, uint32_t keys) {
    s->core->setKeys(s->core, keys & 0x3FF);
    s->core->runFrame(s->core);
}
const uint32_t *MGBAPixels(const MGBASession *s) { return s->pixels; }
unsigned MGBAWidth(const MGBASession *s) { return s->width; }
unsigned MGBAHeight(const MGBASession *s) { return s->height; }
uint32_t MGBAFrameNumber(const MGBASession *s) { return s->core->frameCounter(s->core); }
double MGBAFrameDuration(const MGBASession *s) {
    return (double)s->core->frameCycles(s->core) / s->core->frequency(s->core);
}
size_t MGBAReadAudio(MGBASession *s, int16_t *stereo, size_t capacity) {
    if (!s || !stereo) return 0;
    blip_t *left = s->core->getAudioChannel(s->core, 0);
    blip_t *right = s->core->getAudioChannel(s->core, 1);
    size_t n = (size_t)blip_samples_avail(left);
    size_t r = (size_t)blip_samples_avail(right);
    if (n > r) n = r;
    if (n > capacity) n = capacity;
    blip_read_samples(left, stereo, (int)n, 1);
    blip_read_samples(right, stereo + 1, (int)n, 1);
    return n;
}
bool MGBACopyBattery(MGBASession *s, void **bytes, size_t *length) {
    *bytes = NULL;
    *length = s->core->savedataClone(s->core, bytes);
    return *length == 0 || *bytes != NULL;
}
bool MGBACopyState(MGBASession *s, void **bytes, size_t *length) {
    *bytes = NULL;
    *length = 0;
    struct VFile *vf = VFileMemChunk(NULL, 0);
    if (!vf) return false;
    bool ok = mCoreSaveStateNamed(s->core, vf, SAVESTATE_SAVEDATA | SAVESTATE_RTC | SAVESTATE_METADATA);
    if (ok) {
        *length = (size_t)vf->size(vf);
        *bytes = malloc(*length);
        ok = *bytes != NULL;
        if (ok) {
            vf->seek(vf, 0, SEEK_SET);
            ok = vf->read(vf, *bytes, *length) == (ssize_t)*length;
        }
    }
    vf->close(vf);
    if (!ok) { free(*bytes); *bytes = NULL; *length = 0; }
    return ok;
}
bool MGBALoadState(MGBASession *s, const void *bytes, size_t length) {
    if (!bytes || length < s->core->stateSize(s->core) || length > 4 * 1024 * 1024) return false;
    struct VFile *vf = VFileFromConstMemory(bytes, length);
    if (!vf) return false;
    // Upstream may apply extended savedata even when base-state validation
    // fails. Preserve the current session so a rejected state is non-destructive.
    void *backup = NULL;
    size_t backupLength = 0;
    if (!MGBACopyState(s, &backup, &backupLength)) { vf->close(vf); return false; }
    bool ok = mCoreLoadStateNamed(s->core, vf, SAVESTATE_SAVEDATA | SAVESTATE_RTC);
    vf->close(vf);
    if (!ok) {
        struct VFile *previous = VFileFromConstMemory(backup, backupLength);
        if (previous) {
            mCoreLoadStateNamed(s->core, previous, SAVESTATE_SAVEDATA | SAVESTATE_RTC);
            previous->close(previous);
        }
    }
    free(backup);
    return ok;
}
void MGBAFree(void *bytes) { free(bytes); }
