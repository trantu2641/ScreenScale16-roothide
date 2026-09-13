#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>

#pragma mark - Configuration

/*
 * 90% giống cơ chế scale của OneHand.
 */
static CGFloat const SC16_SCALE = 0.90;

/*
 * Crop thực tế trên màn hình.
 *
 * Vì layer được scale 90%, crop source phải là:
 *
 *     8 / 0.90 = 8.888...
 *
 * để sau scale còn đúng khoảng 8px.
 */
static CGFloat const SC16_CROP = 8.0;

/*
 * Chỉ chạy iOS 16.
 */
static BOOL SC16Enabled(void)
{
    NSString *version =
        UIDevice.currentDevice.systemVersion;

    return [version hasPrefix:@"16."];
}

#pragma mark - SpringBoard

static BOOL SC16IsSpringBoard(void)
{
    NSString *bundleID =
        NSBundle.mainBundle.bundleIdentifier;

    return [bundleID isEqualToString:
                @"com.apple.springboard"];
}

#pragma mark - Window Detection

/*
 * OneHand dùng UIRootSceneWindow.
 *
 * Không xử lý hàng loạt UIWindow.
 */
static BOOL SC16IsRootSceneWindow(UIWindow *window)
{
    if (!window)
        return NO;

    NSString *name =
        NSStringFromClass(window.class);

    return [name isEqualToString:
                @"UIRootSceneWindow"];
}

/*
 * Không đụng keyboard.
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

#pragma mark - Root Window

/*
 * Tìm đúng root window của SpringBoard.
 *
 * Không dùng hard-code pointer.
 * Không lấy keyWindow của app.
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

        NSArray<UIWindow *> *windows =
            windowScene.windows;

        /*
         * Ưu tiên chính xác UIRootSceneWindow.
         */
        for (UIWindow *window in windows)
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
        }

        /*
         * Fallback cực hạn chế.
         *
         * Không dùng keyWindow của app.
         */
        for (UIWindow *window in windows)
        {
            if (!window)
                continue;

            if (window.hidden)
                continue;

            if (window.alpha <= 0.0)
                continue;

            if (SC16IsKeyboardWindow(window))
                continue;

            if (window.rootViewController)
            {
                if (!fallback)
                    fallback = window;
            }
        }
    }

    return fallback;
}

#pragma mark - Layer Transform

/*
 * QUAN TRỌNG:
 *
 * Không dùng:
 *
 *     window.transform
 *
 * Không dùng:
 *
 *     CGAffineTransformMake(... tx ty ...)
 *
 * OneHand dùng layer.transform.
 *
 * CATransform3DMakeScale() scale quanh anchorPoint
 * của layer, mặc định là tâm (0.5, 0.5).
 *
 * Vì vậy không cộng thêm tx / ty.
 */
static void SC16ApplyLayerScale(
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

    CGFloat scale =
        SC16_SCALE;

    if (scale <= 0.0 ||
        scale > 1.0)
    {
        scale = 1.0;
    }

    /*
     * Đây là điểm khác biệt quan trọng
     * so với bản Tweak.xm lỗi trước.
     *
     * Chỉ thay layer.transform.
     */
    layer.transform =
        CATransform3DMakeScale(
            scale,
            scale,
            1.0
        );
}

#pragma mark - Crop

/*
 * Crop 8px sau khi scale.
 *
 * Không thay frame.
 * Không thay bounds.
 * Không thay center.
 * Không thay rotation.
 */
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

    /*
     * Crop tính ngược lại trước scale.
     */
    CGFloat crop =
        SC16_CROP / SC16_SCALE;

    BOOL portrait =
        height > width;

    CGRect visibleRect =
        bounds;

    if (portrait)
    {
        visibleRect.origin.y += crop;
        visibleRect.size.height -=
            crop * 2.0;
    }
    else
    {
        visibleRect.origin.x += crop;
        visibleRect.size.width -=
            crop * 2.0;
    }

    if (visibleRect.size.width <= 0.0 ||
        visibleRect.size.height <= 0.0)
    {
        return;
    }

    /*
     * Tái sử dụng mask.
     *
     * Không tạo mask mới liên tục.
     */
    CAShapeLayer *mask = nil;

    if ([layer.mask
         isKindOfClass:
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
            visibleRect,
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

    CALayer *layer =
        window.layer;

    if (!layer)
        return;

    /*
     * Chỉ reset transform của chính root layer.
     */
    layer.transform =
        CATransform3DIdentity;

    /*
     * Xóa mask do tweak tạo.
     */
    layer.mask = nil;
}

#pragma mark - Apply

static void SC16ApplyRootWindow(void)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    UIWindow *window =
        SC16FindRootWindow();

    if (!window)
        return;

    /*
     * Tuyệt đối không:
     *
     * - setFrame
     * - setBounds
     * - setCenter
     * - window.transform
     * - đổi rotation
     *
     * Chỉ tác động render layer.
     */

    SC16ApplyLayerScale(window);

    SC16ApplyCrop(window);
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

            SC16ApplyRootWindow();
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

    /*
     * Đợi UIKit hoàn tất việc tạo window.
     */
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

- (void)setRootViewController:
    (UIViewController *)rootViewController
{
    %orig(rootViewController);

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

%end

#pragma mark - Constructor

%ctor
{
    @autoreleasepool
    {
        /*
         * Không load vào app.
         */
        if (!SC16Enabled())
            return;

        if (!SC16IsSpringBoard())
            return;

        /*
         * Chờ SpringBoard tạo UIRootSceneWindow.
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
                SC16ApplyRootWindow();
            }
        );
    }
}
