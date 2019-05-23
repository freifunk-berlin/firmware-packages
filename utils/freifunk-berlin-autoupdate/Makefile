include $(TOPDIR)/rules.mk

PKG_NAME:=freifunk-berlin-autoupdate
PKG_VERSION:=0.9.0
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=git://github.com/Akira25/autoupdate.git
PKG_SOURCE_DATE:=2019-05-20
PKG_SOURCE_VERSION:=89997c4ba662eac86a7f8359b25a3b196437ffa9

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/freifunk-berlin-autoupdate/default
  SECTION:=freifunk-berlin
  CATEGORY:=freifunk-berlin
  URL:=https://github.com/Akira25/autoupdate
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
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/files/autoupdate $(1)/usr/bin/autoupdate
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/files/cfg_autoupdate $(1)/etc/config/autoupdate
	$(INSTALL_DIR) $(1)/tmp
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/files/postinst.sh $(1)/tmp/freifunk-berlin-autoupdate_postinst.sh
endef

define Package/freifunk-berlin-autoupdate/conffiles
/etc/config/autoupdate
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
