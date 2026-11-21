# luci-theme-footstrap（中文分支）

本仓库是 [VizzleTF/luci-theme-footstrap](https://github.com/VizzleTF/luci-theme-footstrap)
的分支，在其基础上完成两项改动：

- 增加简体中文翻译，并作为独立语言包 `luci-i18n-footstrap-zh-cn` 分发；
- 将构建流程统一为官方 SDK 单一路径，产物通过 GitHub Release 分发，不再依赖 owfeed
  与真机 e2e 流水线。

主题本身的行为与外观与上游一致，上游的[开发者文档](docs/README.md)在本仓库同样适用。

<picture>
  <source media="(max-width: 767px)" srcset="assets/readme/phone-menu-dark.png">
  <img src="assets/readme/overview-top-dark.png" width="100%" alt="深色模式下的概览页：菜单与品牌位于同一行，内容占满宽度。">
</picture>

## 功能

| 项目 | 说明 |
|---|---|
| 依赖 | 仅 `luci-base` |
| 覆盖范围 | 为 LuCI 全部页面提供样式，含第三方 `luci-app-*` |
| 自带样式的应用 | 不覆盖应用自行定义的样式 |
| 移动端 | 支持手机访问，并可添加至主屏幕 |
| 外观 | 布局、配色、密度、字号、圆角、壁纸、透明度等二十余项设置，修改后即时生效，无需刷新页面 |
| 语言 | 简体中文、俄语、西班牙语，各为独立语言包 |

## 版本要求

| 系统 | 支持情况 |
|---|---|
| OpenWrt 25.12 及以上（包管理器 `apk`） | 提供 `.apk` 包 |
| OpenWrt 24.10.3 及以上（包管理器 `opkg`） | 提供 `.ipk` 包 |
| OpenWrt 24.10.0 – 24.10.2 | 不支持。该版本区间缺少主题所依赖的 LuCI 组件，需先升级 OpenWrt |
| OpenWrt 23.05 | 仅可使用上游 0.14.2 版本，本仓库不提供该版本的包 |

浏览器要求 Chrome 120、Firefox 121、Safari 17.2 及以上。OpenWrt 版本可通过路由器上的
`cat /etc/openwrt_release` 查看。

## 安装

本仓库不提供软件源，仅通过 GitHub Release 分发安装包，因此安装分为下载与安装两步。

### 1. 下载安装包

在 [Releases](https://github.com/SuLingGG/luci-theme-footstrap/releases/latest) 页面按系统
下载对应文件：

| 系统 | 文件 |
|---|---|
| 25.12 及以上（apk） | `luci-theme-footstrap-<版本>-r1.apk` |
| 24.10（opkg） | `luci-theme-footstrap_<版本>-r1_all.ipk` |
| 需要中文界面 | 另加同格式的 `luci-i18n-footstrap-zh-cn` |

已安装 `gh` 的环境可直接下载：

```sh
gh release download --repo SuLingGG/luci-theme-footstrap \
  --pattern 'luci-theme-footstrap*' --pattern 'luci-i18n-footstrap-zh-cn*' --dir /tmp/fs
```

> 未提供单行 `wget` 命令的原因：Release 附件文件名包含版本号，而
> `releases/latest/download/<文件名>` 要求文件名完全一致。通过 GitHub API 查询最新版本号
> 受来源 IP 限流（每小时 60 次，运营商 NAT 环境下多个用户共用同一 IP），上游仓库已就此
> 单独提交 issue。

### 2. 安装

将安装包传输至路由器（可使用 `scp`，或 LuCI 的「系统 → 软件包 → 上传」功能），然后执行：

```sh
# 25.12 及以上（apk）
apk add --allow-untrusted /tmp/luci-theme-footstrap-*.apk

# 24.10（opkg）
opkg install /tmp/luci-theme-footstrap_*.ipk
```

`--allow-untrusted` 仅针对安装包自身的签名：本仓库的包未签名。安装前可使用同一 Release
中的 `SHA256SUMS` 校验下载完整性：

```sh
cd /tmp && sha256sum -c SHA256SUMS
```

### 3. 启用

安装完成后主题不会自动切换，需手动选择一次：

1. 打开 **系统 → 系统 → 语言和界面**；
2. 在 **设计** 中选择 **Footstrap**；
3. 点击 **保存并应用**，页面将以新主题重新加载。

如需中文界面，在同一页面将 **语言** 设为 **简体中文**。该选项在安装语言包后才会出现。

### 升级与卸载

升级：按上述步骤安装新版本的安装包。卸载：

```sh
apk del luci-theme-footstrap luci-i18n-footstrap-zh-cn     # 25.12 及以上
opkg remove luci-theme-footstrap luci-i18n-footstrap-zh-cn  # 24.10
```

LuCI 将自动回退至 bootstrap，无需预先修改 **设计** 设置。

## 构建

### GitHub Actions

工作流位于 [`.github/workflows/build-packages.yml`](.github/workflows/build-packages.yml)，
支持三种触发方式：

| 触发方式 | 结果 |
|---|---|
| 手动运行（Actions → 编译并发布主题包 → Run workflow） | 可选 `all` / `openwrt-24.10` / `openwrt-25.12`，产物作为 artifact 上传，保留 14 天 |
| 推送至 `main` | 同上，构建两种格式 |
| 推送 `v*` 标签 | 先构建，随后由 `release` 作业将同一批产物发布至 GitHub Release |

构建仅有一条路径：下载官方 SDK 压缩包，在其中执行
`make package/luci-theme-footstrap/compile`。主题为 noarch，由 x86_64 SDK 构建的包可安装于
任意架构，因此不设架构矩阵。24.10 SDK 产出 `.ipk`，25.12 SDK 产出 `.apk`。

### 本地构建

需预先准备已解压的 OpenWrt SDK（[下载页面](https://downloads.openwrt.org/releases/)）：

```sh
VERSION=0.14.21 sh tools/ci-sdk-build.sh /path/to/sdk /tmp/out
```

该脚本与 CI 执行相同步骤：更新 luci feed、将包定义接入 SDK、生成 `.config`、显式选中主题包
与中文语言包、构建 SDK 未预装的 `po2lmo` 与 `jsmin`，最终将 `luci-theme-footstrap` 与各
`luci-i18n-footstrap-*` 包输出至 `/tmp/out`。

### 发布版本

1. 将 `CHANGELOG.md` 中的 `## [Unreleased]` 改为 `## [<版本>] — <日期>`，并同步修改
   `CHANGELOG_ru.md`（`npm run changelog` 会校验两份文件是否一致）；
2. 提交后为该提交打标签并推送：

   ```sh
   git tag v0.14.22
   git push fork v0.14.22
   ```

3. 工作流完成后，Release 页面将包含 `.ipk`、`.apk` 与 `SHA256SUMS`。发布说明取自
   `CHANGELOG.md` 中对应版本的章节；若无对应章节，则使用自动生成的提交列表。

## 性能

同一路由器上，页面绘制耗时中位数为 bootstrap 的三分之一。38 个页面的巡览耗时 4.9 秒，
bootstrap 为 11.3 秒。方法与数据见 [docs/benchmark.md](docs/benchmark.md)。

## 相关链接

- [截图](docs/screenshots/)
- [开发者文档](docs/README.md)：建议从 [architecture.md](docs/architecture.md) 与
  [conventions.md](docs/conventions.md) 开始
- [为 `luci-app` 编写样式](docs/luci-app-styling-guide.md)，以及用于校验的
  [devkit](https://vizzletf.github.io/luci-theme-footstrap/)
- [更新日志](CHANGELOG.md) · [许可证：Apache-2.0](LICENSE)

上游仓库另提供[软件源](https://owfeed.org/install/)与基于 `install.sh` 的单行安装命令，
本仓库均未采用：本仓库的安装包仅通过 Release 附件分发。
