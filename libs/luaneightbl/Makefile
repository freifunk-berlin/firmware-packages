#
# Copyright (C) 2012-2013 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
# $Id$

include $(TOPDIR)/rules.mk

PKG_NAME:=luaneightbl
PKG_VERSION:=0.2
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/luaneightbl
  SUBMENU:=Lua
  SECTION:=lang
  CATEGORY:=Languages
  TITLE:=neightbl - Lua lib for IPv6 neighbors
  DEPENDS:=+liblua +lua
endef

define Package/luaneightbl/description
 neightbl is a lua lib for reading mac,ip6 table from kernel
endef


define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

TARGET_CFLAGS += \
	-I$(STAGING_DIR)/usr/include \
	-D_GNU_SOURCE

MAKE_FLAGS += \
	FPIC="$(FPIC)" \
	CFLAGS="$(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)" \

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/neightbl.so $(1)/usr/lib/lua/neightbl.so
endef

define Package/luaneightbl/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/neightbl.so $(1)/usr/lib/lua
endef


$(eval $(call BuildPackage,luaneightbl))
