#
# Copyright (C) 2009 soma <freifunk somakoma de>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=fff2kamikaze
PKG_VERSION:=0.0.1
PKG_RELEASE:=3

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/fff2kamikaze
  SECTION:=admin
  CATEGORY:=Administration
  TITLE:=FFF Nvram to UCI conversion
  VERSION:=$(PKG_VERSION)-$(PKG_RELEASE)
  DEPENDS:=@TARGET_brcm_2_4||TARGET_brcm47xx
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/fff2kamikaze/description
  This is the public part of the well known Freifunk Firmware ported to Kamikaze.
  This interface is meant for people who can configure their Router from the commandline
  and want to save a good amount of space, that the LUCI-webif would occupy. So one could also
  say that this is a Freifunk webinterface for sysadmins.
endef

define Package/fff2kamikaze/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(CP) ./files/etc/init.d/fff2kamikaze $(1)/etc/init.d
endef

$(eval $(call BuildPackage,fff2kamikaze))

