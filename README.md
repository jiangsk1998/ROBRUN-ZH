# ROB RUN 简体中文汉化包

> 为 Steam 游戏 **ROB RUN**（AppID `4262460`）制作的简体中文语言包。官方目前未提供中文，本项目通过替换 Unity Addressables 语言包实现界面汉化，**不修改任何可执行文件或 DLL**。

![platform](https://img.shields.io/badge/platform-Windows-blue)
![game](https://img.shields.io/badge/game-Rob%20Run%202026.11-lightgrey)
![coverage](https://img.shields.io/badge/coverage-95.9%25-brightgreen)
![license](https://img.shields.io/badge/license-MIT%20%2B%20CC%20BY--NC--SA-green)
![release](https://img.shields.io/github/v/release/jiangsk1998/ROBRUN-ZH)

---

## 简介

ROB RUN 使用 Unity Localization 框架，所有界面文本打包在单个 Addressables 资源中：

```
ROB RUN_Data\StreamingAssets\aa\StandaloneWindows64\
    localization-string-tables-english(unitedstates)(en-us)_assets_all.bundle
```

游戏内置了完整的本地化系统，但官方语言包只有 6 种（英 / 法 / 德 / 葡 / 俄 / 西），**没有中文**。本项目做的事就是：把这个英文语言包里的 `4763` 条文本翻译成简体中文，重新封包成一个可以替换原文件的 bundle。

| 项目 | 数值 |
|---|---|
| 文本总数 | 4763 条 |
| 已中文化 | **4567 条（95.9%）** |
| 人工校定术语 | 98 条（见 [`tools/glossary.json`](tools/glossary.json)） |
| 未翻译 | 195 条（武器型号、纯符号、占位符，保留原文更合适） |
| 补丁体积 | 273 KB |

## 快速开始

### 一键安装（推荐）

1. 下载 `ROBRUN-ZH-CN.zip`（**仓库根目录**里的始终是最新版；Releases 页面可能滞后），解压到任意位置
2. **完全退出游戏**（包括 Steam 里的 ROB RUN）
3. 双击 `安装汉化.bat`
4. 看到「[成功] 汉化已安装」后，从 Steam 库正常启动游戏

脚本会自动读取注册表和 `libraryfolders.vdf`，在所有 Steam 库中定位游戏目录，不需要你手动找路径。

> **窗口一闪而过？** 正常情况脚本会停在「按任意键继续」。如果真的秒关，请打开 `%TEMP%\ROBRUN-ZH-install.log` 看最后几行——通常是杀软拦截了 PowerShell，右键「以管理员身份运行」或把解压目录加入信任区即可。细节见 [常见问题](docs/常见问题.md)。

### 手动安装

把仓库里的 [`patch/`](patch/) 目录下的 bundle 文件，覆盖到：

```
<你的Steam库>\steamapps\common\Rob Run\ROB RUN_Data\StreamingAssets\aa\StandaloneWindows64\
```

覆盖前建议先把原文件改名为 `..._assets_all.bundle.original_bak` 备份。

### 卸载 / 还原英文

- 双击 `卸载汉化.bat`（把 `.original_bak` 还原回去并删除备份）
- 或者：Steam 库 → 右键 ROB RUN → 属性 → 已安装文件 → **验证游戏文件的完整性**，Steam 会自动下载回原版语言包

## 目录结构

```
ROBRUN-ZH/
├── installer/                 安装/卸载脚本（PowerShell + 批处理）
│   ├── install.ps1
│   ├── uninstall.ps1
│   ├── 安装汉化.bat
│   └── 卸载汉化.bat
├── patch/                     汉化后的语言包（成品，可直接覆盖）
│   └── localization-string-tables-english(...)_assets_all.bundle
├── strings/                   纯文本，方便 diff 和校对
│   ├── strings_en.json        英文原文（4763 条）
│   └── strings_zh.json        中文译文
├── tools/                     从零重建整个补丁的工具链
│   ├── extract.py             从游戏资源提取原文
│   ├── translate.py           批量机器翻译 + 术语表校正
│   ├── build.py               回写并重新封包
│   ├── glossary.json          人工校定的术语表
│   └── requirements.txt
└── docs/
    ├── 技术原理.md
    └── 常见问题.md
```

## 技术原理

一句话：**用 UnityPy 读出 MonoBehaviour 的 TypeTree，逐条替换 `m_Localized` 字段，再按原格式封包。**

```
原版 bundle
   │  UnityPy.load()
   ▼
MonoBehaviour: StaticStrings_en-US
   m_TableData: [ { m_Id, m_Key, m_Localized }, ... ]   ← 4763 条
   │  替换 m_Localized（术语表优先 > 机器翻译 > 回退原文）
   ▼
obj.save_typetree(tree)  →  env.save()
   │
   ▼
汉化 bundle（结构与原版一致，仅文本变化）
```

这样做的好处：

- **不动 `Assembly-CSharp.dll`、不注入、不打内存补丁** —— 只替换一个资源文件
- **保留完整 TypeTree**，封包后的资源能被引擎正常反序列化
- 富文本标签 `<color=...>` 和占位符 `{0}` 在翻译前做标记保护，翻完还原，不会被翻坏

细节见 [`docs/技术原理.md`](docs/技术原理.md)。

## 自己重新构建

想换翻译风格、修某几条译文，或者游戏更新后要重新生成补丁：

```bash
pip install -r tools/requirements.txt

# 1. 从游戏里提取原文（游戏更新后先重跑这一步）
python tools/extract.py --game "D:\Steam\steamapps\common\Rob Run" -o strings/strings_en.json

# 2. 翻译（可中断，重跑自动续上；术语表里的词条不会被覆盖）
python tools/translate.py -i strings/strings_en.json -o strings/strings_zh.json

# 3. 封包，产物在 dist/bundle/
python tools/build.py --game "D:\Steam\steamapps\common\Rob Run"
```

> `build.py` 会优先读取 `*.original_bak`，避免在已汉化的包上二次打补丁。

## 参与改进

**最有价值的贡献是改译文。** 不需要懂代码：

1. 打开 [`strings/strings_zh.json`](strings/strings_zh.json)，找到要改的条目（按 `id` 定位，原文见 `strings_en.json`）
2. 直接改 `"value"`，提 PR 说明改了什么、为什么
3. 界面上的高频词条请在 [`tools/glossary.json`](tools/glossary.json) 里改，格式是 `"英文原文": "中文译文"` —— 术语表的优先级最高

词汇风格上尽量靠近国内射击 / 生存类游戏的通用译法，例如：

| 英文 | 本项目译法 | 说明 |
|---|---|---|
| Body Armor | 防弹衣 | 不用「身体护甲」 |
| Wanted Level | 通缉等级 | |
| Clan | 帮派 | 不用「氏族」 |
| Carabiner | 快挂 | 登山扣具的通用叫法 |
| Trunk | 后备箱 | 载具语境 |
| Settlement | 据点 | |

## 常见问题

**Q：装完进游戏还是英文？**
确认你替换的是 `ROB RUN_Data\StreamingAssets\aa\StandaloneWindows64\` 下的那个同名文件；如果装过多次，确认游戏目录里只有一份。另外游戏内语言设置保持 English 即可——我们替换的就是「英文」语言包，所以切到英文反而是中文。

**Q：会影响联机 / 被封号吗？**
本项目只替换一个文本资源，不改逻辑、不注入内存。目前没有因换语言包被封的记录。但它确实修改了游戏文件，而 ROB RUN 使用 Easy Anti-Cheat，理论上存在被判定文件异常的可能，**风险请自行判断**。不放心就跑一次「卸载汉化.bat」。

**Q：游戏更新后变回英文了？**
Steam 更新会覆盖语言包。重新运行一次 `安装汉化.bat` 即可；若更新改了文本结构（条目数变了），需要先跑 `extract.py` 重新提取。

**Q：为什么不翻武器型号？**
`MC-10 Mk1` 这类型号名保留原文更符合玩家习惯，硬翻反而看不懂。

更多见 [`docs/常见问题.md`](docs/常见问题.md)。

## 免责声明

- 本项目仅供**个人学习与交流**使用，请勿用于商业用途
- 游戏《ROB RUN》的一切权利归 **Kefir** 所有；`strings/strings_en.json` 中的英文原文版权属于原作者
- 本项目**不含**任何游戏本体文件，不提供破解、绕过 DRM 或反作弊的功能
- 使用本补丁产生的任何后果（包括但不限于账号异常、文件校验失败）由使用者自行承担
- 如果你喜欢这个游戏，请通过 Steam 购买正版支持开发者

## 许可证

- `tools/`、`installer/` 下的代码：[MIT](LICENSE)
- 译文文本：CC BY-NC-SA 4.0（署名 - 非商业性使用 - 相同方式共享）
- 英文原文与游戏资源：版权归 Kefir 所有，见 [NOTICE.md](NOTICE.md)
