# $Id$

include $(TOPDIR)/rules.mk

PKG_NAME:=libwebsockets
PKG_VERSION:=0.5
PKG_RELEASE:=1
PKG_REV:=2f5b9bd30ef2b8556bf8ce808dbd60130c8ac0cb
# PKG_MD5SUM:=46ce665e47d37fce1a0bad935cce58a9

PKG_SOURCE:=$(PKG_NAME).tar.bz2
PKG_SOURCE_URL:=git://git.warmcat.com/libwebsockets
PKG_SOURCE_PROTO:=git
PKG_SOURCE_SUBDIR:=$(PKG_NAME)
PKG_SOURCE_VERSION:=$(PKG_REV)


PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)
PKG_INSTALL:=1

include $(INCLUDE_DIR)/package.mk

define Package/libwebsockets
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=libwebsockets
endef

define Package/libwebsockets/description
 libwebsockets
endef

define Build/Configure
	$(call Build/Configure/Default,--enable-nofork)
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR)
endef

#$(call Build/Compile/Default)

define Package/libwebsockets/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ipkg-install/usr/lib/libwebsockets.so* $(1)/usr/lib/
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ipkg-install/usr/bin/libwebsockets-test-server $(1)/usr/lib/
	$(INSTALL_DIR) $(1)/usr/share/libwebsockets-test-server
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/ipkg-install/usr/share/libwebsockets-test-server/test.html $(1)/usr/share/libwebsockets-test-server/
endef

$(eval $(call BuildPackage,libwebsockets))

