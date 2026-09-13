#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>

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
 * UI được scale vào giữa vùng hiển thị.
 */
static const CGFloat SC16_CROP = 34.0;

/*
 * Chỉ hoạt động trên iOS 16.
 */
static BOOL SC16Enabled(void)
{
    NSString *version = UIDevice.currentDevice.systemVersion;
    return [version hasPrefix:@"16."];
}

#pragma mark - Process

static BOOL SC16IsSpringBoard(void)
{
    NSString *bundleID =
        NSBundle.mainBundle.bundleIdentifier;

    if (!bundleID)
        return NO;

    return [bundleID isEqualToString:@"com.apple.springboard"];
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

    NSString *className =
        NSStringFromClass(window.class);

    /*
     * Không đụng keyboard.
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
     * Không đụng StatusBar window.
     */
    if ([className containsString:@"StatusBar"])
        return YES;

    if ([className containsString:@"_UIStatusBar"])
        return YES;

    /*
     * Không đụng các window phụ của hệ thống.
     */
    if ([className containsString:@"UIText"])
        return YES;

    return NO;
}

#pragma mark - Window Size

static CGRect SC16DisplayBoundsForWindow(UIWindow *window)
{
    if (!window)
        return CGRectZero;

    UIWindowScene *scene =
        window.windowScene;

    if (!scene)
        return window.bounds;

    UIScreen *screen =
        scene.screen;

    if (!screen)
        return window.bounds;

    return screen.bounds;
}

#pragma mark - Scale

static void SC16ApplyScaleToWindow(UIWindow *window)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    if (SC16ShouldSkipWindow(window))
        return;

    /*
     * Chỉ xử lý window thuộc UIWindowScene.
     */
    UIWindowScene *scene =
        window.windowScene;

    if (!scene)
        return;

    if (scene.activationState ==
        UISceneActivationStateUnattached)
    {
        return;
    }

    UIView *rootView =
        window.rootViewController.view;

    if (!rootView)
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
     * Reset transform trước khi tính lại.
     *
     * Quan trọng khi xoay ngang/dọc.
     */
    rootView.transform =
        CGAffineTransformIdentity;

    /*
     * Dùng kích thước thật của window.
     */
    CGFloat scale = 1.0;

    /*
     * Portrait
     *
     * Giữ lại:
     *
     *   34px trên
     *   34px dưới
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
     * Landscape
     *
     * Giữ lại:
     *
     *   34px trái
     *   34px phải
     *
     * Scale theo chiều ngang để toàn bộ UI
     * vẫn nằm trong vùng hiển thị.
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
        scale >= 1.0)
    {
        return;
    }

    /*
     * Giữ nguyên tâm window.
     *
     * Đây là phần quan trọng để UI nằm chính giữa
     * thay vì bị đẩy sang một phía khi landscape.
     */
    CGPoint center =
        rootView.center;

    rootView.transform =
        CGAffineTransformMakeScale(
            scale,
            scale
        );

    rootView.center =
        center;

    /*
     * Không thay frame sau transform.
     *
     * UIKit sẽ dùng transform để render toàn bộ
     * cây view theo cùng một tỷ lệ.
     */
}

#pragma mark - Apply Scene

static void SC16ApplyScene(UIWindowScene *scene)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
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
        /*
         * Chỉ scale root window phù hợp.
         *
         * Tránh transform toàn bộ system windows.
         */
        NSString *className =
            NSStringFromClass(window.class);

        if ([className containsString:@"UIRootSceneWindow"])
        {
            SC16ApplyScaleToWindow(window);
            continue;
        }

        /*
         * Một số phiên bản SpringBoard có thể dùng
         * UIWindow trực tiếp.
         *
         * Chỉ cho phép window có rootViewController
         * và không thuộc nhóm system overlay.
         */
        if ([className isEqualToString:@"UIWindow"])
        {
            SC16ApplyScaleToWindow(window);
        }
    }
}

#pragma mark - Apply All Scenes

static void SC16ApplyAllScenes(void)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    UIApplication *application =
        UIApplication.sharedApplication;

    NSSet<UIScene *> *connectedScenes =
        application.connectedScenes;

    for (UIScene *scene in connectedScenes)
    {
        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;

        SC16ApplyScene(
            (UIWindowScene *)scene
        );
    }
}

#pragma mark - Refresh

static void SC16Refresh(void)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
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

    if (!SC16IsSpringBoard())
        return;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplyScaleToWindow(self);
        }
    );
}

- (void)setRootViewController:
    (UIViewController *)rootViewController
{
    %orig(rootViewController);

    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
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

    if (!SC16IsSpringBoard())
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

%end

#pragma mark - Orientation

%hook UIWindowScene

- (void)sceneDidBecomeActive:(UIScene *)scene
{
    %orig(scene);

    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplyScene(self);
        }
    );
}

%end

#pragma mark - Root View Layout

%hook UIView

- (void)didMoveToWindow
{
    %orig;

    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    UIWindow *window =
        self.window;

    if (!window)
        return;

    UIViewController *root =
        window.rootViewController;

    if (!root)
        return;

    /*
     * Chỉ refresh khi đây thực sự là root view.
     *
     * Không transform từng UIView con.
     */
    if (self != root.view)
        return;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplyScaleToWindow(window);
        }
    );
}

%end

#pragma mark - Constructor

%ctor
{
    @autoreleasepool
    {
        /*
         * Không load vào app thường.
         *
         * Đây là điểm quan trọng để tránh Safe Mode
         * do tweak can thiệp vào UIKit của mọi process.
         */
        if (!SC16Enabled())
            return;

        if (!SC16IsSpringBoard())
            return;

        /*
         * UIKit phải được khởi tạo xong trước khi
         * truy cập connectedScenes.
         */
        dispatch_async(
            dispatch_get_main_queue(),
            ^{
                SC16ApplyAllScenes();

                /*
                 * Refresh sau khi SpringBoard hoàn thành
                 * layout/window setup.
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
                 * Một lần cuối sau khi UI ổn định.
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
