#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Configuration

/*
 * Khoảng chừa ở mỗi đầu màn hình.
 *
 * Portrait:
 * 34px trên
 * 34px dưới
 *
 * Landscape:
 * 34px trái
 * 34px phải
 *
 * Đây là SCALE, không dùng mask để che màn hình.
 */
static const CGFloat SC16_CROP = 34.0;

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
     * Không scale system status bar window.
     */
    if ([name containsString:@"StatusBar"])
        return YES;

    if ([name containsString:@"_UIStatusBar"])
        return YES;

    return NO;
}

#pragma mark - Scale Root View

static void SC16ApplyScale(UIWindow *window)
{
    if (!SC16Enabled())
        return;

    if (SC16ShouldSkipWindow(window))
        return;

    UIViewController *root = window.rootViewController;

    if (!root)
        return;

    UIView *view = root.view;

    if (!view)
        return;

    CGRect bounds = window.bounds;

    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);

    if (width <= 0.0 || height <= 0.0)
        return;

    /*
     * Reset transform trước khi tính lại.
     *
     * Rất quan trọng khi xoay màn hình:
     * không scale chồng lên transform cũ.
     */
    view.transform = CGAffineTransformIdentity;

    /*
     * Lấy frame sau khi layout.
     */
    [view layoutIfNeeded];

    /*
     * PORTRAIT
     *
     * Chừa 34px trên + 34px dưới.
     *
     * Toàn bộ UI được scale theo chiều cao
     * và giữ đúng tâm màn hình.
     */
    if (height > width)
    {
        CGFloat availableHeight =
            height - (SC16_CROP * 2.0);

        if (availableHeight <= 0.0)
            return;

        CGFloat scale =
            availableHeight / height;

        if (scale <= 0.0)
            return;

        CGPoint center = view.center;

        view.transform =
            CGAffineTransformMakeScale(
                scale,
                scale
            );

        /*
         * Giữ UI ở chính giữa.
         */
        view.center = center;
    }

    /*
     * LANDSCAPE
     *
     * Chừa 34px trái + 34px phải.
     *
     * Không dùng chiều cao để tính scale,
     * tránh tình trạng UI landscape bị lệch.
     */
    else
    {
        CGFloat availableWidth =
            width - (SC16_CROP * 2.0);

        if (availableWidth <= 0.0)
            return;

        CGFloat scale =
            availableWidth / width;

        if (scale <= 0.0)
            return;

        CGPoint center = view.center;

        view.transform =
            CGAffineTransformMakeScale(
                scale,
                scale
            );

        /*
         * Giữ nguyên tâm UI.
         */
        view.center = center;
    }
}

#pragma mark - Scene Windows

/*
 * Không dùng UIApplication.windows.
 *
 * iOS 15+ đã deprecated API đó.
 *
 * Duyệt UIWindowScene -> windows thay thế.
 */
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
        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        if (windowScene.activationState ==
            UISceneActivationStateUnattached)
        {
            continue;
        }

        for (UIWindow *window in windowScene.windows)
        {
            SC16ApplyScale(window);
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
            SC16ApplyScale(self);
        }
    );
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
            SC16ApplyScale(self);
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
                /*
                 * Apply sau khi UIKit tạo scene/window.
                 */
                SC16ApplyAllScenes();

                /*
                 * Apply lại sau layout.
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

                /*
                 * Apply lần cuối khi app ổn định.
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
                        SC16ApplyAllScenes();
                    }
                );
            }
        );
    }
}
