# Ethan 分支 APK 签名

在 Ethan13322836698/fqapp 运行 Android APK workflow 时，应用包名为
`com.ethan.fqapp`，名称为「什锦铺 Ethan」。上游仍使用原包名和证书。
两个版本可以同时安装，数据和应用权限各自独立；它们不能互相覆盖更新。
如需迁移书架，请使用备份恢复或同步功能。

## 一次性配置

在自己的 Windows 电脑安装 JDK 和 GitHub CLI，执行 `gh auth login`，
然后运行仓库中的脚本：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/setup_fork_signing.ps1
```

脚本生成独立签名，并写入该仓库的四个 `RELEASE_*` Secrets 和
`FORK_RELEASE_SIGNER_SHA256` 仓库变量。不会修改上游仓库。
密钥和密码保存在「文档/fqapp-signing」中，请安全备份，勿上传或提交。
重复运行会复用已有密钥；不要删除它后重新生成，否则无法覆盖更新旧安装包。

配置完成后运行 `master` 的 Android APK workflow 即可自动签名。
未配置签名的 Ethan 分支发布构建会明确失败，不会产出无法安装的无签名 APK。
外部 PR 检查仍允许没有签名材料。实际签名与最终包名均应通过构件验证。
