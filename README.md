# BUGBOUND — Act 1 Vertical Slice

一个 programmer / bug 主题的短篇 roguelike deckbuilder vertical slice。玩家是被吸进电脑的普通 Developer，在 Desktop 内沿节点式 system path 前进，经过普通战斗、事件或 Elite，最后对抗把玩家误判为 malware 的 Antivirus。

每场战斗随机出现一个 Bug，战斗结束后消失。Bug 只能由玩家打牌触发，同回合可以重复触发，而且每次同时给予即时 Reward 与 Risk：

- Overflow（Energy）：把 Energy 用到 0，抽牌并回能；敌人永久变强。
- Memory Leak（Draw/Hand）：大手牌时打出抽牌卡，额外抽牌；失去 HP。
- Hot Path（Attack）：连续打出 Attack，追加伤害；失去 HP。
- Firewall Backdoor（Defend）：有 Block 时继续叠防，获得大量 Block；下一回合减少 Energy。
- Blood Pact（HP/Damage）：低血量出牌会回能；每次再失去 HP。

Bug 的 Reward/Risk 直接结算，不会触发其他 Bug，也不会形成 Bug-to-Bug chain reaction。

当前完整流程：

- 主菜单可直接 New Run，或输入 Seed 重现指定 Run；Run UI 持续显示 Seed 与 RNG 游标。
- 10 层 Desktop 分支路线后进入 Antivirus；地图、节点、敌人、异常路线与隐藏节点资格均由 Seed 生成。
- Corrupted Folder、Broken Cursor、Trash Beast、Frozen Window 与 Memory Hog 的出现、牌堆、行为和奖励全部可复现。
- OS-style 战斗 Pop-up，两个选项都有清楚的即时收益与代价。
- System Update 事件或 Memory Hog Elite 二选一。
- 每场胜利后从三张牌中安装一张，HP 与牌组会保留到 Run 结束。
- Antivirus Boss：每次主动触发 Bug 都令 Threat +1，扫描伤害随 Threat 增长；没有第二阶段。

确定性原则：所有 gameplay RNG 只使用 Run 内保存的 seeded RNG 状态。`Same Seed + Same Decisions = Same Run`。New Run 按钮只负责生成初始 Seed；Seed 建立后不会再读取系统随机源。

运行：`npm install` 后执行 `npm run dev`。
