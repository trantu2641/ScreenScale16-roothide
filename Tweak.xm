#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Configuration

/*
 * Crop độc lập:
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
 * Scale độc lập:
 *
 * 0.96 = 96%
 */
static CGFloat const SC16_SCALE = 0.96;

#pragma mark - Process

static BOOL SC16Enabled(void)
{
    return [UIDevice.currentDevice.systemVersion
            hasPrefix:@"16."];
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

static BOOL SC16IsUsableWindow(UIWindow *window)
{
    if (!window)
        return NO;

    if (window.hidden)
        return NO;

    if (window.alpha <= 0.0)
        return NO;

    if (SC16IsKeyboardWindow(window))
        return NO;

    if (!window.rootViewController)
        return NO;

    return YES;
}

#pragma mark - Crop

/*
 * Crop mask thực sự cắt 34px ở mỗi cạnh.
 *
 * Không liên quan đến SC16_SCALE.
 */
static void SC16ApplyCrop(UIWindow *window)
{
    if (!window)
        return;

    CALayer *layer = window.layer;

    if (!layer)
        return;

    CGRect bounds = layer.bounds;

    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 ||
        height <= 0.0)
    {
        return;
    }

    BOOL portrait =
        height > width;

    CGFloat crop =
        SC16_CROP;

    CGRect visibleRect;

    if (portrait)
    {
        /*
         * 34px trên + 34px dưới.
         */
        visibleRect =
            CGRectMake(
                CGRectGetMinX(bounds),
                CGRectGetMinY(bounds) + crop,
                width,
                height - (crop * 2.0)
            );
    }
    else
    {
        /*
         * 34px trái + 34px phải.
         */
        visibleRect =
            CGRectMake(
                CGRectGetMinX(bounds) + crop,
                CGRectGetMinY(bounds),
                width - (crop * 2.0),
                height
            );
    }

    if (CGRectGetWidth(visibleRect) <= 0.0 ||
        CGRectGetHeight(visibleRect) <= 0.0)
    {
        return;
    }

    CAShapeLayer *mask =
        [CAShapeLayer layer];

    mask.frame = bounds;

    CGPathRef path =
        CGPathCreateWithRect(
            visibleRect,
            NULL
        );

    mask.path = path;

    CGPathRelease(path);

    layer.mask = mask;
}

#pragma mark - Scale

/*
 * Scale 96% hoàn toàn riêng với crop.
 *
 * Không lấy SC16_CROP để tính scale.
 */
static void SC16ApplyScale(UIWindow *window)
{
    if (!window)
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
     * Reset trước để tránh scale chồng.
     */
    window.transform =
        CGAffineTransformIdentity;

    if (fabs(scale - 1.0) > 0.0001)
    {
        CGFloat cx =
            CGRectGetMidX(bounds);

        CGFloat cy =
            CGRectGetMidY(bounds);

        CGFloat tx =
            cx * (1.0 - scale);

        CGFloat ty =
            cy * (1.0 - scale);

        window.transform =
            CGAffineTransformMake(
                scale,
                0.0,
                0.0,
                scale,
                tx,
                ty
            );
    }
}

#pragma mark - Apply Window

static void SC16ApplyWindow(UIWindow *window)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsUsableWindow(window))
        return;

    /*
     * Crop và scale là 2 cơ chế riêng.
     *
     * Crop:
     *   layer.mask
     *
     * Scale:
     *   window.transform
     */

    SC16ApplyCrop(window);

    SC16ApplyScale(window);
}

#pragma mark - Find Window

static UIWindow *SC16FindWindow(UIWindowScene *scene)
{
    if (!scene)
        return nil;

    UIWindow *fallback = nil;

    for (UIWindow *window in scene.windows)
    {
        if (!SC16IsUsableWindow(window))
            continue;

        /*
         * Ưu tiên key window.
         */
        if (window.isKeyWindow)
            return window;

        if (!fallback)
            fallback = window;
    }

    return fallback;
}

#pragma mark - Apply Scene

static void SC16ApplyScene(UIWindowScene *scene)
{
    if (!scene)
        return;

    if (scene.activationState ==
        UISceneActivationStateUnattached)
    {
        return;
    }

    UIWindow *window =
        SC16FindWindow(scene);

    if (!window)
        return;

    SC16ApplyWindow(window);
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
        if (![scene
              isKindOfClass:
                  [UIWindowScene class]])
        {
            continue;
        }

        SC16ApplyScene(
            (UIWindowScene *)scene
        );
    }
}

#pragma mark - Scheduling

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

- (void)setBounds:(CGRect)bounds
{
    %orig(bounds);

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();
}

- (void)setFrame:(CGRect)frame
{
    %orig(frame);

    if (!SC16Enabled())
        return;

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

- (void)sceneWillEnterForeground
{
    %orig;

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();
}

%end

#pragma mark - Constructor

%ctor
{
    @autoreleasepool
    {
        if (!SC16Enabled())
            return;

        /*
         * Chờ UIKit tạo window/scene.
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
    }
}
