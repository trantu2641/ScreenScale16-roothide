#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Configuration

/*
 * Scale giống kiểu OneHand.
 *
 * 0.90 = 90%
 *
 * SC16_CROP là phần bị CẮT khỏi vùng hiển thị,
 * không phải phần cộng thêm vào scale.
 *
 * Portrait:
 *     8px trên
 *     8px dưới
 *
 * Landscape:
 *     8px trái
 *     8px phải
 */
static CGFloat const SC16_SCALE = 0.90;
static CGFloat const SC16_CROP  = 8.0;

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

static BOOL SC16IsRootSceneWindow(UIWindow *window)
{
    if (!window)
        return NO;

    NSString *className =
        NSStringFromClass(window.class);

    return [className isEqualToString:
            @"UIRootSceneWindow"];
}

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

static BOOL SC16IsStatusBarWindow(UIWindow *window)
{
    if (!window)
        return NO;

    NSString *name =
        NSStringFromClass(window.class);

    if ([name containsString:@"StatusBar"])
        return YES;

    if ([name containsString:@"_UIStatusBar"])
        return YES;

    if ([name containsString:@"UIStatusBar"])
        return YES;

    return NO;
}

static BOOL SC16IsAssistiveTouchWindow(UIWindow *window)
{
    if (!window)
        return NO;

    NSString *name =
        NSStringFromClass(window.class);

    if ([name containsString:@"Assistive"])
        return YES;

    if ([name containsString:@"AssistiveTouch"])
        return YES;

    /*
     * AX windows của SpringBoard có thể dùng
     * nhiều class name khác nhau giữa các bản iOS.
     */
    if ([name hasPrefix:@"AX"])
        return YES;

    if ([name containsString:@"Accessibility"])
        return YES;

    return NO;
}

#pragma mark - Screen Geometry

static CGSize SC16ScreenSizeForWindow(UIWindow *window)
{
    if (!window)
        return CGSizeZero;

    UIWindowScene *scene =
        window.windowScene;

    if (scene)
    {
        CGRect coordinateBounds =
            scene.coordinateSpace.bounds;

        CGSize size =
            coordinateBounds.size;

        if (size.width > 0.0 &&
            size.height > 0.0)
        {
            return size;
        }
    }

    UIScreen *screen =
        window.screen;

    if (screen)
    {
        CGRect bounds =
            screen.bounds;

        if (bounds.size.width > 0.0 &&
            bounds.size.height > 0.0)
        {
            return bounds.size;
        }
    }

    CGRect bounds =
        window.bounds;

    return bounds.size;
}

static CGFloat SC16ScaleForScreenSize(CGSize size)
{
    if (size.width <= 0.0 ||
        size.height <= 0.0)
    {
        return 1.0;
    }

    CGFloat scale =
        SC16_SCALE;

    if (scale <= 0.0)
        scale = 1.0;

    if (scale > 1.0)
        scale = 1.0;

    return scale;
}

#pragma mark - Transform

/*
 * Scale quanh TÂM màn hình.
 *
 * Không dùng window.center để tính tâm.
 * Điều này rất quan trọng với SpringBoard vì
 * UIRootSceneWindow có thể có coordinate space khác.
 */
static CGAffineTransform SC16TransformForScreen(
    CGSize screenSize,
    CGFloat scale
)
{
    CGPoint center =
        CGPointMake(
            screenSize.width * 0.5,
            screenSize.height * 0.5
        );

    /*
     * Công thức:
     *
     * x' = center + scale * (x - center)
     *
     * y' = center + scale * (y - center)
     */
    CGAffineTransform transform =
        CGAffineTransformMakeScale(
            scale,
            scale
        );

    transform =
        CGAffineTransformTranslate(
            transform,
            center.x / scale - center.x,
            center.y / scale - center.y
        );

    return transform;
}

static void SC16ApplyTransformToWindow(
    UIWindow *window,
    CGSize screenSize
)
{
    if (!window)
        return;

    CGFloat scale =
        SC16ScaleForScreenSize(screenSize);

    if (scale >= 1.0)
    {
        window.transform =
            CGAffineTransformIdentity;

        return;
    }

    window.transform =
        SC16TransformForScreen(
            screenSize,
            scale
        );
}

#pragma mark - Crop

/*
 * Tạo crop mask theo COORDINATE SPACE CỦA WINDOW.
 *
 * Lưu ý:
 *
 * Vì window sẽ được scale 0.90,
 * nếu muốn sau cùng bị cắt đúng 8px trên màn hình,
 * phần inset trong window phải là:
 *
 *     8 / 0.90
 *
 * thay vì 8.
 */
