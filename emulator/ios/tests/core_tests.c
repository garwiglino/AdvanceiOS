// SPDX-License-Identifier: MPL-2.0
#include "MGBASession.h"
#include "AudioRing.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "launcher_tests.h"

// Original ARM homebrew: mode 3, green framebuffer, SRAM marker, infinite loop.
// No Nintendo logo, BIOS, or commercial game data is included.
static void makeROM(uint8_t rom[1024]) {
    memset(rom, 0, 1024);
    uint32_t branch = 0xEA00002E; // entry -> 0x080000C0
    memcpy(rom, &branch, 4);
    // mGBA checks these four identification bytes and the fixed header byte.
    const uint8_t magic[] = {0x24, 0xFF, 0xAE, 0x51};
    memcpy(rom + 4, magic, 4);
    memcpy(rom + 0xA0, "IOS CORE TEST", 12);
    memcpy(rom + 0xAC, "TEST", 4);
    rom[0xB2] = 0x96;
    const uint32_t program[] = {
        0xE3A00301, // mov r0, #0x04000000
        0xE59F1028, // ldr r1, display mode
        0xE1C010B0, // strh r1, [r0]
        0xE3A00406, // mov r0, #0x06000000
        0xE59F1020, // ldr r1, green
        0xE59F2020, // ldr r2, pixel count
        0xE0C010B2, // strh r1, [r0], #2
        0xE2522001, // subs r2, r2, #1
        0x1AFFFFFC, // bne fill
        0xE3A0040E, // mov r0, #0x0E000000
        0xE3A0105A, // mov r1, #0x5A
        0xE5C01000, // strb r1, [r0]
        0xEAFFFFFE, // b .
        0x00000403, 0x000003E0, 38400
    };
    memcpy(rom + 0xC0, program, sizeof(program));
    memcpy(rom + 0x180, "SRAM_V113", 9);
}

static void testAudio(void) {
    MGBAAudioRing *r = calloc(1, sizeof(*r));
    MGBAAudioInit(r);
    int16_t samples[] = {32767, -32768, 16384, -16384};
    float left[4], right[4];
    assert(MGBAAudioWrite(r, samples, 2) == 2);
    MGBAAudioRead(r, left, right, 4);
    assert(left[0] > 0.99f && right[0] == -1.0f);
    assert(left[1] == 0.5f && right[1] == -0.5f);
    assert(left[2] == 0 && right[3] == 0);
    // Repeated writes/reads cross the circular storage boundary.
    for (unsigned i = 0; i < 20000; ++i) {
        assert(MGBAAudioWrite(r, samples, 2) == 2);
        MGBAAudioRead(r, left, right, 2);
        assert(left[1] == 0.5f && right[0] == -1.0f);
    }
    MGBAAudioReset(r);
    MGBAAudioRead(r, left, right, 4);
    assert(left[0] == 0 && right[3] == 0);
    int16_t *full = calloc(MGBA_AUDIO_CAPACITY * 2, sizeof(int16_t));
    assert(MGBAAudioWrite(r, full, MGBA_AUDIO_CAPACITY) == MGBA_AUDIO_CAPACITY);
    assert(MGBAAudioWrite(r, samples, 2) == 0);
    MGBAAudioRead(r, left, right, 4); // consumer trims latency safely
    assert(left[0] == 0 && right[3] == 0);
    free(full);
    free(r);
}

