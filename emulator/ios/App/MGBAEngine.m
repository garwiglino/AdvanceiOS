// SPDX-License-Identifier: MPL-2.0
#import "MGBAEngine.h"
#import "AudioRing.h"
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

static NSError *EngineError(NSString *message) {
    return [NSError errorWithDomain:@"mGBA.iOS" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];
}

@implementation MGBAEngine {
    dispatch_queue_t _queue;
    MGBASession *_session;
    MGBAAudioRing *_ring;
    AVAudioEngine *_audio;
    AVAudioSourceNode *_source;
    CADisplayLink *_displayLink;
    NSURL *_directory;
    NSData *_lastBattery;
    BOOL _busy;
    double _lastTime, _accumulator, _batteryTime;
}
- (instancetype)init {
    if ((self = [super init])) {
        _queue = dispatch_queue_create("org.mgba.ios.emulation", DISPATCH_QUEUE_SERIAL);
        _ring = calloc(1, sizeof(*_ring));
        MGBAAudioInit(_ring);
    }
    return self;
}
- (void)dealloc {
    [_displayLink invalidate];
    [_audio stop];
    if (_source) [_audio detachNode:_source];
    MGBADestroy(_session);
    free(_ring);
}
- (void)loadROM:(NSURL *)rom directory:(NSURL *)directory completion:(void (^)(NSError *))completion {
    [self close];
    _directory = directory;
    dispatch_async(_queue, ^{
        NSError *error = nil;
        NSData *data = [NSData dataWithContentsOfURL:rom options:0 error:&error];
        NSURL *batteryURL = [directory URLByAppendingPathComponent:@"battery.sav"];
        NSData *battery = nil;
        if ([[NSFileManager defaultManager] fileExistsAtPath:batteryURL.path])
            battery = [NSData dataWithContentsOfURL:batteryURL options:0 error:&error];
        if (!error) self->_session = MGBACreate(data.bytes, data.length, battery.bytes, battery.length);
        if (!error && !self->_session) error = EngineError(@"Le fichier n’est pas une ROM GBA, GB ou GBC valide, ou sa sauvegarde est incompatible.");
        if (self->_session) {
            self->_lastBattery = battery;
            NSURL *resumeURL = [directory URLByAppendingPathComponent:@"resume.ss0"];
            if ([[NSFileManager defaultManager] fileExistsAtPath:resumeURL.path]) {
                NSData *state = [NSData dataWithContentsOfURL:resumeURL options:0 error:&error];
                if (!error && !MGBALoadState(self->_session, state.bytes, state.length))
                    error = EngineError(@"L’état de reprise est illisible. Déplacez resume.ss0 depuis Fichiers pour repartir de la sauvegarde du jeu.");
            }
        }
        if (error) { MGBADestroy(self->_session); self->_session = NULL; }
        dispatch_async(dispatch_get_main_queue(), ^{ completion(error); });
    });
}
- (BOOL)prepareAudio:(NSError **)error {
    AVAudioSession *audioSession = AVAudioSession.sharedInstance;
    if (![audioSession setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeDefault options:0 error:error]) return NO;
    if (![audioSession setPreferredSampleRate:48000 error:error]) return NO;
    if (![audioSession setPreferredIOBufferDuration:0.01 error:error]) return NO;
    if (![audioSession setActive:YES error:error]) return NO;
    // Rebuild after an interruption or a route change so the hardware format
    // is renegotiated. The source remains planar float stereo at 48 kHz.
    [_audio stop];
    if (_source) [_audio detachNode:_source];
    _audio = [[AVAudioEngine alloc] init];
    AVAudioFormat *format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:48000 channels:2];
    MGBAAudioRing *ring = _ring;
    _source = [[AVAudioSourceNode alloc] initWithFormat:format renderBlock:^OSStatus(BOOL *silent, const AudioTimeStamp *timestamp, AVAudioFrameCount count, AudioBufferList *output) {
        (void)timestamp;
        if (output->mNumberBuffers != 2) {
            for (UInt32 i = 0; i < output->mNumberBuffers; ++i)
                memset(output->mBuffers[i].mData, 0, output->mBuffers[i].mDataByteSize);
            *silent = YES;
            return noErr;
        }
        MGBAAudioRead(ring, output->mBuffers[0].mData, output->mBuffers[1].mData, count);
        *silent = NO;
        return noErr;
    }];
    [_audio attachNode:_source];
    [_audio connect:_source to:_audio.mainMixerNode format:format];
    [_audio prepare];
    return [_audio startAndReturnError:error];
}
- (BOOL)resume:(NSError **)error {
    if (_running) return YES;
    if (!_session) { if (error) *error = EngineError(@"Aucun jeu chargé."); return NO; }
    MGBAAudioReset(_ring);
    if (![self prepareAudio:error]) {
        [_audio stop];
        [AVAudioSession.sharedInstance setActive:NO error:nil];
        return NO;
    }
    _running = YES;
    _lastTime = 0;
    _accumulator = 0;
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    _displayLink.preferredFrameRateRange = CAFrameRateRangeMake(30, 120, 60);
    [_displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    UIApplication.sharedApplication.idleTimerDisabled = YES;
    return YES;
}
- (NSError *)persistBattery {
    if (!_session) return nil;
    void *bytes = NULL;
    size_t length = 0;
    if (!MGBACopyBattery(_session, &bytes, &length)) return EngineError(@"Impossible de lire la sauvegarde du jeu.");
    NSData *data = length ? [NSData dataWithBytes:bytes length:length] : nil;
    MGBAFree(bytes);
    NSError *error = nil;
    if (data && ![data isEqualToData:_lastBattery]) {
        if ([data writeToURL:[_directory URLByAppendingPathComponent:@"battery.sav"] options:NSDataWritingAtomic error:&error]) _lastBattery = data;
    }
    return error;
}
- (NSError *)persistState:(NSString *)name {
    if (!_session) return nil;
    void *bytes = NULL;
    size_t length = 0;
    if (!MGBACopyState(_session, &bytes, &length)) return EngineError(@"Impossible de créer l’état de sauvegarde.");
    NSData *data = [NSData dataWithBytes:bytes length:length];
    MGBAFree(bytes);
    NSError *error = nil;
    [data writeToURL:[_directory URLByAppendingPathComponent:name] options:NSDataWritingAtomic error:&error];
    return error;
}
- (NSError *)pauseAndSave {
    _running = NO;
    self.keys = 0;
    [_displayLink invalidate];
    _displayLink = nil;
    [_audio stop];
    __block NSError *error = nil;
    dispatch_sync(_queue, ^{
        error = [self persistBattery];
        NSError *stateError = [self persistState:@"resume.ss0"];
        if (!error) error = stateError;
    });
    MGBAAudioReset(_ring);
    [AVAudioSession.sharedInstance setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    UIApplication.sharedApplication.idleTimerDisabled = NO;
    return error;
}
- (void)close {
    NSError *error = [self pauseAndSave];
    if (error && self.onError) self.onError(error);
    dispatch_sync(_queue, ^{ MGBADestroy(self->_session); self->_session = NULL; });
    _lastBattery = nil;
}
- (void)tick:(CADisplayLink *)link {
    if (_busy || !_running) return;
    _busy = YES;
    double now = link.timestamp;
    double elapsed = _lastTime ? fmin(now - _lastTime, 0.1) : 0;
    _lastTime = now;
    uint32_t keys = self.keys;
    BOOL fast = self.fastForward;
    dispatch_async(_queue, ^{
        @autoreleasepool {
            self->_accumulator += elapsed * (fast ? 2 : 1);
            double frameDuration = MGBAFrameDuration(self->_session);
            int count = 0;
            while (self->_accumulator >= frameDuration && count++ < 8) {
                MGBARunFrame(self->_session, keys);
                int16_t samples[4096 * 2];
                size_t n = MGBAReadAudio(self->_session, samples, 4096);
                if (!fast) MGBAAudioWrite(self->_ring, samples, n);
                self->_accumulator -= frameDuration;
            }
            self->_batteryTime += elapsed;
            NSError *error = nil;
            if (self->_batteryTime >= 5) {
                self->_batteryTime = 0;
                error = [self persistBattery];
            }
            unsigned width = MGBAWidth(self->_session), height = MGBAHeight(self->_session);
            NSData *pixels = [NSData dataWithBytes:MGBAPixels(self->_session) length:width * height * 4];
            CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)pixels);
            CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
            // mGBA stores 0x00BBGGRR on little endian CPUs: R,G,B,unused bytes.
            CGImageRef cg = CGImageCreate(width, height, 8, 32, width * 4, space, kCGBitmapByteOrder32Big | kCGImageAlphaNoneSkipLast, provider, NULL, NO, kCGRenderingIntentDefault);
            UIImage *image = [UIImage imageWithCGImage:cg];
            CGImageRelease(cg);
            CGColorSpaceRelease(space);
            CGDataProviderRelease(provider);
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_busy = NO;
                if (self.running && self.onFrame) self.onFrame(image);
                if (error && self.onError) self.onError(error);
            });
        }
    });
}
- (void)saveSlot:(NSInteger)slot completion:(void (^)(NSError *))completion {
    dispatch_async(_queue, ^{
        NSError *error = [self persistState:[NSString stringWithFormat:@"slot-%ld.ss0", (long)slot]];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(error); });
    });
}
- (void)loadSlot:(NSInteger)slot completion:(void (^)(NSError *))completion {
    dispatch_async(_queue, ^{
        NSError *error = nil;
        NSURL *url = [self->_directory URLByAppendingPathComponent:[NSString stringWithFormat:@"slot-%ld.ss0", (long)slot]];
        NSData *data = [NSData dataWithContentsOfURL:url options:0 error:&error];
        if (!error && !MGBALoadState(self->_session, data.bytes, data.length)) error = EngineError(@"État invalide ou incompatible avec ce jeu.");
        dispatch_async(dispatch_get_main_queue(), ^{ completion(error); });
    });
}
- (void)reset {
    dispatch_sync(_queue, ^{ if (self->_session) MGBAReset(self->_session); });
}
@end
