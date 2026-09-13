ARCHS = arm64 arm64e

TARGET = iphone:clang:16.5:16.0

THEOS_PACKAGE_SCHEME = roothide

FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ScreenScale16

ScreenScale16_FILES = Tweak.xm

ScreenScale16_CFLAGS = -fobjc-arc

ScreenScale16_FRAMEWORKS = UIKit QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk
