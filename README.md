# GONE Fishing Mods — 公開版

基於 [k-Knight/gone-fishing-mods](https://github.com/k-Knight/gone-fishing-mods) 修改的非官方社群模組。

**版本：0.3-host-support-beta。多人移動同步通過離線模擬，真實 Steam 雙人同步仍待驗證。**

## 下載與安裝

1. 點選 **Code → Download ZIP**，完整解壓縮。
2. 完整關閉遊戲，執行 `Install.cmd`。
3. 貼上 `GONEfishing\Binaries\Win64` 完整路徑，確認出現 `Installed and verified`。
4. 房主與朋友使用相同公開版，在全員同意的私人房間測試。客戶端應顯示 `Multiplayer sync connected`。

詳見 [安裝、還原與測試](docs/INSTALL_zh-TW.md)。更新後必須完整重開遊戲，勿用 Ctrl+R 熱重載。

## 保留的功能

| 功能 | 操作 |
|---|---|
| 跑速 | 數字列 1：OFF → 2x → 5x → 10x → OFF |
| 空中連跳 | 數字列 2 開關；原版 1 倍跳高，放開空白鍵再按可繼續跳 |
| ForceEnablePerks | 自動套用 Perks；房主預設涵蓋有效權威玩家角色 |
| FasterBeerDrinking | 喝酒加速 |
| CustomFishingCursor | 自訂釣魚游標 |
| RemoteGambling（房主服務） | 支援完整版遠端玩家自己的 F1 狀態；公開版本機沒有 F1 熱鍵 |

跑速、空中連跳每次啟動預設 OFF。設定在 `payload/ue4ss/Mods/GonFishMods/settings.lua`。

**公開版本機不提供 F1 最大獎、F6 強制 hotspot、F7／F8／F9 重抽或平常的幸運重抽。** CrazierGambles 與 LuckierFishBite 的實作已移除；兩個同名檔案為無功能的升級佔位檔，用來覆蓋舊版實作。舊 settings.lua 的 enabled=true 也不會讓公開版 loader 載入它們。房主端保留 RemoteGambling 服務，依實際物件歸屬套用完整版遠端玩家的最大獎請求，不提供公開版使用者本機的賭博開關。

### 房主與完整版玩家

公開版房主預設允許已連線的完整版玩家傳送自己的 F1 狀態；僅在該玩家自己的賭博物件 Owner 可對應時生效，未知 Owner 保持正常 RNG。公開版本身不送出最大獎狀態，也不替房主或其他玩家開啟這項效果。這是公開的房主服務設定，不是帳號專屬權限。

房主可在 settings.lua 將 `MultiplayerBridge.AllowRemoteMaxWin=false` 關閉支援。F6～F9 仍屬完整版客戶端本機釣魚流程，公開房主不代為生成魚或保證伺服器接受結果。**真實 Steam 連線與賭博 Owner 對應仍待雙人實測。**

此變更只適用於新版程式；無法撤銷已下載的舊版，也不會使 Git 歷史或其他人修改過的版本失效。

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
