#
# Copyright (C) 2008-2014 The LuCI Team <luci@lists.subsignal.org>
# Modified 2015 by Freifunk Berlin
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=Freifunk Public and Admin LuCI UI
LUCI_SECTION:=luci
LUCI_CATEGORY:=LuCI
LUCI_SUBMENU_FORCED:=2. Modules
LUCI_DEPENDS:=+luci-mod-admin-full +luci-lib-json +community-profiles +luci-lib-ipkg
LUCI_PKGARCH:=all
PKG_RELEASE:=3

include ../../freifunk-berlin-generic.mk

# call BuildPackage - OpenWrt buildroot signature
