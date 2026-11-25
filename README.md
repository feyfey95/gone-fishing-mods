# GONE Fishing Mods — 私人多人 Beta

基於 [k-Knight/gone-fishing-mods](https://github.com/k-Knight/gone-fishing-mods) 修改，新增跑速、空中連跳與私人房間每玩家獨立開關。這是非官方社群模組。

**目前版本：0.1-beta。多人同步已通過離線模擬，真實 Steam 雙人同步仍待驗證。**

## 下載與安裝

1. 點選本頁 **Code → Download ZIP**，完整解壓縮。
2. 房主與朋友都完整關閉遊戲，執行 `Install.cmd`。
3. 貼上各自的 `GONEfishing\Binaries\Win64` 資料夾完整路徑；看到 `Installed and verified` 才算完成。
4. 從 Steam 正常開遊戲，在全員同意的私人房間測試。客戶端應顯示 `Multiplayer sync connected`。

[完整安裝、還原與雙人測試步驟](docs/INSTALL_zh-TW.md)。更新後必須完整重開遊戲，勿使用 Ctrl+R 熱重載。

## 功能

| 按鍵／模組 | 行為 |
|---|---|
| 數字列 1 | 跑速 OFF → 2x → 5x → 10x → OFF |
| 數字列 2 | 空中連跳開關；維持原版 1 倍跳高，放開空白鍵再按可繼續跳 |
| F1 — CrazierGambles | 持續最大獎模式開關；多人 owner 無法辨識時使用正常 RNG |
| F6 — LuckierFishBite | 強制 hotspot 開關 |
| F7／F8／F9 | 下一次咬鉤重抽 50／500／5000 次；平常 5 次 |
| ForceEnablePerks | 自動套用 Perks；房主預設涵蓋有效的權威玩家角色 |
| FasterBeerDrinking | 喝酒加速 |
| CustomFishingCursor | 釣魚游標；魚種／重量文字由 LuckierFishBite 提供 |

跑速、空中連跳與 F1 模式每次啟動預設 OFF。其餘功能模組與 MultiplayerBridge 在 settings.lua 中 enabled=true；MultiplayerDiscovery 探測器停用。設定在 `payload/ue4ss/Mods/GonFishMods/settings.lua`，Lua 在同目錄的 `Scripts/`。

## 相容版本與限制

- Windows x64、Steam App **3645890**、遊戲 Build **26855621**。
- 綁定 UE4SS commit **682a75f103a61f4a5a8d396b9c2b43c8c1958c51**。原生 Hook 與此版本配對，不可任意替換成最新 Experimental。
- 支援目標為私人 **listen server**，不支援 dedicated server。每位玩家需安裝相同套件。
- 安裝器核對 SHA256、備份修改檔案並保留其他模組；遇到不同既有 UE4SS.dll／dwmapi.dll 會停止。Steam manifest 可讀時會檢查 build。
- 遠端跑速校正、空中跳、賭博 Owner 歸屬、喝酒事件及伺服器接受釣魚結果，仍需真實雙人測試。
- 協定限用相互信任的私人房間；不是公開伺服器的安全認證機制。

啟用模組有帳號封鎖、遊戲崩潰與存檔損毀風險。遊戲商店聲明有排行榜伺服器端反作弊；不刷排行榜不能保證不受處分。本專案不含反作弊繞過或停用移動校正的功能。

## 原始碼與檢查

Lua 原始碼與可安裝內容在 `payload/`；修改後的 C++ Hook 原始碼在 `Source/Native/`。`Source/CustomCursor/` 保留游標原始碼。

使用 Python 3 與 Lua **5.4** 執行：

```text
python tools/run_tests.py --lua <lua54執行檔路徑>
```

[驗證範圍與原生編譯限制](docs/DEVELOPMENT.md)。測試不會啟動遊戲或載入遊戲 DLL。

## 授權與致謝

沿用原專案 MIT 授權，見 [LICENSE](LICENSE)。感謝 [k-Knight](https://github.com/k-Knight/gone-fishing-mods)、[UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) 與 [Microsoft Detours](https://github.com/microsoft/Detours)。各元件完整 notices 保留於 [Licenses/](Licenses/)。本儲存庫包含指定版本的 UE4SS 與原生 DLL，供安裝使用。
