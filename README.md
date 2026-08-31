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

- 两层分支战斗：Corrupted Folder、Broken Cursor、Trash Beast、Frozen Window。
- OS-style 战斗 Pop-up，两个选项都有清楚的即时收益与代价。
- System Update 事件或 Memory Hog Elite 二选一。
- 每场胜利后从三张牌中安装一张，HP 与牌组会保留到 Run 结束。
- Antivirus Boss：每次主动触发 Bug 都令 Threat +1，扫描伤害随 Threat 增长；没有第二阶段。

运行：`npm install` 后执行 `npm run dev`。
