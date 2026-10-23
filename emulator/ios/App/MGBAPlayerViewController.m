// SPDX-License-Identifier: MPL-2.0
#import "MGBAPlayerViewController.h"
#import "MGBAEngine.h"
#import "MGBAControls.h"
#import "AdvanceiOS-Swift.h"
#import "MGBAInput.h"
#import "MGBALauncher.h"
#import <GameController/GameController.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface MGBAScreenView : UIImageView
@property (nonatomic, copy) void (^onStep)(int direction);
@property (nonatomic, copy) void (^onActivate)(void);
@end
@implementation MGBAScreenView
- (void)accessibilityIncrement { if (self.onStep) self.onStep(1); }
- (void)accessibilityDecrement { if (self.onStep) self.onStep(-1); }
- (BOOL)accessibilityActivate {
    if (!self.onActivate) return NO;
    self.onActivate();
    return YES;
}
@end

@interface MGBAPlayerViewController () <UIDocumentPickerDelegate>
@end
@implementation MGBAPlayerViewController {
    MGBAGame *_game;
    MGBAEngine *_engine;
    MGBAScreenView *_screen;
    MGBAConsoleSurface *_surface;
    MGBAControls *_controls;
    UIButton *_menuButton, *_resumeButton;
    BOOL _loaded, _errorShown;
    uint32_t _touchKeys, _controllerKeys;
    MGBALibrary *_library;
    NSArray<MGBAGame *> *_games;
    MGBALauncher _launcher;
    CADisplayLink *_launcherClock;
    BOOL _showingLauncher, _working, _gameNeedsKeyRelease;
    NSInteger _pickerPurpose; // 1: ROM import; 2: battery import.
    NSString *_launcherStatus;
}
- (instancetype)init { return [self initWithGame:nil]; }
- (instancetype)initWithGame:(MGBAGame *)game {
    if ((self = [super init])) {
        _game = game;
        _library = [MGBALibrary new];
        MGBALauncherInit(&_launcher);
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return self;
}
- (BOOL)prefersStatusBarHidden { return YES; }
- (BOOL)prefersHomeIndicatorAutoHidden { return YES; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.035 green:0.045 blue:0.065 alpha:1];
    _screen = [MGBAScreenView new];
    _screen.backgroundColor = UIColor.blackColor;
    _screen.contentMode = UIViewContentModeScaleAspectFit;
    _screen.layer.magnificationFilter = kCAFilterNearest;
    _screen.layer.minificationFilter = kCAFilterNearest;
    _screen.userInteractionEnabled = YES;
    [_screen addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(screenTapped:)]];
    _controls = [MGBAControls new];
    _surface = [[MGBAConsoleSurface alloc] initWithScreen:_screen controls:_controls];
    UIViewController *host = _surface.controller;
    [self addChildViewController:host];
    [self.view addSubview:host.view];
    [host didMoveToParentViewController:self];
    _menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_menuButton setImage:[UIImage systemImageNamed:@"pause.circle.fill"] forState:UIControlStateNormal];
    _menuButton.tintColor = UIColor.whiteColor;
    _menuButton.accessibilityLabel = @"Pause et options";
    [_menuButton addTarget:self action:@selector(showMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_menuButton];
    _resumeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_resumeButton setTitle:@"▶ Reprendre" forState:UIControlStateNormal];
    _resumeButton.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    _resumeButton.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.94];
    _resumeButton.tintColor = UIColor.whiteColor;
    _resumeButton.layer.cornerRadius = 18;
    [_resumeButton addTarget:self action:@selector(resumeGame) forControlEvents:UIControlEventTouchUpInside];
    _resumeButton.hidden = YES;
    [self.view addSubview:_resumeButton];
    _engine = [MGBAEngine new];
    __weak typeof(self) weakSelf = self;
    // Avoid direct weak ivar dereferences when the controller has disappeared.
    _engine.onFrame = ^(UIImage *image) {
        MGBAPlayerViewController *strongSelf = weakSelf;
        if (strongSelf && strongSelf->_loaded && !strongSelf->_showingLauncher) strongSelf->_screen.image = image;
    };
    _engine.onError = ^(NSError *error) { [weakSelf showError:error]; };
    _controls.onKeys = ^(uint32_t keys) {
        MGBAPlayerViewController *strongSelf = weakSelf;
        if (strongSelf) { strongSelf->_touchKeys = keys; [strongSelf updateKeys]; }
    };
    _surface.onAccessibleKey = ^(uint32_t key) {
        MGBAPlayerViewController *strongSelf = weakSelf;
        if (!strongSelf || strongSelf->_working || strongSelf.presentedViewController) return;
        if (strongSelf->_showingLauncher) {
            if (key == MGBAKeyUp || key == MGBAKeyDown || key == MGBAKeyLeft || key == MGBAKeyRight) {
                MGBALauncherMove(&strongSelf->_launcher, key == MGBAKeyUp || key == MGBAKeyLeft ? -1 : 1);
                [strongSelf renderLauncher];
            } else if (key == MGBAKeyA || key == MGBAKeyStart) [strongSelf handleLauncherAction:MGBALauncherConfirm(&strongSelf->_launcher)];
            else if (key == MGBAKeySelect) [strongSelf chooseROMs];
        } else {
            strongSelf->_touchKeys |= key;
            [strongSelf updateKeys];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 120*NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                MGBAPlayerViewController *owner = weakSelf;
                if (owner) { owner->_touchKeys &= ~key; [owner updateKeys]; }
            });
        }
    };
    _screen.onStep = ^(int direction) {
        MGBAPlayerViewController *strongSelf = weakSelf;
        if (!strongSelf || !strongSelf->_showingLauncher || strongSelf->_working || strongSelf.presentedViewController) return;
        MGBALauncherMove(&strongSelf->_launcher, direction);
        strongSelf->_launcherStatus = nil;
        [strongSelf renderLauncher];
    };
    _screen.onActivate = ^{
        MGBAPlayerViewController *strongSelf = weakSelf;
        if (strongSelf) [strongSelf handleLauncherAction:MGBALauncherConfirm(&strongSelf->_launcher)];
    };
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(interrupted:) name:UIApplicationWillResignActiveNotification object:nil];
    [center addObserver:self selector:@selector(becameActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [center addObserver:self selector:@selector(audioInterrupted:) name:AVAudioSessionInterruptionNotification object:nil];
    [center addObserver:self selector:@selector(interrupted:) name:AVAudioSessionRouteChangeNotification object:nil];
    [center addObserver:self selector:@selector(interrupted:) name:AVAudioSessionMediaServicesWereResetNotification object:nil];
    [center addObserver:self selector:@selector(connectControllers:) name:GCControllerDidConnectNotification object:nil];
    [center addObserver:self selector:@selector(connectControllers:) name:GCControllerDidDisconnectNotification object:nil];
    [self connectControllers:nil];
    if (_game) [self launchGame:_game];
    else [self showLauncher];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _surface.controller.view.frame = self.view.bounds;
    [_surface updateLayout:self.view.bounds.size insets:self.view.safeAreaInsets];
    CGRect safe = UIEdgeInsetsInsetRect(self.view.bounds, self.view.safeAreaInsets);
    _menuButton.frame = CGRectMake(CGRectGetMidX(safe)-22, CGRectGetMaxY(safe)-48, 44, 44);
    CGRect screen = _surface.screenFrame;
    _resumeButton.frame = CGRectMake(CGRectGetMidX(screen)-90, CGRectGetMidY(screen)-25, 180, 50);
}
- (void)updateKeys {
    uint32_t keys = MGBACancelOpposingDirections(_touchKeys | _controllerKeys);
    [_surface setKeys:keys];
    if (_gameNeedsKeyRelease && !keys) _gameNeedsKeyRelease = NO;
    _engine.keys = _showingLauncher || _working || _gameNeedsKeyRelease ? 0 : keys;
}
- (void)reloadLauncherGames {
    NSURL *selectedURL = _launcher.selected < _games.count ? _games[_launcher.selected].romURL : nil;
    _games = [_library games];
    MGBALauncherSetGameCount(&_launcher, _games.count);
    if (selectedURL) {
        NSUInteger index = [_games indexOfObjectPassingTest:^BOOL(MGBAGame *game, NSUInteger idx, BOOL *stop) { return [game.romURL isEqual:selectedURL]; }];
        if (index != NSNotFound) MGBALauncherSelect(&_launcher, index);
    }
}
- (void)showLauncher {
    _showingLauncher = YES;
    _loaded = NO;
    _working = NO;
    _game = nil;
    _launcherStatus = nil;
    _resumeButton.hidden = YES;
    _menuButton.enabled = YES;
    [_menuButton setImage:[UIImage systemImageNamed:@"ellipsis.circle"] forState:UIControlStateNormal];
    _menuButton.accessibilityLabel = @"Options du lanceur";
    [self reloadLauncherGames];
    [self resetLauncherInput];
    [self renderLauncher];
    [self startLauncherClock];
}
- (void)resetLauncherInput {
    [_controls releaseAll];
    [self pollControllers];
    MGBALauncherReleaseBeforeInput(&_launcher);
}
- (void)startLauncherClock {
    if (_launcherClock || !_showingLauncher || _working || UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    _launcherClock = [CADisplayLink displayLinkWithTarget:self selector:@selector(launcherTick:)];
    _launcherClock.preferredFramesPerSecond = 30;
    [_launcherClock addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}
- (void)stopLauncherClock { [_launcherClock invalidate]; _launcherClock = nil; }
- (void)launcherTick:(CADisplayLink *)link {
    if (!_showingLauncher || _working || self.presentedViewController || _errorShown) return;
    MGBALauncherAction action = MGBALauncherUpdate(&_launcher, _touchKeys | _controllerKeys, link.timestamp);
    if (action == MGBALauncherSelectionChanged) {
        _launcherStatus = nil;
        [self renderLauncher];
    } else [self handleLauncherAction:action];
}
- (void)handleLauncherAction:(MGBALauncherAction)action {
    if (!_showingLauncher || _working || self.presentedViewController || _errorShown) return;
    if (action == MGBALauncherImport) [self chooseROMs];
    if (action == MGBALauncherOpenGame && _launcher.selected < _games.count) [self launchGame:_games[_launcher.selected]];
}
- (void)renderLauncher {
    // Render to the exact same RGBX display path as game frames. The iOS shell
    // manages files; no UI library browser is overlaid on the console screen.
    MGBALauncherItem *items = calloc(MAX((NSUInteger)1, _games.count), sizeof(*items));
    if (!items) return;
    NSMutableArray<NSString *> *labels = [NSMutableArray arrayWithCapacity:_games.count];
    for (MGBAGame *game in _games) [labels addObject:[[game.title stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]] uppercaseString]];
    for (NSUInteger i = 0; i < _games.count; ++i) {
        MGBAGame *game = _games[i];
        items[i].title = labels[i].UTF8String;
        items[i].system = [game.romURL.pathExtension isEqual:@"gba"] ? "GBA" : [game.romURL.pathExtension isEqual:@"gbc"] ? "GBC" : "GB";
        items[i].canResume = [NSFileManager.defaultManager fileExistsAtPath:[game.directory URLByAppendingPathComponent:@"resume.ss0"].path];
    }
    NSMutableData *frame = [NSMutableData dataWithLength:240*160*4];
    NSString *status = [_launcherStatus stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    MGBALauncherRender(&_launcher, items, status.UTF8String, _working, frame.mutableBytes);
    free(items);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)frame);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGImageRef image = CGImageCreate(240,160,8,32,240*4,space,kCGBitmapByteOrder32Big | kCGImageAlphaNoneSkipLast,provider,NULL,NO,kCGRenderingIntentDefault);
    _screen.image = [UIImage imageWithCGImage:image];
    CGImageRelease(image);
    CGColorSpaceRelease(space);
    CGDataProviderRelease(provider);
    _screen.isAccessibilityElement = YES;
    _screen.accessibilityTraits = _working ? UIAccessibilityTraitUpdatesFrequently : UIAccessibilityTraitAdjustable | UIAccessibilityTraitButton;
    _screen.accessibilityLabel = @"Bibliothèque de jeux";
    NSString *selection = _launcher.selected < _games.count ? _games[_launcher.selected].title : @"Importer des ROMs";
    _screen.accessibilityValue = _working ? @"Chargement en cours" : [NSString stringWithFormat:@"%@, %lu sur %lu", selection, (unsigned long)_launcher.selected+1, (unsigned long)_games.count+1];
    _screen.accessibilityHint = @"Balayez vers le haut ou le bas pour choisir. Touchez deux fois pour ouvrir.";
}
- (void)screenTapped:(UITapGestureRecognizer *)recognizer {
    if (!_showingLauncher || _working || self.presentedViewController || _errorShown) return;
    CGSize size = _screen.bounds.size;
    CGFloat scale = MIN(size.width/240.0, size.height/160.0);
    if (scale <= 0) return;
    CGPoint p = [recognizer locationInView:_screen];
    CGFloat x = (p.x-(size.width-240*scale)/2)/scale;
    CGFloat y = (p.y-(size.height-160*scale)/2)/scale;
    size_t index = MGBALauncherHitRow(&_launcher, (int)floor(x), (int)floor(y));
    if (index == SIZE_MAX) return;
    MGBALauncherSelect(&_launcher,index);
    [self renderLauncher];
    [self handleLauncherAction:MGBALauncherConfirm(&_launcher)];
}
- (void)launchGame:(MGBAGame *)game {
    if (_working) return;
    [self stopLauncherClock];
    _working = YES;
    _showingLauncher = NO;
    _loaded = NO;
    _game = game;
    _launcherStatus = game.title;
    _menuButton.enabled = NO;
    _gameNeedsKeyRelease = YES;
    [self updateKeys];
    [self renderLauncher];
    __weak typeof(self) weakSelf = self;
    [_engine loadROM:game.romURL directory:game.directory completion:^(NSError *error) {
        MGBAPlayerViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf->_working = NO;
        strongSelf->_menuButton.enabled = YES;
        if (error) { [strongSelf showError:error]; return; }
        strongSelf->_loaded = YES;
        strongSelf->_screen.isAccessibilityElement = NO;
        [strongSelf->_menuButton setImage:[UIImage systemImageNamed:@"pause.circle.fill"] forState:UIControlStateNormal];
        strongSelf->_menuButton.accessibilityLabel = @"Pause et options";
        [strongSelf resumeGame];
    }];
}
- (void)becameActive:(NSNotification *)note {
    if (_showingLauncher && !_working) {
        [self reloadLauncherGames];
        [self resetLauncherInput];
        [self renderLauncher];
        [self startLauncherClock];
    }
}
- (void)chooseROMs {
    if (_working) return;
    [self stopLauncherClock];
    [self resetLauncherInput];
    _pickerPurpose = 1;
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeData] asCopy:YES];
    picker.allowsMultipleSelection = YES;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)importROMURLs:(NSArray<NSURL *> *)urls {
    if (_working || !urls.count) { [self startLauncherClock]; return; }
    _working = YES;
    _menuButton.enabled = NO;
    _launcherStatus = @"IMPORTATION DES JEUX";
    [self renderLauncher];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray<NSString *> *errors = [NSMutableArray array];
        NSURL *firstImported = nil;
        for (NSURL *url in urls) {
            NSError *error = nil;
            MGBAGame *game = [self->_library importROM:url error:&error];
            if (game) { if (!firstImported) firstImported = game.romURL; }
            else [errors addObject:[NSString stringWithFormat:@"%@ : %@", url.lastPathComponent, error.localizedDescription ?: @"Import impossible"]];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_working = NO;
            self->_menuButton.enabled = YES;
            [self reloadLauncherGames];
            if (firstImported) {
                NSUInteger index = [self->_games indexOfObjectPassingTest:^BOOL(MGBAGame *game, NSUInteger idx, BOOL *stop) { return [game.romURL isEqual:firstImported]; }];
                if (index != NSNotFound) MGBALauncherSelect(&self->_launcher,index);
            }
            self->_launcherStatus = @"JEUX CONSERVES SUR CET APPAREIL";
            [self resetLauncherInput];
            [self renderLauncher];
            [self startLauncherClock];
            if (errors.count) [self showError:[NSError errorWithDomain:@"mGBA.iOS" code:10 userInfo:@{NSLocalizedDescriptionKey:[errors componentsJoinedByString:@"\n\n"]}]];
        });
    });
}
- (void)showLauncherOptions {
    [self resetLauncherInput];
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"AdvanceiOS" message:@"Croix : choisir · A : jouer · Select : importer" preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:@"Importer des ROMs…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [self chooseROMs]; }]];
    BOOL haptics = [NSUserDefaults.standardUserDefaults objectForKey:@"haptics"] == nil || [NSUserDefaults.standardUserDefaults boolForKey:@"haptics"];
    [menu addAction:[UIAlertAction actionWithTitle:haptics ? @"Désactiver les vibrations" : @"Activer les vibrations" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [NSUserDefaults.standardUserDefaults setBool:!haptics forKey:@"haptics"]; [self resetLauncherInput];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"À propos et licences" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [self showAbout]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Fermer" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a) { [self resetLauncherInput]; }]];
    [self anchorSheet:menu];
}
- (void)showAbout {
    UIViewController *content = [UIViewController new];
    content.title = @"AdvanceiOS";
    UITextView *text = [UITextView new];
    text.editable = NO;
    text.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    text.adjustsFontForContentSizeCategory = YES;
    text.textContainerInset = UIEdgeInsetsMake(20,20,30,20);
    NSString *licenses = [NSString stringWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"Licenses" withExtension:@"txt"] encoding:NSUTF8StringEncoding error:nil];
    text.text = [@"AdvanceiOS — port indépendant\n\nFaçade Indigo en SwiftUI. Moteur mGBA 0.10.5 par Jeffrey Pfau et les contributeurs.\n\nROMs et sauvegardes conservées sur l’appareil. Aucun jeu commercial inclus.\n\nSources : https://github.com/garwiglino/AdvanceiOS\n\n" stringByAppendingString:licenses ?: @""];
    content.view = text;
    content.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(closeAbout)];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:content];
    navigation.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:navigation animated:YES completion:nil];
}
- (void)closeAbout {
    [self dismissViewControllerAnimated:YES completion:^{ [self resetLauncherInput]; [self startLauncherClock]; }];
}
- (void)pollControllers {
    uint32_t keys = 0;
    for (GCController *controller in GCController.controllers) {
        GCExtendedGamepad *pad = controller.extendedGamepad;
        if (!pad) continue;
        if (pad.buttonA.pressed) keys |= MGBAKeyA;
        if (pad.buttonB.pressed) keys |= MGBAKeyB;
        if (pad.leftShoulder.pressed) keys |= MGBAKeyL;
        if (pad.rightShoulder.pressed) keys |= MGBAKeyR;
        if (pad.buttonMenu.pressed) keys |= MGBAKeyStart;
        if (pad.buttonOptions.pressed || pad.buttonX.pressed) keys |= MGBAKeySelect;
        if (pad.dpad.left.pressed || pad.leftThumbstick.xAxis.value < -0.4) keys |= MGBAKeyLeft;
        if (pad.dpad.right.pressed || pad.leftThumbstick.xAxis.value > 0.4) keys |= MGBAKeyRight;
        if (pad.dpad.up.pressed || pad.leftThumbstick.yAxis.value > 0.4) keys |= MGBAKeyUp;
        if (pad.dpad.down.pressed || pad.leftThumbstick.yAxis.value < -0.4) keys |= MGBAKeyDown;
    }
    _controllerKeys = keys;
    [self updateKeys];
}
- (void)connectControllers:(NSNotification *)note {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self connectControllers:note]; });
        return;
    }
    __weak typeof(self) weakSelf = self;
    for (GCController *controller in GCController.controllers) {
        controller.handlerQueue = dispatch_get_main_queue();
        controller.extendedGamepad.valueChangedHandler = ^(GCExtendedGamepad *pad, GCControllerElement *element) { [weakSelf pollControllers]; };
    }
    [self pollControllers];
}
- (void)audioInterrupted:(NSNotification *)note {
    if ([note.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue] == AVAudioSessionInterruptionTypeBegan) [self interrupted:note];
}
- (void)interrupted:(NSNotification *)note {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self interrupted:note]; });
        return;
    }
    // setCategory during initial audio setup also posts a route notification.
    if ([note.name isEqualToString:AVAudioSessionRouteChangeNotification]) {
        NSUInteger reason = [note.userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
        if (reason == AVAudioSessionRouteChangeReasonUnknown || reason == AVAudioSessionRouteChangeReasonCategoryChange || reason == AVAudioSessionRouteChangeReasonOverride) return;
    }
    [self stopLauncherClock];
    [_controls releaseAll];
    _controllerKeys = 0;
    [self updateKeys];
    MGBALauncherReleaseBeforeInput(&_launcher);
    if (!_engine.running) return;
    NSError *error = [_engine pauseAndSave];
    [_controls releaseAll];
    _controllerKeys = 0;
    _resumeButton.hidden = NO;
    if (error) [self showError:error];
}
- (void)resumeGame {
    if (!_loaded || UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
        _resumeButton.hidden = !_loaded;
        return;
    }
    NSError *error = nil;
    if ([_engine resume:&error]) { _resumeButton.hidden = YES; [self pollControllers]; }
    else [self showError:error];
}
- (void)showError:(NSError *)error {
    if (_errorShown || !error) return;
    _errorShown = YES;
    if (_engine.running) [_engine pauseAndSave];
    _resumeButton.hidden = !_loaded;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"mGBA" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self->_errorShown = NO;
        if (!self->_loaded && !self->_showingLauncher) [self leaveGame];
        else if (self->_showingLauncher) { [self resetLauncherInput]; [self startLauncherClock]; }
    }]];
    if (self.presentedViewController) {
        [self dismissViewControllerAnimated:NO completion:^{ [self presentViewController:alert animated:YES completion:nil]; }];
    } else [self presentViewController:alert animated:YES completion:nil];
}
- (void)anchorSheet:(UIAlertController *)sheet {
    sheet.popoverPresentationController.sourceView = _menuButton;
    sheet.popoverPresentationController.sourceRect = _menuButton.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}
