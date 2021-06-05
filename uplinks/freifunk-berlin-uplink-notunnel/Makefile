include $(TOPDIR)/rules.mk

LUCI_TITLE:=Freifunk Berlin no tunnel files
LUCI_DEPENDS:=+freifunk-berlin-lib-guard +kmod-veth +freifunk-berlin-network-defaults +pingcheck
PKG_PROVIDES:=freifunk-berlin-uplink

LUCI_DESCRIPTION:=Freifunk Berlin files to setup a uplink without any tunnel.\
  upstream traffic will be directly routed via your network

define Package/freifunk-berlin-uplink-notunnel/postinst
# noop
endef

include ../../freifunk-berlin-generic.mk

# call BuildPackage - is done via freifunk-berlin-generic.mk --> luci.mk
