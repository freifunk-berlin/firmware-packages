include $(TOPDIR)/rules.mk

PKG_NAME:=freifunk-berlin-autoupdate
PKG_VERSION:=0.9.0
PKG_RELEASE:=0

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/freifunk-berlin-autoupdate/default
  SECTION:=freifunk-berlin
  CATEGORY:=freifunk-berlin
  URL:=http://github.com/freifunk-berlin/packages_berlin
  PKGARCH:=all
endef

define Package/freifunk-berlin-autoupdate
  $(call Package/freifunk-berlin-autoupdate/default)
  TITLE:=A script trying to get the upgrade process of a freifunk-berlin router smooth and easy
  DEPENDS:=+uci
endef

define Package/freifunk-berlin-autoupdate/description
  autoupdate wants to get the upgrade process of a freifunk-berlin router via terminal smooth and easy.
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/freifunk-berlin-autoupdate/install
	$(INSTALL_DIR) $(1)/usr/bin
        $(INSTALL_BIN) ./files/autoupdate $(1)/usr/bin/autoupdate
        $(INSTALL_DIR) $(1)/etc/config
        $(INSTALL_DATA) ./files/cfg_autoupdate $(1)/etc/config/autoupdate
        $(INSTALL_DIR) $(1)/tmp
        $(INSTALL_BIN) ./files/postinst.sh $(1)/tmp/freifunk-berlin-autoupdate_postinst.sh
endef

define Package/freifunk-berlin-autoupdate/postinst
#!/bin/sh
$${IPKG_INSTROOT}/tmp/freifunk-berlin-autoupdate_postinst.sh
endef

define Package/freifunk-berlin-autoupdate/postrm
#!/bin/sh
sed '/autoupdate/d' /etc/crontabs/root > /tmp/crontab
cat /tmp/crontab > /etc/crontabs/root
endef

$(eval $(call BuildPackage,freifunk-berlin-autoupdate))
