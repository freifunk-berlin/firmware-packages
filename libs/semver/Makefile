#
# Copyright (C) 2014 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=semver
PKG_VERSION:=0.0.0
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/cloudflare/semver_bash.git
PKG_SOURCE_VERSION:=c1133faf0efe17767b654b213f212c326df73fa3
PKG_SOURCE_PROTO:=git
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/semver/template
  SECTION:=Libraries
  CATEGORY:=Libraries
  MAINTAINER:=Philipp Borgers <borgers@mi.fu-berlin.de>
  TITLE:=semver
	URL:=https://github.com/cloudflare/semver_bash
endef

define Package/semver/description
	Semantic versioning library for sh.
endef

define Package/semver
  $(call Package/semver/template)
endef

define Build/Compile
endef

define Package/semver/install
	$(INSTALL_DIR) $(1)/lib/functions
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/semver.sh $(1)/lib/functions/semver.sh
endef

$(eval $(call BuildPackage,semver))
