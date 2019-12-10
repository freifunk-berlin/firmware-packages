#
# Copyright (C) 2016 Freifunk Berlin
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=freifunk-berlin-bbbdigger
PKG_VERSION:=0.0.4
PKG_RELEASE:=0

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/freifunk-berlin-bbbdigger/default
  SECTION:=freifunk-berlin
  CATEGORY:=freifunk-berlin
  URL:=http://github.com/freifunk-berlin/packages_berlin
  PKGARCH:=all
endef

define Package/freifunk-berlin-bbbdigger
  $(call Package/freifunk-berlin-bbbdigger/default)
  TITLE:=A Tunneldigger (l2tp) based VPN connection to mesh with the Berlin Backbone
  DEPENDS:=+freifunk-berlin-tunneldigger
endef

define Package/freifunk-berlin-bbbdigger/description
  Freifunk Berlin configuration of tunneldigger to connect to and mesh with the Berlin Backbone
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/freifunk-berlin-bbbdigger/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/90-freifunk-berlin-bbbdigger.sh $(1)/etc/uci-defaults/
endef

$(eval $(call BuildPackage,freifunk-berlin-bbbdigger))
