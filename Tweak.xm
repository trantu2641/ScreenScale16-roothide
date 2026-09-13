#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Configuration

/*
 * Crop giữ nguyên logic của bản gốc:
 *
 * Portrait  : 34px trên + 34px dưới
 * Landscape : 34px trái + 34px phải
 */
static CGFloat const SC16_CROP = 34.0;

/*
 * Scale bổ sung độc lập với crop.
 *
 * 0.96 = 96%
 */
static CGFloat const SC16_SCALE = 0.96;

#pragma mark - Process

static BOOL SC16Enabled(void)
{
    NSString *version = UIDevice.currentDevice.systemVersion;

    return [version hasPrefix:@"16."];
}

#pragma mark - Window Detection

static BOOL SC16IsKeyboardWindow(UIWindow *window)
{
    if (!window)
        return YES;

    NSString *name = NSStringFromClass(window.class);

    if ([name containsString:@"UITextEffectsWindow"])
        return YES;

    if ([name containsString:@"UIRemoteKeyboardWindow"])
        return YES;

    if ([name containsString:@"KeyboardWindow"])
        return YES;

    if ([name containsString:@"Keyboard"])
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

    if (SC16IsKeyboardWindow(window))
        return NO;

    if (!window.rootViewController)
        return NO;

    return YES;
}

#pragma mark - Crop

/*
 * Đây là phần crop.
 *
 * KHÔNG dùng SC16_SCALE ở đây.
 *
 * Crop hoàn toàn độc lập với scale 96%.
 */
static CGFloat SC16CropScaleForBounds(CGRect bounds)
{
    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);

    if (width <= 0.0 || height <= 0.0)
        return 1.0;

    CGFloat crop = SC16_CROP * 2.0;

    if (height >= width)
    {
        if (height <= crop)
            return 1.0;

        return (height - crop) / height;
    }

    if (width <= crop)
        return 1.0;

    return (width - crop) / width;
}

static void SC16ApplyCrop(UIView *view)
{
    if (!view)
        return;

    CGRect bounds = view.bounds;

    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);

    if (width <= 0.0 || height <= 0.0)
        return;

    CGFloat cropScale =
        SC16CropScaleForBounds(bounds);

    if (cropScale <= 0.0 || cropScale > 1.0)
        cropScale = 1.0;

    /*
     * Crop scale của bản gốc.
     *
     * Không thay frame.
     * Không thay bounds.
     * Không thay center.
     */
    view.layer.anchorPoint =
        CGPointMake(0.5, 0.5);

    view.transform =
        CGAffineTransformMakeScale(
            cropScale,
            cropScale
        );
}

#pragma mark - Additional Scale

/*
 * Scale 96% là cơ chế RIÊNG.
 *
 * Nó không được dùng để tính crop.
 */
static void SC16ApplyScale(UIView *view)
{
    if (!view)
        return;

    CGFloat scale = SC16_SCALE;

    if (scale <= 0.0 || scale > 1.0)
        scale = 1.0;

    /*
     * Lấy transform hiện tại.
     *
     * Crop đã được áp dụng trước đó.
     * Scale 96% được nhân thêm độc lập.
     */
    CGAffineTransform current =
        view.transform;

    CGFloat a = current.a;
    CGFloat b = current.b;
    CGFloat c = current.c;
    CGFloat d = current.d;

    if (fabs(a) < 0.000001 &&
        fabs(d) < 0.000001)
    {
        return;
    }

    /*
     * Vì crop hiện tại chỉ là scale,
     * nhân thêm 0.96 vào phần scale.
     *
     * Không tính lại SC16_CROP.
     */
    view.transform =
        CGAffineTransformMake(
            a * scale,
            b,
            c,
            d * scale,
            current.tx,
            current.ty
        );
}

#pragma mark - Apply View

