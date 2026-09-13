#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma mark - Configuration

/*
 * System-wide UI scale.
 *
 * 1.00 = nguyên bản
 * 0.90 = nhỏ hơn 10%
 * 0.85 = nhỏ hơn 15%
 *
 * Không dùng crop 34px.
 * Không dùng offset 10px/34px.
 */
static CGFloat const SC16_SCALE = 0.85;

#pragma mark - State

static CGAffineTransform SC16OriginalTransform = CGAffineTransformIdentity;
static BOOL SC16HasOriginalTransform = NO;
static CGSize SC16LastBounds = CGSizeZero;
static NSInteger SC16LastOrientation = -1;

#pragma mark - Helpers

static BOOL SC16ValidWindow(UIWindow *window)
{
    if (!window)
        return NO;

    if (window.hidden)
        return NO;

    if (window.alpha <= 0.0)
        return NO;

    return YES;
}

static BOOL SC16IsSystemWindow(UIWindow *window)
{
    if (!window)
        return NO;

    NSString *className =
        NSStringFromClass(window.class);

    /*
     * Không đụng keyboard.
     */
    if ([className containsString:@"Keyboard"])
        return NO;

    if ([className containsString:@"UITextEffects"])
        return NO;

    if ([className containsString:@"UIRemoteKeyboard"])
        return NO;

    return YES;
}

static UIWindow *SC16KeyWindow(UIWindowScene *scene)
{
    if (!scene)
        return nil;

    UIWindow *candidate = nil;

    for (UIWindow *window in scene.windows)
    {
        if (!SC16ValidWindow(window))
            continue;

        if (![SC16IsSystemWindow(window)])
            continue;

        if (window.isKeyWindow)
            return window;

        if (!candidate)
            candidate = window;
    }

    return candidate;
}

#pragma mark - System Scale

static void SC16ApplyToWindow(UIWindow *window)
{
    if (!SC16ValidWindow(window))
        return;

    if (!SC16IsSystemWindow(window))
        return;

    UIView *view = window;

    CGRect bounds = view.bounds;

    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 || height <= 0.0)
        return;

    CGSize currentSize =
        CGSizeMake(width, height);

    UIInterfaceOrientation orientation =
        UIInterfaceOrientationUnknown;

    if (@available(iOS 13.0, *))
    {
        UIWindowScene *scene =
            window.windowScene;

        if (scene)
        {
            orientation =
                scene.interfaceOrientation;
        }
    }

    /*
     * Không apply lại cùng một transform liên tục.
     *
     * Điều này rất quan trọng để tránh:
     *
     * scale -> scale -> scale -> ...
     *
     * gây sai kích thước hoặc crash.
     */
    if (CGSizeEqualToSize(
            SC16LastBounds,
            currentSize) &&
        SC16LastOrientation ==
            orientation)
    {
        return;
    }

    SC16LastBounds =
        currentSize;

    SC16LastOrientation =
        orientation;

    /*
     * Chỉ lưu transform gốc một lần.
     */
    if (!SC16HasOriginalTransform)
    {
        SC16OriginalTransform =
            view.transform;

        SC16HasOriginalTransform = YES;
    }

    /*
     * Reset trước khi scale.
     *
     * Tuyệt đối không scale trên
     * transform đã scale trước đó.
     */
    view.transform =
        SC16OriginalTransform;

    /*
     * Scale quanh tâm của chính window.
     *
     * Không cộng/trừ X/Y.
     *
     * Không +10.
     * Không +34.
     */
    CGFloat scale =
        SC16_SCALE;

    if (scale <= 0.0 ||
        scale > 1.0)
    {
        return;
    }

    CGPoint center =
        view.center;

    CGAffineTransform original =
        SC16OriginalTransform;

    CGAffineTransform scaleTransform =
        CGAffineTransformScale(
            original,
            scale,
            scale
        );

    view.transform =
        scaleTransform;

    /*
     * Giữ chính xác tâm window.
     *
     * Đặc biệt quan trọng ở Landscape.
     */
    view.center =
        center;
}

#pragma mark - Apply System Windows

static void SC16ApplyAllWindows(void)
{
    if (![NSThread isMainThread])
    {
        dispatch_async(
            dispatch_get_main_queue(),
            ^{
                SC16ApplyAllWindows();
            }
        );

        return;
    }

    UIApplication *application =
        UIApplication.sharedApplication;

    if (!application)
        return;

    if (@available(iOS 13.0, *))
    {
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

            UIWindow *window =
                SC16KeyWindow(windowScene);

            if (!window)
                continue;

            SC16ApplyToWindow(window);
        }
    }
    else
    {
        /*
         * Fallback cho hệ thống cũ.
         */
        UIWindow *window =
            application.keyWindow;

        if (window)
        {
            SC16ApplyToWindow(window);
        }
    }
}

#pragma mark - Orientation Notification

static void SC16OrientationChanged(
    NSNotification *notification)
{
    /*
     * Orientation thay đổi:
     *
     * reset cache bounds/orientation
     * rồi tính lại scale.
     */
    SC16LastBounds = CGSizeZero;
    SC16LastOrientation = -1;

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

    /*
     * Cho UIKit hoàn tất việc tạo/layout window
     * rồi mới scale.
     */
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SC16LastBounds =
                CGSizeZero;

            SC16ApplyToWindow(self);
        }
    );
}

- (void)layoutSubviews
{
    %orig;

    /*
     * Không scale ngay trong layout pass.
     *
     * Tránh recursion:
     *
     * layout
     *  -> transform
     *  -> layout
     *  -> transform
     */
    static BOOL applying = NO;

    if (applying)
        return;

    applying = YES;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            applying = NO;

            if (!SC16ValidWindow(self))
                return;

            CGRect bounds =
                self.bounds;

            CGSize size =
                CGSizeMake(
                    CGRectGetWidth(bounds),
                    CGRectGetHeight(bounds)
                );

            if (!CGSizeEqualToSize(
                    size,
                    SC16LastBounds))
            {
                SC16ApplyToWindow(self);
            }
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
         * Không thực hiện UIKit operation
         * trực tiếp trong constructor.
         */
        dispatch_async(
            dispatch_get_main_queue(),
            ^{
                SC16ApplyAllWindows();

                /*
                 * UIKit/SpringBoard có thể tạo lại
                 * window sau khi tweak load.
                 *
                 * Chỉ retry hữu hạn.
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
                        SC16LastBounds =
                            CGSizeZero;

                        SC16ApplyAllWindows();
                    }
                );
            }
        );

        /*
         * Theo dõi orientation.
         *
         * Không dùng timer liên tục.
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
                    SC16OrientationChanged(
                        notification
                    );
                }];
    }
}
