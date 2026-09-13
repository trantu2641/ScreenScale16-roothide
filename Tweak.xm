#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Configuration

/*
 * Scale toàn bộ nội dung.
 *
 * 0.96 = 96%
 */
static CGFloat const SC16_SCALE = 0.96;

/*
 * Crop độc lập với scale.
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


#pragma mark - Process

static BOOL SC16IsSpringBoard(void)
{
    NSString *bundleID =
        NSBundle.mainBundle.bundleIdentifier;

    return [bundleID isEqualToString:@"com.apple.springboard"];
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


#pragma mark - Geometry

/*
 * Scale quanh tâm WINDOW.
 *
 * Không thay frame.
 * Không thay bounds.
 * Không thay center.
 */
static CGAffineTransform SC16CenteredTransform(
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


#pragma mark - Crop Geometry

/*
 * Crop được tính RIÊNG.
 *
 * Không nhân SC16_CROP với scale.
 *
 * Mục tiêu là vùng đen thực tế trên màn hình
 * luôn xấp xỉ 34px mỗi cạnh.
 */
static CGRect SC16CropRectForBounds(CGRect bounds)
{
    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 || height <= 0.0)
        return CGRectZero;

    if (height >= width)
    {
        CGFloat crop =
            SC16_CROP;

        CGFloat newHeight =
            height - (crop * 2.0);

        if (newHeight <= 0.0)
            return CGRectZero;

        return CGRectMake(
            CGRectGetMinX(bounds),
            CGRectGetMinY(bounds) + crop,
            width,
            newHeight
        );
    }
    else
    {
        CGFloat crop =
            SC16_CROP;

        CGFloat newWidth =
            width - (crop * 2.0);

        if (newWidth <= 0.0)
            return CGRectZero;

        return CGRectMake(
            CGRectGetMinX(bounds) + crop,
            CGRectGetMinY(bounds),
            newWidth,
            height
        );
    }
}


#pragma mark - Crop Mask

/*
 * Crop chỉ là mask.
 *
 * Scale xử lý riêng ở UIWindow.
 */
static void SC16ApplyCropMask(UIWindow *window)
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
        SC16CropRectForBounds(bounds);

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


#pragma mark - Scale

static void SC16ApplyScale(UIWindow *window)
{
    if (!window)
        return;

    CGFloat scale =
        SC16_SCALE;

    if (scale <= 0.0 ||
        scale > 1.0)
    {
        scale = 1.0;
    }

    /*
     * Luôn reset trước.
     *
     * Tránh transform bị cộng dồn
     * mỗi lần scene/window thay đổi.
     */
    window.transform =
        CGAffineTransformIdentity;

    if (fabs(scale - 1.0) < 0.0001)
        return;

    CGRect bounds =
        window.bounds;

    if (CGRectGetWidth(bounds) <= 0.0 ||
        CGRectGetHeight(bounds) <= 0.0)
    {
        return;
    }

    /*
     * Scale chính xác quanh tâm bounds.
     */
    window.transform =
        SC16CenteredTransform(
            bounds,
            scale
        );
}


#pragma mark - Apply Window

static void SC16ApplyToWindow(UIWindow *window)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsUsableWindow(window))
        return;

    /*
     * QUAN TRỌNG:
     *
     * Crop và scale là 2 bước độc lập.
     *
     * 1. Crop 34px
     * 2. Scale 96%
     *
     * Không dùng sourceCrop = crop / scale.
     */
    SC16ApplyCropMask(window);

    SC16ApplyScale(window);
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

    UIWindow *fallback =
        nil;

    for (UIScene *scene in
         application.connectedScenes)
    {
        if (![scene
              isKindOfClass:
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
             * Ưu tiên window chính của SpringBoard.
             */
            if ([name isEqualToString:
                     @"UIRootSceneWindow"])
            {
                return window;
            }

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
    if (!SC16IsSpringBoard())
        return;

    UIWindow *window =
        SC16FindSpringBoardWindow();

    if (!window)
        return;

    SC16ApplyToWindow(window);
}


#pragma mark - Application Window

static UIWindow *SC16FindApplicationWindow(
    UIWindowScene *scene
)
{
    if (!scene)
        return nil;

    UIWindow *fallback =
        nil;

    for (UIWindow *window in scene.windows)
    {
        if (!SC16IsUsableWindow(window))
            continue;

        /*
         * Key window được ưu tiên.
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
    if (!scene)
        return;

    UIWindow *window =
        SC16FindApplicationWindow(scene);

    if (!window)
        return;

    SC16ApplyToWindow(window);
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

    for (UIScene *scene in
         application.connectedScenes)
    {
        if (![scene
              isKindOfClass:
                  [UIWindowScene class]])
        {
            continue;
        }

        /*
         * Ép kiểu đúng trước khi truyền vào
         * SC16ApplyScene().
         */
        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        SC16ApplyScene(windowScene);
    }
}


#pragma mark - Scheduling

static void SC16ScheduleApply(void)
{
    if (!SC16Enabled())
        return;

    static BOOL scheduled =
        NO;

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

- (void)setWindowLevel:
    (UIWindowLevel)windowLevel
{
    %orig(windowLevel);

    if (SC16Enabled())
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

- (void)sceneWillEnterForeground
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

        /*
         * Chờ UIKit/Scene khởi tạo hoàn tất.
         */
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(
                    1.0 *
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
