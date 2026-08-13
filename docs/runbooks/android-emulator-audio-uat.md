# Android 模拟器音频 UAT 安装

使用 `scripts/qa-install-emulator-apk.sh` 构建 QA debug APK、安装到 Android 模拟器，并配置 App 访问宿主 QA gateway 所需的 `adb reverse`。

脚本只接受 `emulator-*` 设备；即使真机同时连接，也不会安装到真机。构建参数复用 `qa-install-apk.sh`，包括：

- `BABY_TALK_API_BASE_URL=http://127.0.0.1:19091`
- `BABY_TALK_CUSTOM_SCENE_ENABLED=true`

安装使用 `adb install -r`，保留模拟器中的 App 数据。

## 前置条件

1. QA gateway 已启动，宿主机 `http://127.0.0.1:19091/actuator/health` 可访问。
2. `flutter`、`adb`、Android Emulator 已加入 `PATH`，或已设置 `ANDROID_SDK_ROOT`。
3. 至少存在一个 AVD。可用 `emulator -list-avds` 查看。

## 构建、启动模拟器并安装

指定 AVD：

```bash
bash ./scripts/qa-install-emulator-apk.sh --avd Pixel_9_Pro
```

只有一个 AVD 且没有在线模拟器时，可省略 `--avd`：

```bash
bash ./scripts/qa-install-emulator-apk.sh
```

已有在线模拟器时，脚本自动复用。多个模拟器同时在线时必须指定 serial：

```bash
bash ./scripts/qa-install-emulator-apk.sh --device emulator-5554
```

仅重新安装已有 APK，跳过构建：

```bash
bash ./scripts/qa-install-emulator-apk.sh --device emulator-5554 --skip-build
```

使用非默认 QA gateway 端口：

```bash
bash ./scripts/qa-install-emulator-apk.sh --gateway-port 19092
```

## 验证

成功输出包含：

```text
emulator_install_status=ok
target_emulator=emulator-5554
gateway_reverse=tcp:19091->tcp:19091
```

也可手工检查：

```bash
adb -s emulator-5554 shell pm path com.babytalk.mobile
adb -s emulator-5554 reverse --list
```

`reverse --list` 必须包含模拟器的 `tcp:19091 tcp:19091` 规则。

## 剩余音频 UAT

此脚本只准备运行环境，不产生 UAT PASS 结论。剩余音频项仍需真人在模拟器实际听取并逐项确认：

1. starter 音频；
2. `cooperating`；
3. `hesitant`；
4. `resisting`；
5. `no_response`；
6. `other`。

每项确认音频确实播放、与当前显示分支一致、语音清晰且表达低压力。未完成真人听取前，UAT4 保持 `PENDING`，不得创建 PASS record。
