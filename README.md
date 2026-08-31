# BUGBOUND Demo 2

一个 programmer / bug 主题的最小可玩 roguelike deckbuilder 原型。保留传统的 Attack、Defend、Draw、Energy 卡牌，把变化集中在每场战斗唯一的 Bug Monitor。

每场战斗随机出现一个 Bug，战斗结束后消失。Bug 只能由玩家打牌触发，同回合可以重复触发，而且每次同时给予即时 Reward 与 Risk：

- Overflow（Energy）：把 Energy 用到 0，抽牌并回能；敌人永久变强。
- Memory Leak（Draw/Hand）：大手牌时打出抽牌卡，额外抽牌；失去 HP。
- Hot Path（Attack）：连续打出 Attack，追加伤害；失去 HP。
- Firewall Backdoor（Defend）：有 Block 时继续叠防，获得大量 Block；下一回合减少 Energy。
- Blood Pact（HP/Damage）：低血量出牌会回能；每次再失去 HP。

Bug 的 Reward/Risk 直接结算，不会触发其他 Bug，也不会形成 Bug-to-Bug chain reaction。

运行：`npm install` 后执行 `npm run dev`。
