#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>

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


#pragma mark - Scale

/*
 * Scale quanh chính giữa WINDOW.
 *
 * Không dùng:
 *   frame
 *   screen center
 *
 * Chỉ thay transform.
 */
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


#pragma mark - Crop Geometry

/*
 * Crop được tính RIÊNG với scale.
 *
 * SC16_CROP là số pixel muốn mất
 * ở màn hình sau khi scale.
 *
 * Vì scale = 0.96 nên source crop:
 *
 *     34 / 0.96
 *
 * Sau transform:
 *
 *     sourceCrop * 0.96 = 34px
 *
 * Như vậy crop không bị biến thành
 * ~35-36px ngoài ý muốn.
 */
static CGRect SC16MakeCropRect(CGRect bounds)
{
    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 ||
        height <= 0.0)
    {
        return CGRectZero;
    }

    CGFloat scale =
        SC16_SCALE;

    if (scale <= 0.0 ||
        scale > 1.0)
    {
        scale = 1.0;
    }

    CGFloat sourceCrop =
        SC16_CROP / scale;

    /*
     * PORTRAIT
     *
     * Cắt trên + dưới.
     */
    if (height > width)
    {
        CGFloat newHeight =
            height - (sourceCrop * 2.0);

        if (newHeight <= 0.0)
            return CGRectZero;

        return CGRectMake(
            CGRectGetMinX(bounds),
            CGRectGetMinY(bounds) + sourceCrop,
            width,
            newHeight
        );
    }

    /*
     * LANDSCAPE
     *
     * Cắt trái + phải.
     */
    CGFloat newWidth =
        width - (sourceCrop * 2.0);

    if (newWidth <= 0.0)
        return CGRectZero;

    return CGRectMake(
        CGRectGetMinX(bounds) + sourceCrop,
        CGRectGetMinY(bounds),
        newWidth,
        height
    );
}


#pragma mark - Crop Mask

/*
 * Áp dụng crop bằng mask trên WINDOW.
 *
 * Không thay:
 *   frame
 *   bounds
 *   center
 *
 * Crop là lớp riêng.
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
        SC16MakeCropRect(bounds);

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


#pragma mark - Apply Window

/*
 * Scale + Crop.
 *
 * Hai chức năng hoàn toàn tách riêng:
 *
 *   1. Crop mask
 *   2. Window transform
 */
static void SC16ApplyToWindow(UIWindow *window)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsUsableWindow(window))
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
     * Reset transform cũ TRỰC TIẾP.
     *
     * Không cần SC16ResetWindow().
     * Tránh lỗi unused-function.
     */
    window.transform =
        CGAffineTransformIdentity;

    /*
     * CROP
     *
     * Không phụ thuộc việc transform
     * có tồn tại hay không.
     */
    SC16ApplyCrop(window);

    /*
     * SCALE
     *
     * Áp dụng sau crop.
     */
    if (fabs(scale - 1.0) > 0.0001)
    {
        window.transform =
            SC16MakeScaleTransform(
                bounds,
                scale
            );
    }
}


#pragma mark - SpringBoard Window

static BOOL SC16IsRootSceneWindow(UIWindow *window)
{
    if (!window)
        return NO;

    NSString *name =
        NSStringFromClass(window.class);

    return [name isEqualToString:
                @"UIRootSceneWindow"];
}

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

    NSSet<UIScene *> *scenes =
        application.connectedScenes;

    for (UIScene *scene in scenes)
    {
        if (![scene isKindOfClass:
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
             * Ưu tiên root SpringBoard.
             */
            if (SC16IsRootSceneWindow(window))
            {
                return window;
            }

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
    if (!SC16Enabled())
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

    NSArray<UIWindow *> *windows =
        scene.windows;

    for (UIWindow *window in windows)
    {
        if (!SC16IsUsableWindow(window))
            continue;

        /*
         * Ưu tiên key window.
         */
        if (window.isKeyWindow)
        {
            return window;
        }

        if (!fallback)
        {
            fallback = window;
        }
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

    /*
     * SpringBoard.
     */
    if (SC16IsSpringBoard())
    {
        SC16ApplySpringBoard();
        return;
    }

    /*
     * Application.
     */
    SC16ApplyApplicationScene(scene);
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

    NSSet<UIScene *> *scenes =
        application.connectedScenes;

    for (UIScene *scene in scenes)
    {
        if (![scene isKindOfClass:
                  [UIWindowScene class]])
        {
            continue;
        }

        /*
         * QUAN TRỌNG:
         *
         * Không truyền UIScene *
         * vào hàm nhận UIWindowScene *.
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

    /*
     * Chống schedule liên tục.
     */
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
    {
        SC16ScheduleApply();
    }
}


- (void)setAlpha:(CGFloat)alpha
{
    %orig(alpha);

    if (!SC16Enabled())
        return;

    if (alpha > 0.0)
    {
        SC16ScheduleApply();
    }
}


%end


#pragma mark - UIWindowScene Hooks

/*
 * Không hook sceneDidBecomeActive trực tiếp.
 *
 * Thay vào đó dùng notification của UIKit,
 * vì UIWindowScene không phải scene delegate.
 */

#pragma mark - Constructor

%ctor
{
    @autoreleasepool
    {
        if (!SC16Enabled())
            return;

        /*
         * Đợi UIKit/SpringBoard dựng scene.
         */
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(
                    0.8 *
                    NSEC_PER_SEC
                )
            ),
            dispatch_get_main_queue(),
            ^{
                SC16ApplyAllScenes();
            }
        );

        /*
         * Window xuất hiện.
         */
        [[NSNotificationCenter defaultCenter]
            addObserverForName:
                UIWindowDidBecomeVisibleNotification
            object:nil
            queue:[NSOperationQueue mainQueue]
            usingBlock:
                ^(NSNotification *note)
                {
                    if (!SC16Enabled())
                        return;

                    UIWindow *window =
                        note.object;

                    if ([window isKindOfClass:
                             [UIWindow class]])
                    {
                        SC16ScheduleApply();
                    }
                }];

        /*
         * App/scene trở lại foreground.
         */
        [[NSNotificationCenter defaultCenter]
            addObserverForName:
                UIApplicationDidBecomeActiveNotification
            object:nil
            queue:[NSOperationQueue mainQueue]
            usingBlock:
                ^(NSNotification *note)
                {
                    if (!SC16Enabled())
                        return;

                    SC16ScheduleApply();
                }];

        /*
         * Scene được activate.
         */
        [[NSNotificationCenter defaultCenter]
            addObserverForName:
                UISceneDidActivateNotification
            object:nil
            queue:[NSOperationQueue mainQueue]
            usingBlock:
                ^(NSNotification *note)
                {
                    if (!SC16Enabled())
                        return;

                    SC16ScheduleApply();
                }];

        /*
         * Một số app tạo lại window sau khi
         * transition xong.
         *
         * Chạy thêm một lần sau một khoảng ngắn
         * để bắt window mới.
         */
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(
                    1.5 *
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
