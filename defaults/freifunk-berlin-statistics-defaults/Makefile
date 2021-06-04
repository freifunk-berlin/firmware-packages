include $(TOPDIR)/rules.mk

LUCI_TITLE:=Freifunk Berlin statistics default configuration
LUCI_DEPENDS:=+olsrd-mod-txtinfo +freifunk-berlin-lib-guard
LUCI_DESCRIPTION:=Freifunk Berlin configuration files for statistics

define Package/freifunk-berlin-dhcp-defaults/postinst
# noop
endef

include ../../freifunk-berlin-generic.mk

# call BuildPackage - is done via freifunk-berlin-generic.mk --> luci.mk
