#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma mark - Configuration

/*
 * SCALE RIÊNG
 *
 * 0.96 = 96%
 */
static CGFloat const SC16_SCALE = 0.96;

/*
 * CROP RIÊNG
 *
 * Portrait:
 *   34px trên
 *   34px dưới
 *
 * Landscape:
 *   34px trái
 *   34px phải
 */
static CGFloat const SC16_CROP = 34.0;


/*
 * Để tránh transform bị cộng dồn.
 */
static char kSC16AppliedKey;


#pragma mark - Process

static BOOL SC16IsSpringBoard(void)
{
    NSString *bundleID =
        NSBundle.mainBundle.bundleIdentifier;

    return [bundleID isEqualToString:
                @"com.apple.springboard"];
}


static BOOL SC16Enabled(void)
{
    NSString *version =
        UIDevice.currentDevice.systemVersion;

    return [version hasPrefix:@"16."];
}


#pragma mark - Window Detection

static BOOL SC16IsKeyboardWindow(UIWindow *window)
{
    if (!window)
        return YES;

    NSString *name =
        NSStringFromClass(window.class);

    if ([name containsString:@"Keyboard"])
        return YES;

    if ([name containsString:@"UITextEffects"])
        return YES;

    if ([name containsString:@"UIRemoteKeyboard"])
        return YES;

    return NO;
}


static BOOL SC16IsSystemWindow(UIWindow *window)
{
    if (!window)
        return YES;

    if (SC16IsKeyboardWindow(window))
        return YES;

    NSString *name =
        NSStringFromClass(window.class);

    /*
     * Không đụng các window UI đặc biệt
     * của UIKit.
     */
    if ([name containsString:@"TextEffects"])
        return YES;

    if ([name containsString:@"Keyboard"])
        return YES;

    if ([name containsString:@"Remote"])
        return YES;

    return NO;
}


#pragma mark - Geometry

/*
 * Scale quanh TÂM THẬT của window.
 *
 * Không dùng frame.
 *
 * Scale và crop là 2 phần độc lập.
 */
static CGAffineTransform SC16ScaleTransform(
    CGRect bounds,
    CGFloat scale
)
{
    CGFloat cx =
        CGRectGetMidX(bounds);

    CGFloat cy =
        CGRectGetMidY(bounds);

    CGFloat tx =
        cx - (cx * scale);

    CGFloat ty =
        cy - (cy * scale);

    return CGAffineTransformMake(
        scale,
        0.0,
        0.0,
        scale,
        tx,
        ty
    );
}


#pragma mark - Crop

/*
 * Tính vùng nguồn cần giữ lại.
 *
 * Crop 34px là crop THỰC TẾ trên màn hình.
 *
 * Vì scale = 0.96 nên source crop phải
 * bù lại phần scale:
 *
 *     34 / 0.96
 */
static CGRect SC16CropRect(
    CGRect bounds
)
{
    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    CGFloat crop =
        SC16_CROP / SC16_SCALE;

    BOOL portrait =
        height >= width;

    if (portrait)
    {
        CGFloat h =
            height - (crop * 2.0);

        if (h <= 1.0)
            return CGRectZero;

        return CGRectMake(
            CGRectGetMinX(bounds),
            CGRectGetMinY(bounds) + crop,
            width,
            h
        );
    }

    CGFloat w =
        width - (crop * 2.0);

    if (w <= 1.0)
        return CGRectZero;

    return CGRectMake(
        CGRectGetMinX(bounds) + crop,
        CGRectGetMinY(bounds),
        w,
        height
    );
}


#pragma mark - Crop Mask

