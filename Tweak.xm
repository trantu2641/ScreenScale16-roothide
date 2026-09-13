#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Configuration

static CGFloat const SC16_SCALE = 0.96;
static CGFloat const SC16_CROP  = 34.0;


#pragma mark - Process

static BOOL SC16Enabled(void)
{
    NSString *version =
        UIDevice.currentDevice.systemVersion;

    return [version hasPrefix:@"16."];
}

static BOOL SC16IsSpringBoard(void)
{
    NSString *bundleID =
        NSBundle.mainBundle.bundleIdentifier;

    return [bundleID isEqualToString:
                @"com.apple.springboard"];
}


#pragma mark - Window Detection

static BOOL SC16IsKeyboardWindow(UIWindow *window)
{
    if (!window)
        return YES;

    NSString *name =
        NSStringFromClass(window.class);

    if ([name rangeOfString:@"Keyboard"
                    options:NSCaseInsensitiveSearch].location != NSNotFound)
        return YES;

    if ([name rangeOfString:@"UITextEffects"
                    options:NSCaseInsensitiveSearch].location != NSNotFound)
        return YES;

    if ([name rangeOfString:@"UIRemoteKeyboard"
                    options:NSCaseInsensitiveSearch].location != NSNotFound)
        return YES;

    return NO;
}

static BOOL SC16IsRootSceneWindow(UIWindow *window)
{
    if (!window)
        return NO;

    NSString *name =
        NSStringFromClass(window.class);

    return [name isEqualToString:@"UIRootSceneWindow"];
}


#pragma mark - Scale

static CGAffineTransform SC16MakeScaleTransform(
    CGRect bounds,
    CGFloat scale
)
{
    CGFloat centerX =
        CGRectGetMidX(bounds);

    CGFloat centerY =
        CGRectGetMidY(bounds);

    CGFloat tx =
        centerX * (1.0 - scale);

    CGFloat ty =
        centerY * (1.0 - scale);

    return CGAffineTransformMake(
        scale,
        0.0,
        0.0,
        scale,
        tx,
        ty
    );
}


#pragma mark - Crop Overlay

/*
 * Crop là lớp RIÊNG với scale.
 *
 * Không dùng window.layer.mask.
 *
 * Overlay này nằm trong window nhưng được cập nhật
 * sau khi window đã có kích thước cuối cùng.
 *
 * Mục đích:
 *   - 34px trên
 *   - 34px dưới
 *   - 34px trái
 *   - 34px phải
 *
 * Phần giữa trong suốt.
 */

static NSInteger const SC16CropTag = 0x53433136;


static void SC16RemoveCropOverlay(UIWindow *window)
{
    if (!window)
        return;

    UIView *oldView =
        [window viewWithTag:SC16CropTag];

    if (oldView)
        [oldView removeFromSuperview];
}


static void SC16ApplyCropOverlay(UIWindow *window)
{
    if (!window)
        return;

    if (window.hidden)
        return;

    if (window.alpha <= 0.0)
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

    /*
     * Xóa overlay cũ.
     */
    SC16RemoveCropOverlay(window);

    UIView *overlay =
        [[UIView alloc] initWithFrame:bounds];

    overlay.tag =
        SC16CropTag;

    overlay.backgroundColor =
        [UIColor clearColor];

    overlay.userInteractionEnabled =
        NO;

    overlay.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;

    /*
     * Đưa overlay lên trên CONTENT.
     */
    [window addSubview:overlay];

    /*
     * Crop thực tế.
     */
    CGFloat crop =
        SC16_CROP;

    BOOL portrait =
        height >= width;

    if (portrait)
    {
        /*
         * Trên.
         */
        UIView *top =
            [[UIView alloc]
                initWithFrame:CGRectMake(
                    0.0,
                    0.0,
                    width,
                    crop
                )];

        top.backgroundColor =
            [UIColor blackColor];

        top.userInteractionEnabled =
            NO;

        [overlay addSubview:top];

        /*
         * Dưới.
         */
        UIView *bottom =
            [[UIView alloc]
                initWithFrame:CGRectMake(
                    0.0,
                    height - crop,
                    width,
                    crop
                )];

        bottom.backgroundColor =
            [UIColor blackColor];

        bottom.userInteractionEnabled =
            NO;

        [overlay addSubview:bottom];
    }
    else
    {
        /*
         * Trái.
         */
        UIView *left =
            [[UIView alloc]
                initWithFrame:CGRectMake(
                    0.0,
                    0.0,
                    crop,
                    height
                )];

        left.backgroundColor =
            [UIColor blackColor];

        left.userInteractionEnabled =
            NO;

        [overlay addSubview:left];

        /*
         * Phải.
         */
        UIView *right =
            [[UIView alloc]
                initWithFrame:CGRectMake(
                    width - crop,
                    0.0,
                    crop,
                    height
                )];

        right.backgroundColor =
            [UIColor blackColor];

        right.userInteractionEnabled =
            NO;

        [overlay addSubview:right];
    }
}


