# 公開版開發與驗證

## 保留與移除

公開版保留 PlayerMovement、MultiplayerBridge、ForceEnablePerks、FasterBeerDrinking、CustomFishingCursor，新增 RemoteGambling 房主服務。main.lua 只載入這些白名單模組。移除 CrazierGambles、LuckierFishBite 的實作與相關測試，保留無功能同名檔供升級覆蓋。公開版不註冊 F1/F6/F7/F8/F9。

MultiplayerProtocol 保留舊線上格式供移動互通；Bridge 只送出跑速／跳躍及中性保留欄位。Session 只有在房主明確設定 AllowRemoteMaxWin=true 時保留遠端 MaxWin；Rerolls=5、Hotspot=false 仍強制中性值，不代做釣魚。Bridge.BetSettings 依 pool.Owner 鏈對應實際遠端權威 controller／Pawn，僅傳回該玩家的 session 狀態；本機房主、未知 Owner 與不支援的 session 都不套用。這不是遠端 DRM，也不會停用別人自行修改的本機程式。

## 檢查

用 Python 3.9+、Lua 5.4 執行 tools/run_tests.py。檢查 manifest SHA256、Lua 語法、實際 loader、模擬兩位客戶端獨立移動、掉 ACK 重送、OFF還原／換Pawn／斷線，以及舊模組直接呼叫與舊設定無法啟用移除的本機功能。RemoteGambling 測試確認不綁熱鍵、巢狀下注隔離、OFF／非房主／未知 Owner／原生API不符時不修改結果。測試不啟動遊戲、不載入 DLL。真實 Steam 物理校正與遠端喝酒／Perks 仍未驗證。

## Native

Source/Native/ExtendedBPHooker.cpp 需 Windows SDK、PSAPI 及 Microsoft Detours 4.0.1 標頭與 x64 static library。UE4SSBuildProfile.hpp 的 guard 對應指定 UE4SS commit；不能任意換版本。來源與配對 DLL 都保留，沒有跨機器可重現建置保證。PDB、存檔與使用者診斷資料不隨儲存庫提供。

修改 payload 後必須更新 manifest.json 對應 SHA256。payload 在 Git 中保留原始位元組，避免 GitHub ZIP 的換行轉換讓安裝器驗證失敗。

## 遠端賭博服務

RemoteGambling 透過既有、與指定 UE4SS 配對的 native prehook 在 ScaleFishCompeteServer 期間建立下注上下文，腳本回呼結束後清除；RandomFloatInRange 只在對應遠端玩家 MaxWin=true 的上下文內修改。沒有公開版本機最大獎或原本的基礎 RNG 偏移。設定預設啟用且 README／settings.lua 可見，沒有隱藏的帳號授權或遠端任意程式執行。

已用模擬接收原本完整版的 GFMP1 封包與服務程式驗證。**pool.Owner 是否在真實遊戲指向下注者仍未證實**；已知函式還有 FishOwner 輸入，但本版沒有從未知 native stack offset 擷取參數。Owner 無法解析時維持正常 RNG，需真實多人日誌才能繼續確認。
