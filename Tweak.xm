#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

#pragma mark - Configuration

/*
 * Scale UI vào giữa màn hình.
 *
 * 34px là khoảng vùng đen ở mỗi phía.
 *
 * Portrait:
 *   34px trên + 34px dưới
 *
 * Landscape:
 *   34px trái + 34px phải
 *
 * Không ẩn Status Bar.
 */
static const CGFloat SC16_INSET = 34.0;

#pragma mark - State

static BOOL SC16IsApplying = NO;
static CGFloat SC16Scale = 1.0;

#pragma mark - Enable

static BOOL SC16Enabled(void)
{
    NSString *version =
        [UIDevice currentDevice].systemVersion;

    return [version hasPrefix:@"16."];
}

#pragma mark - SpringBoard Detection

static BOOL SC16IsSpringBoard(void)
{
    NSString *bundleIdentifier =
        [[NSBundle mainBundle] bundleIdentifier];

    return [bundleIdentifier isEqualToString:@"com.apple.springboard"];
}

#pragma mark - Calculate Scale

static CGFloat SC16CalculateScale(UIWindow *window)
{
    if (!window)
        return 1.0;

    CGRect bounds = window.bounds;

    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 || height <= 0.0)
        return 1.0;

    /*
     * Portrait
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
     */
    CGFloat availableWidth =
        width - (SC16_INSET * 2.0);

    if (availableWidth <= 0.0)
        return 1.0;

    return availableWidth / width;
}

#pragma mark - Apply Scale

static void SC16ApplyToWindow(UIWindow *window)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    if (!window)
        return;

    if (window.hidden)
        return;

    if (window.alpha <= 0.0)
        return;

    /*
     * Không đụng keyboard.
     */
    NSString *className =
        NSStringFromClass([window class]);

    if ([className containsString:@"Keyboard"])
        return;

    if ([className containsString:@"UITextEffects"])
        return;

    if ([className containsString:@"UIRemoteKeyboard"])
        return;

    /*
     * Không đụng Status Bar window.
     */
    if ([className containsString:@"StatusBar"])
        return;

    if ([className containsString:@"_UIStatusBar"])
        return;

    UIView *contentView = window;

    if (!contentView)
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
        SC16CalculateScale(window);

    if (scale <= 0.0 || scale >= 1.0)
        return;

    /*
     * Không cho phép apply lồng transform.
     */
    if (SC16IsApplying)
        return;

    SC16IsApplying = YES;

    /*
     * Reset trước khi tính lại.
     *
     * Quan trọng khi xoay màn hình.
     */
    contentView.transform =
        CGAffineTransformIdentity;

    /*
     * Giữ nguyên tâm window.
     */
    CGPoint center =
        contentView.center;

    /*
     * Scale toàn bộ nội dung theo tâm.
     *
     * Không dịch thủ công UI.
     */
    contentView.transform =
        CGAffineTransformMakeScale(
            scale,
            scale
        );

    contentView.center =
        center;

    SC16Scale = scale;

    SC16IsApplying = NO;
}

#pragma mark - Apply All SpringBoard Windows

static void SC16ApplyAllWindows(void)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    UIApplication *application =
        [UIApplication sharedApplication];

    if (!application)
        return;

    for (UIWindow *window in application.windows)
    {
        SC16ApplyToWindow(window);
    }
}

#pragma mark - UIWindow

%hook UIWindow

- (void)makeKeyAndVisible
{
    %orig;

    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    __weak UIWindow *weakWindow = self;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            UIWindow *window = weakWindow;

            if (window)
            {
                SC16ApplyToWindow(window);
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

    __weak UIWindow *weakWindow = self;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            UIWindow *window = weakWindow;

            if (window)
            {
                SC16ApplyToWindow(window);
            }
        }
    );
}

- (void)layoutSubviews
{
    %orig;

    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    /*
     * Không gọi lại ngay trong lúc đang apply
     * để tránh vòng lặp layout.
     */
    if (SC16IsApplying)
        return;

    /*
     * Chỉ schedule một lần ở main queue.
     */
    static BOOL scheduled = NO;

    if (scheduled)
        return;

    scheduled = YES;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            scheduled = NO;

            SC16ApplyAllWindows();
        }
    );
}

%end

#pragma mark - Orientation

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application
{
    %orig(application);

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

#pragma mark - Scene / Orientation Refresh

static void SC16ScheduleRefresh(void)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            /*
             * Reset trước khi UIKit hoàn tất rotation.
             */
            SC16IsApplying = YES;

            UIApplication *application =
                [UIApplication sharedApplication];

            for (UIWindow *window in application.windows)
            {
                if (!window)
                    continue;

                NSString *className =
                    NSStringFromClass([window class]);

                if ([className containsString:@"Keyboard"])
                    continue;

                if ([className containsString:@"StatusBar"])
                    continue;

                window.transform =
                    CGAffineTransformIdentity;
            }

            SC16IsApplying = NO;

            /*
             * Tính lại theo geometry mới.
             */
            dispatch_async(
                dispatch_get_main_queue(),
                ^{
                    SC16ApplyAllWindows();
                }
            );
        }
    );
}

%hook UIApplication

- (void)_updateVisibleWindowsForScene:(id)scene
{
    %orig(scene);

    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    SC16ScheduleRefresh();
}

%end

#pragma mark - Constructor

%ctor
{
    @autoreleasepool
    {
        /*
         * Quan trọng:
         *
         * Tweak này chỉ chạy logic scale trong
         * SpringBoard.
         *
         * Không áp dụng cho app bình thường.
         */
        if (!SC16Enabled())
            return;

        if (!SC16IsSpringBoard())
            return;

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
