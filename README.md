# GONE Fishing Mods — 公開版

基於 [k-Knight/gone-fishing-mods](https://github.com/k-Knight/gone-fishing-mods) 修改的非官方社群模組。

**版本：0.6 Beta。多人跑速與連跳已有實測回報；本次同步修正仍需雙人驗證。**

## 下載與安裝

1. 點選 **Code → Download ZIP**，完整解壓縮。
2. 完整關閉遊戲，執行 `Install.cmd`。
3. 貼上 `GONEfishing\Binaries\Win64` 完整路徑，確認出現 `Installed and verified`。
4. 房主與朋友使用相同公開版，在全員同意的私人房間測試。客戶端應顯示 `Multiplayer sync connected`。

詳見 [安裝、還原與測試](docs/INSTALL_zh-TW.md)。更新後必須完整重開遊戲，勿用 Ctrl+R 熱重載。

## 功能

| 功能 | 操作 |
|---|---|
| 跑速 | 數字列 7：OFF → 3x → 5x → OFF |
| 空中連跳 | 數字列 8 開關；原版 1 倍跳高，放開空白鍵再按可繼續跳 |
| ForceEnablePerks | 自動套用 Perks；房主預設涵蓋有效權威玩家角色 |
| FasterBeerDrinking | 喝酒加速 |

0.6 移除每5秒重送完整設定的工作，僅在操作變更或重連時同步；客戶端等待房主確認後套用跑速。請完整更新套件，勿只複製 Lua 檔。

跑速、空中連跳每次啟動預設 OFF。0.4 版已移除自訂游標，房主與客戶端都需要更新至相同版本。設定在 `payload/ue4ss/Mods/GonFishMods/settings.lua`。

## 相容版本與限制

- Windows x64、Steam App **3645890**、遊戲 Build **26855621**。
- 指定 UE4SS commit **682a75f103a61f4a5a8d396b9c2b43c8c1958c51**；原生 DLL 與此版本配對，不可任意替換。
- 目標為相互信任的私人 **listen server**；不支援 dedicated server。每位玩家需安裝相同套件。
- 安裝器驗證 SHA256、先備份、保留其他模組，遇到不同既有 UE4SS.dll／dwmapi.dll 停止。Steam manifest 可讀時會核對 build。
- 實際網路移動校正、空中跳、遠端 Perks／喝酒事件仍需雙人實測；不保證所有遊戲版本相容。

模組仍有帳號封鎖、崩潰與存檔損毀風險。遊戲商店聲明有排行榜伺服器端反作弊。本專案沒有反作弊繞過或停用移動校正的功能。

## 程式碼、驗證與授權

可安裝 Lua 在 `payload/`，C++ 在 `Source/`，版本與 SHA256 在 `manifest.json`。使用 Python 3.9+ 與 Lua 5.4：

```text
python tools/run_tests.py --lua <lua54執行檔路徑>
```

測試不啟動遊戲或載入 DLL，詳見 [開發說明](docs/DEVELOPMENT.md)。沿用 [MIT 授權](LICENSE)，各元件 notices 在 [Licenses/](Licenses/)。感謝原專案、[UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) 與 [Microsoft Detours](https://github.com/microsoft/Detours)。