static void SC16ApplyCrop(
    UIWindow *window
)
{
    if (!window)
        return;

    CALayer *layer =
        window.layer;

    if (!layer)
        return;

    CGRect bounds =
        layer.bounds;

    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 ||
        height <= 0.0)
    {
        return;
    }

    CGRect cropRect =
        SC16CropRect(bounds);

    if (CGRectIsEmpty(cropRect))
        return;

    CAShapeLayer *mask = nil;

    if ([layer.mask isKindOfClass:
             [CAShapeLayer class]])
    {
        mask =
            (CAShapeLayer *)layer.mask;
    }
    else
    {
        mask =
            [CAShapeLayer layer];

        layer.mask = mask;
    }

    mask.frame =
        bounds;

    CGPathRef path =
        CGPathCreateWithRect(
            cropRect,
            NULL
        );

    mask.path =
        path;

    CGPathRelease(path);
}


#pragma mark - Reset

static void SC16ResetWindow(
    UIWindow *window
)
{
    if (!window)
        return;

    window.transform =
        CGAffineTransformIdentity;

    window.layer.mask =
        nil;

    objc_setAssociatedObject(
        window,
        &kSC16AppliedKey,
        @(NO),
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
}


#pragma mark - Apply

static void SC16ApplyWindow(
    UIWindow *window
)
{
    if (!SC16Enabled())
        return;

    if (!window)
        return;

    if (window.hidden)
        return;

    if (window.alpha <= 0.0)
        return;

    if (SC16IsSystemWindow(window))
        return;

    CGRect bounds =
        window.bounds;

    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 ||
        height <= 0.0)
    {
        return;
    }

    CGFloat scale =
        SC16_SCALE;

    if (scale <= 0.0 ||
        scale > 1.0)
    {
        scale = 1.0;
    }

    /*
     * LUÔN RESET trước.
     *
     * Điều này cực kỳ quan trọng:
     * tránh transform bị nhân chồng
     * sau mỗi lần UIKit layout.
     */
    window.transform =
        CGAffineTransformIdentity;

    /*
     * Crop trước để mask nằm đúng
     * trong hệ tọa độ gốc của window.
     */
    SC16ApplyCrop(window);

    /*
     * Scale RIÊNG.
     */
    if (fabs(scale - 1.0) > 0.0001)
    {
        window.transform =
            SC16ScaleTransform(
                bounds,
                scale
            );
    }

    objc_setAssociatedObject(
        window,
        &kSC16AppliedKey,
        @(YES),
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
}


#pragma mark - Find Application Window

static UIWindow *SC16FindApplicationWindow(
    UIWindowScene *scene
)
{
    if (!scene)
        return nil;

    UIWindow *fallback = nil;

    for (UIWindow *window in scene.windows)
    {
        if (!window)
            continue;

        if (window.hidden)
            continue;

        if (window.alpha <= 0.0)
            continue;

        if (SC16IsSystemWindow(window))
            continue;

        if (!window.rootViewController)
            continue;

        /*
         * Ưu tiên keyWindow.
         */
        if (window.isKeyWindow)
            return window;

        if (!fallback)
            fallback = window;
    }

    return fallback;
}


#pragma mark - Find SpringBoard Window

static UIWindow *SC16FindSpringBoardWindow(void)
{
    if (!SC16IsSpringBoard())
        return nil;

    UIApplication *application =
        UIApplication.sharedApplication;

    if (!application)
        return nil;

    UIWindow *fallback = nil;

    for (UIScene *scene in
         application.connectedScenes)
    {
        if (![scene isKindOfClass:
                  [UIWindowScene class]])
        {
            continue;
        }

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        if (windowScene.activationState ==
            UISceneActivationStateUnattached)
        {
            continue;
        }

        for (UIWindow *window in
             windowScene.windows)
        {
            if (!window)
                continue;

            if (window.hidden)
                continue;

            if (window.alpha <= 0.0)
                continue;

            if (SC16IsKeyboardWindow(window))
                continue;

            NSString *name =
                NSStringFromClass(window.class);

            /*
             * Ưu tiên đúng root scene window.
             */
            if ([name isEqualToString:
                     @"UIRootSceneWindow"])
            {
                return window;
            }

            /*
             * Fallback.
             */
            if (!fallback &&
                window.rootViewController)
            {
                fallback = window;
            }
        }
    }

    return fallback;
}


#pragma mark - Apply SpringBoard

static void SC16ApplySpringBoard(void)
{
    if (!SC16Enabled())
        return;

    UIWindow *window =
        SC16FindSpringBoardWindow();

    if (!window)
        return;

    SC16ApplyWindow(window);
}


#pragma mark - Apply Application

static void SC16ApplyApplicationScene(
    UIWindowScene *scene
)
{
    if (!scene)
        return;

    UIWindow *window =
        SC16FindApplicationWindow(scene);

    if (!window)
        return;

    SC16ApplyWindow(window);
}


#pragma mark - Apply Scene

static void SC16ApplyScene(
    UIWindowScene *scene
)
{
    if (!scene)
        return;

    if (scene.activationState ==
        UISceneActivationStateUnattached)
    {
        return;
    }

    /*
     * SpringBoard chỉ xử lý root window.
     */
    if (SC16IsSpringBoard())
    {
        SC16ApplySpringBoard();
        return;
    }

    /*
     * App chỉ xử lý window chính.
     */
    SC16ApplyApplicationScene(scene);
}


#pragma mark - Apply All

static void SC16ApplyAllScenes(void)
{
    if (!SC16Enabled())
        return;

    UIApplication *application =
        UIApplication.sharedApplication;

    if (!application)
        return;

    for (UIScene *scene in
         application.connectedScenes)
    {
        if (![scene isKindOfClass:
                  [UIWindowScene class]])
        {
            continue;
        }

        SC16ApplyScene(
            (UIWindowScene *)scene
        );
    }
}


#pragma mark - Safe Scheduling

static void SC16ScheduleApply(void)
{
    if (!SC16Enabled())
        return;

    static BOOL scheduled = NO;

    if (scheduled)
        return;

    scheduled = YES;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            scheduled = NO;

            SC16ApplyAllScenes();
        }
    );
}


