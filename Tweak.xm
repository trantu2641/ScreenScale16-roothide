#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Configuration

/*
 * Scale nội dung.
 *
 * 0.90 = 90%
 */
static CGFloat const SC16_SCALE = 0.90;

/*
 * Phần bị CẮT khỏi vùng hiển thị.
 *
 * Portrait:
 *     8px trên
 *     8px dưới
 *
 * Landscape:
 *     8px trái
 *     8px phải
 */
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

static BOOL SC16IsRootSceneWindow(UIWindow *window)
{
    if (!window)
        return NO;

    NSString *name =
        NSStringFromClass(window.class);

    return [name isEqualToString:@"UIRootSceneWindow"];
}


#pragma mark - Geometry

/*
 * Transform quanh TÂM CỦA WINDOW.
 *
 * Công thức:
 *
 * x' = center + scale * (x - center)
 * y' = center + scale * (y - center)
 *
 * Không dùng frame.
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


#pragma mark - Crop

/*
 * Tính vùng nhìn thấy.
 *
 * Lưu ý:
 *
 * SC16_CROP là số pixel muốn CẮT SAU KHI SCALE.
 *
 * Vì scale = 0.90 nên vùng crop trong
 * tọa độ nguồn phải chia cho scale.
 */
static CGRect SC16VisibleRect(
    CGRect bounds
)
{
    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    BOOL portrait =
        height > width;

    CGFloat crop =
        SC16_CROP / SC16_SCALE;

    if (portrait)
    {
        return CGRectMake(
            CGRectGetMinX(bounds),
            CGRectGetMinY(bounds) + crop,
            width,
            height - (crop * 2.0)
        );
    }

    return CGRectMake(
        CGRectGetMinX(bounds) + crop,
        CGRectGetMinY(bounds),
        width - (crop * 2.0),
        height
    );
}


#pragma mark - Crop Mask

/*
 * Mask chỉ cắt phần ngoài vùng hiển thị.
 *
 * KHÔNG thay:
 *     frame
 *     bounds
 *     center
 *
 * Chỉ dùng layer.mask.
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

    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 ||
        height <= 0.0)
    {
        return;
    }

    CGRect visibleRect =
        SC16VisibleRect(bounds);

    if (CGRectGetWidth(visibleRect) <= 0.0 ||
        CGRectGetHeight(visibleRect) <= 0.0)
    {
        return;
    }

    CAShapeLayer *mask =
        (CAShapeLayer *)layer.mask;

    if (![mask isKindOfClass:[CAShapeLayer class]])
    {
        mask = [CAShapeLayer layer];
        layer.mask = mask;
    }

    mask.frame =
        bounds;

    CGPathRef path =
        CGPathCreateWithRect(
            visibleRect,
            NULL
        );

    mask.path =
        path;

    CGPathRelease(path);
}


#pragma mark - Remove Crop

static void SC16RemoveCropMask(UIWindow *window)
{
    if (!window)
        return;

    CALayer *layer =
        window.layer;

    if (!layer)
        return;

    layer.mask = nil;
}


#pragma mark - Apply Root Window

/*
 * Đây là phần chính.
 *
 * Chỉ transform ROOT WINDOW.
 *
 * Không transform:
 *     rootView
 *     subview
 *     background layer
 *     từng UI element
 *
 * Vì vậy toàn bộ nội dung bên trong window
 * giữ nguyên quan hệ tọa độ với nhau.
 */
static void SC16ApplyRootWindow(
    UIWindow *window
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
     * Reset trước khi tính lại.
     *
     * Quan trọng:
     * không để transform bị nhân chồng.
     */
    window.transform =
        CGAffineTransformIdentity;

    /*
     * Crop được đặt theo bounds gốc.
     */
    SC16ApplyCropMask(window);

    /*
     * Scale quanh đúng tâm WINDOW.
     */
    if (fabs(scale - 1.0) > 0.0001)
    {
        window.transform =
            SC16CenteredTransform(
                bounds,
                scale
            );
    }
}


#pragma mark - Find SpringBoard Root

static UIWindow *SC16FindRootWindow(void)
{
    if (!SC16IsSpringBoard())
        return nil;

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
            if (!window)
                continue;

            if (window.hidden)
                continue;

            if (window.alpha <= 0.0)
                continue;

            if (SC16IsKeyboardWindow(window))
                continue;

            /*
             * Ưu tiên chính xác UIRootSceneWindow.
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


#pragma mark - SpringBoard

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

    /*
     * CHỈ root window.
     *
     * Không scale từng window.
     */
    SC16ApplyRootWindow(rootWindow);
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

    /*
     * App cũng chỉ scale WINDOW GỐC.
     *
     * Không đụng rootView.
     */
    SC16ApplyRootWindow(window);
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

static void SC16ScheduleApply(void)
{
    if (!SC16Enabled())
        return;

    /*
     * Chỉ schedule một lần trong mỗi
     * vòng main queue.
     */
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
         * Đợi UIKit/SpringBoard tạo scene.
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
