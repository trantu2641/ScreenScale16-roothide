#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Configuration

/*
 * ScreenScale16
 *
 * Portrait:
 *   34px phía trên
 *   34px phía dưới
 *
 * Landscape:
 *   34px bên trái
 *   34px bên phải
 *
 * Đây là SCALE toàn bộ UI.
 * Không dùng mask để che màn hình.
 */

static CGFloat const SC16_CROP = 34.0;
static CGFloat const SC16_SCALE_EPSILON = 0.0001;

#pragma mark - Enable

static BOOL SC16Enabled(void)
{
    NSString *version = UIDevice.currentDevice.systemVersion;

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

    NSString *name = NSStringFromClass(window.class);

    /*
     * Keyboard
     */
    if ([name containsString:@"UITextEffectsWindow"])
        return YES;

    if ([name containsString:@"UIRemoteKeyboardWindow"])
        return YES;

    if ([name containsString:@"KeyboardWindow"])
        return YES;

    if ([name containsString:@"Keyboard"])
        return YES;

    /*
     * Status bar window.
     *
     * Status Bar được xử lý riêng bằng
     * prefersStatusBarHidden.
     */
    if ([name containsString:@"StatusBar"])
        return YES;

    if ([name containsString:@"_UIStatusBar"])
        return YES;

    /*
     * Một số window hệ thống không nên transform.
     */
    if ([name containsString:@"UITextEffects"])
        return YES;

    if ([name containsString:@"UIRemoteKeyboard"])
        return YES;

    return NO;
}

#pragma mark - Scale State

/*
 * Lưu trạng thái transform riêng cho từng UIWindow.
 *
 * Không dùng associated object phức tạp để tránh
 * tạo thêm dependency/runtime hook không cần thiết.
 */

static NSHashTable *SC16ScaledWindows(void)
{
    static NSHashTable *table = nil;

    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        table = [NSHashTable
                 weakObjectsHashTable];
    });

    return table;
}

static BOOL SC16WindowWasScaled(UIWindow *window)
{
    if (!window)
        return NO;

    return [SC16ScaledWindows()
            containsObject:window];
}

static void SC16MarkWindowScaled(UIWindow *window)
{
    if (!window)
        return;

    [SC16ScaledWindows()
        addObject:window];
}

#pragma mark - Apply Scale

static void SC16ApplyScale(UIWindow *window)
{
    if (!SC16Enabled())
        return;

    if (SC16ShouldSkipWindow(window))
        return;

    UIViewController *root =
        window.rootViewController;

    if (!root)
        return;

    UIView *view = root.view;

    if (!view)
        return;

    CGRect bounds = window.bounds;

    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 ||
        height <= 0.0)
    {
        return;
    }

    BOOL portrait =
        (height > width);

    CGFloat scale = 1.0;

    /*
     * PORTRAIT
     *
     * 34px trên
     * 34px dưới
     */
    if (portrait)
    {
        CGFloat availableHeight =
            height - (SC16_CROP * 2.0);

        if (availableHeight <= 0.0)
            return;

        scale =
            availableHeight / height;
    }

    /*
     * LANDSCAPE
     *
     * 34px trái
     * 34px phải
     */
    else
    {
        CGFloat availableWidth =
            width - (SC16_CROP * 2.0);

        if (availableWidth <= 0.0)
            return;

        scale =
            availableWidth / width;
    }

    if (scale <= 0.0 ||
        scale > 1.0)
    {
        return;
    }

    /*
     * Nếu kích thước/orientation không thay đổi
     * thì không apply lại transform.
     */
    CGAffineTransform current =
        view.transform;

    CGFloat currentScaleX =
        sqrt(
            current.a * current.a +
            current.c * current.c
        );

    CGFloat currentScaleY =
        sqrt(
            current.b * current.b +
            current.d * current.d
        );

    if (fabs(currentScaleX - scale)
            < SC16_SCALE_EPSILON &&
        fabs(currentScaleY - scale)
            < SC16_SCALE_EPSILON)
    {
        SC16MarkWindowScaled(window);
        return;
    }

    /*
     * Giữ nguyên tâm của UI.
     *
     * Không dịch UI lên/xuống.
     * Không dịch UI trái/phải.
     */
    CGPoint center = view.center;

    /*
     * Reset transform trước khi tính lại.
     *
     * Quan trọng khi xoay portrait <-> landscape.
     */
    view.transform =
        CGAffineTransformIdentity;

    /*
     * SCALE thu nhỏ toàn bộ root UI.
     */
    view.transform =
        CGAffineTransformMakeScale(
            scale,
            scale
        );

    /*
     * Giữ vị trí trung tâm.
     */
    view.center = center;

    SC16MarkWindowScaled(window);
}

#pragma mark - Apply Window Safely

static void SC16ApplyWindowSafely(UIWindow *window)
{
    if (!SC16Enabled())
        return;

    if (!window)
        return;

    /*
     * Chỉ chạy khi UIKit đã hoàn thành layout.
     */
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            if (!window)
                return;

            if (window.hidden)
                return;

            SC16ApplyScale(window);
        }
    );
}

#pragma mark - Apply All Application Windows

static void SC16ApplyAllWindows(void)
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

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        if (windowScene.activationState ==
            UISceneActivationStateUnattached)
        {
            continue;
        }

        NSArray<UIWindow *> *windows =
            windowScene.windows;

        for (UIWindow *window in windows)
        {
            if (SC16ShouldSkipWindow(window))
                continue;

            SC16ApplyWindowSafely(window);
        }
    }
}

#pragma mark - Orientation

static void SC16OrientationChanged(void)
{
    if (!SC16Enabled())
        return;

    /*
     * Khi xoay màn hình, UIKit thay đổi bounds
     * rồi mới tính lại scale.
     */
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplyAllWindows();
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

    SC16ApplyWindowSafely(self);
}

- (void)setRootViewController:
    (UIViewController *)rootViewController
{
    %orig(rootViewController);

    if (!SC16Enabled())
        return;

    /*
     * Đợi root view được tạo/layout xong.
     */
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplyScale(self);
        }
    );
}

%end

#pragma mark - UIViewController

%hook UIViewController

/*
 * Chỉ ẩn Status Bar.
 *
 * Không ẩn Home Bar.
 * Không transform UIViewController ở đây.
 */
- (BOOL)prefersStatusBarHidden
{
    if (SC16Enabled())
        return YES;

    return %orig;
}

%end

#pragma mark - UIApplication

%hook UIApplication

- (void)_didFinishLaunching
{
    %orig;

    if (!SC16Enabled())
        return;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplyAllWindows();
        }
    );
}

%end

#pragma mark - Rotation Notification

%ctor
{
    @autoreleasepool
    {
        if (!SC16Enabled())
            return;

        /*
         * Không apply ngay trong constructor.
         *
         * Tránh đụng UIKit quá sớm.
         */
        dispatch_async(
            dispatch_get_main_queue(),
            ^{
                /*
                 * UIKit đã khởi tạo.
                 */
                SC16ApplyAllWindows();

                /*
                 * Cho layout ổn định rồi apply lần nữa.
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
                        SC16ApplyAllWindows();
                    }
                );

                /*
                 * Theo dõi xoay màn hình.
                 */
                [[NSNotificationCenter defaultCenter]
                    addObserverForName:
                        UIDeviceOrientationDidChangeNotification
                    object:nil
                    queue:[NSOperationQueue mainQueue]
                    usingBlock:
                    ^(NSNotification *notification)
                    {
                        (void)notification;

                        SC16OrientationChanged();
                    }];
            }
        );
    }
}