#pragma mark - Window Apply

static void SC16ApplyWindow(UIWindow *window)
{
    if (!window)
        return;

    if (window.hidden)
        return;

    if (window.alpha <= 0.0)
        return;

    if (SC16IsKeyboardWindow(window))
        return;

    if (!window.rootViewController &&
        !SC16IsRootSceneWindow(window))
    {
        return;
    }

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

    /*
     * ==========================================
     * 1. RESET SCALE
     * ==========================================
     *
     * Tránh transform bị nhân chồng.
     */
    window.transform =
        CGAffineTransformIdentity;


    /*
     * ==========================================
     * 2. SCALE
     * ==========================================
     *
     * Scale riêng.
     *
     * Không liên quan tới crop.
     */
    CGFloat scale =
        SC16_SCALE;

    if (scale <= 0.0 ||
        scale > 1.0)
    {
        scale = 1.0;
    }

    if (fabs(scale - 1.0) > 0.0001)
    {
        window.transform =
            SC16MakeScaleTransform(
                bounds,
                scale
            );
    }


    /*
     * ==========================================
     * 3. CROP
     * ==========================================
     *
     * Crop riêng.
     *
     * Luôn áp dụng SAU scale.
     */
    SC16ApplyCropOverlay(window);
}


#pragma mark - Find SpringBoard Window

static UIWindow *SC16FindSpringBoardWindow(void)
{
    UIApplication *application =
        UIApplication.sharedApplication;

    if (!application)
        return nil;

    UIWindow *fallback = nil;

    NSSet<UIScene *> *scenes =
        application.connectedScenes;

    for (UIScene *scene in scenes)
    {
        if (![scene
              isKindOfClass:
                  [UIWindowScene class]])
        {
            continue;
        }

        UIWindowScene *sceneWindow =
            (UIWindowScene *)scene;

        if (sceneWindow.activationState ==
            UISceneActivationStateUnattached)
        {
            continue;
        }

        for (UIWindow *window in
             sceneWindow.windows)
        {
            if (!window)
                continue;

            if (window.hidden)
                continue;

            if (window.alpha <= 0.0)
                continue;

            if (SC16IsKeyboardWindow(window))
                continue;

            /*
             * Ưu tiên UIRootSceneWindow.
             */
            if (SC16IsRootSceneWindow(window))
                return window;

            if (!fallback &&
                window.rootViewController)
            {
                fallback = window;
            }
        }
    }

    return fallback;
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

        if (SC16IsKeyboardWindow(window))
            continue;

        if (!window.rootViewController)
            continue;

        /*
         * Key window ưu tiên cao nhất.
         */
        if (window.isKeyWindow)
            return window;

        if (!fallback)
            fallback = window;
    }

    return fallback;
}


#pragma mark - SpringBoard

static void SC16ApplySpringBoard(void)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    UIWindow *window =
        SC16FindSpringBoardWindow();

    if (!window)
        return;

    SC16ApplyWindow(window);
}


#pragma mark - Application

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


#pragma mark - Scene

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


#pragma mark - Apply All

static void SC16ApplyAllScenes(void)
{
    if (!SC16Enabled())
        return;

    UIApplication *application =
        UIApplication.sharedApplication;

    if (!application)
        return;

    NSSet<UIScene *> *scenes =
        application.connectedScenes;

    for (UIScene *scene in scenes)
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
                    0.5 *
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
