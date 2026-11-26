# 0.7 開發與驗證

公開版保留 PlayerMovement、MultiplayerBridge、ForceEnablePerks、FasterBeerDrinking、RemoteGambling。loader 白名單與無功能升級佔位檔維持；公開版不綁F1/F6～F9。

## 同步與移動

GFMP2狀態、H2版本握手、A2絕對walk/jump/crouch確認。收到匹配challenge的舊H1會顯示版本不符並停止重試，下一次明確操作可重試。沒有閒置完整設定heartbeat。

同一world與pawn的操作ACK暫時遺失不撤銷上次確認狀態；換pawn/world仍清除。Context快取補入有效的已知controller，單次FindAllOf漏列不刪除有效peer。controller失效才移除狀態。

ServerMovePacked、ServerMove、ServerMoveDual、CanJumpInternal、Jump採可選RegisterHook pre-callback，在遊戲原函式前重套既有設定；失敗的函式不阻止載入，日誌記錄成功數。只寫MaxWalkSpeed、MaxWalkSpeedCrouched、JumpMaxCount、JumpZVelocity，還原各角色原值。沒有改位置、RPC參數、velocity、移動誤差門檻或關閉伺服器校正。這可覆蓋測試中的屬性重寫窗口；是否解決真實回拉仍須遊戲測試。

ChatControlFilter只隱藏固定協定的UI widget，保留普通聊天；支援GFMP1舊字串及新版GFMP2/H2/A2，格式前綴、GetText、延後文字有限重試。未取消聊天RPC。

## 房間級賭博

房主AllowRemoteMaxWin必須明確開啟。任一有效連線peer的MaxWin為true時，RoomMaxWin成立；公開版本機不提供熱鍵。全部關閉或失效才結束。公開host只接受此布林能力，重抽／hotspot仍強制中性。

Native仍只註冊ScaleFishCompeteServer的UFunction位址。0.7的AddFunctionObjectScope偏移參數新增字串none，代表函式scope不讀Object名稱或FishOwner blob；舊數字偏移模式保留。ProcessEvent與最近匹配的Blueprint caller frame都能建立scope，完成與例外後清理。其他函式RNG不受影響；沒有把所有RandomFloat全域改大。Lua未取得新DLL時none註冊會拒絕，不能只更新Lua。

FFrame四個存取器、14個Lua入口仍以精確UE4SS commit/PDB/RVA/entry guard限制。GameThread以外原函式passthrough，原函式期間不持有Lua鎖，callback coroutine強引用保留。原生測試取消NDEBUG，避免最佳化關閉assert。

## 驗證

執行 python tools/run_tests.py --lua <Lua5.4路徑>：檢查manifest、所有Lua語法、loader、兩客戶端實際Bridge/Driver、版本拒絕、ACK丟失、controller漏列、重生、移動邊界覆寫、crouch、30秒閒置零RPC、聊天及房間scope。

tests/native/ObjectScopeRegression.cpp驗證ProcessEvent、直接與祖先frame、巢狀／例外清理、off-thread passthrough，並確認none模式無FishOwner和名稱查詢也可生效。需Windows x64、Detours4.0.1相容建置環境。Source/Native保存配對來源；修改payload後更新manifest SHA256，Git保持payload原位元組。

離線測試與自建原生測試程式不啟動遊戲，也不載入待測DLL。沒有真實Steam frame-time或遊戲內結果，不能宣稱卡頓／下注已實測修復。
