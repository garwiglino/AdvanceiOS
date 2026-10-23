// SPDX-License-Identifier: MPL-2.0
#include "MGBALauncher.h"
#include "MGBAInput.h"
#include <math.h>
static void testLauncher(const char *previewPath) {
    const uint32_t expected[8] = { MGBAKeyRight, MGBAKeyRight|MGBAKeyDown, MGBAKeyDown,
        MGBAKeyDown|MGBAKeyLeft, MGBAKeyLeft, MGBAKeyLeft|MGBAKeyUp, MGBAKeyUp, MGBAKeyUp|MGBAKeyRight };
    for (int i = 0; i < 8; ++i) {
        // Both sides of every sector, near and far from the pivot.
        for (int offset = -21; offset <= 21; ++offset) {
            double angle = (i*45+offset)*3.14159265358979323846/180;
            assert(MGBADirectionForPoint(cos(angle),sin(angle)) == expected[i]);
            assert(MGBADirectionForPoint(0.26*cos(angle),0.26*sin(angle)) == expected[i]);
        }
    }
    assert(MGBADirectionForPoint(0,0) == 0 && MGBADirectionForPoint(0.17,0.17) == 0);
    assert(MGBADirectionForPoint(NAN,1) == 0 && MGBADirectionForPoint(INFINITY,1) == 0);
    assert(MGBACancelOpposingDirections(MGBAKeyUp|MGBAKeyDown|MGBAKeyA) == MGBAKeyA);
    assert(MGBACancelOpposingDirections(0x3FF) == (0x3FF & ~240));
    MGBALauncher s;
    MGBALauncherInit(&s);
    assert(MGBALauncherConfirm(&s) == MGBALauncherImport);
    assert(MGBALauncherHitRow(&s,20,40) == 0);
    assert(MGBALauncherHitRow(&s,20,60) == SIZE_MAX);
    MGBALauncherSetGameCount(&s,12);
    assert(MGBALauncherUpdate(&s,MGBAKeyDown,0) == MGBALauncherSelectionChanged && s.selected == 1);
    assert(MGBALauncherUpdate(&s,MGBAKeyDown,0.34) == MGBALauncherNoAction);
    assert(MGBALauncherUpdate(&s,MGBAKeyDown,0.36) == MGBALauncherSelectionChanged && s.selected == 2);
    assert(MGBALauncherUpdate(&s,MGBAKeyDown,0.40) == MGBALauncherNoAction);
    assert(MGBALauncherUpdate(&s,MGBAKeyDown,0.47) == MGBALauncherSelectionChanged && s.selected == 3);
    MGBALauncherUpdate(&s,0,0.5);
    assert(MGBALauncherUpdate(&s,MGBAKeyR,0.6) == MGBALauncherSelectionChanged && s.selected == 8 && s.firstVisible == 4);
    assert(MGBALauncherHitRow(&s,20,34) == 4);
    assert(MGBALauncherHitRow(&s,20,123) == 8);
    assert(MGBALauncherHitRow(&s,240,123) == SIZE_MAX);
    MGBALauncherReleaseBeforeInput(&s);
    assert(MGBALauncherUpdate(&s,MGBAKeyA,1) == MGBALauncherNoAction);
    assert(MGBALauncherUpdate(&s,MGBAKeyA,2) == MGBALauncherNoAction);
    MGBALauncherUpdate(&s,0,3);
    assert(MGBALauncherUpdate(&s,MGBAKeyA,4) == MGBALauncherOpenGame);
    assert(MGBALauncherUpdate(&s,MGBAKeyA,5) == MGBALauncherNoAction);
    MGBALauncherUpdate(&s,0,6);
    assert(MGBALauncherUpdate(&s,MGBAKeySelect,7) == MGBALauncherImport);
    MGBALauncherSelect(&s,12); assert(MGBALauncherConfirm(&s) == MGBALauncherImport);
    MGBALauncherMove(&s,1); assert(s.selected == 0 && s.firstVisible == 0);
    MGBALauncherMove(&s,-1); assert(s.selected == 12 && s.firstVisible == 8);
    MGBALauncherSetGameCount(&s,1); assert(s.selected == 1 && s.firstVisible == 0);
    // Guard the framebuffer while rendering empty, long, non-ASCII and busy states.
    uint32_t *guarded = malloc((240*160+2)*sizeof(uint32_t));
    guarded[0] = guarded[240*160+1] = 0xDEADBEEF;
    MGBALauncherItem items[] = {{"DEMO GBA", "GBA", true}, {"MA PARTIE", "GBC", false}, {"AVENTURE", "GB", false},
        {"UN TITRE TRES LONG POUR VERIFIER LA TRONCATURE DE LA LIGNE", "GBA", false}, {"\xc3\xa9\xe6\x97\xa5", "GBA", false}};
    for (size_t count = 0; count <= 5; ++count) {
        MGBALauncherSetGameCount(&s,count);
        for (size_t selected = 0; selected <= count; ++selected) {
            MGBALauncherSelect(&s,selected);
            MGBALauncherRender(&s,items,"STATUT",false,guarded+1);
            assert(guarded[0] == 0xDEADBEEF && guarded[240*160+1] == 0xDEADBEEF);
        }
    }
    MGBALauncherRender(&s,items,"IMPORTATION",true,guarded+1);
    assert(guarded[0] == 0xDEADBEEF && guarded[240*160+1] == 0xDEADBEEF);
    if (previewPath) {
        MGBALauncherSetGameCount(&s,3); MGBALauncherSelect(&s,0);
        MGBALauncherRender(&s,items,NULL,false,guarded+1);
        FILE *file = fopen(previewPath,"wb"); assert(file);
        fprintf(file,"P6\n240 160\n255\n");
        for (size_t p = 1; p <= 240*160; ++p) assert(fwrite(&guarded[p],1,3,file) == 3);
        fclose(file);
    }
    free(guarded);
    puts("PASS: eight 45-degree directions, neutral centre, opposing inputs, launcher navigation/repeat/pages/import/gating, RGBX render bounds.");
}
