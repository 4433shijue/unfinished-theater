# 成就系统清单

本清单对应 V2.1，按 `lib/models/gamification.dart` 中的成就定义生成，用于核对 App 内成就、奖励和文档是否一致。

- 普通成就：126 个
- 隐藏成就：33 个
- 总计：159 个

隐藏成就在 App 里未解锁前显示为“？？？”。解锁后会在成就名和状态里标出“隐藏”，方便玩家知道自己撞到了彩蛋。

## 普通成就

| 成就名 | 解锁方式 | 统计键 / 阈值 | 奖励 |
|---|---|---|---|
| 今日开麦 |  | `userMessages / -` | 3 啥币 |
| 乖宝宝 | 打开新手教程并且不跳过，一条条完整看完。 | `totalTutorialCompletions / 1` | 20 啥币 |
| 坏宝宝 | 直接跳过新手教程。 | `totalTutorialSkips / 1` | 20 啥币 |
| 宫里来新人了 | 第一次打开这个小程序。 | `firstOpen / 1` | 10 啥币，称号“宫里来新人了” |
| 开麦，朕要说话 | 发送第一条用户消息。 | `totalUserMessages / 1` | 5 啥币 |
| 第一只回音怪 | 成功获得第一条 AI 回复。 | `totalAssistantReplies / 1` | 6 啥币 |
| 话匣子拧开了 | 累计发送 20 条消息。 | `totalUserMessages / 20` | 12 啥币 |
| 本宫今日话很多 | 累计发送 100 条消息。 | `totalUserMessages / 100` | 25 啥币 |
| 今天也在捏人 | 创建第一个 AI 角色。 | `totalCharactersCreated / 1` | 6 啥币 |
| 我只是想给每个人一个家 | 同时拥有 10 个及以上 AI 角色。 | `maxActiveCharacters / 10` | 20 啥币，称号“端水大师预备役” |
| 来也匆匆去也匆匆？ | 累计删除角色超过 10 个。 | `totalCharactersDeleted / 10` | 20 啥币，称号“来也匆匆去也匆匆” |
| 隔壁有人敲门 | 创建或自动识别第一个 NPC。 | `totalNpcProfilesCreated / 1` | 6 啥币 |
| 人脉这不就来了吗 | 累计创建或识别 5 个 NPC。 | `totalNpcProfilesCreated / 5` | 14 啥币 |
| 小窗已读不回？不存在的 | 完成第一次 NPC 私聊回复。 | `totalNpcReplies / 1` | 8 啥币，称号“小窗社交恐怖分子” |
| 突然收到一张纸条 | 收到第一封 NPC 主动来信。 | `totalNpcLetters / 1` | 8 啥币 |
| 工具箱第一次上工 | 生成第一条剧情工具结果。 | `totalToolResults / 1` | 8 啥币 |
| 工具箱包工头 | 累计生成 10 条剧情工具结果。 | `totalToolResults / 10` | 18 啥币，称号“工具箱包工头” |
| 啥币花出去了，心疼但爽 | 第一次在商店购买道具或装扮。 | `totalShopPurchases / 1` | 5 啥币，称号“精致穷鬼” |
| 道具不是买来吃灰的 | 累计使用 5 次背包道具。 | `totalItemsUsed / 5` | 16 啥币 |
| 今日份营业 | 领取第一次每日啥币。 | `totalDailyClaims / 1` | 5 啥币 |
| 七天没跑路 | 累计领取 7 次每日啥币。 | `totalDailyClaims / 7` | 20 啥币 |
| 清空也是一种重开 | 首次清空当前角色聊天记录。 | `totalHistoryClears / 1` | 6 啥币 |
| 把故事装进小盒子 | 首次导出聊天记录。 | `totalExports / 1` | 8 啥币 |
| 文游开炉 | 首次使用“AI 帮你写”生成模拟器提示词。 | `totalSimulatorPrompts / 1` | 10 啥币 |
| 换衣服也算更新 | 首次装备称号或气泡边框。 | `totalCosmeticsEquipped / 1` | 6 啥币 |
| 你俩开始熟了 | 任意 AI 角色陪伴等级达到 3 级。 | `maxCompanionLevel / 3` | 14 啥币 |
| 这不是陪伴是什么 | 任意 AI 角色陪伴等级达到 6 级。 | `maxCompanionLevel / 6` | 28 啥币，称号“这不是陪伴是什么” |
| 背包物品贴便签 | 给剧情背包里的物品写下第一条备注。 | `totalStoryItemNotes / 1` | 6 啥币 |
| 背包鼓起来了 | 背包里的功能券累计达到 5 张。 | `maxInventoryItems / 5` | 12 啥币 |
| 深渊盯上我了 | 切换到“深渊观测站”主题一次。 | `totalCthulhuThemeUses / 1` | 8 啥币，称号“祂看见我了” |
| 乱码也是一种艺术 | 切换到“愚人节特调”主题一次。 | `totalAprilFoolsThemeUses / 1` | 8 啥币，称号“乱码修仙大成” |
| 花非花，梦非梦 | 切换到“花非花”主题一次。 | `totalFlowerNotFlowerThemeUses / 1` | 12 啥币，称号“夜半来，天明去” |
| 裂隙打卡成功 | 切换到“裂隙中转站”主题一次。 | `totalRiftRelayThemeUses / 1` | 12 啥币 |
| 齿轮转我也转 | 切换到“机械迷城”主题一次。 | `totalMechanicalCityThemeUses / 1` | 12 啥币 |
| 雨声调频成功 | 切换到“雨巷电台”主题一次。 | `totalRainRadioThemeUses / 1` | 12 啥币 |
| 今天开始放牧云朵 | 购买后第一次装扮“晴空牧场”。 | `totalSkyPastureThemeUses / 1` | 20 啥币，称号“云朵牧场主” |
| 唱针落下，钱包轻响 | 购买后第一次装扮“黑胶往事”。 | `totalVinylMemoriesThemeUses / 1` | 20 啥币，称号“黑胶收藏家” |
| 盲盒成精了 | 使用一次创新版开盲盒生成模拟器。 | `totalBlindBoxes / 1` | 10 啥币 |
| 老板，来点旧梦 | 使用一次“开盲盒（怀旧版）”。 | `totalClassicBlindBoxes / 1` | 10 啥币，称号“经典永不过时” |
| 边框也是门面 | 装备第一款非默认边框。 | `totalFramesEquipped / 1` | 8 啥币 |
| 衣柜里开始有边框味了 | 累计解锁 3 款气泡边框。 | `maxFramesUnlocked / 3` | 12 啥币 |
| 装修队进场 | 购买并保存第一个自定义气泡格子。 | `totalCustomBubbleSlots / 1` | 12 啥币 |
| 这边框有点东西 | 第一次装备自定义气泡。 | `totalCustomBubblesEquipped / 1` | 12 啥币 |
| 给 TA 单独穿上 | 第一次给当前角色绑定专属气泡。 | `totalCharacterBubbleAssignments / 1` | 12 啥币 |
| CSS 玄学大师 | 累计保存 3 次自定义气泡。 | `totalCustomBubblesSaved / 3` | 18 啥币 |
| 装修队接到大单 | 购买并保存第一个自定义主题格子。 | `totalCustomThemeSlots / 1` | 20 啥币，称号“主题裁缝” |
| 这屋终于像我家了 | 第一次装备自定义主题。 | `totalCustomThemesEquipped / 1` | 20 啥币 |
| 调色盘开始发烫 | 累计保存 3 次自定义主题。 | `totalCustomThemesSaved / 3` | 28 啥币 |
| 改到像亲生的 | 累计编辑 5 次自定义主题。 | `totalCustomThemesEdited / 5` | 35 啥币 |
| 全身上下都是戏 | 同时装备非默认称号和非默认边框。 | `maxFullCosmeticSlots / 1` | 16 啥币，称号“全身上下都是戏” |
| 商店老板认识我 | 累计购买 10 次商店道具或装扮。 | `totalShopPurchases / 10` | 20 啥币，称号“老板，还是老样子” |
| 来都来了 | 累计领取 30 次每日啥币。 | `totalDailyClaims / 30` | 40 啥币 |
| 低语收藏家 | 累计收到 10 封 NPC 主动来信。 | `totalNpcLetters / 10` | 22 啥币 |
| 我宣布这段封神 | 累计导出 5 次聊天记录。 | `totalExports / 5` | 18 啥币 |
| 工具箱住户 | 累计生成 25 条剧情工具或商店工具结果。 | `totalToolResults / 25` | 30 啥币 |
| 券不是券，是生活方式 | 累计使用 20 次背包功能券。 | `totalItemsUsed / 20` | 30 啥币 |
| 成就它自己成就了 | 累计解锁 10 个成就。 | `maxAchievements / 10` | 25 啥币 |
| 嘴比剧情还长 | 累计发送 300 条消息。 | `totalUserMessages / 300` | 40 啥币 |
| 回音壁包年用户 | 累计获得 50 条 AI 回复。 | `totalAssistantReplies / 50` | 35 啥币 |
| 五口之家启动 | 累计创建 5 个 AI 角色。 | `totalCharactersCreated / 5` | 14 啥币 |
| 角色户口本爆页了 | 累计创建 20 个 AI 角色。 | `totalCharactersCreated / 20` | 35 啥币 |
| NPC 开始排队进群 | 累计创建或识别 10 个 NPC。 | `totalNpcProfilesCreated / 10` | 22 啥币 |
| 小窗聊到发烫 | 累计完成 50 次 NPC 私聊回复。 | `totalNpcReplies / 50` | 40 啥币 |
| 信箱长出第二层 | 累计收到 25 封 NPC 主动来信。 | `totalNpcLetters / 25` | 38 啥币 |
| 模拟器批发商 | 累计使用“AI 帮你写”生成 5 份模拟器提示词。 | `totalSimulatorPrompts / 5` | 25 啥币 |
| 盲盒有点上头 | 累计使用创新版开盲盒 5 次。 | `totalBlindBoxes / 5` | 25 啥币 |
| 旧梦回收站站长 | 累计使用怀旧版开盲盒 5 次。 | `totalClassicBlindBoxes / 5` | 25 啥币 |
| 装修队常驻嘉宾 | 累计切换主题 10 次。 | `totalThemeChanges / 10` | 18 啥币 |
| 主题钱包受害者 | 累计解锁 3 个付费主题。 | `totalThemeUnlocks / 3` | 24 啥币 |
| 装修预算是什么，可以吃吗 | 累计解锁 6 个付费主题。 | `totalThemeUnlocks / 6` | 45 啥币 |
| 邮箱薅羊毛科代表 | 累计领取 10 次邮箱奖励。 | `totalMailboxClaims / 10` | 20 啥币 |
| 每日任务打卡机器 | 累计完成并领取 30 次每日任务。 | `totalDailyTasksClaimed / 30` | 30 啥币 |
| 成就墙贴满了 | 累计解锁 30 个成就。 | `maxAchievements / 30` | 60 啥币 |
| 成就山登顶游客 | 累计解锁 60 个成就。 | `maxAchievements / 60` | 100 啥币，称号“成就山登顶游客” |
| 转起来，别停 | 第一次玩“幸运转转转”。 | `totalRouletteSpins / 1` | 3 啥币 |
| 这不是上头，是热身 | 累计转盘 10 次。 | `totalRouletteSpins / 10` | 12 啥币 |
| 保底是我的心理医生 | 累计转盘 50 次。 | `totalRouletteSpins / 50` | 35 啥币 |
| 老板脸绿了 | 在幸运转转转里抽到 100 啥币大奖。 | `totalRouletteJackpots / 1` | 20 啥币 |
| 夜半小铺已开门 | 第一次在黑心小卖部买东西。 | `totalBlackMarketPurchases / 1` | 6 啥币 |
| 老板说你是熟人价 | 累计在黑心小卖部购买 10 次。 | `totalBlackMarketPurchases / 10` | 24 啥币 |
| 先赊着，明天一定还 | 第一次向黑心小卖部赊账。 | `totalDebtTaken / 1` | 6 啥币 |
| 这玩意儿真有用啊？ | 第一次鉴定未知道具。 | `totalItemsIdentified / 1` | 8 啥币 |
| 炼金术士下岗再就业 | 第一次合成剧情道具。 | `totalItemsSynthesized / 1` | 10 啥币 |
| 他真的有在回礼 | 第一次收到 NPC 回礼。 | `totalNpcGiftsReceived / 1` | 10 啥币 |
| 名场面管理员 | 第一次收藏道具触发的高光剧情。 | `totalSceneCardsCollected / 1` | 8 啥币 |
| 同人文开张大吉 | 第一次生成同人文。 | `totalFanficResults / 1` | 12 啥币，称号“三千字起步选手” |
| 这对我先磕为敬 | 累计生成 5 篇同人文。 | `totalFanficResults / 5` | 30 啥币 |
| 番外工厂夜班主管 | 累计生成 20 篇同人文。 | `totalFanficResults / 20` | 80 啥币 |
| 梗从天降接住了 | 第一次使用同人文灵感盲盒。 | `totalFanficBlindBoxes / 1` | 15 啥币，称号“梗从天降接住了” |
| 我和 TA 的三行情诗变三千字 | 累计生成 3 篇用户 × NPC 同人文。 | `totalFanficUserNpc / 3` | 24 啥币 |
| NPC 自己把门焊上了 | 累计生成 3 篇 NPC × NPC 同人文。 | `totalFanficNpcNpc / 3` | 24 啥币 |
| 三千字只是热身 | 单篇同人文长度达到 3000 字以上。 | `maxFanficLength / 3000` | 30 啥币 |
| 先存档再作死 | 第一次创建本地存档快照。 | `totalSaveSnapshotsCreated / 1` | 12 啥币，称号“存档保命派” |
| 命运备份狂 | 累计创建 5 个本地存档快照。 | `totalSaveSnapshotsCreated / 5` | 35 啥币 |
| 撤回人生重开一局 | 第一次恢复本地存档快照。 | `totalSaveSnapshotsRestored / 1` | 15 啥币 |
| 外来存档已抵达 | 第一次成功导入数据存档。 | `totalDataImports / 1` | 12 啥币 |
| 本地清洁大师 | 第一次使用数据清理器完成清理。 | `totalDataCleanerRuns / 1` | 12 啥币，称号“本地清洁大师” |
| 世界书第一页 | 第一次创建世界书条目。 | `totalWorldBooksCreated / 1` | 10 啥币 |
| 世界书管理员 | 第一次批量绑定或批量设定世界书。 | `totalWorldBookBulkBinds / 1` | 18 啥币，称号“世界书管理员” |
| 我带你走 | 第一次把 NPC 带离旧世界，生成独立角色。 | `totalNpcMigrations / 1` | 30 啥币，称号“我带你走” |
| 舍不得就别舍得 | 累计带走 5 个 NPC。 | `totalNpcMigrations / 5` | 80 啥币 |
| 关系不是数字 | 任意 NPC 羁绊进度达到 40。 | `maxNpcBondScore / 40` | 20 啥币，称号“关系不是数字” |
| 这次真的牵住了 | 任意 NPC 羁绊进度达到 80。 | `maxNpcBondScore / 80` | 60 啥币 |
| 剧场先来点声 | 第一次播放背景音乐。 | `totalMusicPlays / 1` | 8 啥币 |
| 暂停也是一种态度 | 第一次暂停背景音乐。 | `totalMusicPauses / 1` | 5 啥币 |
| 切歌比翻脸快 | 第一次切换背景音乐。 | `totalMusicSwitches / 1` | 8 啥币 |
| 下拉列表很好使 | 第一次用下拉列表切歌。 | `totalMusicDropdownSwitches / 1` | 8 啥币 |
| 卡片滑得很熟练 | 第一次用滑动卡片切歌。 | `totalMusicCardSwitches / 1` | 8 啥币 |
| 六色开场白 | 播放过六首基础主题曲。 | `maxBasicMusicPlayed / 6` | 18 啥币 |
| 这首我买了 | 第一次解锁付费背景音乐。 | `totalMusicUnlocks / 1` | 12 啥币 |
| 耳朵开始氪金 | 累计解锁 3 首付费背景音乐。 | `totalMusicUnlocks / 3` | 24 啥币 |
| 主题曲收藏家 | 累计解锁 8 首付费背景音乐。 | `totalMusicUnlocks / 8` | 45 啥币，称号“剧场调音师” |
| 全曲库制霸 | 解锁全部背景音乐。 | `maxMusicTracksUnlocked / 14` | 80 啥币，称号“随身唱片柜” |
| 歌单开张 | 第一次把歌曲加入歌单。 | `totalMusicPlaylistAdds / 1` | 10 啥币 |
| 这首先别唱 | 第一次从歌单删除歌曲。 | `totalMusicPlaylistRemoves / 1` | 6 啥币 |
| 顺序必须听我的 | 第一次拖动排序歌单。 | `totalMusicPlaylistReorders / 1` | 12 啥币 |
| 五首刚刚好 | 歌单内达到 5 首歌曲。 | `maxMusicPlaylistSize / 5` | 18 啥币 |
| 一整晚不用换 | 歌单内达到 10 首歌曲。 | `maxMusicPlaylistSize / 10` | 35 啥币 |
| 全塞进去再说 | 歌单内达到全部已解锁歌曲。 | `maxMusicPlaylistFull / 1` | 45 啥币 |
| 循环开始了 | 第一次开启歌单循环。 | `totalMusicPlaylistLoops / 1` | 10 啥币 |
| 单曲执念 | 第一次开启单曲循环。 | `totalMusicSingleLoops / 1` | 10 啥币 |
| 听完一轮才算数 | 完整播放一轮歌单。 | `totalMusicPlaylistRounds / 1` | 30 啥币 |
| 背景音常驻嘉宾 | 累计播放 30 分钟背景音乐。 | `totalMusicMinutes / 30` | 20 啥币 |
| 今天耳朵加班 | 累计播放 120 分钟背景音乐。 | `totalMusicMinutes / 120` | 45 啥币 |
| 剧场有自己的 BGM | 累计播放 500 分钟背景音乐。 | `totalMusicMinutes / 500` | 100 啥币，称号“常驻听众” |
| 紫雾落座 | 播放 Lavender Mist。 | `musicPlayed_lavender_mist / 1` | 6 啥币 |
| 日落续杯 | 播放 Peach Dusk。 | `musicPlayed_peach_dusk / 1` | 6 啥币 |
| 破晓调亮 | 播放 Blue Dawn Haze。 | `musicPlayed_blue_dawn_haze / 1` | 6 啥币 |
| 薄荷醒神 | 播放 Sage Mint Breeze。 | `musicPlayed_sage_mint_breeze / 1` | 6 啥币 |
| 月柠轻响 | 播放 Moonlit Lemon Fog。 | `musicPlayed_moonlit_lemon_fog / 1` | 6 啥币 |
| 晨露入场 | 播放 Berry Dew Morning。 | `musicPlayed_berry_dew_morning / 1` | 6 啥币 |
| 深渊开始低声说话 | 解锁并播放 Abyss Observatory。 | `musicPlayed_abyss_observatory / 1` | 14 啥币 |
| 裂隙准点发车 | 解锁并播放 Rift Transit。 | `musicPlayed_rift_transit / 1` | 14 啥币 |
| 纸上花影动了一下 | 解锁并播放 Flowers Beyond Flowers。 | `musicPlayed_not_flowers / 1` | 14 啥币 |
| 齿轮懂点节拍 | 解锁并播放 Clockwork Machinarium。 | `musicPlayed_clockwork_machinarium / 1` | 14 啥币 |
| 雨夜调频成功 | 解锁并播放 Rain Alley Radio。 | `musicPlayed_rain_alley_radio / 1` | 14 啥币 |
| 云朵也会哼歌 | 解锁并播放 Pasture Under Blue Skies。 | `musicPlayed_pasture_under_blue_skies / 1` | 14 啥币 |
| 唱针落下 | 解锁并播放 Vinyl Memories。 | `musicPlayed_vinyl_memories / 1` | 14 啥币 |

