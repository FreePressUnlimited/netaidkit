NAK_FEEDS = https://github.com/freepressunlimited/netaidkit-feeds;trunk
LEDE_BRANCH = lede-17.01

# Not really a proper Makefile, nor it ever can be. Sorry!
.PHONY: all image submodules clean mrproper update_feeds configure \
	install_nak_env set_ssh_password enable_root_ssh dev_image \
    dev_configure update_release_info clean_feeds
.DEFAULT: all

all: image

image: submodules update_feeds configure install_nak_env \
                                        update_release_info
	+make -C lede

dev_image: submodules update_feeds dev_configure install_nak_env \
				enable_root_ssh set_ssh_password update_release_info
	+make -C lede

submodules:
	(cd lede && git checkout feeds.conf.default || true)
	git submodule update --init lede
	cd lede && git fetch
	cd lede && git checkout origin/$(LEDE_BRANCH)
	git submodule update --init netaidkit-env
	cd netaidkit-env && git fetch
	cd netaidkit-env && git checkout origin/master

# This will clean package build directories. Package files will temporarily
# remain in the image root, but it's recreated every time an image is built.
clean_nak:
	+cd lede && make package/nakd/clean
	+cd lede && make package/nak-web/clean

clean: clean_nak
	+cd lede && make clean

mrproper_nak: clean_nak
	rm -f lede/dl/nakd-*
	rm -f lede/dl/nak-web-*
	rm -rf lede/files/*

mrproper: clean mrproper_nak clean_feeds
	+cd lede && make distclean
	cd lede && git clean -fd

add_nak_feeds: submodules
	(! grep -q netaidkit lede/feeds.conf.default && \
		cd lede && sed -i \
		'1 i\src-git netaidkit $(NAK_FEEDS)' \
		feeds.conf.default) || true

update_feeds: add_nak_feeds submodules
	+cd lede && ./scripts/feeds update \
		&& ./scripts/feeds install -a

clean_feeds:
	rm -rf lede/dl/*
	rm -rf lede/feeds/*

configure: submodules update_feeds
	cat netaidkit.config > lede/.config
	+cd lede && make defconfig # expand to full configuration

dev_configure: submodules update_feeds
	cat netaidkit.config > lede/.config
	cat netaidkit_dev.config >> lede/.config
	+cd lede && make defconfig

install_nak_env: submodules
	rm -rf lede/files
	mkdir -p lede/files
	git archive --remote=netaidkit-env --format=tar HEAD | \
		tar -x -C lede/files
	mkdir -p lede/files/usr/share/nak/defaults
	git archive --remote=netaidkit-env --format=tar HEAD | \
		tar -x -C lede/files/usr/share/nak/defaults

# These changes will end up in lede/files, netaidkit-env remains unchanged.
enable_root_ssh: submodules install_nak_env
	./scripts/enable_root_ssh.py

set_ssh_password: submodules install_nak_env
	./scripts/change_rootpwd.py "\`K@qt1)pLMto"

update_release_info: submodules install_nak_env
	./scripts/make_release.sh
