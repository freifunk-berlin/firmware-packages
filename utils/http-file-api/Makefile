include $(TOPDIR)/rules.mk

PKG_NAME:=http-file-api
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_MAINTAINER:=André Gaul <andre@gaul.io>

include $(INCLUDE_DIR)/package.mk

define Package/http-file-api
	SECTION:=net
	CATEGORY:=NETWORK
	SUBMENU:=Web Servers/Proxies
	TITLE:=HTTP file API
  MENU:=1
  DEPENDS:=+uhttpd +ubus +jsonfilter
endef

define Package/http-file-api/description
  HTTP file API for uploading files to the filesystem.
endef

define Build/Prepare
endef

define Build/Compile
endef

define Package/freifunk-berlin-wizard-backend/install
	$(INSTALL_DIR) $(1)/www/cgi-bin
	$(INSTALL_BIN) files/files $(1)/www/cgi-bin/
endef

$(eval $(call BuildPackage,http-file-api))
