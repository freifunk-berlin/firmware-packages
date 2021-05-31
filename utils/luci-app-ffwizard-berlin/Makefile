# $Id: Makefile 2010-02-04 23:25:21Z pg $

include $(TOPDIR)/rules.mk

LUCI_TITLE:=Freifunk Berlin configuration wizard
LUCI_DEPENDS:=+luci-compat +luci-mod-admin-full +freifunk-policyrouting +luci-lib-jsonc +community-profiles +luci-lib-ipkg
PKG_RELEASE:=5

define Package/luci-app-ffwizard-berlin/postrm
#!/bin/sh
[ '/cgi-bin/luci/admin/freifunk/assistent?luci_username=root&luci_password=' = "$$(uci -q get freifunk.luci.redirect_landingurl)" ] &&
  { uci delete freifunk.luci.redirect_landingurl; uci commit freifunk.luci; }
endef

include ../../freifunk-berlin-generic.mk

# call BuildPackage - OpenWrt buildroot signature
