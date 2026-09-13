#pragma mark - Configuration

static CGFloat const SC16_CROP = 34.0;

#pragma mark - Enable

static BOOL SC16Enabled(void)
{
    return [UIDevice.currentDevice.systemVersion hasPrefix:@"16."];
}

#pragma mark - Scale

static void SC16ApplyScale(UIWindow *window)
{
    if (!SC16Enabled() || !window)
        return;

    if (window.hidden || window.alpha <= 0.0)
        return;

    UIViewController *root =
        window.rootViewController;

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

    BOOL portrait = height > width;

    CGFloat scale;

    if (portrait)
    {
        CGFloat availableHeight =
            height - (SC16_CROP * 2.0);

        if (availableHeight <= 0.0)
            return;

        scale = availableHeight / height;
    }
    else
    {
        CGFloat availableWidth =
            width - (SC16_CROP * 2.0);

        if (availableWidth <= 0.0)
            return;

        scale = availableWidth / width;
    }

    if (scale <= 0.0 || scale >= 1.0)
        return;

    /*
     * Scale toàn bộ UI.
     *
     * KHÔNG translate.
     * KHÔNG mask.
     */
    CGPoint center = view.center;

    view.transform =
        CGAffineTransformMakeScale(
            scale,
            scale
        );

    view.center = center;
}

#pragma mark - Status Bar

%hook UIViewController

- (BOOL)prefersStatusBarHidden
{
    if (SC16Enabled())
        return YES;

    return %orig;
}

%end

#pragma mark - UIWindow

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

- (void)setRootViewController:(UIViewController *)controller
{
    %orig(controller);

    if (!SC16Enabled())
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
                UIApplication *app =
                    UIApplication.sharedApplication;

                for (UIScene *scene in app.connectedScenes)
                {
                    if (![scene
                          isKindOfClass:[UIWindowScene class]])
                        continue;

                    UIWindowScene *windowScene =
                        (UIWindowScene *)scene;

                    for (UIWindow *window in windowScene.windows)
                    {
                        SC16ApplyScale(window);
                    }
                }
            }
        );
    }
}
