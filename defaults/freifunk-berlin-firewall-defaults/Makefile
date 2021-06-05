include $(TOPDIR)/rules.mk

LUCI_TITLE:=Freifunk Berlin firewall default configuration
LUCI_DEPENDS= +firewall +freifunk-berlin-lib-guard
LUCI_DESCRIPTION:=Freifunk Berlin configuration files for firewall

define Package/freifunk-berlin-firewall-defaults/postinst
# noop
endef

include ../../freifunk-berlin-generic.mk

# call BuildPackage - is done via freifunk-berlin-generic.mk --> luci.mk
