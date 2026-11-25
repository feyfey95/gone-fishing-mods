# 公開版開發與驗證

## 保留與移除

公開版保留 PlayerMovement、MultiplayerBridge、ForceEnablePerks、FasterBeerDrinking、CustomFishingCursor。main.lua 只載入這些白名單模組。移除 CrazierGambles、LuckierFishBite 的實作與相關測試，保留無功能同名檔供升級覆蓋。公開版不註冊 F1/F6/F7/F8/F9。

MultiplayerProtocol 保留舊線上格式供移動互通；Bridge 只送出跑速／跳躍及中性保留欄位。Session 在儲存任何外來玩家狀態前強制 MaxWin=false、Rerolls=5、Hotspot=false，不套用賭博／釣魚請求。Bridge 不再提供 BetSettings。這不是遠端 DRM，也不會停用別人自行修改的本機程式。

## 檢查

用 Python 3.9+、Lua 5.4 執行 tools/run_tests.py。檢查 manifest SHA256、Lua 語法、實際 loader、模擬兩位客戶端獨立移動、掉 ACK 重送、OFF還原／換Pawn／斷線，以及舊模組直接呼叫與舊設定無法啟用移除功能。測試不啟動遊戲、不載入 DLL。真實 Steam 物理校正與遠端喝酒／Perks 仍未驗證。

## Native

Source/Native/ExtendedBPHooker.cpp 需 Windows SDK、PSAPI 及 Microsoft Detours 4.0.1 標頭與 x64 static library。UE4SSBuildProfile.hpp 的 guard 對應指定 UE4SS commit；不能任意換版本。來源與配對 DLL 都保留，沒有跨機器可重現建置保證。PDB、存檔與使用者診斷資料不隨儲存庫提供。

修改 payload 後必須更新 manifest.json 對應 SHA256。payload 在 Git 中保留原始位元組，避免 GitHub ZIP 的換行轉換讓安裝器驗證失敗。
