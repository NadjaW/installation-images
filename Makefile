
# perl libraries & binaries
PLIBS	= AddFiles MakeFATImage MakeMinixImage ReadConfig
PBINS	= initrd_test mk_boot mk_initrd mk_initrd_test mk_root  

.PHONY: all dirs initrd initrd_test boot boot_axp rescue \
        root liveeval html clean distdir install install_xx rdemo brescue \
	rescue_cd mboot base bootcd2 bootdisk bootcd rootcd rootfonts hal

all: bootdvd bootcd2 rescue root
	@rm -rf images/cd[12]
	@mkdir -p images/cd1/boot/loader images/cd2/boot
	@cp images/boot.small images/cd1/boot/bootdisk
	@cp -r images/boot.isolinux/* images/cd1/boot/loader
	@cp images/root.cramfs images/cd1/boot/root
	@cp images/rescue images/cd1/boot
	@cp images/boot.medium images/cd2/boot/image

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
	initramfs=$${initramfs:-1} YAST_IS_RUNNING=1 bin/mk_initrd

zeninitrd: dirs base
	initramfs=$${initramfs:-1} YAST_IS_RUNNING=1 theme=Zen filelist=zeninitrd bin/mk_initrd

zenboot: zeninitrd mboot
	theme=Zen initrd=large boot=isolinux memtest=no bin/mk_boot

zenroot: dirs base
	YAST_IS_RUNNING=1 theme=Zen use_cramfs= uncompressed_root=1 filelist=zenroot bin/mk_root

plain_initrd: dirs
	YAST_IS_RUNNING=1 bin/mk_initrd

initrd_test: initrd
	bin/mk_initrd_test
	@echo "now, run bin/initrd_test"

boot: initrd mboot
	bin/mk_boot

bootcd2: eltorito
#	initrd=medium boot=medium make boot
	cp src/eltorito/boot images/boot.cd2

bootdisk:
# with_smb=1
	initrd=large boot=small make boot

bootcd:
# with_smb=1
	initramfs=$${initramfs:-1} initrd=large boot=isolinux make boot

bootdvd:
# with_smb=1
	initramfs=$${initramfs:-1} is_dvd=1 initrd=large boot=isolinux make boot

rootcd:
	use_cramfs=1 make root

boot_axp: initrd
	bin/mk_boot_axp

install_xx: initrd
	bin/mk_install_xx

boot-efi: base
	image=boot-efi src=boot filelist=efi fs=none bin/mk_image
	ln images/initrd tmp/boot-efi/efi/boot/initrd
	bin/hdimage --size 500k --fit-size --chs 0 4 63 --part-ofs 0 --mkfs fat --add-files tmp/boot-efi/* tmp/boot-efi/.p* -- images/efi
	rm -f tmp/boot-efi/efi/boot/initrd

root: dirs base
	# just for now
	root_i18n=1 root_gfx=1 \
	YAST_IS_RUNNING=1 bin/mk_root

rootfonts: dirs base
	use_cramfs=0 nolibs=1 filelist=fonts image_name=root.fonts bin/mk_root

liveeval: dirs base
	bin/mk_liveeval

rdemo: dirs base
	bin/mk_rdemo

rescue: dirs base
	YAST_IS_RUNNING=1 bin/mk_rescue

hal: dirs base
	YAST_IS_RUNNING=1 filelist=hal bin/mk_rescue

brescue: dirs base
	bin/mk_brescue

rescue_cd: boot brescue rdemo
	bin/mk_rescue_cd

mboot:
	make -C src/mboot

eltorito:
	make -C src/eltorito

base: dirs
	@[ -d tmp/base ] || YAST_IS_RUNNING=1 bin/mk_base

html:
	@for i in $(PLIBS); do echo $$i; pod2html --noindex --title=$$i --outfile=doc/$$i.html lib/$$i.pm; done
	@for i in $(PBINS); do echo $$i; pod2html --noindex --title=$$i --outfile=doc/$$i.html bin/$$i; done
	@rm pod2html-dircache pod2html-itemcache

clean:
	-@make -C src/mboot clean
	-@make -C src/eltorito clean
	-@umount test/initdisk/proc 2>/dev/null ; true
	-@umount test/initdisk/mnt 2>/dev/null ; true
	-@rm -rf images test tmp
	-@rm -f `find -name '*~'`
	-@rm -rf /tmp/mk_base_* /tmp/mk_initrd_* /tmp/mk_rescue_* /tmp/mk_root_* 
	-@rm -rf data/initrd/gen data/boot/gen data/base/gen data/demo/gen
