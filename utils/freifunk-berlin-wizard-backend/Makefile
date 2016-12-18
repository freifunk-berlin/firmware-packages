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
  DEPENDS:=+uhttpd +uhttpd-mod-ubus +jsonfilter \
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
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(CP) files/etc/uci-defaults/* $(1)/etc/uci-defaults

	$(INSTALL_DIR) $(1)/usr/sbin $(1)/usr/lib/ffwizard.d
	$(INSTALL_BIN) files/usr/lib/ffwizard.d/* $(1)/usr/lib/ffwizard.d/
	$(INSTALL_BIN) files/sbin/ffwizard_apply $(1)/usr/sbin/

	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_BIN) files/usr/share/rpcd/acl.d/ffwizard.json $(1)/usr/share/rpcd/acl.d/

	$(INSTALL_DIR) $(1)/usr/libexec/rpcd
	$(INSTALL_BIN) files/rpcd/* $(1)/usr/libexec/rpcd/
endef

$(eval $(call BuildPackage,freifunk-berlin-wizard-backend))
