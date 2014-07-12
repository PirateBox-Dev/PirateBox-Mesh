NAME = piratebox-mesh
VERSION = 1.1.2
ARCH = all
IPK = $(NAME)_$(VERSION)_$(ARCH).ipk
IPKDIR = src
NON_WRT = $(NAME)_$(VERSION)_$(ARCH)_NON_WRT.sh

.DEFAULT_GOAL = all

$(IPKDIR)/control.tar.gz: $(IPKDIR)/control
	tar czf $@ -C $(IPKDIR)/control .

control: $(IPKDIR)/control.tar.gz 

$(IPKDIR)/data.tar.gz: $(IPKDIR)/data
	tar czf $@ -C $(IPKDIR)/data .


data: $(IPKDIR)/data.tar.gz $(IPKPSDIR)/data.tar.gz


$(IPK): $(IPKDIR)/control.tar.gz $(IPKDIR)/data.tar.gz $(IPKDIR)/control $(IPKDIR)/data
	tar czf $@ -C $(IPKDIR) ./control.tar.gz ./data.tar.gz debian-binary

all: $(IPK) $(NON_WRT)

cleanbuild:
	-rm -f $(IPKDIR)/control.tar.gz
	-rm -f $(IPKDIR)/data.tar.gz

clean: cleanbuild cleanlaptop
	-rm -f $(IPK)

laptop: $(NON_WRT)

$(NON_WRT):
	cat src/data/etc/mesh.config > $(NON_WRT)
	grep -v \#! src/data/usr/share/mesh/mesh.common >>  $(NON_WRT)
	sed 's/OPENWRT=yes/OPENWRT=no/' -i $(NON_WRT)
	sed 's/IPV4_LOAD="yes"/IPV4_LOAD="no"/' -i $(NON_WRT)
	cat non-wrt/piece_start_stop >> $(NON_WRT)


cleanlaptop:
	-rm -f $(NON_WRT)


.PHONY: all clean laptop 

