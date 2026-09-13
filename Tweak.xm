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
 * Phần bị CẮT KHỎI VÙNG HIỂN THỊ.
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
 * Transform quanh đúng TÂM CỦA WINDOW.
 *
 * Không giả định bounds.origin = (0,0).
 *
 * Đây là điểm quan trọng để tránh bị lệch tâm.
 */
static CGAffineTransform SC16CenteredTransform(
    CGRect bounds,
    CGFloat scale
)
{
    CGPoint center =
        CGPointMake(
            CGRectGetMidX(bounds),
            CGRectGetMidY(bounds)
        );

    CGFloat tx =
        center.x * (1.0 - scale);

    CGFloat ty =
        center.y * (1.0 - scale);

    return CGAffineTransformMake(
        scale,
        0.0,
        0.0,
        scale,
        tx,
        ty
    );
}


/*
 * Tính vùng nội dung sau khi crop.
 *
 * Crop được tính trong tọa độ gốc trước transform
 * để sau khi scale vẫn mất đúng khoảng mong muốn.
 */
static CGRect SC16CropRectForBounds(CGRect bounds)
{
    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    BOOL portrait =
        height > width;

    /*
     * Vì nội dung còn được scale 0.90,
     * muốn phần hiển thị cuối cùng mất đúng 8px
     * thì crop trong tọa độ trước scale phải là:
     *
     *     8 / 0.90
     */
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


#pragma mark - Crop Mask

/*
 * Mask chỉ giữ lại vùng CONTENT.
 *
 * Không thay frame.
 * Không thay bounds.
 * Không thay center.
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

    CGRect cropRect =
        SC16CropRectForBounds(bounds);

    if (CGRectGetWidth(cropRect) <= 0.0 ||
        CGRectGetHeight(cropRect) <= 0.0)
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


/*
 * Xóa mask khi cần.
 */
static void SC16RemoveCropMask(UIWindow *window)
{
    if (!window)
        return;

    window.layer.mask = nil;
}


#pragma mark - Root Window

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
             * Ưu tiên UIRootSceneWindow.
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


#pragma mark - Apply Window

static void SC16ApplyWindow(
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
     * Nếu scale = 1 thì reset.
     */
    if (fabs(scale - 1.0) < 0.0001)
    {
        window.transform =
            CGAffineTransformIdentity;

        SC16RemoveCropMask(window);

        return;
    }

    /*
     * Scale quanh tâm WINDOW.
     *
     * Không sử dụng frame.
     * Không sử dụng screen center giả định.
     */
    window.transform =
        SC16CenteredTransform(
            bounds,
            scale
        );

    /*
     * Cắt vùng 8px.
     */
    SC16ApplyCropMask(window);
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

    SC16ApplyWindow(rootWindow);
}


#pragma mark - Application

static void SC16ApplyApplicationScene(
    UIWindowScene *scene
)
{
    if (!scene)
        return;

    NSArray<UIWindow *> *windows =
        scene.windows;

    /*
     * Chỉ xử lý window ứng dụng chính.
     *
     * Không đụng keyboard / system window.
     */
    UIWindow *target = nil;

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

        if (!window.rootViewController)
            continue;

        /*
         * Ưu tiên keyWindow.
         */
        if (window.isKeyWindow)
        {
            target = window;
            break;
        }

        if (!target)
            target = window;
    }

    if (target)
        SC16ApplyWindow(target);
}


#pragma mark - Apply Scene

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


#pragma mark - Safe Scheduling

static void SC16ScheduleApply(void)
{
    if (!SC16Enabled())
        return;

    /*
     * Chống gọi lặp.
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
         * Đợi UIKit/SpringBoard khởi tạo scene.
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
