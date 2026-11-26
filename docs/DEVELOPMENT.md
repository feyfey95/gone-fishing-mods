# 公開版開發與驗證

## 保留與移除

公開版保留 PlayerMovement、MultiplayerBridge、ForceEnablePerks、FasterBeerDrinking，新增 RemoteGambling 房主服務。main.lua 只載入這些白名單模組。移除 CrazierGambles、LuckierFishBite 的實作與相關測試，保留無功能同名檔供升級覆蓋。公開版不註冊 F1/F6/F7/F8/F9。

MultiplayerProtocol 保留舊線上格式供移動互通；Bridge 只送出跑速／跳躍及中性保留欄位。Session 只有在房主明確設定 AllowRemoteMaxWin=true 時保留遠端 MaxWin；Rerolls=5、Hotspot=false 仍強制中性值，不代做釣魚。Bridge.BetSettings 依 pool.Owner 鏈對應實際遠端權威 controller／Pawn，僅傳回該玩家的 session 狀態；本機房主、未知 Owner 與不支援的 session 都不套用。這不是遠端 DRM，也不會停用別人自行修改的本機程式。

## 檢查

用 Python 3.9+、Lua 5.4 執行 tools/run_tests.py。檢查 manifest SHA256、Lua 語法、實際 loader、模擬兩位客戶端獨立移動、掉 ACK 重送、OFF還原／換Pawn／斷線，以及舊模組直接呼叫與舊設定無法啟用移除的本機功能。RemoteGambling 測試確認不綁熱鍵、巢狀下注隔離、OFF／非房主／未知 Owner／原生API不符時不修改結果。測試不啟動遊戲、不載入 DLL。真實 Steam 物理校正與遠端喝酒／Perks 仍未驗證。

## Native

Source/Native/ExtendedBPHooker.cpp 需 Windows SDK、PSAPI 及 Microsoft Detours 4.0.1 標頭與 x64 static library。UE4SSBuildProfile.hpp 的 guard 對應指定 UE4SS commit；不能任意換版本。來源與配對 DLL 都保留，沒有跨機器可重現建置保證。PDB、存檔與使用者診斷資料不隨儲存庫提供。

修改 payload 後必須更新 manifest.json 對應 SHA256。payload 在 Git 中保留原始位元組，避免 GitHub ZIP 的換行轉換讓安裝器驗證失敗。

## 遠端賭博服務（0.5）

使用 ProcessEvent 真正的參數 blob，在執行原函式前讀取當次 FishOwner；偏移由載入中的 UFunction.ForEachProperty／GetOffset_Internal 反射取得，限定ObjectProperty與8-byte對齊、0..128範圍。沒有猜測FFrame offset，也不使用上一筆下注的Owner。Native callback在GameThread與既有UE4SS profile guard之下執行，原函式期間不持有Lua callback鎖，完成／例外後皆清理scope。

RemoteGambling仍沒有本機熱鍵；房主明確設定允許時才接受相應玩家的最大獎狀態。無法解析當次玩家時保持正常RNG。最初三筆會記錄是否解析成功，供真實多人測試確認。這不是帳號專屬的授權機制，僅供全員同意的私人房間。

## 移動與聊天修正

客戶端僅套用上次由房主ACK確認的絕對跑速與跳高，切換中不自行預測新倍率；只在等待操作確認逾時時重握手，無閒置完整狀態heartbeat。快取仍有效的controller，角色／world變更會重建，定時刷新避免殘留。Perks迴圈不在加速啟用期間重寫SprintSpeed；伺服器只在數值改變時寫入movement屬性。

ChatControlFilter只識別固定GFMP協定封包，接受GFM Coop格式前綴與GetText，並對延後建立的文字作最多8次、64個widget的有限重試。不取消RPC、不移除一般聊天、不掃描全畫面。

C++新增邊界測試見tests/native/ObjectScopeRegression.cpp，需與Detours相容的x64建置環境。Lua測試另涵蓋ACK等待／掉線重連、當次FishOwner優先、200個idle ticks的查找次數、延後UI與一般聊天。實際Steam連線與畫面FPS仍需人為測試；400→0的控制器掃描計數不能視為FPS數字。

## 0.6：直接Blueprint與事件同步

房主日誌顯示服務已註冊、持續接收5秒同步，但沒有scope內部紀錄。0.5的ProcessEvent範圍未涵蓋直接Blueprint亂數呼叫。本版在既有RandomFloat thunk處搜尋最多8層有效caller frame，從最近匹配的函式取當次Object與Locals；不依賴上一筆Owner，也不把FFrame資料偏移寫死。Node、Locals、Object、PreviousFrame四個UE4SS匯出存取器都以精確版本、RVA與entry bytes驗證。ProcessEvent路徑仍保留。

移除5秒完整狀態重送與閒置ACK過期，不以另一個定時完整重送取代。維持操作變更、重試、角色／world變更與操作未確認時的重連。閒置30秒測試要求零聊天RPC；伺服器session重置後由下一次操作觸發恢復。

原生測試明確取消NDEBUG，確保最佳化建置也執行assert。修正前直接Blueprint範例已實際失敗，修正後當層與祖先frame、獨立亂數、巢狀scope與例外清理皆通過。模擬仍不能代替真實遊戲frame-time量測。
