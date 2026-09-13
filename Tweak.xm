#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>

#pragma mark - Configuration

/*
 * Khoảng chừa mỗi bên màn hình.
 *
 * Portrait:
 *     34px trên
 *     34px dưới
 *
 * Landscape:
 *     34px trái
 *     34px phải
 *
 * UI được scale vào giữa vùng hiển thị.
 */
static const CGFloat SC16_CROP = 34.0;

#pragma mark - Runtime helpers

static BOOL SC16IsSpringBoard(void)
{
    NSString *process =
        [NSProcessInfo processInfo].processName;

    return [process isEqualToString:@"SpringBoard"];
}

static BOOL SC16Enabled(void)
{
    if (!SC16IsSpringBoard())
        return NO;

    NSString *version =
        UIDevice.currentDevice.systemVersion;

    return [version hasPrefix:@"16."];
}

static UIWindow *SC16GetWindowRoot(void)
{
    UIApplication *app =
        UIApplication.sharedApplication;

    NSSet *scenes =
        app.connectedScenes;

    for (UIScene *scene in scenes)
    {
        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;

        UIWindowScene *ws =
            (UIWindowScene *)scene;

        if (ws.activationState ==
            UISceneActivationStateUnattached)
            continue;

        /*
         * Ưu tiên UIRootSceneWindow.
         *
         * Đây là loại window mà OneHandWizard2
         * cũng sử dụng.
         */
        for (UIWindow *window in ws.windows)
        {
            NSString *name =
                NSStringFromClass(window.class);

            if ([name isEqualToString:@"UIRootSceneWindow"])
                return window;
        }
    }

    return nil;
}

#pragma mark - Scale calculation

static CGFloat SC16ScaleForBounds(CGRect bounds)
{
    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 || height <= 0.0)
        return 1.0;

    /*
     * Portrait:
     *
     * scale theo chiều cao.
     */
    if (height > width)
    {
        CGFloat usableHeight =
            height - (SC16_CROP * 2.0);

        if (usableHeight <= 0.0)
            return 1.0;

        return usableHeight / height;
    }

    /*
     * Landscape:
     *
     * scale theo chiều ngang.
     *
     * Không dùng height ở đây để tránh
     * UI landscape bị lệch.
     */
    CGFloat usableWidth =
        width - (SC16_CROP * 2.0);

    if (usableWidth <= 0.0)
        return 1.0;

    return usableWidth / width;
}

#pragma mark - Transform

static void SC16ApplyTransformToWindow(UIWindow *window)
{
    if (!window)
        return;

    if (!window.windowScene)
        return;

    if (window.hidden)
        return;

    if (window.alpha <= 0.0)
        return;

    NSString *name =
        NSStringFromClass(window.class);

    /*
     * Tuyệt đối không scale keyboard.
     */
    if ([name containsString:@"Keyboard"])
        return;

    /*
     * Status bar không bị transform riêng.
     */
    if ([name containsString:@"StatusBar"])
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
        SC16ScaleForBounds(bounds);

    if (scale >= 0.9999)
    {
        window.transform =
            CGAffineTransformIdentity;

        return;
    }

    /*
     * Giữ chính giữa màn hình.
     *
     * Không thay frame.
     * Không thay bounds.
     *
     * Chỉ thay transform của root system
     * window.
     */
    CGPoint center =
        CGPointMake(
            CGRectGetMidX(bounds),
            CGRectGetMidY(bounds)
        );

    window.transform =
        CGAffineTransformIdentity;

    window.center = center;

    window.transform =
        CGAffineTransformMakeScale(
            scale,
            scale
        );

    window.center = center;
}

#pragma mark - Find system root windows

static void SC16ApplySystemWindows(void)
{
    if (!SC16Enabled())
        return;

    UIApplication *app =
        UIApplication.sharedApplication;

    NSSet *scenes =
        app.connectedScenes;

    for (UIScene *scene in scenes)
    {
        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;

        UIWindowScene *ws =
            (UIWindowScene *)scene;

        if (ws.activationState ==
            UISceneActivationStateUnattached)
            continue;

        NSArray *windows =
            ws.windows;

        /*
         * Chỉ lấy window hệ thống.
         *
         * Không scale app windows.
         */
        for (UIWindow *window in windows)
        {
            NSString *name =
                NSStringFromClass(window.class);

            if ([name isEqualToString:@"UIRootSceneWindow"])
            {
                SC16ApplyTransformToWindow(window);
            }
        }
    }
}

#pragma mark - Rotation / layout

static void SC16ScheduleApply(void)
{
    if (!SC16Enabled())
        return;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplySystemWindows();

            dispatch_after(
                dispatch_time(
                    DISPATCH_TIME_NOW,
                    (int64_t)(
                        0.15 *
                        NSEC_PER_SEC
                    )
                ),
                dispatch_get_main_queue(),
                ^{
                    SC16ApplySystemWindows();
                }
            );
        }
    );
}

#pragma mark - System root window

%hook UIRootSceneWindow

- (void)layoutSubviews
{
    %orig;

    if (!SC16Enabled())
        return;

    /*
     * UIKit vừa layout xong thì áp scale lại.
     */
    static BOOL applying = NO;

    if (applying)
        return;

    applying = YES;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16ApplyTransformToWindow(self);

            applying = NO;
        }
    );
}

- (void)setFrame:(CGRect)frame
{
    %orig(frame);

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();
}

- (void)setBounds:(CGRect)bounds
{
    %orig(bounds);

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();
}

%end

#pragma mark - UIApplication lifecycle

%hook UIApplication

- (void)applicationDidBecomeActive:
    (UIApplication *)application
{
    %orig(application);

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
        /*
         * QUAN TRỌNG:
         *
         * Tweak chỉ chạy phần scale trong
         * SpringBoard.
         *
         * Các app bình thường không bị
         * transform root view.
         */
        if (!SC16IsSpringBoard())
            return;

        if (!SC16Enabled())
            return;

        dispatch_once(
            &(static dispatch_once_t){0},
            ^{
                SC16ScheduleApply();

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
                        SC16ApplySystemWindows();
                    }
                );

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
                        SC16ApplySystemWindows();
                    }
                );
            }
        );
    }
}
