#import <UIKit/UIKit.h>

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
 * Không dùng mask/crop layer.
 */

static CGFloat const SC16_CROP = 34.0;
static CGFloat const SC16_EPSILON = 0.0001;

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
     * Không scale keyboard.
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
     * Không scale Status Bar window.
     * Status Bar được ẩn riêng bằng
     * prefersStatusBarHidden.
     */
    if ([name containsString:@"StatusBar"])
        return YES;

    if ([name containsString:@"_UIStatusBar"])
        return YES;

    return NO;
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

    UIView *view =
        root.view;

    if (!view)
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
     * Lấy orientation dựa trên kích thước
     * thực tế của window.
     */
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
     * Nếu transform hiện tại đã đúng scale
     * thì không apply lại.
     *
     * Điều này cũng giúp tránh transform
     * chồng lên nhau.
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

    if (fabs(currentScaleX - scale) <
            SC16_EPSILON &&
        fabs(currentScaleY - scale) <
            SC16_EPSILON)
    {
        return;
    }

    /*
     * Giữ nguyên tâm UI.
     *
     * Không dịch UI lên/xuống.
     * Không dịch UI trái/phải.
     */
    CGPoint center =
        view.center;

    /*
     * Reset transform trước khi tính lại.
     * Quan trọng khi xoay Portrait/Landscape.
     */
    view.transform =
        CGAffineTransformIdentity;

    /*
     * SCALE toàn bộ root UI.
     */
    view.transform =
        CGAffineTransformMakeScale(
            scale,
            scale
        );

    /*
     * Giữ tâm.
     */
    view.center =
        center;
}

#pragma mark - Safe Apply

static void SC16ApplyWindowSafely(UIWindow *window)
{
    if (!SC16Enabled())
        return;

    if (!window)
        return;

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

#pragma mark - Apply All Windows

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

#pragma mark - Rotation

static void SC16OrientationChanged(void)
{
    if (!SC16Enabled())
        return;

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

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplyScale(self);
        }
    );
}

%end

#pragma mark - Status Bar

%hook UIViewController

/*
 * Chỉ ẩn Status Bar.
 *
 * Không ẩn Home Bar.
 * Không transform UIViewController ở hook này.
 */
- (BOOL)prefersStatusBarHidden
{
    if (SC16Enabled())
        return YES;

    return %orig;
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
         * Không đụng UIKit ngay lập tức trong
         * constructor.
         */
        dispatch_async(
            dispatch_get_main_queue(),
            ^{
                /*
                 * Apply sau khi UIKit đã khởi tạo.
                 */
                SC16ApplyAllWindows();

                /*
                 * Apply lại sau khi layout ổn định.
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
                    queue:
                        [NSOperationQueue mainQueue]
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
