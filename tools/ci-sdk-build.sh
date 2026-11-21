#!/bin/sh
# 在官方 OpenWrt SDK 里编主题包。
#
#   VERSION=0.14.21 ./tools/ci-sdk-build.sh <SDK 根> <产物目录>
#
# 编出来的不止主题本体：luci.mk 会把 po/ 下的每个语言目录变成一个包，中文目录
# （po/zh_Hans）因此自动得到 luci-i18n-footstrap-zh-cn，不需要另写包定义。
#
# CI 与本地走同一条路径：工作流只是先把 SDK 压缩包解开，再调这个脚本。两个包都是
# all/noarch，所以在哪个架构的 SDK 里编都一样——用 x86_64 的 SDK 当编译宿主，
# 不需要架构矩阵。
set -eu

SDK="${1:?用法: VERSION=<版本号> $0 <SDK 根> <产物目录>}"
OUT="${2:?用法: VERSION=<版本号> $0 <SDK 根> <产物目录>}"
VERSION="${VERSION:?请用 VERSION=<版本号> 指定版本}"
SRC="$(cd "$(dirname "$0")/.." && pwd)"

[ -f "$SDK/rules.mk" ] || {
	echo "不是 SDK 根目录（缺 rules.mk）：$SDK" >&2
	exit 1
}
# 产物目录相对路径按调用者的当前目录算，下面 cd 进 SDK 之后就找不回来了。
case "$OUT" in
	/*) ;;
	*) OUT="$PWD/$OUT" ;;
esac

cd "$SDK"

# luci-theme-footstrap/Makefile 用绝对路径 include $(TOPDIR)/feeds/luci/luci.mk，
# 所以 luci feed 必须先落盘。SDK 压缩包里只有 feeds.conf.default，feed 本身要拉。
#
# 只 update、不 install luci-base：+luci-base 是运行时依赖（写进 control 的 Depends），
# 编译期一个头文件都不需要。一旦 install 它，defconfig 会把它当成可满足的依赖选上，
# 编译目标就去编 luci-base 和目标机 toolchain 下的整条链，SDK 里那几个 feed 没装，
# 只会一路红。
[ -f feeds.conf ] || cp feeds.conf.default feeds.conf
[ -f feeds/luci/luci.mk ] || ./scripts/feeds update luci

# 包定义挂进 SDK。符号链接就够了：打包只读源码树，不往里写。
rm -f package/luci-theme-footstrap
ln -s "$SRC/luci-theme-footstrap" package/luci-theme-footstrap

# .config 必须由 defconfig 先生成：没有它时，任何编译目标都会掉进 menuconfig 的界面
# 等键盘——在 CI 里就是跑满 timeout 的空转，看起来像卡死。收尾的 </dev/null 是保底：
# 万一哪一步又想要输入，宁可立刻失败，不要静默挂住。
make defconfig </dev/null

# 语言包默认不选（luci.mk 给它的 DEFAULT 是空的），显式选上；否则编译目标只出
# 主题本体，而构建本身不会报任何错——正是要避免的失败方式。选完再 defconfig 一次，
# 让依赖跟着解析。
for sym in luci-theme-footstrap luci-i18n-footstrap-zh-cn; do
	grep -qx "CONFIG_PACKAGE_$sym=y" .config 2>/dev/null ||
		echo "CONFIG_PACKAGE_$sym=y" >> .config
done
make defconfig </dev/null

# luci.mk 调用的 po2lmo（po/ → .lmo，语言包靠它）和 jsmin（压 JS）来自 luci-base 的
# host 部分，SDK 里没有预装，也没有 host 目标可 make：luci.mk 只 include 了
# package.mk，没 include host-build.mk，`make package/.../host/install` 会报无规则。
# 于是直接按 luci-base 自己的 Host/Compile 那两行编出来，放进包构建的 PATH：
# TARGET_PATH_PKG 含 staging_dir/hostpkg/bin（rules.mk）。少了它们，主题本体能编过、
# 语言包会在打包时报错。
make -C feeds/luci/modules/luci-base/src clean po2lmo jsmin </dev/null
mkdir -p "$SDK/staging_dir/hostpkg/bin"
install -m755 feeds/luci/modules/luci-base/src/po2lmo \
	feeds/luci/modules/luci-base/src/jsmin "$SDK/staging_dir/hostpkg/bin/"

# PKG_VERSION 给主题包，PKG_PO_VERSION 给语言包。两处都要带 -r1：主题包由
# package-pack.mk 补 PKG_RELEASE，语言包的 VERSION 是 luci.mk 直接取 PKG_PO_VERSION
# 原文，不补 release，只给 0.14.21 的话两个包版本号会对不上（也不跟着升级）。
make package/luci-theme-footstrap/compile -j"$(nproc)" \
	PKG_VERSION="$VERSION" PKG_PO_VERSION="$VERSION-r1" </dev/null

mkdir -p "$OUT"
found=0
# ipk 是 <name>_<version>_<arch>.ipk，apk 是 <name>-<version>.apk，两种都要收。
for f in bin/packages/*/*/luci-theme-footstrap[_-]* \
	bin/packages/*/*/luci-i18n-footstrap[_-]*; do
	[ -f "$f" ] || continue
	cp "$f" "$OUT/"
	found=$((found + 1))
done
[ "$found" -gt 0 ] || {
	echo "编译结束但没有产物，检查上面 make 的输出" >&2
	exit 1
}
echo "产物（$found 个）："
ls -l "$OUT"
