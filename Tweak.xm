@import UIKit;
#import <spawn.h>
#import <rootless.h>

@interface NSUserDefaults (FakePowerOff)
-(id)objectForKey:(NSString *)key inDomain:(NSString *)domain;
-(void)setObject:(id)value forKey:(NSString *)key inDomain:(NSString *)domain;
@end

@interface UIWindow ()
-(void)_setSecure:(BOOL)arg1;
@end

@interface SBUserAgent
-(void)lockAndDimDevice;
-(void)undimScreen;
@end

@interface SpringBoard : UIApplication
-(SBUserAgent*)pluginUserAgent;
-(void)_simulateLockButtonPress;
@end

@interface SBPowerDownViewController : UIViewController
-(void)powerDownViewRequestPowerDown:(id)arg1;
@end

@interface SBUIPowerDownView : UIView
-(BOOL)isFocused;
-(void)focusedViewDidChange;
@end

@interface SBSOSLockGestureObserver
-(void)pressSequenceRecognizerDidCompleteSequence:(id)arg1;
@end

@interface SBSOSClawGestureObserver
-(void)_presentSOSInterface;
@end

@interface SBLiftToWakeController
-(void)_screenTurnedOff;
@end

@interface SBTapToWakeController
-(void)tapToWakeDidRecognize:(id)arg1;
-(void)pencilToWakeDidRecognize:(id)arg1;
@end

@interface SBLockHardwareButton : NSObject
-(void)forceResetSequenceDidBegin;
-(void)buttonDown:(id)arg1;
-(void)singlePress:(id)arg1;
-(void)doublePress:(id)arg1;
-(void)triplePress:(id)arg1;
-(void)quadruplePress:(id)arg1;
-(void)longPress:(id)arg1;
-(BOOL)isButtonDown;
@end

@interface SBHomeHardwareButton : NSObject
-(void)initialButtonDown:(id)arg1;
-(void)initialButtonUp:(id)arg1;
-(void)singlePressUp:(id)arg1;
-(void)longPress;
-(BOOL)isButtonDown;
@end

typedef NS_ENUM(NSUInteger, FakeStates) {
    FakeSNormal,
    FakeSOff,
    FakeSReboot,
    FakeSTryOn,
    FakeSBooting,
};

typedef NS_ENUM(NSUInteger, FakeOns) {
    FOnNone,
    FOnRespringSBReload,
    FOnRespringKillall,
    FOnBlackBoot,
    FOnWhiteBoot,
};

NSDictionary *FakeOnsMap = @{
    @"None" : @(FOnNone),
    @"RespringSBReload" : @(FOnRespringSBReload),
    @"RespringKillall" : @(FOnRespringKillall),
    @"BlackBoot" : @(FOnBlackBoot),
    @"WhiteBoot" : @(FOnWhiteBoot),
};

static NSString *nsEnabledString = @"moe.saru.homebrew.ios.fakepoweroff.enabled";
static NSString *nsReenableString = @"moe.saru.homebrew.ios.fakepoweroff.reenable";
static NSString *nsNukeSOSString = @"moe.saru.homebrew.ios.fakepoweroff.nukesos";
static NSString *nsFakeOnString = @"moe.saru.homebrew.ios.fakepoweroff.fakeon";
static NSString *nsHomeBootString = @"moe.saru.homebrew.ios.fakepoweroff.homeboot";
static NSString *nsLockedString = @"moe.saru.homebrew.ios.fakepoweroff.locked";
static NSString *nsNotificationString = @"moe.saru.homebrew.ios.fakepoweroff.prefchanged";

static BOOL Enabled;
static BOOL NukeSOS;
static FakeOns FakeOn;
static BOOL HomeBoot;
static BOOL Locked;

static FakeStates FakeState = FakeSNormal;
static BOOL InPowerOffView = NO;

static void notificationCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    NSNumber *v1 = (NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"Enabled" inDomain:nsEnabledString];
    Enabled = v1 ? [v1 boolValue] : YES;
    NSNumber *v2 = (NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"Enabled" inDomain:nsNukeSOSString];
    NukeSOS = v2 ? [v2 boolValue] : YES;
    NSString *v3 = (NSString *)[[NSUserDefaults standardUserDefaults] objectForKey:@"Value" inDomain:nsFakeOnString];
    FakeOn = v3 ? [[FakeOnsMap objectForKey:v3] integerValue] : FOnRespringKillall;
    NSNumber *v4 = (NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"Enabled" inDomain:nsHomeBootString];
    HomeBoot = v4 ? [v4 boolValue] : NO;
    NSNumber *v5 = (NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"Enabled" inDomain:nsLockedString];
    Locked = v5 ? [v5 boolValue] : NO;

    if (!Enabled) {
        FakeState = FakeSNormal;
    }
}

static void respring_sbreload() {
    pid_t pid;
    const char *args[] = { ROOT_PATH("/usr/bin/sbreload"), NULL };
    posix_spawn(&pid, args[0], NULL, NULL, (char *const *)args, NULL);
    waitpid(pid, NULL, 0);
}

static void respring_killall() {
    pid_t pid;
    const char *args[] = { ROOT_PATH("/usr/bin/killall"), "SpringBoard", NULL };
    posix_spawn(&pid, args[0], NULL, NULL, (char *const *)args, NULL);
    waitpid(pid, NULL, 0);
}

static void fakePoweredOn() {
    if (FakeState == FakeSNormal) return;

    FakeState = FakeSNormal;
}

