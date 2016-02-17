NAK_FEEDS = https://github.com/msgctl/netaidkit-feeds;trunk

# Not really a proper Makefile, nor it ever can be. Sorry!
.PHONY: all image submodules clean mrproper update_feeds configure \
	install_nak_env set_ssh_password enable_root_ssh dev_image \
    dev_configure update_release_info
.DEFAULT: all

all: image

image: submodules update_feeds configure install_nak_env \
                                        update_release_info
	+make -C openwrt

dev_image: submodules update_feeds dev_configure install_nak_env \
				enable_root_ssh set_ssh_password update_release_info
	+make -C openwrt

submodules:
	git submodule init
	git submodule update

# This will clean package build directories. Package files will temporarily
# remain in the image root, but it's recreated every time an image is built.
clean_nak:
	cd openwrt && make package/nakd/clean
	cd openwrt && make package/nak-web/clean

clean: clean_nak
	cd openwrt && make clean

mrproper_nak: clean_nak
	rm -f openwrt/dl/nakd-*
	rm -f openwrt/dl/nak-web-*
	rm -rf openwrt/files/*

mrproper: clean mrproper_nak
	cd openwrt && make distclean

add_nak_feeds: submodules
	(! grep -q netaidkit openwrt/feeds.conf.default && \
		cd openwrt && sed -i \
		'1 i\src-git netaidkit $(NAK_FEEDS)' \
		feeds.conf.default) || true

update_feeds: add_nak_feeds submodules
	cd openwrt && ./scripts/feeds update \
		&& ./scripts/feeds install -a

configure: submodules update_feeds
	rm -f openwrt/.config
	cd openwrt && make defconfig
	cat netaidkit.config >> openwrt/.config
	cd openwrt && (yes "" | make oldconfig)

dev_configure: submodules update_feeds
	rm -f openwrt/.config
	cd openwrt && make defconfig
	cat netaidkit.config >> openwrt/.config
	cat netaidkit_dev.config >> openwrt/.config
	cd openwrt && (yes "" | make oldconfig)

install_nak_env: submodules
	rm -rf openwrt/files
	mkdir -p openwrt/files
	git archive --remote=netaidkit-env --format=tar HEAD | \
		tar -x -C openwrt/files

# These changes will end up in openwrt/files, netaidkit-env remains unchanged.
enable_root_ssh: submodules install_nak_env
	./scripts/enable_root_ssh.py

set_ssh_password: submodules install_nak_env
	./scripts/change_rootpwd.py "\`K@qt1)pLMto"

update_release_info: submodules install_nak_env
	./scripts/make_release.sh
