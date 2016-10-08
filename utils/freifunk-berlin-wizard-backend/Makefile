include $(TOPDIR)/rules.mk

PKG_NAME:=freifunk-berlin-wizard-backend
PKG_VERSION:=0.0.0
PKG_RELEASE:=1
PKG_MAINTAINER:=André Gaul <andre@gaul.io>

include $(INCLUDE_DIR)/package.mk

define Package/freifunk-berlin-wizard-backend
	SECTION:=util
	CATEGORY:=Utilities
	SUBMENU:=Freifunk
	TITLE:=Freifunk Berlin configuration backend
	URL:=http://berlin.freifunk.net
  MENU:=1
  DEPENDS:=+uhttpd +uhttpd-mod-ubus \
  +rpcd +rpcd-mod-file +rpcd-mod-iwinfo +rpcd-mod-rpcsys +iwinfo \
  @IPV6
endef

define Package/freifunk-berlin-wizard-backend/description
  Freifunk Berlin wizard backend
endef

define Package/freifunk-berlin-wizard-backend/conffiles
/etc/ffwizard/config.json
endef

define Build/Prepare
endef

define Build/Compile
endef

define Package/freifunk-berlin-wizard-backend/install
	$(INSTALL_DIR) $(1)/usr/sbin $(1)/etc/ffwizard.d $(1)/etc/ffwizard
	$(INSTALL_BIN) files/etc/ffwizard.d/10-system.sh $(1)/etc/ffwizard.d/
	$(INSTALL_BIN) files/sbin/ffwizard_load $(1)/usr/sbin/

	$(INSTALL_DIR) $(1)/usr/libexec/rpcd
	$(INSTALL_BIN) files/rpcd/ffwizard $(1)/usr/libexec/rpcd/ffwizard
endef

$(eval $(call BuildPackage,freifunk-berlin-wizard-backend))
