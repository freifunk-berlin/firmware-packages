include $(TOPDIR)/rules.mk

LUCI_TITLE:=Freifunk Berlin dhcp default configuration
LUCI_DEPENDS:=+dnsmasq +freifunk-berlin-lib-guard
LUCI_DESCRIPTION:=Freifunk Berlin configuration files for dhcp

define Package/freifunk-berlin-dhcp-defaults/postinst
# noop
endef

include ../../freifunk-berlin-generic.mk

# call BuildPackage - is done via freifunk-berlin-generic.mk --> luci.mk