static void SC16ApplyToView(UIView *view)
{
    if (!SC16Enabled())
        return;

    if (!view)
        return;

    CGRect bounds = view.bounds;

    if (CGRectGetWidth(bounds) <= 0.0 ||
        CGRectGetHeight(bounds) <= 0.0)
    {
        return;
    }

    /*
     * Reset về identity trước.
     *
     * Sau đó tạo lại crop + scale.
     *
     * Điều này tránh bị scale/crop chồng
     * nhiều lần khi viewDidAppear chạy lại.
     */
    view.transform =
        CGAffineTransformIdentity;

    /*
     * Crop 34px.
     */
    CGFloat cropScale =
        SC16CropScaleForBounds(bounds);

    if (cropScale <= 0.0 || cropScale > 1.0)
        cropScale = 1.0;

    /*
     * Crop.
     */
    view.transform =
        CGAffineTransformMakeScale(
            cropScale,
            cropScale
        );

    /*
     * Scale 96% RIÊNG.
     */
    CGFloat scale = SC16_SCALE;

    if (scale <= 0.0 || scale > 1.0)
        scale = 1.0;

    if (fabs(scale - 1.0) > 0.0001)
    {
        view.transform =
            CGAffineTransformScale(
                view.transform,
                scale,
                scale
            );
    }
}

#pragma mark - Root View

static UIView *SC16RootViewForWindow(UIWindow *window)
{
    if (!SC16IsUsableWindow(window))
        return nil;

    UIViewController *root =
        window.rootViewController;

    if (!root)
        return nil;

    UIView *view =
        root.view;

    if (!view)
        return nil;

    return view;
}

static void SC16ApplyWindow(UIWindow *window)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsUsableWindow(window))
        return;

    UIView *view =
        SC16RootViewForWindow(window);

    if (!view)
        return;

    SC16ApplyToView(view);
}

#pragma mark - Application Windows

static UIWindow *SC16FindWindow(UIWindowScene *scene)
{
    if (!scene)
        return nil;

    UIWindow *fallback = nil;

    for (UIWindow *window in scene.windows)
    {
        if (!SC16IsUsableWindow(window))
            continue;

        /*
         * Key window được ưu tiên.
         */
        if (window.isKeyWindow)
            return window;

        /*
         * Nếu chưa có key window,
         * giữ window hợp lệ đầu tiên.
         */
        if (!fallback)
            fallback = window;
    }

    return fallback;
}

static void SC16ApplyScene(UIWindowScene *scene)
{
    if (!scene)
        return;

    if (scene.activationState ==
        UISceneActivationStateUnattached)
    {
        return;
    }

    UIWindow *window =
        SC16FindWindow(scene);

    if (!window)
        return;

    SC16ApplyWindow(window);
}

static void SC16ApplyAllScenes(void)
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
              isKindOfClass:
                  [UIWindowScene class]])
        {
            continue;
        }

        SC16ApplyScene(
            (UIWindowScene *)scene
        );
    }
}

#pragma mark - Scheduling

static void SC16ScheduleApply(void)
{
    if (!SC16Enabled())
        return;

    static BOOL scheduled = NO;

    if (scheduled)
        return;

    scheduled = YES;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            scheduled = NO;

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

    SC16ScheduleApply();
}

- (void)setRootViewController:
    (UIViewController *)rootViewController
{
    %orig(rootViewController);

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();
}

- (void)setHidden:(BOOL)hidden
{
    %orig(hidden);

    if (!SC16Enabled())
        return;

    if (!hidden)
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

#pragma mark - UIViewController Hooks

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated
{
    %orig(animated);

    if (!SC16Enabled())
        return;

    /*
     * App vừa xuất hiện / chuyển màn hình.
     *
     * Áp dụng lại để app không mất
     * crop + scale.
     */
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            UIView *view = self.view;

            if (!view)
                return;

            /*
             * Chỉ xử lý root view của window.
             * Không scale từng subview.
             */
            UIWindow *window =
                view.window;

            if (!window)
                return;

            if (window.rootViewController != self)
                return;

            SC16ApplyWindow(window);
        }
    );
}

%end

#pragma mark - UIWindowScene Hooks

%hook UIWindowScene

- (void)sceneDidBecomeActive
{
    %orig;

    if (!SC16Enabled())
        return;

    SC16ScheduleApply();
}

- (void)sceneWillEnterForeground
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
         * UIKit cần có thời gian khởi tạo
         * window/scene.
         */
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(
                    0.8 *
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
