#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Configuration

/*
 * Cắt vùng hiển thị:
 *
 * Portrait:
 *   34px trên
 *   34px dưới
 *
 * Landscape:
 *   34px trái
 *   34px phải
 *
 * Không cộng thêm 34px.
 */
static const CGFloat SC16_CROP = 34.0;

#pragma mark - Process

static BOOL SC16IsSpringBoard(void)
{
    NSString *bundleID =
        NSBundle.mainBundle.bundleIdentifier;

    return [bundleID isEqualToString:@"com.apple.springboard"];
}

static BOOL SC16IsApplicationProcess(void)
{
    if (SC16IsSpringBoard())
        return NO;

    NSString *bundleID =
        NSBundle.mainBundle.bundleIdentifier;

    if (!bundleID)
        return NO;

    /*
     * Không động vào process hệ thống.
     */
    if ([bundleID hasPrefix:@"com.apple."])
        return NO;

    return YES;
}

static BOOL SC16Enabled(void)
{
    NSString *version =
        UIDevice.currentDevice.systemVersion;

    return [version hasPrefix:@"16."];
}

#pragma mark - Geometry

/*
 * Tính tỷ lệ để nội dung bị thu nhỏ đúng
 * theo vùng crop.
 *
 * Portrait:
 *
 *     +------------------+
 *     |      CROP 34     |
 *     +------------------+
 *     |                  |
 *     |      CONTENT     |
 *     |                  |
 *     +------------------+
 *     |      CROP 34     |
 *     +------------------+
 *
 * Landscape:
 *
 *     +----+------------------+----+
 *     |34  |     CONTENT      | 34 |
 *     +----+------------------+----+
 */
static CGFloat SC16ScaleForSize(CGSize size)
{
    CGFloat width = size.width;
    CGFloat height = size.height;

    if (width <= 0.0 || height <= 0.0)
        return 1.0;

    /*
     * Portrait
     */
    if (height > width)
    {
        CGFloat availableHeight =
            height - (SC16_CROP * 2.0);

        if (availableHeight <= 0.0)
            return 1.0;

        return availableHeight / height;
    }

    /*
     * Landscape
     */
    CGFloat availableWidth =
        width - (SC16_CROP * 2.0);

    if (availableWidth <= 0.0)
        return 1.0;

    return availableWidth / width;
}

#pragma mark - Window Classification

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

    /*
     * Keyboard để UIKit tự quản lý.
     */
    if (SC16IsKeyboardWindow(window))
        return NO;

    return YES;
}

#pragma mark - Transform

/*
 * Scale quanh tâm hiện tại.
 *
 * QUAN TRỌNG:
 *
 * Không:
 *   - setFrame:
 *   - setBounds:
 *   - thay frame rootView
 *   - thay layout
 *
 * để tránh recursion và Safe Mode.
 */
static void SC16ApplyCenteredTransform(
    UIWindow *window,
    CGFloat scale
)
{
    if (!window)
        return;

    if (scale <= 0.0 || scale >= 1.0)
    {
        window.transform =
            CGAffineTransformIdentity;

        return;
    }

    window.transform =
        CGAffineTransformMakeScale(
            scale,
            scale
        );
}

static void SC16ResetWindowTransform(
    UIWindow *window
)
{
    if (!window)
        return;

    if (!CGAffineTransformIsIdentity(
            window.transform))
    {
        window.transform =
            CGAffineTransformIdentity;
    }
}

#pragma mark - Application UI

/*
 * App process:
 *
 * Scale trực tiếp UIWindow.
 *
 * Như vậy toàn bộ nội dung bên trong window
 * cùng sử dụng một hệ số:
 *
 *   - app UI
 *   - navigation
 *   - tab bar
 *   - alert
 *   - game UI
 *   - controls
 */
static void SC16ScaleApplicationWindow(
    UIWindow *window
)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsApplicationProcess())
        return;

    if (!SC16IsUsableWindow(window))
        return;

    CGRect bounds =
        window.bounds;

    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 || height <= 0.0)
        return;

    CGFloat scale =
        SC16ScaleForSize(bounds.size);

    if (scale >= 1.0)
    {
        SC16ResetWindowTransform(window);
        return;
    }

    SC16ApplyCenteredTransform(
        window,
        scale
    );
}

#pragma mark - SpringBoard UI

/*
 * SpringBoard:
 *
 * Chỉ xử lý khi đang thực sự ở SpringBoard.
 *
 * Không áp dụng logic này cho process khác.
 */
static void SC16ScaleSpringBoardWindow(
    UIWindow *window
)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    if (!SC16IsUsableWindow(window))
        return;

    CGRect bounds =
        window.bounds;

    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 || height <= 0.0)
        return;

    CGFloat scale =
        SC16ScaleForSize(bounds.size);

    if (scale >= 1.0)
    {
        SC16ResetWindowTransform(window);
        return;
    }

    /*
     * Scale quanh chính tâm window.
     *
     * Không thay frame.
     * Không thay center.
     *
     * Việc này quan trọng với:
     *   - Home Screen
     *   - Notification
     *   - Control Center
     *   - Alert
     *   - system overlay
     */
    SC16ApplyCenteredTransform(
        window,
        scale
    );
}

#pragma mark - Scene

/*
 * iOS 15+:
 *
 * Dùng UIWindowScene.windows.
 *
 * KHÔNG dùng:
 *
 *     UIApplication.windows
 *
 * vì API này deprecated từ iOS 15.
 */
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

    NSArray<UIWindow *> *windows =
        scene.windows;

    for (UIWindow *window in windows)
    {
        if (SC16IsSpringBoard())
        {
            SC16ScaleSpringBoardWindow(
                window
            );
        }
        else if (SC16IsApplicationProcess())
        {
            SC16ScaleApplicationWindow(
                window
            );
        }
    }
}

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
              isKindOfClass:[UIWindowScene class]])
        {
            continue;
        }

        SC16ApplyScene(
            (UIWindowScene *)scene
        );
    }
}

#pragma mark - Safe Refresh

/*
 * Chỉ chạy một lần sau event.
 *
 * Không gọi refresh từ:
 *
 *   setFrame:
 *   setBounds:
 *   viewDidLayoutSubviews
 *
 * để tránh vòng lặp.
 */
static void SC16ScheduleApply(void)
{
    if (!SC16Enabled())
        return;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplyAllScenes();
        }
    );
}

#pragma mark - UIWindow

%hook UIWindow

/*
 * Window mới xuất hiện.
 */
- (void)makeKeyAndVisible
{
    %orig;

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();
}

/*
 * Root controller mới.
 */
- (void)setRootViewController:
    (UIViewController *)rootViewController
{
    %orig(rootViewController);

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();
}

/*
 * Window hiện lại.
 */
- (void)setHidden:(BOOL)hidden
{
    %orig(hidden);

    if (!SC16Enabled())
        return;

    if (hidden)
        return;

    SC16ScheduleApply();
}

%end

#pragma mark - Scene Lifecycle

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
         * Chờ UIKit/SpringBoard khởi tạo scene.
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
