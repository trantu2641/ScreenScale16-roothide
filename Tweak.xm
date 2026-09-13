#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma mark - Configuration

/*
 * Scale giống kiểu OneHand:
 *
 *   0.90 = 90%
 *
 * 8px là phần CẮT khỏi vùng hiển thị,
 * không phải tăng scale.
 */
static CGFloat const SC16_SCALE = 0.90;
static CGFloat const SC16_CROP = 8.0;

#pragma mark - Process

static BOOL SC16IsSpringBoard(void)
{
    NSString *bundleID =
        NSBundle.mainBundle.bundleIdentifier;

    return [bundleID isEqualToString:@"com.apple.springboard"];
}

static BOOL SC16Enabled(void)
{
    NSString *version =
        UIDevice.currentDevice.systemVersion;

    return [version hasPrefix:@"16."];
}

#pragma mark - Window Detection

/*
 * OneHand sử dụng UIRootSceneWindow làm root window.
 *
 * Không hard-code object pointer.
 * Tìm root window từ UIWindowScene đang active.
 */
static BOOL SC16IsRootSceneWindow(UIWindow *window)
{
    if (!window)
        return NO;

    NSString *className =
        NSStringFromClass(window.class);

    return [className isEqualToString:@"UIRootSceneWindow"];
}

/*
 * Keyboard không tham gia scale.
 */
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

#pragma mark - Geometry

/*
 * Tạo transform theo TÂM MÀN HÌNH,
 * không theo tâm riêng của từng window.
 *
 * Công thức:
 *
 *     x' = center + scale * (x - center)
 *
 * Vì vậy portrait và landscape đều giữ đúng
 * tâm màn hình.
 */
static CGAffineTransform SC16ScreenTransform(
    CGSize screenSize,
    CGFloat scale
)
{
    CGPoint screenCenter =
        CGPointMake(
            screenSize.width * 0.5,
            screenSize.height * 0.5
        );

    CGFloat tx =
        (1.0 - scale) *
        screenCenter.x;

    CGFloat ty =
        (1.0 - scale) *
        screenCenter.y;

    /*
     * T * S
     *
     * scale quanh tâm màn hình + translation.
     */
    CGAffineTransform transform =
        CGAffineTransformMakeScale(
            scale,
            scale
        );

    transform =
        CGAffineTransformTranslate(
            transform,
            tx / scale,
            ty / scale
        );

    return transform;
}

#pragma mark - Crop Mask

/*
 * Mask để phần ngoài vùng hiển thị bị CẮT.
 *
 * Không thay frame/bounds.
 *
 * Portrait:
 *
 *       8px
 *   +----------+
 *   |XXXXXXXXXX|
 *   |          |
 *   | CONTENT  |
 *   |          |
 *   |XXXXXXXXXX|
 *       8px
 *
 * Landscape:
 *
 *   8px | CONTENT | 8px
 */
static void SC16ApplyCropMask(
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
        window.bounds;

    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 || height <= 0.0)
        return;

    BOOL portrait =
        height > width;

    CGFloat cropX = 0.0;
    CGFloat cropY = 0.0;
    CGFloat cropWidth = width;
    CGFloat cropHeight = height;

    if (portrait)
    {
        cropY = SC16_CROP;
        cropHeight =
            height -
            (SC16_CROP * 2.0);
    }
    else
    {
        cropX = SC16_CROP;
        cropWidth =
            width -
            (SC16_CROP * 2.0);
    }

    if (cropWidth <= 0.0 ||
        cropHeight <= 0.0)
    {
        return;
    }

    /*
     * Dùng CAShapeLayer duy nhất cho window.
     *
     * Không tạo mask mới mỗi lần refresh.
     */
    CAShapeLayer *mask =
        (CAShapeLayer *)layer.mask;

    if (![mask isKindOfClass:[CAShapeLayer class]])
    {
        mask =
            [CAShapeLayer layer];

        layer.mask = mask;
    }

    mask.frame = bounds;

    CGPathRef path =
        CGPathCreateWithRect(
            CGRectMake(
                CGRectGetMinX(bounds) + cropX,
                CGRectGetMinY(bounds) + cropY,
                cropWidth,
                cropHeight
            ),
            NULL
        );

    mask.path = path;

    CGPathRelease(path);
}

