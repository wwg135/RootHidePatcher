ARCHS = arm64
TARGET = iphone:latest:15.0
DEB_ARCH = iphoneos-arm64e
IPHONEOS_DEPLOYMENT_TARGET = 15.0

INSTALL_TARGET_PROCESSES = RootHidePatcher

THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk

XCODE_SCHEME = RootHidePatcher

XCODEPROJ_NAME = RootHidePatcher

RootHidePatcher_XCODEFLAGS = MARKETING_VERSION=$(THEOS_PACKAGE_BASE_VERSION) \
	IPHONEOS_DEPLOYMENT_TARGET="$(IPHONEOS_DEPLOYMENT_TARGET)" \
	CODE_SIGN_IDENTITY="" \
	AD_HOC_CODE_SIGNING_ALLOWED=YES
RootHidePatcher_XCODE_SCHEME = $(XCODE_SCHEME)
RootHidePatcher_CODESIGN_FLAGS = -Sentitlements.plist
RootHidePatcher_INSTALL_PATH = /Applications

include $(THEOS_MAKE_PATH)/xcodeproj.mk

clean::
	rm -rf ./packages/*

