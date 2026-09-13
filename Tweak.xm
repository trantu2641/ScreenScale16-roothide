#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Configuration

/*
 * Khoảng chừa mỗi đầu màn hình.
 *
 * Portrait:
 *   34px trên
 *   34px dưới
 *
 * Landscape:
 *   34px trái
 *   34px phải
 *
 * Đây là SCALE.
 */
static const CGFloat SC16_CROP = 34.0;

#pragma mark - Enable

static BOOL SC16Enabled(void)
{
    NSString *version = UIDevice.currentDevice.systemVersion;
    return [version hasPrefix:@"16."];
}

#pragma mark - Window Filter

static BOOL SC16IsSystemWindow(UIWindow *window)
{
    if (!window)
        return YES;

    if (window.hidden)
        return YES;

    if (window.alpha <= 0.0)
        return YES;

    NSString *name = NSStringFromClass(window.class);

    /*
     * Không đụng keyboard.
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
     * Không đụng Status Bar window.
     */
    if ([name containsString:@"StatusBar"])
        return YES;

    if ([name containsString:@"_UIStatusBar"])
        return YES;

    return NO;
}

#pragma mark - Scale

static void SC16ApplyScaleToWindow(UIWindow *window)
{
    if (!SC16Enabled())
        return;

    if (SC16IsSystemWindow(window))
        return;

    UIViewController *rootViewController =
        window.rootViewController;

    if (!rootViewController)
        return;

    UIView *rootView =
        rootViewController.view;

    if (!rootView)
        return;

    CGRect bounds = window.bounds;

    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 || height <= 0.0)
        return;

    /*
     * Luôn reset trước khi tính.
     * Điều này rất quan trọng khi xoay màn hình.
     */
    rootView.transform =
        CGAffineTransformIdentity;

    /*
     * Lấy center nguyên bản.
     */
    CGPoint originalCenter =
        rootView.center;

    CGFloat scale = 1.0;

    /*
     * PORTRAIT
     *
     * Chừa 34px trên + 34px dưới.
     */
    if (height > width)
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
     * Chừa 34px trái + 34px phải.
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

    if (scale <= 0.0 || scale >= 1.0)
        return;

    /*
     * Scale toàn bộ root UI.
     */
    rootView.transform =
        CGAffineTransformMakeScale(
            scale,
            scale
        );

    /*
     * Đưa UI về chính giữa màn hình.
     *
     * Không dịch UI theo kiểu crop.
     */
    rootView.center =
        CGPointMake(
            CGRectGetMidX(bounds),
            CGRectGetMidY(bounds)
        );

    /*
     * Tránh compiler warning nếu center
     * không được sử dụng ở build hiện tại.
     */
    (void)originalCenter;
}

#pragma mark - Apply Scene Windows

static void SC16ApplyAllWindows(void)
{
    if (!SC16Enabled())
        return;

    UIApplication *application =
        UIApplication.sharedApplication;

    NSSet<UIScene *> *connectedScenes =
        application.connectedScenes;

    for (UIScene *scene in connectedScenes)
    {
        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        UISceneActivationState state =
            windowScene.activationState;

        if (state == UISceneActivationStateUnattached)
            continue;

        NSArray<UIWindow *> *windows =
            windowScene.windows;

        for (UIWindow *window in windows)
        {
            SC16ApplyScaleToWindow(window);
        }
    }
}

#pragma mark - UIWindow Hooks

%hook UIWindow

- (void)makeKeyAndVisible
{
    %orig;

    if (!SC16Enabled())
        return;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplyScaleToWindow(self);
        }
    );
}

- (void)setRootViewController:(UIViewController *)rootViewController
{
    %orig(rootViewController);

    if (!SC16Enabled())
        return;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplyScaleToWindow(self);
        }
    );
}

- (void)setHidden:(BOOL)hidden
{
    %orig(hidden);

    if (!SC16Enabled())
        return;

    if (hidden)
        return;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplyScaleToWindow(self);
        }
    );
}

- (void)layoutSubviews
{
    %orig;

    if (!SC16Enabled())
        return;

    /*
     * Không scale ngay trong layout.
     * Chỉ schedule sau khi UIKit hoàn tất layout,
     * tránh vòng lặp layout/transform.
     */
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplyScaleToWindow(self);
        }
    );
}

%end

#pragma mark - Orientation

%hook UIWindowScene

- (void)willConnectToSession:(UISceneSession *)session
                    options:(UISceneConnectionOptions *)connectionOptions
{
    %orig(session, connectionOptions);

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

#pragma mark - Constructor

%ctor
{
    @autoreleasepool
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
                            0.25 *
                            NSEC_PER_SEC
                        )
                    ),
                    dispatch_get_main_queue(),
                    ^{
                        SC16ApplyAllWindows();
                    }
                );

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
                        SC16ApplyAllWindows();
                    }
                );
            }
        );
    }
}
