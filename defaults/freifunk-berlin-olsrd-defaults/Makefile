include $(TOPDIR)/rules.mk

LUCI_TITLE:=Freifunk Berlin olsrd default configuration
LUCI_DEPENDS:=+olsrd +freifunk-common-olsr +freifunk-berlin-lib-guard
LUCI_DESCRIPTION:=Freifunk Berlin configuration files for olsrd and olsrd6

define Package/freifunk-berlin-olsrd-defaults/postinst
# noop
endef

include ../../freifunk-berlin-generic.mk

# call BuildPackage - is done via freifunk-berlin-generic.mk --> luci.mk
