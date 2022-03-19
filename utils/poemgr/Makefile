include $(TOPDIR)/rules.mk

PKG_NAME:=poemgr
PKG_VERSION:=0.0.0
PKG_RELEASE:=1

# Switch back to original github.com/blocktrron/poemgr when patch is merged
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/pktpls/poemgr.git
PKG_SOURCE_DATE:=2022-03-19
PKG_SOURCE_VERSION:=b5dc3935142a04eacc43b918f0d4cd61af634619

PKG_MAINTAINER:=David Bauer <mail@david-bauer.net>
PKG_LICENSE:=GPL-2.0-only

include $(INCLUDE_DIR)/package.mk

define Package/poemgr
  SECTION:=utils
  CATEGORY:=Utilities
  DEPENDS:=+libuci +libjson-c
  TITLE:=Control PoE ports on the UniFi Flex switch
endef

define Package/poemgr/install
	$(INSTALL_DIR) $(1)/sbin $(1)/usr/lib/poemgr/config $(1)/etc/config $(1)/etc/uci-defaults $(1)/etc/init.d
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/poemgr $(1)/sbin/poemgr
	$(INSTALL_BIN) ./files/uswlite-pse-enable $(1)/usr/lib/poemgr/uswlite-pse-enable
	$(CP) ./files/usw-lite.config $(1)/usr/lib/poemgr/config/usw-lite.config
	$(INSTALL_BIN) ./files/uci-defaults.sh $(1)/etc/uci-defaults/99-poemgr
	$(INSTALL_BIN) ./files/procd-init.sh $(1)/etc/init.d/poemgr
endef


$(eval $(call BuildPackage,poemgr))
