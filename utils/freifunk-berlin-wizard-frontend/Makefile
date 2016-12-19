include $(TOPDIR)/rules.mk

PKG_NAME:=freifunk-berlin-wizard-frontend
PKG_VERSION:=0.0.0
PKG_RELEASE:=1
PKG_MAINTAINER:=André Gaul <andre@gaul.io>

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/freifunk-berlin/firmware-wizard-frontend.git
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_VERSION:=b3c1ff405175aef4bcaedc05437f0420bbea0982
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_SOURCE_VERSION).tar.gz

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_SOURCE_SUBDIR)

include $(INCLUDE_DIR)/package.mk

define Package/freifunk-berlin-wizard-frontend
  SECTION:=util
  CATEGORY:=Utilities
  SUBMENU:=Freifunk
  TITLE:=Freifunk Berlin configuration wizard
  URL:=http://berlin.freifunk.net
  DEPENDS+= +uhttpd +freifunk-berlin-wizard-backend
endef

define Package/freifunk-berlin-wizard-frontend/description
  Freifunk Berlin wizard frontend for luci2-based backend (built with AngularJS)
endef

define Build/Compile
endef

define Package/freifunk-berlin-wizard-frontend/install
	$(INSTALL_DIR) $(1)/www/wizard
	$(CP) $(PKG_BUILD_DIR)/assets $(1)/www/wizard/
	$(CP) $(PKG_BUILD_DIR)/index.css $(1)/www/wizard/
	$(CP) $(PKG_BUILD_DIR)/index.html $(1)/www/wizard/
	$(CP) $(PKG_BUILD_DIR)/status.html $(1)/www/wizard/
	$(CP) $(PKG_BUILD_DIR)/index.js $(1)/www/wizard/
	$(CP) $(PKG_BUILD_DIR)/nls $(1)/www/wizard/
	$(CP) $(PKG_BUILD_DIR)/shared $(1)/www/wizard/
	$(CP) $(PKG_BUILD_DIR)/vendor $(1)/www/wizard/
endef

$(eval $(call BuildPackage,freifunk-berlin-wizard-frontend))
