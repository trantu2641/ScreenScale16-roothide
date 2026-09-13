#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>

#pragma mark - Configuration

/*
 * ScreenScale16
 *
 * 90% UI.
 */
static CGFloat const SC16_SCALE = 0.90;

/*
 * Cắt 8px ở vùng hiển thị cuối cùng.
 *
 * Không phải tăng/giảm scale.
 */
static CGFloat const SC16_CROP = 8.0;


#pragma mark - Process

static BOOL SC16Enabled(void)
{
    return [UIDevice.currentDevice.systemVersion
            hasPrefix:@"16."];
}

static BOOL SC16IsSpringBoard(void)
{
    NSString *bundleID =
        NSBundle.mainBundle.bundleIdentifier;

    return [bundleID isEqualToString:
                @"com.apple.springboard"];
}


#pragma mark - Window

static BOOL SC16IsRootSceneWindow(UIWindow *window)
{
    if (!window)
        return NO;

    return [NSStringFromClass(window.class)
            isEqualToString:@"UIRootSceneWindow"];
}

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


#pragma mark - OneHand-style Window Discovery

/*
 * OneHandWizard2 sử dụng:
 *
 * +[UIWindow allWindowsIncludingInternalWindows:
 *                 onlyVisibleWindows:]
 *
 * Đây là điểm khác biệt quan trọng so với bản cũ
 * chỉ quét connectedScenes.
 */
static NSArray<UIWindow *> *SC16AllInternalWindows(void)
{
    Class windowClass =
        [UIWindow class];

    SEL selector =
        NSSelectorFromString(
            @"allWindowsIncludingInternalWindows:onlyVisibleWindows:"
        );

    if (![windowClass
          respondsToSelector:selector])
    {
        return nil;
    }

    typedef NSArray *(*SC16WindowListFn)(
        id,
        SEL,
        BOOL,
        BOOL
    );

    SC16WindowListFn fn =
        (SC16WindowListFn)
        objc_msgSend;

    return fn(
        windowClass,
        selector,
        YES,
        NO
    );
}


/*
 * Lấy tất cả UIRootSceneWindow.
 *
 * Root + background đều được xử lý cùng một
 * transform để không bị tách layer.
 */
static NSArray<UIWindow *> *SC16RootWindows(void)
{
    NSArray<UIWindow *> *windows =
        SC16AllInternalWindows();

    if (!windows)
        return nil;

    NSMutableArray<UIWindow *> *result =
        [NSMutableArray array];

    for (UIWindow *window in windows)
    {
        if (!window)
            continue;

        if (window.hidden)
            continue;

        if (window.alpha <= 0.0)
            continue;

        if (SC16IsKeyboardWindow(window))
            continue;

        if (!SC16IsRootSceneWindow(window))
            continue;

        [result addObject:window];
    }

    return result;
}


#pragma mark - Layer Geometry

/*
 * Đưa anchor về đúng giữa layer mà không làm
 * nội dung nhảy vị trí.
 *
 * Không sử dụng:
 *
 *   window.frame
 *   window.center
 *   window.bounds
 *
 * để tạo vị trí mới.
 */
static void SC16CenterAnchor(
    CALayer *layer
)
{
    if (!layer)
        return;

    CGPoint oldAnchor =
        layer.anchorPoint;

    CGPoint newAnchor =
        CGPointMake(0.5, 0.5);

    if (fabs(oldAnchor.x - newAnchor.x) < 0.0001 &&
        fabs(oldAnchor.y - newAnchor.y) < 0.0001)
    {
        return;
    }

    CGRect bounds =
        layer.bounds;

    CGPoint oldPosition =
        layer.position;

    CGFloat dx =
        (newAnchor.x - oldAnchor.x) *
        CGRectGetWidth(bounds);

    CGFloat dy =
        (newAnchor.y - oldAnchor.y) *
        CGRectGetHeight(bounds);

    /*
     * Giữ nguyên vị trí hiển thị khi đổi anchor.
     */
    layer.anchorPoint =
        newAnchor;

    layer.position =
        CGPointMake(
            oldPosition.x + dx,
            oldPosition.y + dy
        );
}


#pragma mark - Scale

/*
 * Scale theo đúng kiểu OneHand:
 *
 *   CGAffineTransformMakeScale
 *              ↓
 *   CATransform3DMakeAffineTransform
 *              ↓
 *   rootWindow.layer.transform
 *
 * Không dùng window.transform.
 */
