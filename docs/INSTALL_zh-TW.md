# 公開版 0.7 安裝與測試

## 完整更新

1. 雙方完整關閉遊戲，下載目前 main 的 ZIP，完整解壓。
2. 執行 Install.cmd，貼上各自的 GONEfishing\Binaries\Win64 路徑。
3. 確認 Installed and verified，保留備份路徑，再由 Steam 啟動。
4. 不用 Ctrl+R 熱重載。0.7 包含新 ExtendedBPHooker.dll，不能只複製 Lua。

UE4SS.dll 與 dwmapi.dll 仍使用指定 commit 682a75f103a61f4a5a8d396b9c2b43c8c1958c51；指定 Steam build 26855621。不同既有 loader 會停止安裝。安裝器核對 SHA256、備份並保留其他模組，不修改 SaveGames。權限不足時可在管理員 PowerShell 執行 Install.ps1。

0.7 使用新版線上協定，雙方需同版；若出現 Host mod update required，請完整更新房主與客戶端並重開。舊版不能視為相容。公開版 loader 只載入白名單；舊 CrazierGambles、LuckierFishBite、CustomFishingCursor 會覆蓋為無功能佔位檔，不能從 enabled=true 重新啟用。

## 操作與房主服務

公開版：數字列7切換 OFF/3x/5x/OFF；數字列8切換無限空中跳，原本1倍跳高。每次啟動皆OFF。保留Perks與喝酒加速；沒有F1／F6～F9的本機操作，也不再載入自訂游標。

RemoteGambling 是房主端服務。完整版客戶端可傳送 F1 最大獎模式；0.7 按需求改成房間級開關，任一有效連線的完整版玩家開啟時，所有玩家在指定血池賭博函式中的亂數都套用近最大值。它不再辨識每筆 FishOwner，也不綁帳號。若有多個玩家開啟，需要全部關閉才停止。房主可設定 MultiplayerBridge.AllowRemoteMaxWin=false 或停用 RemoteGambling。釣魚重抽不經此房主服務代理。

僅用於全員同意的私人 listen-server 房間。這是整個房間都可能受影響的功能，請先與其他玩家確認。

## 雙人驗證

先確認客戶端出現 Multiplayer sync connected，以及兩端 log 都有 v0.7 transport loaded。房主 log 應顯示 native movement boundaries registered，確認值大於0；若為0請保留日誌。

各自測3倍、5倍、關閉、地面直跑／轉向，以及空中連跳與關閉。記錄是否回拉或突然不能跳。角色重生、離開再加入後再測一次。同步中斷保留同角色上次確認模式；真正換角色／世界會重設。保留遊戲原有的移動校正與驗證。

由完整版玩家開 F1，自己和房主各賭兩次，再關 F1 比較；測試前確定沒有其他人也開啟。房主最初三筆已辨識的 scope 會記錄 room gamble scope entered; maxwin=true/false。出現熱鍵ON不代表下注結果已成功；保留兩端日誌與實際結果。

測普通聊天並確認固定協定字串不再顯示。模組可能造成帳號封鎖、崩潰與存檔損毀；未繞過反作弊。離線回歸不代替 Steam 多人、真實 FPS 或實際下注結果驗證。

## 還原

關閉遊戲，執行 Restore.ps1，輸入安裝器顯示的 Win64\GFM-Coop-Backups\<UTC時間>。還原前核對目前雜湊；若檔案再被修改會停止。還原到安裝前版本，可能包含之前的舊功能。
