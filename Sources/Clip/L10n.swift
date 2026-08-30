import Foundation

enum L10n {
    static var chinese: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }

    static var appName: String { "Clip" }
    static var history: String { chinese ? "历史" : "History" }
    static var search: String { chinese ? "搜索剪切板" : "Search clipboard" }
    static var searchPlaceholder: String { chinese ? "搜索…" : "Search" }
    static var newPinboard: String { chinese ? "新建分组" : "New Pinboard" }
    static var pinboardName: String { chinese ? "分组名称" : "Pinboard name" }
    static var pin: String { chinese ? "固定到分组" : "Pin" }
    static var unpin: String { chinese ? "取消固定" : "Unpin" }
    static var rename: String { chinese ? "重命名" : "Rename" }
    static var edit: String { chinese ? "编辑" : "Edit" }
    static var delete: String { chinese ? "删除" : "Delete" }
    static var copy: String { chinese ? "拷贝" : "Copy" }
    static var paste: String { chinese ? "粘贴" : "Paste" }
    static var pastePlain: String { chinese ? "粘贴为纯文本" : "Paste as Plain Text" }
    static var preview: String { chinese ? "预览" : "Preview" }
    static var settings: String { chinese ? "设置" : "Settings" }
    static var quit: String { chinese ? "退出 Clip" : "Quit Clip" }
    static var pause: String { chinese ? "暂停记录" : "Pause" }
    static var resume: String { chinese ? "继续记录" : "Resume" }
    static var paused: String { chinese ? "已暂停" : "Paused" }
    static var pause5: String { chinese ? "暂停 5 分钟" : "Pause for 5 minutes" }
    static var pause15: String { chinese ? "暂停 15 分钟" : "Pause for 15 minutes" }
    static var pause60: String { chinese ? "暂停 1 小时" : "Pause for 1 hour" }
    static var pauseUntil: String { chinese ? "暂停直到手动恢复" : "Pause until resumed" }
    static var showClip: String { chinese ? "显示 Clip" : "Show Clip" }
    static var emptyHistory: String { chinese ? "复制任意内容，就会出现在这里" : "Copy something and it will show up here" }
    static var emptySearch: String { chinese ? "没有匹配的内容" : "No matching clips" }
    static var emptyBoard: String { chinese ? "把卡片拖到这里，或右键固定" : "Pin clips here to keep them" }
    static var all: String { chinese ? "全部" : "All" }
    static var text: String { chinese ? "文本" : "Text" }
    static var link: String { chinese ? "链接" : "Link" }
    static var image: String { chinese ? "图片" : "Image" }
    static var color: String { chinese ? "颜色" : "Color" }
    static var file: String { chinese ? "文件" : "File" }
    static var code: String { chinese ? "代码" : "Code" }
    static var characters: String { chinese ? "字符" : "chars" }
    static var justNow: String { chinese ? "刚刚" : "Just now" }
    static var save: String { chinese ? "保存" : "Save" }
    static var cancel: String { chinese ? "取消" : "Cancel" }
    static var create: String { chinese ? "创建" : "Create" }
    static var deleteBoard: String { chinese ? "删除分组" : "Delete Pinboard" }
    static var deleteBoardConfirm: String { chinese ? "分组里的内容仍会留在历史中。" : "Clips will remain in History." }
    static var general: String { chinese ? "通用" : "General" }
    static var privacy: String { chinese ? "隐私" : "Privacy" }
    static var shortcuts: String { chinese ? "快捷键" : "Shortcuts" }
    static var about: String { chinese ? "关于" : "About" }
    static var launchAtLogin: String { chinese ? "登录时打开" : "Launch at login" }
    static var autoPaste: String { chinese ? "选中后自动粘贴" : "Paste automatically after selecting" }
    static var keepHistory: String { chinese ? "保留历史" : "Keep History" }
    static var forever: String { chinese ? "永久" : "Forever" }
    static var days7: String { chinese ? "7 天" : "7 days" }
    static var days30: String { chinese ? "30 天" : "30 days" }
    static var days90: String { chinese ? "90 天" : "90 days" }
    static var ignoredApps: String { chinese ? "忽略这些应用的复制" : "Ignore copies from these apps" }
    static var addApp: String { chinese ? "添加应用" : "Add App" }
    static var accessibility: String { chinese ? "辅助功能" : "Accessibility" }
    static var accessibilityHint: String { chinese ? "开启后，选中条目会直接粘贴到当前应用。" : "Needed to paste directly into the app you are using." }
    static var openAccessibility: String { chinese ? "打开系统设置" : "Open System Settings" }
    static var granted: String { chinese ? "已授权" : "Granted" }
    static var notGranted: String { chinese ? "未授权" : "Not granted" }
    static var localOnly: String { chinese ? "数据只保存在这台 Mac 上，没有账户，也不会上传。" : "Your clipboard stays on this Mac. No account, no upload." }
    static var welcomeTitle: String { chinese ? "欢迎使用 Clip" : "Welcome to Clip" }
    static var welcomeBody: String { chinese ? "复制的一切都会变成底部的卡片。快捷键随时唤出，选中即可粘贴。" : "Everything you copy becomes a card. Open Clip with your shortcut, then select to paste." }
    static var continueBtn: String { chinese ? "开始使用" : "Get Started" }
    static var skip: String { chinese ? "稍后" : "Later" }
    static var hotkeyHint: String { chinese ? "显示 / 隐藏" : "Show or hide" }
    static var pressShortcut: String { chinese ? "按下快捷键…" : "Press shortcut…" }
    static var resetShortcuts: String { chinese ? "恢复默认快捷键" : "Reset to Defaults" }
    static var globalShortcuts: String { chinese ? "全局" : "Global" }
    static var panelShortcuts: String { chinese ? "窗口内" : "In Clip" }
    static var shortcutHint: String { chinese ? "点一下再按下新的组合键。Esc 取消，⌫ 恢复该项默认。" : "Click, then press a new shortcut. Esc cancels, Delete restores the default." }
    static var globalNeedsModifier: String { chinese ? "全局快捷键需要带 ⌘ / ⌥ / ⌃" : "Global shortcuts need ⌘, ⌥, or ⌃" }
    static var recordShortcut: String { chinese ? "录制" : "Record" }
    static var stack: String { chinese ? "粘贴栈" : "Paste Stack" }
    static var clearHistory: String { chinese ? "清空历史" : "Clear History" }
    static var clearHistoryConfirm: String { chinese ? "清空历史不会删除分组中的条目。" : "Pinned items on pinboards are kept." }
    static var newText: String { chinese ? "新建文本" : "New Text Item" }
    static var snippets: String { chinese ? "常用" : "Snippets" }
    static var done: String { chinese ? "完成" : "Done" }
    static var openLink: String { chinese ? "打开链接" : "Open Link" }
    static var copyColor: String { chinese ? "拷贝色值" : "Copy Color" }
    static var aboutBody: String {
        chinese
            ? "Clip 是一个本地剪切板管理器。没有登录，没有同步账号。"
            : "Clip is a local clipboard manager. No sign-in, no account."
    }
}