## 隐藏成就登记

| 成就名 | 解锁方式 | 统计键 / 阈值 | 奖励 | 隐藏 |
|---|---|---|---|---|
| 旧世界的回音 | 带走 NPC 时保留旧世界记忆。 | `totalNpcMigrationsWithMemory / 1` | 35 啥币 | 是 |
| 转盘称号毕业生 | 集齐全部 5 个转盘限定称号。 | `maxRouletteTitlesOwned / 5` | 80 啥币 | 是 |
| 碎片拼成了钱包的形状 | 集齐全部 5 个转盘限定气泡碎片边框。 | `maxRouletteFramesOwned / 5` | 80 啥币 | 是 |
| 祂刚刚眨眼了 | 首次触发克苏鲁凝视悬浮窗。 | `totalCthulhuGazes / 1` | 10 啥币，称号“被祂看过一眼” | 是 |
| 别回头 | 克苏鲁凝视悬浮窗累计出现 5 次。 | `totalCthulhuGazes / 5` | 18 啥币 | 是 |
| 我说这不是幻觉 | 克苏鲁凝视悬浮窗累计出现 15 次。 | `totalCthulhuGazes / 15` | 30 啥币，装扮“低语裂隙” | 是 |
| 夜深了还在写命运 | 凌晨时段发送消息。 | `totalLateNightMessages / 1` | 15 啥币，称号“夜班造梦员” | 是 |
| 怎么全都来找我 | 同时拥有 3 条及以上未读 NPC 来信。 | `maxNpcUnreadMessages / 3` | 25 啥币，装扮“信箱爆炸” | 是 |
| 这条线我追定了 | 累计完成 20 次 NPC 私聊回复。 | `totalNpcReplies / 20` | 25 啥币 | 是 |
| 邮箱里真的有东西 | 首次领取邮箱奖励。 | `totalMailboxClaims / 1` | 12 啥币 | 是 |
| 选项恐惧症晚期 | 一次输入里插入 3 个以上选项。 | `totalMultiChoiceInputs / 1` | 18 啥币 | 是 |
| 这把我要逆天改命 | 选择过 F 选项累计 5 次。 | `totalFChoiceInputs / 5` | 30 啥币，称号“F 选项信徒” | 是 |
| 买它不是因为需要 | 商店购买累计 20 次。 | `totalShopPurchases / 20` | 35 啥币 | 是 |
| 我全都要 | 解锁 10 个气泡边框。 | `maxFramesUnlocked / 10` | 50 啥币，称号“边框收藏家” | 是 |
| 今天也被盯上了 | 累计领取每日福利 3 次。 | `totalDailyClaims / 3` | 20 啥币 | 是 |
| 盲盒梗王已上线 | 同人文灵感盲盒累计使用 10 次。 | `totalFanficBlindBoxes / 10` | 60 啥币 | 是 |
| 这不是番外，这是砖头 | 单篇同人文长度达到 8000 字以上。 | `maxFanficLength / 8000` | 80 啥币 | 是 |
| 我忠实的信徒。 | 在深渊观测站主题下走遍全部主菜单。 | `cthulhuMenuMask / 15` | 100 啥币 | 是 |
| 嘴上说不听，手很诚实 | 打开音乐面板后 5 秒内点播放。 | `hiddenMusicFastPlay / 1` | 12 啥币 | 是 |
| 关掉又打开，欲擒故纵 | 1 分钟内暂停又继续同一首歌。 | `hiddenMusicPauseResume / 1` | 12 啥币 | 是 |
| 夜雨正合适 | 深夜时段播放 Rain Alley Radio。 | `hiddenMusicRainNight / 1` | 25 啥币 | 是 |
| 黑胶要配黑胶 | 当前主题为黑胶往事时播放 Vinyl Memories。 | `hiddenMusicTheme_vinyl_memories / 1` | 25 啥币 | 是 |
| 深渊声卡已连接 | 当前主题为深渊观测站时播放 Abyss Observatory。 | `hiddenMusicTheme_cthulhu / 1` | 25 啥币 | 是 |
| 裂隙信号满格 | 当前主题为裂隙中转站时播放 Rift Transit。 | `hiddenMusicTheme_rift_relay / 1` | 25 啥币 | 是 |
| 花影落在歌单里 | 当前主题为花非花时播放 Flowers Beyond Flowers。 | `hiddenMusicTheme_flower_not_flower / 1` | 25 啥币 | 是 |
| 齿轮没白转 | 当前主题为机械迷城时播放 Clockwork Machinarium。 | `hiddenMusicTheme_mechanical_city / 1` | 25 啥币 | 是 |
| 今日频道有雨 | 当前主题为雨巷电台时播放 Rain Alley Radio。 | `hiddenMusicTheme_rain_radio / 1` | 25 啥币 | 是 |
| 云层开了声 | 当前主题为晴空牧场时播放 Pasture Under Blue Skies。 | `hiddenMusicTheme_sky_pasture / 1` | 25 啥币 | 是 |
| 这歌单有点私人 | 创建一个只包含 1 首歌的歌单并循环播放。 | `hiddenMusicPrivatePlaylist / 1` | 20 啥币 | 是 |
| 我全都要听一遍 | 24 小时内播放过全部已解锁歌曲。 | `hiddenMusicAllUnlockedDay / 1` | 60 啥币 | 是 |
| 调音台被你摸热了 | 单日切歌 30 次。 | `musicSwitches / 30` | 35 啥币 | 是 |
| 安静五分钟失败 | 暂停后 5 分钟内再次播放。 | `hiddenMusicQuietFail / 1` | 15 啥币 | 是 |
| 真正的后台演员 | 音乐播放时完成一次聊天回复。 | `hiddenMusicReplyBackground / 1` | 20 啥币 | 是 |

