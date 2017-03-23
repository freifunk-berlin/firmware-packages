#
# Copyright (C) 2016 Freifunk Berlin
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=collectd-addons
PKG_VERSION:=0.0.2
PKG_RELEASE:=2

UBIQUITI_MIBS_REL=ubnt-mibs_20160803.zip

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/collectd-addons/default
  SECTION:=freifunk-berlin
  CATEGORY:=freifunk-berlin
  URL:=http://github.com/freifunk-berlin/packages_berlin
  PKGARCH:=all
endef

define Package/collectd-snmp-templates
  $(call Package/collectd-addons/default)
  TITLE:=Templates to gather statistics from different SNMP-nodes
  DEPENDS:=+collectd-mod-snmp +snmp-mibs
endef

define Package/collectd-snmp-templates/description
  Freifunk Berlin configuration files for statistics
endef

define Package/collectd-dnsmasq-addon
  $(call Package/collectd-addons/default)
  TITLE:=monitor the usage of the DHCP-range of dnsmasq
  DEPENDS:=+luci-app-statistics +collectd-mod-exec dnsmasq
endef

define Package/collectd-dnsmasq-addon/description
  addon script to monitor the usage of the DHCP-range of dnsmasq
endef

define Download/ubnt_mibs
	URL_FILE:=UBNT-MIBs.zip
	URL:=https://help.ubnt.com/hc/en-us/article_attachments/203306028/
	MD5SUM:=92087a11d75a94c7cfdb81f730642614
	FILE:=$(UBIQUITI_MIBS_REL)
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	mkdir -p $(PKG_BUILD_DIR)/ubnt-mibs
	unzip -j $(DL_DIR)/$(UBIQUITI_MIBS_REL) -d $(PKG_BUILD_DIR)/ubnt-mibs
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/collectd-snmp-templates/install
	$(INSTALL_DIR) $(1)/usr/share/snmp/mibs
	$(CP) $(PKG_BUILD_DIR)/ubnt-mibs/* $(1)/usr/share/snmp/mibs
	$(INSTALL_DIR) $(1)/etc/collectd/conf.d
	$(INSTALL_DIR) $(1)/etc/collectd/conf.d-templates
	$(CP) ./files/collectd-snmp/* $(1)/etc/collectd/conf.d-templates
	$(INSTALL_DIR) $(1)/lib/upgrade/keep.d
	echo  >$(1)/lib/upgrade/keep.d/collectd-snmp "# by $(PKG_NAME)"
	echo >>$(1)/lib/upgrade/keep.d/collectd-snmp "/etc/collectd/conf.d"
endef

define Package/collectd-dnsmasq-addon/install
	$(INSTALL_DIR) $(1)/etc/collectd/
	$(INSTALL_BIN) ./files/collectd-dnsmasq/dnsmasq.sh $(1)/etc/collectd/
	$(INSTALL_DIR) $(1)/tmp
	$(INSTALL_BIN) ./files/collectd-dnsmasq/postinst.sh $(1)/tmp/collectd-dnsmasq-addon_postinst.sh
endef

define Package/collectd-dnsmasq-addon/postinst
#!/bin/sh
$${IPKG_INSTROOT}/tmp/collectd-dnsmasq-addon_postinst.sh
endef

$(eval $(call Download,ubnt_mibs))
$(eval $(call BuildPackage,collectd-snmp-templates))
$(eval $(call BuildPackage,collectd-dnsmasq-addon))