#pragma mark - Remove Mask

static void SC16RemoveCropMask(
    UIWindow *window
)
{
    if (!window)
        return;

    window.layer.mask = nil;
}

#pragma mark - Root Window

/*
 * Tìm UIRootSceneWindow.
 *
 * Đây là phần quan trọng nhất lấy theo cách
 * OneHand đang hoạt động.
 */
static UIWindow *SC16FindRootWindow(void)
{
    if (!SC16IsSpringBoard())
        return nil;

    UIApplication *application =
        UIApplication.sharedApplication;

    if (!application)
        return nil;

    NSSet<UIScene *> *scenes =
        application.connectedScenes;

    UIWindow *fallback = nil;

    for (UIScene *scene in scenes)
    {
        if (![scene
              isKindOfClass:[UIWindowScene class]])
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
            if (!window ||
                window.hidden ||
                window.alpha <= 0.0)
            {
                continue;
            }

            if (SC16IsKeyboardWindow(window))
                continue;

            if (SC16IsRootSceneWindow(window))
                return window;

            /*
             * Fallback:
             * window có rootViewController.
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

#pragma mark - SpringBoard Apply

static void SC16ApplySpringBoard(void)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    UIWindow *rootWindow =
        SC16FindRootWindow();

    if (!rootWindow)
        return;

    CGRect bounds =
        rootWindow.bounds;

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
     * Không thay frame.
     * Không thay bounds.
     * Không thay center.
     *
     * Chỉ transform quanh tâm màn hình.
     */
    rootWindow.transform =
        SC16ScreenTransform(
            CGSizeMake(width, height),
            scale
        );

    /*
     * Cắt 8px ở vùng ngoài.
     */
    SC16ApplyCropMask(rootWindow);
}

#pragma mark - Application Apply

/*
 * App process:
 *
 * Không áp dụng system-wide vào mọi UIWindow.
 *
 * Chỉ scale window chính của app.
 */
static void SC16ApplyApplicationWindow(
    UIWindow *window
)
{
    if (!SC16Enabled())
        return;

    if (SC16IsSpringBoard())
        return;

    if (!window)
        return;

    if (window.hidden ||
        window.alpha <= 0.0)
    {
        return;
    }

    if (SC16IsKeyboardWindow(window))
        return;

    if (!window.rootViewController)
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
     * App window sử dụng chính scale 90%.
     */
    CGFloat scale =
        SC16_SCALE;

    if (scale <= 0.0 ||
        scale > 1.0)
    {
        scale = 1.0;
    }

    /*
     * Chỉ transform window.
     *
     * Không transform rootView.
     */
    window.transform =
        SC16ScreenTransform(
            CGSizeMake(width, height),
            scale
        );

    /*
     * Crop 8px.
     */
    SC16ApplyCropMask(window);
}

#pragma mark - Scene Apply

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
     * SpringBoard:
     *
     * Chỉ target rootWindow giống OneHand.
     */
    if (SC16IsSpringBoard())
    {
        SC16ApplySpringBoard();
        return;
    }

    /*
     * Application:
     *
     * Chỉ lấy window có root VC.
     */
    for (UIWindow *window in scene.windows)
    {
        if (!window)
            continue;

        if (!window.rootViewController)
            continue;

        SC16ApplyApplicationWindow(
            window
        );

        /*
         * Không transform hàng loạt window
         * kỹ thuật của UIKit.
         */
        break;
    }
}

#pragma mark - Apply All Scenes

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
              isKindOfClass:[UIWindowScene class]])
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
 * Chống refresh liên tục.
 *
 * Không gọi từ setFrame:
 * Không gọi từ setBounds:
 * Không gọi từ viewDidLayoutSubviews:
 */
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

#pragma mark - UIWindow

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

#pragma mark - UIWindowScene

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
         * Đợi SpringBoard/UIKit khởi tạo scene.
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