static void fakePowerOn() {
    if (FakeState == FakeSBooting) return;

    FakeState = FakeSBooting;

    switch (FakeOn) {
        case FOnNone:
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [[(SpringBoard*)[%c(SpringBoard) sharedApplication] pluginUserAgent] undimScreen];
                fakePoweredOn();
            });
            break;
        case FOnRespringSBReload:
        case FOnRespringKillall:
            if (FakeOn == FOnRespringSBReload) {
                respring_sbreload();
            } else {
                respring_killall();
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [[(SpringBoard*)[%c(SpringBoard) sharedApplication] pluginUserAgent] undimScreen];
                fakePoweredOn();
            });
            break;
        case FOnBlackBoot:
        case FOnWhiteBoot:
            // TODO: implement proper boot screen
            CGRect bounds = [[UIScreen mainScreen] bounds];
            UIWindow* window = [[UIWindow alloc] initWithFrame:bounds];
            window.windowLevel = 10000;
            [window setHidden:NO];
            [window _setSecure:YES];
            [window setAlpha:1.0];
            [window makeKeyAndVisible];

            UIView *view = [[UIView alloc] initWithFrame:bounds];
            view.backgroundColor = [UIColor systemGrayColor];
            [window addSubview:view];

            [[(SpringBoard*)[%c(SpringBoard) sharedApplication] pluginUserAgent] undimScreen];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [window setHidden:YES];
                fakePoweredOn();
            });
    }
}

static void fakePowerOff() {
    if (FakeState == FakeSOff) return;

    FakeState = FakeSOff;

    [[(SpringBoard*)[%c(SpringBoard) sharedApplication] pluginUserAgent] lockAndDimDevice];
}

%hook SBPowerDownViewController

-(void)powerDownViewRequestPowerDown:(id)arg1 {
    if (Enabled) {
        fakePowerOff();
    } else {
        %orig;
    }
}

%end

%hook SBUIPowerDownView

-(void)focusedViewDidChange {
    InPowerOffView = [self isFocused];
    %orig;
}

%end

%hook SBSOSLockGestureObserver

-(void)pressSequenceRecognizerDidCompleteSequence:(id)arg1 {
    if (!NukeSOS && FakeState == FakeSNormal) {
        %orig;
    }
}

%end

%hook SBSOSClawGestureObserver

-(void)_presentSOSInterface {
    if (!NukeSOS && FakeState == FakeSNormal) {
        %orig;
    }
}

%end

%hook SBLiftToWakeController
-(void)_screenTurnedOff {
    if (FakeState == FakeSNormal) {
        %orig;
    }
}
%end

// TODO: need someone to test this
%hook SBTapToWakeController

-(void)tapToWakeDidRecognize:(id)arg1 {
    if (FakeState == FakeSNormal) {
        %orig;
    }
}

-(void)pencilToWakeDidRecognize:(id)arg1 {
    if (FakeState == FakeSNormal) {
        %orig;
    }
}

%end

%hook SBLockHardwareButton

-(void)forceResetSequenceDidBegin { 
    if (Enabled) {
        if (Locked && FakeState == FakeSOff) {
            FakeState = FakeSTryOn;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                FakeState = FakeSOff;
            });
        } else if (FakeState == FakeSNormal) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                if ([self isButtonDown]) {
                    fakePowerOff();
                    if (!Locked) {
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                            fakePowerOn();
                        });
                    }
                }
            });
        }
    } else {
        %orig;
    }
}

-(void)buttonDown:(id)arg1 {
    if (FakeState == FakeSNormal) {
        %orig;
    }
}

-(void)singlePress:(id)arg1 {
    if (FakeState == FakeSNormal) {
        %orig;
    }
}

-(void)doublePress:(id)arg1 {
    if (FakeState == FakeSNormal) {
        %orig;
    }
}

-(void)triplePress:(id)arg1 {
    if (FakeState == FakeSNormal) {
        %orig;
    }
}

-(void)quadruplePress:(id)arg1 {
    if (FakeState == FakeSNormal) {
        %orig;
    }
}

-(void)longPress:(id)arg1 {
    if (!Locked && FakeState == FakeSOff) {
        fakePowerOn();
    } else if (FakeState == FakeSNormal) {
        %orig;
    }
}

-(BOOL)isButtonDown {
    if (FakeState == FakeSNormal || (!Locked && FakeState == FakeSOff)) {
        return %orig;
    } else {
        return NO;
    }
}

%end

%hook SBHomeHardwareButton

-(void)initialButtonDown:(id)arg1 {
    if ((Locked && FakeState == FakeSTryOn) ||
        (HomeBoot && !Locked && FakeState == FakeSOff)) {
        fakePowerOn();
    } else if (FakeState == FakeSNormal) {
        %orig;
    }
}

-(void)initialButtonUp:(id)arg1 {
    if (FakeState == FakeSNormal) {
        %orig;
    }
}

-(void)singlePressUp:(id)arg1 {
    if (FakeState == FakeSNormal) {
        %orig;
    }
}

-(void)longPress {
    if (FakeState == FakeSNormal) {
        %orig;
    }
}

-(BOOL)isButtonDown {
    if (FakeState == FakeSNormal) {
        return %orig;
    } else {
        return NO;
    }
}

%end

%ctor {
    NSNumber *v1 = (NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"Enabled" inDomain:nsEnabledString];
    BOOL enabled = v1 ? [v1 boolValue] : YES;
    NSNumber *v2 = (NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"Enabled" inDomain:nsReenableString];
    BOOL reenable = v2 ? [v2 boolValue] : YES;
    if (reenable && !enabled) {
        NSNumber *v = [[NSNumber alloc] initWithBool:YES];
        [[NSUserDefaults standardUserDefaults] setObject:v forKey:@"Enabled" inDomain:nsEnabledString];
    }

    notificationCallback(NULL, NULL, NULL, NULL, NULL);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        notificationCallback,
        (CFStringRef)nsNotificationString,
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );
}