#pragma mark - UIWindow Hooks

%hook UIWindow

- (void)makeKeyAndVisible
{
    %orig;

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();
}


- (void)setRootViewController:
    (UIViewController *)rootViewController
{
    %orig(rootViewController);

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();
}


- (void)setHidden:(BOOL)hidden
{
    %orig(hidden);

    if (!SC16Enabled())
        return;

    if (!hidden)
        SC16ScheduleApply();
}

%end


#pragma mark - UIWindowScene Hooks

%hook UIWindowScene

- (void)sceneDidBecomeActive
{
    %orig;

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();
}

%end


#pragma mark - Notifications

static void SC16WindowChanged(
    NSNotification *notification
)
{
    if (!SC16Enabled())
        return;

    SC16ScheduleApply();
}


#pragma mark - Constructor

%ctor
{
    @autoreleasepool
    {
        if (!SC16Enabled())
            return;

        /*
         * UIKit cần thời gian tạo scene/window.
         */
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(
                    0.8 *
                    NSEC_PER_SEC
                )
            ),
            dispatch_get_main_queue(),
            ^{
                SC16ApplyAllScenes();
            }
        );

        NSNotificationCenter *center =
            [NSNotificationCenter defaultCenter];

        [center addObserverForName:
                    UIWindowDidBecomeKeyNotification
                            object:nil
                             queue:
                    [NSOperationQueue mainQueue]
                        usingBlock:
                    ^(NSNotification *note)
        {
            SC16WindowChanged(note);
        }];

        [center addObserverForName:
                    UIWindowDidBecomeVisibleNotification
                            object:nil
                             queue:
                    [NSOperationQueue mainQueue]
                        usingBlock:
                    ^(NSNotification *note)
        {
            SC16WindowChanged(note);
        }];

        [center addObserverForName:
                    UISceneDidActivateNotification
                            object:nil
                             queue:
                    [NSOperationQueue mainQueue]
                        usingBlock:
                    ^(NSNotification *note)
        {
            SC16WindowChanged(note);
        }];
    }
}
