#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Configuration

/*
 * Crop của bản gốc.
 *
 * Portrait:
 *   34px trên
 *   34px dưới
 *
 * Landscape:
 *   34px trái
 *   34px phải
 */
static CGFloat const SC16_CROP = 34.0;

/*
 * Scale bổ sung.
 *
 * 0.96 = 96%
 */
static CGFloat const SC16_SCALE = 0.96;


#pragma mark - Process

static BOOL SC16Enabled(void)
{
    NSString *version =
        UIDevice.currentDevice.systemVersion;

    return [version hasPrefix:@"16."];
}


#pragma mark - Window Detection

static BOOL SC16IsExcludedWindow(UIWindow *window)
{
    if (!window)
        return YES;

    NSString *name =
        NSStringFromClass(window.class);

    /*
     * Giữ nguyên các loại window mà bản gốc
     * không nên crop/scale.
     */
    if ([name containsString:@"UITextEffectsWindow"])
        return YES;

    if ([name containsString:@"UIRemoteKeyboardWindow"])
        return YES;

    if ([name containsString:@"Keyboard"])
        return YES;

    if ([name containsString:@"KeyboardWindow"])
        return YES;

    if ([name containsString:@"StatusBar"])
        return YES;

    if ([name containsString:@"_UIStatusBar"])
        return YES;

    if ([name containsString:@"Alert"])
        return YES;

    if ([name containsString:@"UIAlert"])
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

    if (SC16IsExcludedWindow(window))
        return NO;

    if (!window.rootViewController)
        return NO;

    return YES;
}


#pragma mark - Crop

/*
 * CROP GIỮ RIÊNG.
 *
 * Không lấy 34 / 0.96.
 * Không phụ thuộc vào scale.
 *
 * Vì vậy giá trị crop luôn là 34px
 * trong hệ tọa độ của window.
 */
static CGRect SC16CropRect(CGRect bounds)
{
    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 ||
        height <= 0.0)
    {
        return CGRectZero;
    }

    CGFloat crop =
        SC16_CROP;

    /*
     * Portrait:
     *
     * trên 34
     * dưới 34
     */
    if (height > width)
    {
        CGFloat newHeight =
            height - (crop * 2.0);

        if (newHeight <= 0.0)
            return CGRectZero;

        return CGRectMake(
            CGRectGetMinX(bounds),
            CGRectGetMinY(bounds) + crop,
            width,
            newHeight
        );
    }

    /*
     * Landscape:
     *
     * trái 34
     * phải 34
     */
    CGFloat newWidth =
        width - (crop * 2.0);

    if (newWidth <= 0.0)
        return CGRectZero;

    return CGRectMake(
        CGRectGetMinX(bounds) + crop,
        CGRectGetMinY(bounds),
        newWidth,
        height
    );
}


static void SC16ApplyCrop(UIWindow *window)
{
    if (!window)
        return;

    CALayer *layer =
        window.layer;

    if (!layer)
        return;

    CGRect bounds =
        layer.bounds;

    if (CGRectGetWidth(bounds) <= 0.0 ||
        CGRectGetHeight(bounds) <= 0.0)
    {
        return;
    }

    CGRect cropRect =
        SC16CropRect(bounds);

    if (CGRectIsEmpty(cropRect))
        return;

    CAShapeLayer *mask =
        [CAShapeLayer layer];

    mask.frame =
        bounds;

    CGPathRef path =
        CGPathCreateWithRect(
            cropRect,
            NULL
        );

    mask.path =
        path;

    CGPathRelease(path);

    layer.mask =
        mask;
}


#pragma mark - Scale

/*
 * SCALE RIÊNG.
 *
 * Không thay frame.
 * Không thay bounds.
 * Không thay center.
 *
 * Scale quanh chính tâm của window.
 */
static CGAffineTransform SC16ScaleTransform(
    CGRect bounds
)
{
    CGFloat centerX =
        CGRectGetMidX(bounds);

    CGFloat centerY =
        CGRectGetMidY(bounds);

    CGFloat tx =
        centerX * (1.0 - SC16_SCALE);

    CGFloat ty =
        centerY * (1.0 - SC16_SCALE);

    return CGAffineTransformMake(
        SC16_SCALE,
        0.0,
        0.0,
        SC16_SCALE,
        tx,
        ty
    );
}


static void SC16ApplyScale(UIWindow *window)
{
    if (!window)
        return;

    CGRect bounds =
        window.bounds;

    if (CGRectGetWidth(bounds) <= 0.0 ||
        CGRectGetHeight(bounds) <= 0.0)
    {
        return;
    }

    /*
     * Reset trước để tránh scale bị cộng dồn.
     */
    window.transform =
        CGAffineTransformIdentity;

    /*
     * 96% quanh tâm window.
     */
    if (fabs(SC16_SCALE - 1.0) > 0.0001)
    {
        window.transform =
            SC16ScaleTransform(bounds);
    }
}


#pragma mark - Apply

/*
 * Hai chức năng hoàn toàn độc lập:
 *
 * 1. Crop
 * 2. Scale
 *
 * Crop không dùng giá trị scale.
 */
static void SC16ApplyWindow(UIWindow *window)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsUsableWindow(window))
        return;

    /*
     * Giữ nguyên crop.
     */
    SC16ApplyCrop(window);

    /*
     * Chỉ thêm scale 96%.
     */
    SC16ApplyScale(window);
}


#pragma mark - Find Windows

static UIWindow *SC16FindWindow(
    UIWindowScene *scene
)
{
    if (!scene)
        return nil;

    UIWindow *fallback =
        nil;

    for (UIWindow *window in scene.windows)
    {
        if (!SC16IsUsableWindow(window))
            continue;

        /*
         * Ưu tiên key window.
         */
        if (window.isKeyWindow)
            return window;

        if (!fallback)
            fallback = window;
    }

    return fallback;
}


#pragma mark - Apply Scene

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

        /*
         * Ép kiểu rõ ràng để tránh lỗi:
         *
         * UIScene *
         * -> UIWindowScene *
         */
        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        SC16ApplyScene(windowScene);
    }
}


#pragma mark - Scheduling

static void SC16ScheduleApply(void)
{
    if (!SC16Enabled())
        return;

    static BOOL scheduled =
        NO;

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

    if (SC16Enabled())
        SC16ScheduleApply();
}


- (void)setHidden:(BOOL)hidden
{
    %orig(hidden);

    if (SC16Enabled() && !hidden)
        SC16ScheduleApply();
}


- (void)setRootViewController:
    (UIViewController *)rootViewController
{
    %orig(rootViewController);

    if (SC16Enabled())
        SC16ScheduleApply();
}


- (void)setFrame:(CGRect)frame
{
    %orig(frame);

    if (SC16Enabled())
        SC16ScheduleApply();
}


%end


#pragma mark - UIWindowScene Hooks

%hook UIWindowScene

- (void)sceneDidBecomeActive
{
    %orig;

    if (SC16Enabled())
        SC16ScheduleApply();
}


- (void)sceneWillEnterForeground
{
    %orig;

    if (SC16Enabled())
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
         * Chờ UIKit/Scene dựng xong rồi apply.
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