static void SC16ApplyScaleToLayer(
    CALayer *layer
)
{
    if (!layer)
        return;

    CGFloat scale =
        SC16_SCALE;

    if (scale <= 0.0 ||
        scale > 1.0)
    {
        scale = 1.0;
    }

    /*
     * OneHand giữ anchor ở giữa.
     */
    SC16CenterAnchor(layer);

    if (fabs(scale - 1.0) < 0.0001)
    {
        layer.transform =
            CATransform3DIdentity;

        return;
    }

    CGAffineTransform affine =
        CGAffineTransformMakeScale(
            scale,
            scale
        );

    CATransform3D transform =
        CATransform3DMakeAffineTransform(
            affine
        );

    layer.transform =
        transform;
}


#pragma mark - Crop

/*
 * Crop 8px thực tế sau scale.
 *
 * Source crop:
 *
 *   8 / 0.90
 *   = 8.888888...
 *
 * Như vậy sau khi layer scale 90%,
 * vùng bị cắt tương đương 8px.
 */
static void SC16ApplyCropToLayer(
    CALayer *layer
)
{
    if (!layer)
        return;

    CGRect bounds =
        layer.bounds;

    CGFloat width =
        CGRectGetWidth(bounds);

    CGFloat height =
        CGRectGetHeight(bounds);

    if (width <= 0.0 ||
        height <= 0.0)
    {
        return;
    }

    CGFloat crop =
        SC16_CROP / SC16_SCALE;

    CGRect visible =
        bounds;

    /*
     * Crop theo hướng màn hình.
     *
     * Portrait:
     *   trên + dưới
     *
     * Landscape:
     *   trái + phải
     */
    if (height > width)
    {
        visible.origin.y += crop;

        visible.size.height -=
            crop * 2.0;
    }
    else
    {
        visible.origin.x += crop;

        visible.size.width -=
            crop * 2.0;
    }

    if (visible.size.width <= 0.0 ||
        visible.size.height <= 0.0)
    {
        return;
    }

    CAShapeLayer *mask = nil;

    if ([layer.mask
         isKindOfClass:
             [CAShapeLayer class]])
    {
        mask =
            (CAShapeLayer *)layer.mask;
    }
    else
    {
        mask =
            [CAShapeLayer layer];

        layer.mask =
            mask;
    }

    mask.frame =
        bounds;

    CGPathRef path =
        CGPathCreateWithRect(
            visible,
            NULL
        );

    mask.path =
        path;

    CGPathRelease(path);
}


#pragma mark - Apply Root Windows

static void SC16ApplyWindow(
    UIWindow *window
)
{
    if (!window)
        return;

    if (!SC16IsRootSceneWindow(window))
        return;

    if (SC16IsKeyboardWindow(window))
        return;

    CALayer *layer =
        window.layer;

    if (!layer)
        return;

    /*
     * Không đụng:
     *
     *   frame
     *   bounds
     *   center
     *   rotation
     *   window.transform
     *
     * Chỉ render layer.
     */
    SC16ApplyScaleToLayer(layer);

    SC16ApplyCropToLayer(layer);
}


static void SC16ApplyAllRootWindows(void)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    NSArray<UIWindow *> *windows =
        SC16RootWindows();

    if (!windows)
        return;

    /*
     * Scale ROOT + BACKGROUND cùng một tỷ lệ.
     *
     * Đây là phần nhằm tránh:
     *
     * UI một chỗ
     * wallpaper một chỗ
     * background một chỗ
     */
    for (UIWindow *window in windows)
    {
        SC16ApplyWindow(window);
    }
}


#pragma mark - Safe Scheduling

static void SC16ScheduleApply(void)
{
    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    static BOOL scheduled = NO;

    if (scheduled)
        return;

    scheduled = YES;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            scheduled = NO;

            SC16ApplyAllRootWindows();
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

    SC16ScheduleApply();
}

- (void)setHidden:(BOOL)hidden
{
    %orig(hidden);

    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
        return;

    if (!hidden)
        SC16ScheduleApply();
}

%end


#pragma mark - UIWindowScene Hooks

%hook UIWindowScene

- (void)sceneDidBecomeActive
{
    %orig;

    if (!SC16Enabled())
        return;

    if (!SC16IsSpringBoard())
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
         * Chỉ chạy iOS 16.
         */
        if (!SC16Enabled())
            return;

        /*
         * Chỉ chạy SpringBoard.
         */
        if (!SC16IsSpringBoard())
            return;

        /*
         * Chờ UIRootSceneWindow xuất hiện.
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
                SC16ApplyAllRootWindows();
            }
        );
    }
}
