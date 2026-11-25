# 公開版 0.2 安裝與測試

## 安裝與更新

1. 雙方完整關閉遊戲，下載 GitHub 目前 main 的 ZIP，完整解壓。
2. 執行 Install.cmd，貼上自己的 GONEfishing\Binaries\Win64 完整路徑。
3. 確認 Installed and verified，保留程式顯示的備份資料夾路徑。
4. 正常從 Steam 啟動遊戲；不要用 Ctrl+R 熱重載。

更新會覆蓋原本 CrazierGambles.lua 與 LuckierFishBite.lua 為無功能佔位檔，並更新載入白名單與 settings.lua。這比只刪除新套件中的檔案更能避免升級時留下舊實作。即使舊設定手動改回 enabled=true，公開版 loader 也不會載入這兩個模組。不要把其他來源的舊 main.lua 混入新版。

F1、F6、F7／F8／F9 在公開版沒有對應功能；沒有幸運重抽與魚種／重量提示。保留自訂游標、Perks、喝酒加速、跑速與空中連跳。

指定 Steam build 26855621 與 UE4SS commit 682a75f103a61f4a5a8d396b9c2b43c8c1958c51。不同既有 loader 會停止安裝；不要手動覆蓋此版本的 DLL。找不到 Steam manifest 時無法自動確認遊戲 build。權限不足時可在管理員 PowerShell 執行 Install.ps1，請勿停用防毒。

## 雙人測試

僅限全員同意的私人 listen-server 房間。雙方都安裝相同公開版；加入後確認客戶端顯示 Multiplayer sync connected。先各自按數字列1一次測2倍跑速，再按2測空中連跳，確認另一人的開關不被影響、移動不會拉回。跳高維持1x，空白鍵需放開再按。

跑速依序 OFF/2x/5x/10x/OFF；空中跳與跑速每次啟動 OFF。測試關閉與重新加入後的同步，最後確認正常聊天。若出現異常，保存兩端 UE4SS.log 和對應 crash files，不要公開包含個資的原始日誌。

多人同步尚未經真實 Steam 雙人驗證，離線測試只驗證程式邏輯。

## 還原

關閉遊戲後執行 Restore.ps1，輸入安裝時顯示的 Win64\GFM-Coop-Backups\<UTC時間> 備份資料夾。還原前核對目前檔案雜湊，若安裝後又改過會停止。此操作會還原安裝前版本，可能包含當時已存在的舊功能。安裝與還原不會修改 SaveGames。

公開版更新不撤銷已下載的舊版、其他人自行修改的程式或 Git 歷史。模組使用仍有封鎖、崩潰及存檔損毀風險，未繞過反作弊。
