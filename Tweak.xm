#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Configuration

static CGFloat const SC16_SCALE = 0.96;
static CGFloat const SC16_CROP  = 34.0;


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

    return [name containsString:@"Keyboard"] ||
           [name containsString:@"UITextEffects"] ||
           [name containsString:@"UIRemoteKeyboard"];
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


#pragma mark - Scale

static CGAffineTransform SC16MakeScaleTransform(
    CGRect bounds,
    CGFloat scale
)
{
    CGFloat cx = CGRectGetMidX(bounds);
    CGFloat cy = CGRectGetMidY(bounds);

    CGFloat tx = cx * (1.0 - scale);
    CGFloat ty = cy * (1.0 - scale);

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

static CGRect SC16MakeCropRect(CGRect bounds)
{
    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    /*
     * Crop độc lập với scale.
     *
     * Vì transform scale 96% được áp dụng
     * sau khi tạo vùng crop, bù 34px theo
     * hệ tọa độ source.
     */
    CGFloat sourceCrop =
        SC16_CROP / SC16_SCALE;

    if (height >= width)
    {
        CGFloat newHeight =
            height - (sourceCrop * 2.0);

        if (newHeight <= 0.0)
            return CGRectZero;

        return CGRectMake(
            CGRectGetMinX(bounds),
            CGRectGetMinY(bounds) + sourceCrop,
            width,
            newHeight
        );
    }

    CGFloat newWidth =
        width - (sourceCrop * 2.0);

    if (newWidth <= 0.0)
        return CGRectZero;

    return CGRectMake(
        CGRectGetMinX(bounds) + sourceCrop,
        CGRectGetMinY(bounds),
        newWidth,
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

    if (CGRectGetWidth(bounds) <= 0.0 ||
        CGRectGetHeight(bounds) <= 0.0)
    {
        return;
    }

    CGRect cropRect =
        SC16MakeCropRect(bounds);

    if (CGRectIsEmpty(cropRect))
        return;

    CAShapeLayer *mask =
        [CAShapeLayer layer];

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

    layer.mask =
        mask;
}


#pragma mark - Apply

static void SC16ApplyToWindow(
    UIWindow *window
)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsUsableWindow(window))
        return;

    CGRect bounds =
        window.bounds;

    if (CGRectGetWidth(bounds) <= 0.0 ||
        CGRectGetHeight(bounds) <= 0.0)
    {
        return;
    }

    CGFloat scale =
        SC16_SCALE;

    if (scale <= 0.0 || scale > 1.0)
        scale = 1.0;

    /*
     * Quan trọng:
     *
     * Reset transform trực tiếp trước khi
     * tính transform mới.
     *
     * Không có hàm reset riêng => không còn
     * lỗi unused-function.
     */
    window.transform =
        CGAffineTransformIdentity;

    /*
     * Crop là một lớp riêng.
     */
    SC16ApplyCrop(window);

    /*
     * Scale là một phần riêng.
     */
    if (fabs(scale - 1.0) > 0.0001)
    {
        window.transform =
            SC16MakeScaleTransform(
                bounds,
                scale
            );
    }
}


#pragma mark - SpringBoard

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
             * SpringBoard root.
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


static void SC16ApplySpringBoard(void)
{
    UIWindow *window =
        SC16FindSpringBoardWindow();

    if (!window)
        return;

    SC16ApplyToWindow(window);
}


#pragma mark - Application

static UIWindow *SC16FindApplicationWindow(
    UIWindowScene *scene
)
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


static void SC16ApplyApplicationScene(
    UIWindowScene *scene
)
{
    UIWindow *window =
        SC16FindApplicationWindow(scene);

    if (!window)
        return;

    SC16ApplyToWindow(window);
}


#pragma mark - Scenes

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

    if (SC16IsSpringBoard())
    {
        SC16ApplySpringBoard();
        return;
    }

    SC16ApplyApplicationScene(scene);
}


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

        SC16ApplyScene(scene);
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

    if (SC16Enabled())
        SC16ScheduleApply();
}


- (void)setRootViewController:
    (UIViewController *)rootViewController
{
    %orig(rootViewController);

    if (SC16Enabled())
        SC16ScheduleApply();
}


- (void)setHidden:(BOOL)hidden
{
    %orig(hidden);

    if (SC16Enabled() && !hidden)
        SC16ScheduleApply();
}

%end


#pragma mark - UIWindowScene Hooks

%hook UIWindowScene

- (void)sceneDidBecomeActive
{
    %orig;

    if (SC16Enabled())
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
