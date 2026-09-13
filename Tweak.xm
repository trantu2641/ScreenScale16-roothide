#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

#pragma mark - Configuration

/*
 * Scale toàn bộ UI vào giữa màn hình.
 *
 * Portrait:
 *   34px vùng đen phía trên
 *   34px vùng đen phía dưới
 *
 * Landscape:
 *   34px vùng đen bên trái
 *   34px vùng đen bên phải
 *
 * Không ẩn Status Bar.
 */
static const CGFloat SC16_INSET = 34.0;

#pragma mark - State

static BOOL SC16Applying = NO;

#pragma mark - Enable

static BOOL SC16Enabled(void)
{
    NSString *version =
        [UIDevice currentDevice].systemVersion;

    return [version hasPrefix:@"16."];
}

#pragma mark - Process

static BOOL SC16IsSpringBoard(void)
{
    NSString *bundleIdentifier =
        [[NSBundle mainBundle] bundleIdentifier];

    return [bundleIdentifier isEqualToString:
            @"com.apple.springboard"];
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
        NSStringFromClass([window class]);

    /*
     * Không scale keyboard.
     */
    if ([name containsString:@"Keyboard"])
        return YES;

    if ([name containsString:@"UITextEffects"])
        return YES;

    if ([name containsString:@"UIRemoteKeyboard"])
        return YES;

    /*
     * Không scale Status Bar.
     */
    if ([name containsString:@"StatusBar"])
        return YES;

    if ([name containsString:@"_UIStatusBar"])
        return YES;

    return NO;
}

#pragma mark - Calculate Scale

static CGFloat SC16ScaleForWindow(UIWindow *window)
{
    CGRect bounds =
        window.bounds;

    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 || height <= 0.0)
        return 1.0;

    /*
     * Portrait
     *
     * Giữ 34px trên + 34px dưới.
     */
    if (height > width)
    {
        CGFloat availableHeight =
            height - (SC16_INSET * 2.0);

        if (availableHeight <= 0.0)
            return 1.0;

        return availableHeight / height;
    }

    /*
     * Landscape
     *
     * Giữ 34px trái + 34px phải.
     */
    CGFloat availableWidth =
        width - (SC16_INSET * 2.0);

    if (availableWidth <= 0.0)
        return 1.0;

    return availableWidth / width;
}

#pragma mark - Apply Window

static void SC16ApplyWindow(UIWindow *window)
{
    if (!SC16Enabled())
        return;

    /*
     * Chỉ chạy trong SpringBoard.
     */
    if (!SC16IsSpringBoard())
        return;

    if (SC16ShouldSkipWindow(window))
        return;

    if (SC16Applying)
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
        SC16ScaleForWindow(window);

    if (scale <= 0.0 ||
        scale >= 1.0)
        return;

    SC16Applying = YES;

    /*
     * Reset transform trước khi tính lại.
     *
     * Điều này rất quan trọng khi xoay
     * Portrait <-> Landscape.
     */
    window.transform =
        CGAffineTransformIdentity;

    /*
     * Giữ đúng tâm màn hình.
     *
     * UI sẽ thu nhỏ vào chính giữa,
     * không tự dịch trái/phải/lên/xuống.
     */
    CGPoint center =
        window.center;

    window.transform =
        CGAffineTransformMakeScale(
            scale,
            scale
        );

    window.center =
        center;

    SC16Applying = NO;
}

#pragma mark - Get Scene Windows

static void SC16ApplyScene(UIWindowScene *scene)
{
    if (!scene)
        return;

    if (scene.activationState ==
        UISceneActivationStateUnattached)
    {
        return;
    }

    /*
     * iOS 15+
     *
     * Không dùng UIApplication.windows
     * vì API đó đã deprecated.
     */
    NSArray<UIWindow *> *windows =
        scene.windows;

    for (UIWindow *window in windows)
    {
        SC16ApplyWindow(window);
    }
}

#pragma mark - Get All Windows

static void SC16ApplyAllScenes(void)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    UIApplication *application =
        [UIApplication sharedApplication];

    if (!application)
        return;

    NSSet<UIScene *> *connectedScenes =
        application.connectedScenes;

    for (UIScene *scene in connectedScenes)
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

    __weak UIWindow *weakWindow =
        self;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            UIWindow *window =
                weakWindow;

            if (window)
            {
                SC16ApplyWindow(window);
            }
        }
    );
}

- (void)setHidden:(BOOL)hidden
{
    %orig(hidden);

    if (hidden)
        return;

    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    __weak UIWindow *weakWindow =
        self;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            UIWindow *window =
                weakWindow;

            if (window)
            {
                SC16ApplyWindow(window);
            }
        }
    );
}

%end

#pragma mark - UIWindowScene Hooks

%hook UIWindowScene

- (void)setInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    %orig(orientation);

    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    /*
     * Khi orientation thay đổi,
     * reset rồi tính lại geometry.
     */
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16Applying = YES;

            NSArray<UIWindow *> *windows =
                self.windows;

            for (UIWindow *window in windows)
            {
                if (!window)
                    continue;

                if (SC16ShouldSkipWindow(window))
                    continue;

                window.transform =
                    CGAffineTransformIdentity;
            }

            SC16Applying = NO;

            /*
             * Đợi UIKit hoàn tất rotation/layout
             * rồi scale lại theo kích thước mới.
             */
            dispatch_async(
                dispatch_get_main_queue(),
                ^{
                    SC16ApplyScene(self);
                }
            );
        }
    );
}

%end

#pragma mark - SpringBoard Launch

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application
{
    %orig(application);

    if (!SC16Enabled())
        return;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplyAllScenes();

            /*
             * UIKit có thể tạo window sau launch,
             * nên kiểm tra lại một lần.
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
    );
}

%end

#pragma mark - Constructor

%ctor
{
    @autoreleasepool
    {
        /*
         * Chỉ enable trên iOS 16.x
         * và chỉ thực hiện logic trong SpringBoard.
         */
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
}
