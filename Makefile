
# perl libraries & binaries
PLIBS	= AddFiles MakeFATImage MakeMinixImage ReadConfig
PBINS	= initrd_test mk_boot mk_initrd mk_initrd_test mk_root  

.PHONY: all dirs initrd initrd_test boot boot_axp rescue\
        root demo modules html clean distdir install install_xx rdemo brescue
	rescue_cd mboot base bootcd2 bootdisk bootcd rootcd

all:

install:

distdir: clean
	@mkdir -p $(distdir)
	@tar -cf - . | tar -C $(distdir) -xpf -
	@find $(distdir) -depth -name CVS -exec rm -r {} \;

dirs:
	@[ -d images ] || mkdir images
	@[ -d test ] || mkdir test
	@[ -d tmp ] || mkdir tmp

initrd: dirs base
	YAST_IS_RUNNING=1 bin/mk_initrd

plain_initrd: dirs
	YAST_IS_RUNNING=1 bin/mk_initrd

initrd_test: initrd
	bin/mk_initrd_test
	@echo "now, run bin/initrd_test"

boot: initrd mboot
	bin/mk_boot

bootcd2:
#	linuxrc=linuxrc_tiny use_k_inst=1 nopcmcia=1 nousb=1 fewkeymaps=1 initrd_name=small initrd=small bootlogo=no boot=small make boot
	initrd=medium boot=medium make boot

bootdisk:
# with_smb=1
	noinitrd=small initrd=small bootsplash=yes boot=small make boot

bootcd:
# with_smb=1
	initrd=large boot=isolinux make boot

rootcd:
	use_cramfs=1 make root

boot_axp: initrd
	bin/mk_boot_axp

install_xx: initrd
	bin/mk_install_xx

root: dirs base
	YAST_IS_RUNNING=1 bin/mk_root

demo: dirs base
	bin/mk_demo

rdemo: dirs base
	bin/mk_rdemo

rescue: dirs base
	YAST_IS_RUNNING=1 bin/mk_rescue

brescue: dirs base
	bin/mk_brescue

rescue_cd: boot brescue rdemo
	bin/mk_rescue_cd

modules: dirs base
	bin/mk_modules
	bin/mk_mod_disk

hp1disks:
	hp1=1 usbscsi=1 fastboot=1 linuxrc=linuxrc_tiny make bootdisk
	hp1=1 modules=1 make modules

usbdisks:
	usbscsi=1 fastboot=1 make bootdisk
	modules=1 make modules
	modules=2 make modules
	modules=3 make modules
	modules=4 make modules

mboot:
	make -C src/mboot

base: dirs
	@[ -d tmp/base ] || YAST_IS_RUNNING=1 bin/mk_base

html:
	@for i in $(PLIBS); do echo $$i; pod2html --noindex --title=$$i --outfile=doc/$$i.html lib/$$i.pm; done
	@for i in $(PBINS); do echo $$i; pod2html --noindex --title=$$i --outfile=doc/$$i.html bin/$$i; done
	@rm pod2html-dircache pod2html-itemcache

clean:
	-@make -C src/mboot clean
	-@umount test/initdisk/proc 2>/dev/null ; true
	-@umount test/initdisk/mnt 2>/dev/null ; true
	-@rm -rf images test tmp
	-@rm -f `find -name '*~'`
	-@rm -rf /tmp/mk_base_* /tmp/mk_initrd_* /tmp/mk_rescue_* /tmp/mk_root_* 
	-@rm -rf data/initrd/gen data/boot/gen