static void SC16ApplyCropMask(
    UIWindow *window,
    CGSize screenSize
)
{
    if (!window)
        return;

    CALayer *layer =
        window.layer;

    if (!layer)
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
        SC16ScaleForScreenSize(screenSize);

    if (scale >= 1.0)
    {
        layer.mask = nil;
        return;
    }

    /*
     * Bù ngược scale để crop thực tế
     * trên màn hình vẫn là đúng 8px.
     */
    CGFloat crop =
        SC16_CROP / scale;

    BOOL portrait =
        screenSize.height >
        screenSize.width;

    CGRect cropRect =
        bounds;

    if (portrait)
    {
        cropRect.origin.y += crop;

        cropRect.size.height -=
            crop * 2.0;
    }
    else
    {
        cropRect.origin.x += crop;

        cropRect.size.width -=
            crop * 2.0;
    }

    if (cropRect.size.width <= 0.0 ||
        cropRect.size.height <= 0.0)
    {
        return;
    }

    CAShapeLayer *mask =
        (CAShapeLayer *)layer.mask;

    if (![mask isKindOfClass:
          [CAShapeLayer class]])
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

#pragma mark - Apply One Window

static void SC16ApplyWindow(
    UIWindow *window,
    BOOL systemWindow
)
{
    if (!window)
        return;

    if (window.hidden)
        return;

    if (window.alpha <= 0.0)
        return;

    if (SC16IsKeyboardWindow(window))
        return;

    CGSize screenSize =
        SC16ScreenSizeForWindow(window);

    if (screenSize.width <= 0.0 ||
        screenSize.height <= 0.0)
    {
        return;
    }

    /*
     * Chỉ system window hoặc root app window.
     */
    if (systemWindow)
    {
        SC16ApplyTransformToWindow(
            window,
            screenSize
        );

        SC16ApplyCropMask(
            window,
            screenSize
        );

        return;
    }

    /*
     * Application:
     *
     * Không đụng các window kỹ thuật.
     */
    if (!window.rootViewController)
        return;

    SC16ApplyTransformToWindow(
        window,
        screenSize
    );

    SC16ApplyCropMask(
        window,
        screenSize
    );
}

#pragma mark - SpringBoard Root

/*
 * Tìm UIRootSceneWindow của scene đang active.
 *
 * Không dùng application.windows.
 */
static UIWindow *SC16FindRootSceneWindow(
    UIWindowScene *scene
)
{
    if (!scene)
        return nil;

    UIWindow *fallback =
        nil;

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

        if (SC16IsRootSceneWindow(window))
            return window;

        if (!fallback &&
            window.rootViewController)
        {
            fallback = window;
        }
    }

    return fallback;
}

#pragma mark - SpringBoard Windows

static void SC16ApplySpringBoardScene(
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

    CGSize screenSize =
        scene.coordinateSpace.bounds.size;

    if (screenSize.width <= 0.0 ||
        screenSize.height <= 0.0)
    {
        return;
    }

    UIWindow *rootWindow =
        SC16FindRootSceneWindow(scene);

    if (rootWindow)
    {
        /*
         * Đây là window chính theo kiểu
         * OneHand / UIRootSceneWindow.
         */
        SC16ApplyWindow(
            rootWindow,
            YES
        );
    }

    /*
     * Status Bar / AssistiveTouch có thể nằm
     * ở window riêng.
     *
     * Chỉ xử lý đúng các loại system window này,
     * không transform toàn bộ UIWindow của SpringBoard.
     */
    for (UIWindow *window in scene.windows)
    {
        if (!window)
            continue;

        if (window == rootWindow)
            continue;

        if (SC16IsKeyboardWindow(window))
            continue;

        if (SC16IsStatusBarWindow(window) ||
            SC16IsAssistiveTouchWindow(window))
        {
            SC16ApplyWindow(
                window,
                YES
            );
        }
    }
}

#pragma mark - Application Scene

static void SC16ApplyApplicationScene(
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
     * Chỉ lấy window chính.
     *
     * Không scale alert/keyboard/technical windows
     * riêng lẻ.
     */
    UIWindow *mainWindow =
        nil;

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
         * Bỏ qua một số window overlay.
         */
        NSString *className =
            NSStringFromClass(window.class);

        if ([className containsString:@"TextEffects"])
            continue;

        if ([className containsString:@"Keyboard"])
            continue;

        mainWindow =
            window;

        break;
    }

    if (!mainWindow)
        return;

    SC16ApplyWindow(
        mainWindow,
        NO
    );
}

#pragma mark - Scene Apply

static void SC16ApplyScene(
    UIWindowScene *scene
)
{
    if (!scene)
        return;

    if (SC16IsSpringBoard())
    {
        SC16ApplySpringBoardScene(
            scene
        );

        return;
    }

    SC16ApplyApplicationScene(
        scene
    );
}

#pragma mark - All Scenes

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

#pragma mark - Safe Scheduling

/*
 * Không gọi trực tiếp trong setFrame/setBounds.
 *
 * Tránh:
 *
 * setFrame
 *   -> transform
 *      -> layout
 *         -> setFrame
 *            -> ...
 *
 * Đây là một trong những điểm dễ gây crash/Safe Mode.
 */
static void SC16ScheduleApply(void)
{
    if (!SC16Enabled())
        return;

    static BOOL scheduled =
        NO;

    if (scheduled)
        return;

    scheduled =
        YES;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            scheduled =
                NO;

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

    if (hidden)
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

#pragma mark - UIViewController

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated
{
    %orig(animated);

    if (!SC16Enabled())
        return;

    /*
     * App vừa xuất hiện -> apply một lần.
     *
     * Không gọi trong viewDidLayoutSubviews,
     * tránh vòng lặp layout.
     */
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
         * Đợi UIKit / SpringBoard hoàn tất
         * quá trình tạo scene.
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
