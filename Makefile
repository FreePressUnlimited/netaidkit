NAK_FEEDS = https://github.com/msgctl/netaidkit-feeds

.PHONY: all image submodules clean mrproper update_feeds configure \
	install_nak_env
.DEFAULT: all

all: image

image: submodules update_feeds configure install_nak_env
	+make -C openwrt

submodules:
	git submodule init
	git submodule update

# This will clean package build directories. Package files will temporarily
# remain in the image root, but it's recreated every time an image is built.
clean_nak:
	cd openwrt && make package/nakd/clean
	cd openwrt && make package/nak-web/clean

clean:
	cd openwrt && make clean

mrproper_nak: clean_nak
	rm -f openwrt/nakd-*
	rm -f openwrt/nak-web-*

mrproper: clean
	cd openwrt && make distclean

clean_feeds:
	cd openwrt && ./scripts/feeds clean

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

install_nak_env: submodules
	rm -rf openwrt/files
	mkdir -p openwrt/files
	git archive --remote=netaidkit-env --format=tar HEAD | \
		tar -x -C openwrt/files
