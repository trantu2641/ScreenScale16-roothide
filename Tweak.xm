#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

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
 *     34px trên
 *     34px dưới
 *
 * Landscape:
 *     34px trái
 *     34px phải
 */
static CGFloat const SC16_CROP = 34.0;


#pragma mark - Process

static BOOL SC16IsEnabled(void)
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

    NSString *className =
        NSStringFromClass(window.class);

    if ([className containsString:@"Keyboard"])
        return YES;

    if ([className containsString:@"UITextEffects"])
        return YES;

    if ([className containsString:@"UIRemoteKeyboard"])
        return YES;

    if ([className containsString:@"UIInput"])
        return YES;

    return NO;
}

static BOOL SC16IsRootSceneWindow(UIWindow *window)
{
    if (!window)
        return NO;

    NSString *className =
        NSStringFromClass(window.class);

    return [className isEqualToString:
                @"UIRootSceneWindow"];
}


#pragma mark - Geometry

/*
 * SCALE CHỈ SCALE.
 *
 * Không tự tính translation.
 *
 * UIView transform được áp dụng quanh center
 * của chính UIView/window.
 *
 * Đây là điểm quan trọng để tránh:
 *
 * - lệch trái
 * - lệch phải
 * - lệch trên
 * - lệch dưới
 * - background đi một nơi
 * - content đi một nơi
 */
static CGAffineTransform SC16ScaleTransform(CGFloat scale)
{
    return CGAffineTransformMakeScale(
        scale,
        scale
    );
}


/*
 * Crop là một hệ riêng.
 *
 * Mask được tạo trong tọa độ gốc của window.
 *
 * Vì toàn bộ window sau đó scale xuống 96%,
 * để phần crop cuối cùng trên màn hình vẫn
 * đúng 34px thì crop source phải bù scale:
 *
 *     34 / 0.96
 *
 * Crop không được dùng để tính scale.
 */
static CGRect SC16CropRect(CGRect bounds)
{
    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    BOOL portrait =
        height > width;

    CGFloat sourceCrop =
        SC16_CROP / SC16_SCALE;

    if (portrait)
    {
        return CGRectMake(
            CGRectGetMinX(bounds),
            CGRectGetMinY(bounds) + sourceCrop,
            width,
            height - (sourceCrop * 2.0)
        );
    }

    return CGRectMake(
        CGRectGetMinX(bounds) + sourceCrop,
        CGRectGetMinY(bounds),
        width - (sourceCrop * 2.0),
        height
    );
}


#pragma mark - Crop

/*
 * Tạo mask CROP riêng.
 *
 * Không thay:
 *
 * - frame
 * - bounds
 * - center
 * - position
 * - rootViewController
 *
 * Chỉ giới hạn vùng được render của window.
 */
static void SC16ApplyCrop(UIWindow *window)
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

    if (CGRectGetWidth(cropRect) <= 0.0 ||
        CGRectGetHeight(cropRect) <= 0.0)
    {
        return;
    }

    /*
     * Tạo một CAShapeLayer duy nhất.
     *
     * Không tạo mask mới liên tục.
     */
    CAShapeLayer *mask =
        (CAShapeLayer *)layer.mask;

    if (![mask isKindOfClass:
              [CAShapeLayer class]])
    {
        mask = [CAShapeLayer layer];

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


#pragma mark - Apply

static void SC16ApplyToWindow(UIWindow *window)
{
    if (!window)
        return;

    if (window.hidden)
        return;

    if (window.alpha <= 0.0)
        return;

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

    CGFloat scale =
        SC16_SCALE;

    if (scale <= 0.0 ||
        scale > 1.0)
    {
        scale = 1.0;
    }

    /*
     * RESET trước để tránh scale chồng.
     */
    window.transform =
        CGAffineTransformIdentity;

    /*
     * CROP hoàn toàn độc lập.
     *
     * Không dùng crop để tính transform.
     */
    SC16ApplyCrop(window);

    /*
     * SCALE hoàn toàn độc lập.
     *
     * CGAffineTransformMakeScale()
     * tự scale quanh tâm của window.
     *
     * Không cộng tx / ty.
     */
    if (fabs(scale - 1.0) > 0.0001)
    {
        window.transform =
            SC16ScaleTransform(scale);
    }
}


#pragma mark - SpringBoard Window

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

            /*
             * Ưu tiên đúng UIRootSceneWindow.
             */
            if (SC16IsRootSceneWindow(window))
                return window;

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
    if (!SC16IsEnabled())
        return;

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

    /*
     * SpringBoard:
     *
     * Chỉ xử lý root window.
     */
    if (SC16IsSpringBoard())
    {
        SC16ApplySpringBoard();
        return;
    }

    /*
     * App:
     *
     * Chỉ xử lý window chính.
     */
    SC16ApplyApplicationScene(scene);
}


#pragma mark - Apply All Scenes

static void SC16ApplyAllScenes(void)
{
    if (!SC16IsEnabled())
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

static void SC16ScheduleApply(void)
{
    if (!SC16IsEnabled())
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

    if (!SC16IsEnabled())
        return;

    SC16ScheduleApply();
}

- (void)setRootViewController:
    (UIViewController *)rootViewController
{
    %orig(rootViewController);

    if (!SC16IsEnabled())
        return;

    SC16ScheduleApply();
}

- (void)setHidden:(BOOL)hidden
{
    %orig(hidden);

    if (!SC16IsEnabled())
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

    if (!SC16IsEnabled())
        return;

    SC16ScheduleApply();
}

%end


#pragma mark - Constructor

%ctor
{
    @autoreleasepool
    {
        if (!SC16IsEnabled())
            return;

        /*
         * Chờ UIKit/SpringBoard dựng scene xong.
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
