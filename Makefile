ARCHS = arm64 arm64e

THEOS_PACKAGE_SCHEME=rootless

PACKAGE_VERSION = $(THEOS_PACKAGE_BASE_VERSION)
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FakePowerOff
FakePowerOff_FILES = Tweak.xm
FakePowerOff_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
