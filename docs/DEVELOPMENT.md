# 開發與驗證範圍

## 已完成的檢查

- Lua 5.4 語法與實際 main/config 載入。
- 真實 Bridge／Protocol／Session／Movement Lua 在模擬 RPC bus 上的房主與兩客戶端測試。
- 每玩家獨立開關、掉 ACK 重送不累乘、OFF 還原、換 Pawn／斷線、格式與數值拒絕。
- 本機釣魚 owner 隔離、巢狀重抽不重複掃描、持續賭博的 owner 設定與 GameThread 排程。
- PowerShell 安裝／還原與不同 loader 拒絕寫入已在非遊戲沙盒測過。

這些測試不代表真實 Steam 連線或物理校正成功，不代表多人獎勵一定被遊戲接受。

## Native 原始碼

`ExtendedBPHooker.cpp` 依賴 Windows SDK、PSAPI 與 Microsoft Detours 4.0.1 標頭及對應 x64 static library。它直接包裝指定 UE4SS build 的 Lua API，因此不能對其他 UE4SS 版本使用。

`UE4SSBuildProfile.hpp` 記錄版本、映像與 PDB profile guard；PDB 不隨本儲存庫分發。`NativeHookDispatch.hpp` 保留 GameThread／callback 分派相關程式。這次上傳保留已配對的 DLL 與來源，未提供跨機器可重現建置的保證；完整 C++ 建置環境與第三方開發套件需自行準備。

如修改 payload 中的任何內容，需同步更新 manifest.json 的對應 SHA256，安裝器才會接受。不要把日誌、SaveGames、minidump、個人路徑或憑證加入提交。

## 多人協定

借用遊戲的聊天 RPC，透過實際接收 chat component 對應 controller。狀態含固定 nonce／序號／跑速／空中跳／最大獎／重抽／hotspot 欄位；限制長度與頻率，未知欄位拒絕。nonce 僅區分 session，不是密碼學認證。無遠端任意 Lua 執行與任意物件路徑呼叫。

賭博以 pool.Owner 鏈找玩家；多人無法確認時回到正常 RNG。UI 僅收起控制訊息，不影響反作弊。釣魚仍為原本本機流程，伺服器可能拒絕結果。
