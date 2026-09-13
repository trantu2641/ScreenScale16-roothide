#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Configuration

static const CGFloat SC16_MARGIN = 34.0;

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

    if (!window.rootViewController)
        return YES;

    NSString *className =
        NSStringFromClass(window.class);

    /*
     * Keyboard.
     */
    if ([className containsString:@"UITextEffectsWindow"])
        return YES;

    if ([className containsString:@"UIRemoteKeyboardWindow"])
        return YES;

    if ([className containsString:@"KeyboardWindow"])
        return YES;

    if ([className containsString:@"Keyboard"])
        return YES;

    /*
     * Status bar window.
     */
    if ([className containsString:@"StatusBar"])
        return YES;

    if ([className containsString:@"_UIStatusBar"])
        return YES;

    /*
     * Không scale alert/system windows.
     */
    if ([className containsString:@"TextEffects"])
        return YES;

    return NO;
}

#pragma mark - Scale

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

    if (width <= 0.0 || height <= 0.0)
        return;

    /*
     * Reset trước khi tính scale mới.
     * Tránh scale chồng khi xoay màn hình.
     */
    view.transform =
        CGAffineTransformIdentity;

    /*
     * Lấy tâm màn hình.
     */
    CGPoint center =
        CGPointMake(
            CGRectGetMidX(bounds),
            CGRectGetMidY(bounds)
        );

    CGFloat scale = 1.0;

    /*
     * Portrait:
     *
     * 34px trên
     * 34px dưới
     */
    if (height > width)
    {
        CGFloat usableHeight =
            height - (SC16_MARGIN * 2.0);

        if (usableHeight <= 0.0)
            return;

        scale =
            usableHeight / height;
    }
    /*
     * Landscape:
     *
     * 34px trái
     * 34px phải
     */
    else
    {
        CGFloat usableWidth =
            width - (SC16_MARGIN * 2.0);

        if (usableWidth <= 0.0)
            return;

        scale =
            usableWidth / width;
    }

    if (scale <= 0.0)
        return;

    if (scale > 1.0)
        scale = 1.0;

    /*
     * Scale root UI.
     */
    view.transform =
        CGAffineTransformMakeScale(
            scale,
            scale
        );

    /*
     * Căn chính giữa màn hình.
     *
     * Không có +10 / -10.
     * Không có offset 34.
     */
    view.center = center;
}

#pragma mark - Apply Scenes

static void SC16ApplyAllWindows(void)
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
            SC16ApplyScale(window);
        }
    }
}

#pragma mark - Delayed Apply

static void SC16ApplyLater(void)
{
    if (!SC16Enabled())
        return;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplyAllWindows();

            dispatch_after(
                dispatch_time(
                    DISPATCH_TIME_NOW,
                    (int64_t)(
                        0.30 *
                        NSEC_PER_SEC
                    )
                ),
                dispatch_get_main_queue(),
                ^{
                    SC16ApplyAllWindows();
                }
            );
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

    SC16ApplyLater();
}

- (void)setRootViewController:
    (UIViewController *)rootViewController
{
    %orig(rootViewController);

    if (!SC16Enabled())
        return;

    SC16ApplyLater();
}

- (void)setHidden:(BOOL)hidden
{
    %orig(hidden);

    if (!SC16Enabled())
        return;

    if (hidden)
        return;

    SC16ApplyLater();
}

%end

#pragma mark - Status Bar

%hook UIViewController

- (BOOL)prefersStatusBarHidden
{
    if (SC16Enabled())
        return YES;

    return %orig;
}

%end

#pragma mark - Orientation Notification

static void SC16OrientationChanged(
    NSNotification *notification
)
{
    if (!SC16Enabled())
        return;

    /*
     * Không hook private orientation API.
     *
     * Chỉ đợi UIKit hoàn thành orientation transition
     * rồi tính scale lại.
     */
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplyAllWindows();
        }
    );
}

#pragma mark - Constructor

%ctor
{
    @autoreleasepool
    {
        if (!SC16Enabled())
            return;

        /*
         * Orientation notification.
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
                SC16OrientationChanged(notification);
            }];

        /*
         * Initial apply.
         */
        dispatch_async(
            dispatch_get_main_queue(),
            ^{
                SC16ApplyAllWindows();

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
                        SC16ApplyAllWindows();
                    }
                );
            }
        );
    }
}
