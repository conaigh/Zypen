ARCHS = armv7 arm64

CFLAGS = -I../ -I../Theming/ -O2 -Wno-deprecated-declarations
CFLAGS += -fobjc-arc

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ZypenBackgrounding
ZypenBackgrounding_FILES = $(wildcard *.xm) ../Tweak.xm
ZypenBackgrounding_FRAMEWORKS = UIKit CoreGraphics
ZypenBackgrounding_LIBRARIES = applist

IconIndicator.xm_CFLAGS = -fno-objc-arc
SpringBoard_UIAppCustomBackgroundModes.xm_CFLAGS = -fno-objc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