- (void)showMenu {
    if (_working || self.presentedViewController) return;
    if (_showingLauncher) { [self showLauncherOptions]; return; }
    NSError *error = [_engine pauseAndSave];
    [_controls releaseAll];
    _controllerKeys = 0;
    _resumeButton.hidden = NO;
    if (error) { [self showError:error]; return; }
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:_game.title message:@"Jeu en pause · sauvegarde automatique effectuée" preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:@"Reprendre" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a) { [self resumeGame]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Sauvegarder un état…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [self chooseSlotSaving:YES]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Charger un état…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [self chooseSlotSaving:NO]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:_engine.fastForward ? @"Vitesse normale (son actif)" : @"Vitesse ×2 (son coupé)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { self->_engine.fastForward = !self->_engine.fastForward; [self resumeGame]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Exporter la sauvegarde .sav" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [self exportBattery]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Importer une sauvegarde .sav…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [self confirmImportBattery]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Redémarrer le jeu…" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) { [self confirmReset]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Retour au lanceur" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [self leaveGame]; }]];
    [self anchorSheet:menu];
}
- (void)chooseSlotSaving:(BOOL)saving {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:saving ? @"Sauvegarder un état" : @"Charger un état" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSInteger slot = 1; slot <= 5; ++slot) {
        NSURL *url = [_game.directory URLByAppendingPathComponent:[NSString stringWithFormat:@"slot-%ld.ss0", (long)slot]];
        BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:url.path];
        NSString *title = [NSString stringWithFormat:@"Emplacement %ld%@", (long)slot, exists ? @" · enregistré" : @" · vide"];
        UIAlertAction *action = [UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            void (^perform)(void) = ^{
                void (^done)(NSError *) = ^(NSError *error) { if (error) [self showError:error]; else [self resumeGame]; };
                if (saving) [self->_engine saveSlot:slot completion:done];
                else [self->_engine loadSlot:slot completion:done];
            };
            if (saving && exists) {
                UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Remplacer cet état ?" message:@"L’ancien état de cet emplacement sera remplacé." preferredStyle:UIAlertControllerStyleAlert];
                [confirm addAction:[UIAlertAction actionWithTitle:@"Annuler" style:UIAlertActionStyleCancel handler:nil]];
                [confirm addAction:[UIAlertAction actionWithTitle:@"Remplacer" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) { perform(); }]];
                [self presentViewController:confirm animated:YES completion:nil];
            } else perform();
        }];
        action.enabled = saving || exists;
        [sheet addAction:action];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Annuler" style:UIAlertActionStyleCancel handler:nil]];
    [self anchorSheet:sheet];
}
- (void)exportBattery {
    NSURL *url = [_game.directory URLByAppendingPathComponent:@"battery.sav"];
    if (![NSFileManager.defaultManager fileExistsAtPath:url.path]) {
        [self showError:[NSError errorWithDomain:@"mGBA.iOS" code:5 userInfo:@{NSLocalizedDescriptionKey:@"Ce jeu n’a pas encore créé de sauvegarde. Sauvegardez d’abord depuis le menu du jeu."}]];
        return;
    }
    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    share.popoverPresentationController.sourceView = _menuButton;
    share.popoverPresentationController.sourceRect = _menuButton.bounds;
    [self presentViewController:share animated:YES completion:nil];
}
- (void)confirmImportBattery {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Importer une sauvegarde" message:@"Le jeu redémarrera avec le fichier choisi. La sauvegarde précédente sera conservée dans battery-backup.sav." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Annuler" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Choisir un fichier" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeData] asCopy:YES];
        picker.delegate = self;
        self->_pickerPurpose = 2;
        [self presentViewController:picker animated:YES completion:nil];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSInteger purpose = _pickerPurpose;
    _pickerPurpose = 0;
    [controller dismissViewControllerAnimated:YES completion:^{
        if (purpose == 1) [self importROMURLs:urls];
        else if (purpose == 2 && urls.count) [self importBatteryURL:urls.firstObject];
    }];
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    _pickerPurpose = 0;
    [controller dismissViewControllerAnimated:YES completion:^{ [self resetLauncherInput]; [self startLauncherClock]; }];
}
- (void)importBatteryURL:(NSURL *)url {
    BOOL scoped = [url startAccessingSecurityScopedResource];
    NSError *error = nil;
    NSNumber *size = nil;
    [url getResourceValue:&size forKey:NSURLFileSizeKey error:&error];
    NSData *data = nil;
    if (!error && [url.pathExtension.lowercaseString isEqual:@"sav"] && size.unsignedIntegerValue > 0 && size.unsignedIntegerValue <= 1024 * 1024)
        data = [NSData dataWithContentsOfURL:url options:0 error:&error];
    if (scoped) [url stopAccessingSecurityScopedResource];
    if (!data || error) {
        [self showError:error ?: [NSError errorWithDomain:@"mGBA.iOS" code:6 userInfo:@{NSLocalizedDescriptionKey:@"Choisissez une sauvegarde .sav valide de moins de 1 Mo."}]];
        return;
    }
    // Validate against a fresh session before touching existing user data.
    NSData *rom = [NSData dataWithContentsOfURL:_game.romURL options:0 error:&error];
    MGBASession *probe = rom ? MGBACreate(rom.bytes, rom.length, data.bytes, data.length) : NULL;
    if (!probe) {
        [self showError:error ?: [NSError errorWithDomain:@"mGBA.iOS" code:7 userInfo:@{NSLocalizedDescriptionKey:@"Cette sauvegarde n’est pas compatible."}]];
        return;
    }
    MGBADestroy(probe);
    [_engine close];
    _loaded = NO;
    NSURL *battery = [_game.directory URLByAppendingPathComponent:@"battery.sav"];
    NSData *previous = [NSData dataWithContentsOfURL:battery];
    if (previous && ![previous writeToURL:[_game.directory URLByAppendingPathComponent:@"battery-backup.sav"] options:NSDataWritingAtomic error:&error]) { [self showError:error]; return; }
    if (![data writeToURL:battery options:NSDataWritingAtomic error:&error]) { [self showError:error]; return; }
    NSURL *resume = [_game.directory URLByAppendingPathComponent:@"resume.ss0"];
    if ([NSFileManager.defaultManager fileExistsAtPath:resume.path] && ![NSFileManager.defaultManager removeItemAtURL:resume error:&error]) { [self showError:error]; return; }
    _loaded = NO;
    [_engine loadROM:_game.romURL directory:_game.directory completion:^(NSError *loadError) {
        if (loadError) [self showError:loadError];
        else { self->_loaded = YES; [self resumeGame]; }
    }];
}
- (void)confirmReset {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Redémarrer le jeu ?" message:@"La sauvegarde du jeu sera conservée." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Annuler" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Redémarrer" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) { [self->_engine reset]; [self resumeGame]; }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)leaveGame {
    NSError *error = [_engine pauseAndSave];
    if (error) { [self showError:error]; return; }
    [_engine close];
    _engine.fastForward = NO;
    [self showLauncher];
}
- (void)dealloc {
    [_launcherClock invalidate];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}
@end
