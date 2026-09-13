#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Configuration

/*
 * Scale nội dung.
 *
 * 0.90 = 90%
 */
static const CGFloat SC16_SCALE = 0.90;

/*
 * Số pixel thực tế bị CẮT khỏi vùng hiển thị.
 *
 * Portrait:
 *     8px trên
 *     8px dưới
 *
 * Landscape:
 *     8px trái
 *     8px phải
 */
static const CGFloat SC16_CROP = 8.0;


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
 * Scale quanh tâm LOCAL của window.
 *
 * Không sử dụng frame.
 * Không thay bounds.
 * Không thay center.
 *
 * Với:
 *
 *     scale = 0.90
 *
 * tâm window vẫn giữ nguyên.
 */
static CGAffineTransform SC16CenteredTransform(
    CGRect bounds,
    CGFloat scale
)
{
    CGFloat cx =
        CGRectGetMidX(bounds);

    CGFloat cy =
        CGRectGetMidY(bounds);

    CGFloat tx =
        cx * (1.0 - scale);

    CGFloat ty =
        cy * (1.0 - scale);

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
 * Mask được tính theo coordinate space GỐC.
 *
 * Vì window sau đó scale 90%, muốn mất đúng
 * 8px trên màn hình thực tế thì source crop phải là:
 *
 *     8 / 0.90
 */
static CGRect SC16CropRect(CGRect bounds)
{
    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    CGFloat crop =
        SC16_CROP / SC16_SCALE;

    if (crop <= 0.0)
        return bounds;

    /*
     * Portrait:
     * cắt trên + dưới.
     */
    if (height > width)
    {
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

    /*
     * Landscape:
     * cắt trái + phải.
     */
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


#pragma mark - Crop

/*
 * Tạo clipping mask duy nhất cho window.
 *
 * Mask nằm trong cùng coordinate space với window.
 * Không thay frame / bounds / center.
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

    if (CGRectGetWidth(bounds) <= 0.0 ||
        CGRectGetHeight(bounds) <= 0.0)
    {
        return;
    }

    CGRect visible =
        SC16CropRect(bounds);

    if (CGRectIsEmpty(visible))
        return;

    CAShapeLayer *mask = nil;

    if ([layer.mask isKindOfClass:
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
            visible,
            NULL
        );

    mask.path =
        path;

    CGPathRelease(path);
}


#pragma mark - Window Apply

/*
 * Apply scale + crop.
 *
 * Thứ tự:
 *
 *     1. Reset transform
 *     2. Crop
 *     3. Scale quanh tâm
 *
 * Không cộng dồn transform.
 */
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

    if (CGRectGetWidth(bounds) <= 0.0 ||
        CGRectGetHeight(bounds) <= 0.0)
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
     * QUAN TRỌNG:
     *
     * luôn reset trước khi tính lại.
     *
     * Tránh:
     *
     *     0.90 x 0.90 x 0.90 ...
     */
    window.transform =
        CGAffineTransformIdentity;

    /*
     * Crop ở coordinate space gốc.
     */
    SC16ApplyCrop(window);

    /*
     * Scale toàn bộ window cùng một lần.
     *
     * Background + root view + subview + layer
     * sẽ đi cùng coordinate system của window.
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


#pragma mark - SpringBoard Root

/*
 * Tìm UIRootSceneWindow.
 *
 * Không scale toàn bộ UIWindow của SpringBoard.
 */
static UIWindow *SC16FindSpringBoardWindow(void)
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
             * Ưu tiên root window thật.
             */
            if (SC16IsRootSceneWindow(window))
                return window;

            /*
             * Fallback chỉ khi có root VC.
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


#pragma mark - Application Window

/*
 * Chỉ lấy window chính của app.
 *
 * Không scale hàng loạt window.
 */
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

        /*
         * Window có root VC làm fallback.
         */
        if (!fallback)
            fallback = window;
    }

    return fallback;
}


#pragma mark - Apply SpringBoard

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


#pragma mark - Apply Application

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
    }
    else
    {
        SC16ApplyApplicationScene(scene);
    }
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

/*
 * Chỉ schedule một lần trong cùng một vòng main queue.
 *
 * Không gọi lại từ setFrame/setBounds/layout.
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


#pragma mark - UIApplication

/*
 * Khi SpringBoard/app trở lại active,
 * apply lại window chính.
 */
%hook UIApplication

- (void)applicationDidBecomeActive:
    (UIApplication *)application
{
    %orig(application);

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
         * UIKit/SpringBoard cần thời gian tạo scene/window.
         */
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(
                    0.50 *
                    NSEC_PER_SEC
                )
            ),
            dispatch_get_main_queue(),
            ^{
                SC16ApplyAllScenes();
            }
        );

        /*
         * Một lần bổ sung để bắt root window được
         * tạo muộn sau quá trình khởi động.
         */
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(
                    1.50 *
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
