#
# Copyright (C) 2019 Freifunk Berlin
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=freifunk-berlin-configtools
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include ../../freifunk-berlin-generic.mk

define Package/freifunk-berlin-configtools
  SECTION:=freifunk-berlin
  CATEGORY:=freifunk-berlin
  TITLE:=Freifunk Berlin console configtools
  URL:=http://github.com/freifunk-berlin/packages_berlin
  PKGARCH:=all
  DEPENDS:=+libuci-lua +lua
endef

define Package/freifunk-berlin-configtools/description
  some handy tools and scripts to handle Freifunk-Berlin configuration
endef

# directly taken from luci.mk
define Build/Prepare
	for d in luasrc htdocs root src; do \
	  if [ -d ./$$$$d ]; then \
	    mkdir -p $(PKG_BUILD_DIR)/$$$$d; \
		$(CP) ./$$$$d/* $(PKG_BUILD_DIR)/$$$$d/; \
	  fi; \
	done
	$(call Build/Prepare/Default)
endef

define Build/Configure
endef

define Build/Compile
endef

# taken from luci.mk
define Package/freifunk-berlin-configtools/install
	$(INSTALL_DIR) $(1)/
	$(CP) $(PKG_BUILD_DIR)/root/* $(1)/
endef

$(eval $(call BuildPackage,freifunk-berlin-configtools))
