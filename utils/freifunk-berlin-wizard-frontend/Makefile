include $(TOPDIR)/rules.mk

PKG_NAME:=freifunk-berlin-wizard-frontend
PKG_VERSION_BASE:=1.0.0
PKG_VERSION_SUFFIX:=beta.2
PKG_VERSION:=$(PKG_VERSION_BASE)~$(PKG_VERSION_SUFFIX)
PKG_RELEASE:=1
PKG_MAINTAINER:=André Gaul <andre@gaul.io>

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/freifunk-berlin/firmware-wizard-frontend.git
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
# you can also use a commit hash here from the gh-pages branch:
PKG_SOURCE_VERSION:=$(PKG_VERSION_BASE)-$(PKG_VERSION_SUFFIX)
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
	$(INSTALL_DIR) $(1)/www/assets
	$(CP) $(PKG_BUILD_DIR)/assets/*.woff $(1)/www/assets/
	$(CP) $(PKG_BUILD_DIR)/assets/*.png $(1)/www/assets/

	$(INSTALL_DIR) $(1)/www/img
	$(CP) $(PKG_BUILD_DIR)/img/* $(1)/www/img/

	$(CP) $(PKG_BUILD_DIR)/index.css $(1)/www/
	$(CP) $(PKG_BUILD_DIR)/index.html $(1)/www/
	$(CP) $(PKG_BUILD_DIR)/index.js $(1)/www/

	$(INSTALL_DIR) $(1)/www/nls
	$(CP) $(PKG_BUILD_DIR)/nls/*.json $(1)/www/nls/
endef

$(eval $(call BuildPackage,freifunk-berlin-wizard-frontend))
