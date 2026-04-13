# S06 Android-first Demo Release Runbook

## 目标

把 `mobile/` 产出收口为可安装、可说明边界的 Baby Talk demo 包，并确保 fresh install → onboarding → practice → garden/growth → sign-in sync → Mentor 求助 这条链路可重复走查。

## 应用身份合同

- Android package / namespace：`com.babytalk.mobile`
- iOS bundle id：`com.babytalk.mobile`
- App label / display name：`Baby Talk`
- iPhone / iPad：仅允许 portrait（iPad 额外允许 upside-down portrait，不允许 landscape）

## Build-time dart-define 合同

移动端默认值来自 `mobile/lib/features/account/data/services/account_api_service.dart`：

- `BABY_TALK_API_BASE_URL` 默认 `http://127.0.0.1:8080`
- `BABY_TALK_API_VERSION` 默认 `1.2.0`

### Demo / profile 构建

可安装 demo 包允许使用受控示例地址，命令如下：

```bash
cd mobile && flutter build apk --profile \
  --dart-define=BABY_TALK_API_BASE_URL=https://demo.example.com \
  --dart-define=BABY_TALK_API_VERSION=1.2.0
```

产物路径：

- `mobile/build/app/outputs/flutter-apk/app-profile.apk`

### Release 构建边界

release 不再回退到 debug signing。执行者必须先准备：

1. 复制 `mobile/android/key.properties.example` 为 `mobile/android/key.properties`
2. 填入真实 `storeFile / storePassword / keyAlias / keyPassword`
3. 确保 `storeFile` 指向实际存在的 `.jks` / `.keystore`

若缺失配置或 keystore，Gradle 会直接失败并输出明确错误；这属于预期保护，避免误产出模板签名包。

## 最小校验命令

```bash
rg -n "Baby Talk|com\.babytalk\.mobile" \
  mobile/android/app/build.gradle.kts \
  mobile/android/app/src/main/AndroidManifest.xml \
  mobile/ios/Runner/Info.plist \
  mobile/ios/Runner.xcodeproj/project.pbxproj
```

## 手工 smoke 流程

1. fresh install 安装 `app-profile.apk`
2. 首开确认进入 onboarding，而不是旧数据恢复页
3. 完成 onboarding，进入首页
4. 连续完成 starter practice，确认首页 recent result、花园 patch、成长 summary 都出现
5. 打开账号面板，执行 sign-in + sync，确认 banner / phase 可见且 recent result 显示已同步
6. 打开 Mentor，发起一次普通求助，再发起一次触发 blocked fallback 的求助，确认 code / phase / correlationId 可见

## 失败可见性

- Android 缺 `INTERNET` 或身份残留：看 manifest / Gradle grep 结果与安装后 app 名称
- Release signing 未配置：`flutter build apk --release` 直接失败，不再默默走 debug key
- 非法 `BABY_TALK_API_BASE_URL` / 版本不匹配：在 smoke 中表现为 restore/sync/mentor banner 或 version gate 错误，不应伪装成成功
- 构建产物路径：固定查看 `mobile/build/app/outputs/flutter-apk/app-profile.apk`

## Redaction

runbook、截图与命令输出中不得回显：

- 手机号
- 验证码
- session secret
- 同意前宝宝 PII
- Mentor raw prompt / raw response
