#
# This is free software, licensed under the GNU General Public License v3.0 .
#

LUCIMKFILE:=$(wildcard $(TOPDIR)/feeds/*/luci.mk)

# verify that there is only one single file returned
ifneq (1,$(words $(LUCIMKFILE)))
ifeq (0,$(words $(LUCIMKFILE)))
$(error did not find luci.mk in any feed)
else
$(error found multiple luci.mk files in the feeds)
endif
else
#$(info found luci.mk at $(LUCIMKFILE))
endif

PKG_VERSION?=$(if $(DUMP),x,$(strip $(shell \
	if svn info >/dev/null 2>/dev/null; then \
		revision="svn-r$$(LC_ALL=C svn info | sed -ne 's/^Revision: //p')"; \
	elif git log -1 >/dev/null 2>/dev/null; then \
		revision="svn-r$$(LC_ALL=C git log -1 | sed -ne 's/.*git-svn-id: .*@\([0-9]\+\) .*/\1/p')"; \
		if [ "$$revision" = "svn-r" ]; then \
			set -- $$(git log -1 --format="%ct %h" --abbrev=7); \
			secs="$$(($$1 % 86400))"; \
			yday="$$(date --utc --date="@$$1" "+%y.%j")"; \
			revision="$$(printf 'git-%s.%05d-%s' "$$yday" "$$secs" "$$2")"; \
		fi; \
	else \
		revision="unknown"; \
	fi; \
	echo "$$revision" \
)))

include $(LUCIMKFILE)