static void testGB(bool color) {
    uint8_t *rom = calloc(1, 32768);
    rom[0x100] = 0xC3; rom[0x101] = 0x50; rom[0x102] = 0x01;
    const uint8_t magic[] = {0xCE, 0xED, 0x66, 0x66};
    memcpy(rom + 0x104, magic, 4);
    memcpy(rom + 0x134, "IOS GB TEST", 11);
    rom[0x143] = color ? 0x80 : 0;
    const uint8_t program[] = {0xF3, 0x18, 0xFE}; // di; jr .
    memcpy(rom + 0x150, program, sizeof(program));
    MGBASession *s = MGBACreate(rom, 32768, NULL, 0);
    free(rom);
    assert(s && MGBAWidth(s) == 160 && MGBAHeight(s) == 144);
    int16_t audio[4096 * 2];
    size_t frames = 0;
    for (unsigned i = 0; i < 5; ++i) {
        MGBARunFrame(s, MGBAKeyStart);
        frames += MGBAReadAudio(s, audio, 4096);
    }
    assert(frames > 3000 && frames < 4500);
    assert(MGBAFrameNumber(s) >= 5);
    void *state;
    size_t stateSize;
    assert(MGBACopyState(s, &state, &stateSize));
    assert(MGBALoadState(s, state, stateSize));
    MGBAFree(state);
    MGBADestroy(s);
}

int main(int argc, char **argv) {
    uint8_t rom[1024];
    makeROM(rom);
    if (argc >= 2) {
        FILE *out = fopen(argv[1], "wb");
        assert(out && fwrite(rom, 1, sizeof(rom), out) == sizeof(rom));
        fclose(out);
    }
    uint8_t invalid[256] = {0};
    assert(!MGBACreate(NULL, 0, NULL, 0));
    assert(!MGBACreate(invalid, sizeof(invalid), NULL, 0));
    MGBASession *s = MGBACreate(rom, sizeof(rom), NULL, 0);
    assert(s);
    assert(MGBAWidth(s) == 240 && MGBAHeight(s) == 160);
    assert(MGBAFrameDuration(s) > 0.0167 && MGBAFrameDuration(s) < 0.0168);
    int16_t audio[4096 * 2];
    size_t frames = 0;
    for (int i = 0; i < 6; ++i) {
        MGBARunFrame(s, MGBAKeyA | MGBAKeyRight);
        frames += MGBAReadAudio(s, audio, 4096);
    }
    assert(frames > 4000 && frames < 5000);
    assert((MGBAPixels(s)[120 + 80 * 240] & 0xFFFFFF) == 0x00FF00);
    void *state, *battery;
    size_t stateSize, batterySize;
    assert(MGBACopyState(s, &state, &stateSize) && stateSize > 0);
    uint32_t savedFrame = MGBAFrameNumber(s);
    MGBARunFrame(s, 0);
    MGBAReadAudio(s, audio, 4096);
    assert(MGBAFrameNumber(s) != savedFrame);
    assert(MGBALoadState(s, state, stateSize));
    assert(MGBAFrameNumber(s) == savedFrame);
    assert(!MGBALoadState(s, invalid, sizeof(invalid)));
    uint8_t *badState = malloc(stateSize);
    memcpy(badState, state, stateSize);
    memset(badState, 0xFF, 4); // invalidate the serialized-state version
    assert(!MGBALoadState(s, badState, stateSize));
    assert(MGBAFrameNumber(s) == savedFrame);
    free(badState);
    assert(MGBACopyBattery(s, &battery, &batterySize));
    assert(batterySize == 32768 && ((uint8_t *)battery)[0] == 0x5A);
    MGBADestroy(s);
    s = MGBACreate(rom, sizeof(rom), battery, batterySize);
    assert(s);
    void *roundtrip;
    size_t roundtripSize;
    assert(MGBACopyBattery(s, &roundtrip, &roundtripSize));
    assert(roundtripSize == batterySize && memcmp(battery, roundtrip, batterySize) == 0);
    MGBAFree(roundtrip);
    MGBAFree(battery);
    MGBAFree(state);
    MGBADestroy(s);
    testAudio();
    testGB(false);
    testGB(true);
    testLauncher(argc >= 3 ? argv[2] : NULL);
    puts("PASS: ROM validation, GBA/GB/GBC execution, pixels, timing, stereo audio, savestate rollback, SRAM persistence, audio ring.");
    return 0;
}