## V2.1 音乐覆盖

本次新增或补强的成就覆盖以下玩法：

- 背景音乐：播放、暂停、切歌、卡片切歌、下拉切歌、播放时长。
- 主题曲库：六首基础主题曲播放记录、付费主题曲解锁和全曲库收集。
- 自定义歌单：加入歌曲、移出歌曲、拖拽排序、歌单大小和完整循环。
- 隐藏彩蛋：当前主题播放对应主题曲、深夜雨巷、快速播放、暂停后反悔、后台播放时完成聊天回复。
- V2.1 更新福利会通过邮箱发放 70 啥币。

## V2.0.5 性能覆盖

本次没有新增成就，属于长聊天和大存档性能专项：

- V2.0.5 小版本福利会通过邮箱发放 50 啥币。
- 现有导入、数据清理器和聊天相关成就不变。

## V2.0.4 修复覆盖

本次没有新增成就，沿用 V2.0.0 的带走 NPC 与羁绊路线统计：

- 带走 NPC 的迁徙次数、保留旧世界记忆隐藏成就仍会照常触发。
- V2.0.4 小版本福利会通过邮箱发放 50 啥币。

## V2.0.3 新增覆盖

本次新增或补强的成就覆盖以下玩法：

- 自定义主题：购买格子、装备自制主题、累计保存、累计编辑。
- 新增称号「主题裁缝」，作为第一次购买并保存自定义主题的纪念。
- V2.0.3 小版本福利会通过邮箱发放 50 啥币。

## V2.0.2 新增覆盖

本次新增或补强的成就覆盖以下玩法：

- 自定义气泡：购买格子、装备自制气泡、绑定当前角色、累计保存编辑。
- NPC 私聊气泡装扮：沿用现有装扮/边框成就统计，并让私聊界面同步显示。

## V2.0.0 新增覆盖

本次新增或补强的成就覆盖以下玩法：

- 带走 NPC：第一次迁徙、累计迁徙、保留旧世界记忆隐藏成就。
- 羁绊路线：任意 NPC 羁绊进度达到关键阶段。
- 继续保留 V1.9.9 的新主题、同人文、存档、导入、清理器和世界书批量绑定成就。
