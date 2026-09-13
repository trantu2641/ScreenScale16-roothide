#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Configuration

/*
 * Portrait:
 *   Trên 34px
 *   Dưới 34px
 *
 * Không dùng phần này để dịch UI.
 */
static CGFloat const SC16_CROP_TOP = 34.0;
static CGFloat const SC16_CROP_BOTTOM = 34.0;

/*
 * Scale toàn bộ nội dung.
 *
 * 1.00 = kích thước gốc
 * 0.90 = thu nhỏ 90%
 */
static CGFloat const SC16_SCALE = 0.90;

#pragma mark - Enable

static BOOL SC16Enabled(void)
{
    NSString *version =
        UIDevice.currentDevice.systemVersion;

    return [version hasPrefix:@"16."];
}

#pragma mark - Window Filter

static BOOL SC16ShouldSkipWindow(UIWindow *window)
{
    if (!window)
        return YES;

    if (window.hidden)
        return YES;

    if (window.alpha <= 0.0)
        return YES;

    NSString *name =
        NSStringFromClass(window.class);

    /*
     * Keyboard.
     */
    if ([name containsString:@"UITextEffectsWindow"])
        return YES;

    if ([name containsString:@"UIRemoteKeyboardWindow"])
        return YES;

    if ([name containsString:@"Keyboard"])
        return YES;

    if ([name containsString:@"KeyboardWindow"])
        return YES;

    /*
     * Status bar.
     *
     * Bản này không xử lý/scale status bar window.
     */
    if ([name containsString:@"StatusBar"])
        return YES;

    if ([name containsString:@"_UIStatusBar"])
        return YES;

    /*
     * Alert.
     */
    if ([name containsString:@"Alert"])
        return YES;

    if ([name containsString:@"UIAlert"])
        return YES;

    return NO;
}

#pragma mark - Status Bar

static void SC16HideStatusBar(void)
{
    UIApplication *application =
        UIApplication.sharedApplication;

    if (!application)
        return;

    for (UIScene *scene in application.connectedScenes)
    {
        if (![scene
              isKindOfClass:[UIWindowScene class]])
        {
            continue;
        }

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        if (!windowScene.windows.count)
            continue;

        /*
         * Không đụng geometry.
         *
         * Chỉ yêu cầu scene không hiển thị status bar.
         */
        UIViewController *rootController = nil;

        for (UIWindow *window in windowScene.windows)
        {
            if (window.hidden)
                continue;

            if (window.rootViewController)
            {
                rootController =
                    window.rootViewController;
                break;
            }
        }

        if (!rootController)
            continue;

        [rootController setNeedsStatusBarAppearanceUpdate];
    }
}

#pragma mark - Scale + Crop

static void SC16ApplyScale(UIWindow *window)
{
    if (!SC16Enabled())
        return;

    if (SC16ShouldSkipWindow(window))
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
     * Xác định orientation dựa trên
     * bounds hiện tại của window.
     *
     * Không dùng frame cũ.
     */
    BOOL portrait =
        height > width;

    /*
     * Crop 34px trên/dưới ở portrait.
     *
     * Landscape:
     * không crop trái/phải trong bản scale này.
     */
    CGFloat top = 0.0;
    CGFloat bottom = 0.0;

    if (portrait)
    {
        top = SC16_CROP_TOP;
        bottom = SC16_CROP_BOTTOM;
    }

    CGFloat usableWidth =
        width;

    CGFloat usableHeight =
        height - top - bottom;

    if (usableWidth <= 0.0 ||
        usableHeight <= 0.0)
    {
        return;
    }

    /*
     * Dùng layer mask để giới hạn vùng render.
     *
     * Không tạo UIView che.
     */
    CALayer *layer =
        window.layer;

    layer.mask = nil;

    CAShapeLayer *mask =
        [CAShapeLayer layer];

    mask.frame =
        bounds;

    CGRect visibleRect =
        CGRectMake(
            CGRectGetMinX(bounds),
            CGRectGetMinY(bounds) + top,
            usableWidth,
            usableHeight
        );

    CGPathRef path =
        CGPathCreateWithRect(
            visibleRect,
            NULL
        );

    mask.path =
        path;

    CGPathRelease(path);

    layer.mask =
        mask;

    /*
     * Scale nội dung.
     *
     * Không thay:
     * - frame
     * - bounds
     * - center
     * - safeAreaInsets
     *
     * Vì vậy không tạo offset UI.
     */
    CGFloat scale =
        SC16_SCALE;

    if (scale <= 0.0)
        scale = 1.0;

    if (scale > 1.0)
        scale = 1.0;

    /*
     * Scale quanh tâm vùng hiển thị.
     */
    CGFloat centerX =
        CGRectGetMidX(visibleRect);

    CGFloat centerY =
        CGRectGetMidY(visibleRect);

    CGFloat windowCenterX =
        CGRectGetMidX(bounds);

    CGFloat windowCenterY =
        CGRectGetMidY(bounds);

    CGFloat offsetX =
        centerX - windowCenterX;

    CGFloat offsetY =
        centerY - windowCenterY;

    CATransform3D transform =
        CATransform3DIdentity;

    transform =
        CATransform3DTranslate(
            transform,
            offsetX,
            offsetY,
            0.0
        );

    transform =
        CATransform3DScale(
            transform,
            scale,
            scale,
            1.0
        );

    transform =
        CATransform3DTranslate(
            transform,
            -offsetX,
            -offsetY,
            0.0
        );

    layer.sublayerTransform =
        transform;
}

#pragma mark - Scene

static void SC16ApplyScene(UIWindowScene *scene)
{
    if (!SC16Enabled())
        return;

    if (!scene)
        return;

    if (scene.activationState ==
        UISceneActivationStateUnattached)
    {
        return;
    }

    NSArray<UIWindow *> *windows =
        scene.windows;

    for (UIWindow *window in windows)
    {
        if (!window)
            continue;

        SC16ApplyScale(window);
    }
}

#pragma mark - All Scenes

static void SC16ApplyAllScenes(void)
{
    if (!SC16Enabled())
        return;

    UIApplication *application =
        UIApplication.sharedApplication;

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

    SC16HideStatusBar();
}

#pragma mark - Delayed Apply

static void SC16ApplyDelayed(void)
{
    if (!SC16Enabled())
        return;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplyAllScenes();

            /*
             * UIKit có thể cập nhật bounds
             * sau lifecycle hiện tại.
             */
            dispatch_after(
                dispatch_time(
                    DISPATCH_TIME_NOW,
                    (int64_t)(
                        0.25 *
                        NSEC_PER_SEC
                    )
                ),
                dispatch_get_main_queue(),
                ^{
                    SC16ApplyAllScenes();
                }
            );
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

    SC16ApplyDelayed();
}

- (void)setHidden:(BOOL)hidden
{
    %orig(hidden);

    if (!SC16Enabled())
        return;

    if (hidden)
        return;

    SC16ApplyDelayed();
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
         * Đợi UIKit khởi tạo scene/window.
         */
        dispatch_async(
            dispatch_get_main_queue(),
            ^{
                SC16ApplyDelayed();
            }
        );
    }
}
