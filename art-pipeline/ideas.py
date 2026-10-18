# Source for art-pipeline/ideas.json and ideas.md: 100 candidate poses for the art pipeline.
# Each entry: id, Chinese display name, category, inspiration, English pose prompt, optional allowEdges.
import json

C = {
    "emotion": "表情包情绪",
    "lore": "鲸鱼娘人设与梗",
    "pet": "桌宠动作",
    "work": "打工人与程序员",
    "money": "记账与花钱",
    "time": "峰谷与时间",
    "reply": "回应用户",
    "food": "吃吃喝喝",
    "season": "节日与季节",
    "ocean": "海洋与鲸鱼",
}
S = {"sticker": "常见 chibi 表情包", "lore": "鲸鱼娘社区设定", "shimeji": "Shimeji 等桌宠动作集",
     "office": "程序员 / 打工人表情包", "app": "本应用的使用场景"}

ideas = [
    # 表情包情绪
    ("gen_laugh", "笑出声", "emotion", "sticker", "laughing so hard she is holding her belly, eyes squeezed shut, tiny tears of laughter at the corners"),
    ("gen_pout", "鼓脸生气", "emotion", "sticker", "pouting with puffed cheeks and arms crossed, a small cartoon anger mark floating near her head"),
    ("gen_wail", "嚎啕大哭", "emotion", "sticker", "crying comically with two streams of tears and mouth wide open, fists clenched at her sides"),
    ("gen_hide_face", "捂脸害羞", "emotion", "sticker", "covering her bright red blushing face with both hands while peeking through her fingers"),
    ("gen_smug", "得意", "emotion", "sticker", "hands on hips with a smug closed-eye smile and nose slightly raised, tiny sparkles around her"),
    ("gen_shock", "震惊", "emotion", "sticker", "jumping back in shock with both hands raised, hair and tail standing up, a big exclamation mark above her head"),
    ("gen_finger_heart", "比心", "emotion", "sticker", "making a finger heart with one hand toward the viewer, winking, small pink hearts floating up"),
    ("gen_dizzy_stars", "眼冒金星", "emotion", "sticker", "wobbling dizzily with swirl eyes and little yellow stars circling around her head"),
    ("gen_question", "疑惑", "emotion", "sticker", "tilting her head with one finger on her cheek, a big question mark floating above her"),
    ("gen_gloomy", "蹲墙角", "emotion", "sticker", "squatting and drawing circles on the ground with one finger, gloomy vertical lines over her head"),
    # 鲸鱼娘人设与梗
    ("gen_rice_guard", "护饭", "lore", "lore", "hugging a big bowl of plain white rice protectively and glaring sideways, as if someone wants to take it"),
    ("gen_rice_refill", "再来一碗", "lore", "lore", "holding out an empty rice bowl with both hands, pleading sparkly eyes, a few rice grains on her cheek"),
    ("gen_tsundere", "傲娇", "lore", "lore", "turning her face away with closed eyes and a blush, arms crossed, but peeking back at the viewer with one eye"),
    ("gen_fish_slice", "叫你鱼片", "lore", "lore", "pointing playfully at the viewer while holding a thin slice of raw fish on chopsticks in the other hand, teasing grin"),
    ("gen_think_gears", "深度思考中", "lore", "lore", "hand on chin with eyes looking up, a large thought bubble above her filled with turning gears and sparkles"),
    ("gen_think_long", "想太久了", "lore", "lore", "sitting tangled in a very long ribbon of small thought bubbles that loops around her, slightly dizzy"),
    ("gen_busy_queue", "排队等服务器", "lore", "lore", "holding a numbered queue ticket with a blank number, standing patiently but sighing, a small clock beside her"),
    ("gen_fat_fish", "大肥鱼", "lore", "lore", "puffing out her cheeks and spreading her arms wide to look round like a big puffy fish, playful"),
    ("gen_open_gift", "开源送礼", "lore", "lore", "opening a big gift box from which small glowing cubes burst out, generous happy smile"),
    ("gen_cheap_tag", "便宜又好用", "lore", "lore", "proudly holding up a small blank price tag on a string, confident wink"),
    # 桌宠动作
    ("gen_sit_edge", "坐在边上", "pet", "shimeji", "sitting on an invisible ledge with legs dangling and swinging, relaxed smile, hands resting beside her"),
    ("gen_climb", "爬墙", "pet", "shimeji", "climbing up a tall vertical wooden ladder seen from the side, both hands gripping a rung above her head and one foot on a lower rung, determined face, tail curled"),
    ("gen_hang", "挂着", "pet", "shimeji", "hanging from an invisible bar above her with both hands, legs dangling, nervous smile", ["top"]),
    ("gen_falling", "掉下去了", "pet", "shimeji", "falling through the air with limbs flailing, hair and tail flying upward, panicked expression"),
    ("gen_landing", "落地", "pet", "shimeji", "landing in a crouch with one hand touching the ground, small dust puffs around her feet, triumphant grin"),
    ("gen_dragged", "被拎起来", "pet", "shimeji", "being lifted by the back of her collar from above, dangling and kicking her legs, annoyed pout", ["top"]),
    ("gen_jump", "跳起来", "pet", "shimeji", "jumping high with both arms raised and knees tucked, joyful open-mouth smile"),
    ("gen_spin", "转圈圈", "pet", "shimeji", "spinning on one foot with arms out, skirt and hair swirling, motion lines around her"),
    ("gen_sing", "唱歌", "pet", "shimeji", "singing happily into a small microphone, eyes closed, music notes floating around her"),
    ("gen_magic", "变魔术", "pet", "shimeji", "waving a small magic wand that leaves a trail of sparkles and tiny stars, excited expression"),
    # 打工人与程序员
    ("gen_overtime_faint", "加班到昏厥", "work", "office", "collapsed face-down on a stack of papers on a small desk, a little ghost-like soul floating out of her mouth"),
    ("gen_still_can", "我还能加班", "work", "office", "giving a shaky thumbs up with dark circles under her eyes and a forced bright smile, a coffee cup in the other hand"),
    ("gen_bug_run", "跑去改bug", "work", "office", "running urgently while holding a laptop under her arm, a tiny cute cartoon bug chasing behind her"),
    ("gen_bug_catch", "抓到bug", "work", "office", "holding up a magnifying glass to inspect a tiny cute cartoon bug held in her other hand, focused"),
    ("gen_slack_phone", "摸鱼", "work", "office", "secretly looking at a smartphone hidden behind an open book, sly little smile, glancing sideways"),
    ("gen_lie_flat", "躺平", "work", "office", "lying completely flat on her back on the floor, seen from the side so her body is horizontal, arms and legs stretched out limply, blank exhausted face with half-closed eyes, a tiny sigh puff above her mouth"),
    ("gen_worker", "打工人出发", "work", "office", "marching forward with a briefcase in one hand and a piece of toast in her mouth, determined morning face"),
    ("gen_merge_conflict", "代码冲突", "work", "office", "pulling her hair in frustration in front of a floating screen with two overlapping tangled lines"),
    ("gen_deploy", "上线祈祷", "work", "office", "kneeling with hands clasped in prayer in front of a small server box with blinking lights, nervous sweat"),
    ("gen_meeting_sleep", "开会犯困", "work", "office", "sitting upright on a chair but nodding off, eyes half-closed, a small drool bubble, notebook slipping from her lap"),
    # 记账与花钱
    ("gen_count_cash", "数钱", "money", "app", "sitting and carefully counting a small stack of banknotes, tongue slightly out in concentration"),
    ("gen_coin_rain", "金币雨", "money", "app", "spreading her arms joyfully as a shower of gold coins falls around her"),
    ("gen_calculator", "按计算器", "money", "app", "frowning while pressing buttons on a big calculator with a blank display, pencil in mouth"),
    ("gen_topup_button", "充值", "money", "app", "pressing a big round glowing button with a plus symbol on it, excited expression"),
    ("gen_empty_pockets", "掏空口袋", "money", "app", "pulling out the empty pockets of her apron, embarrassed smile, a single sweat drop"),
    ("gen_shopping_bags", "买买买", "money", "app", "carrying many colorful shopping bags in both hands, guilty but happy smile"),
    ("gen_treasure_chest", "宝箱", "money", "app", "opening a small treasure chest that glows with golden light, amazed sparkling eyes"),
    ("gen_coin_stack", "顶硬币", "money", "app", "balancing a tall wobbly stack of gold coins on her head while standing on one foot"),
    ("gen_budget_check", "核对账本", "money", "app", "holding a clipboard checklist and ticking items off with a pen, serious accountant face, glasses on"),
    ("gen_tip_jar", "打赏罐", "money", "app", "holding out a small glass jar with a few coins inside toward the viewer, hopeful puppy eyes"),
    # 峰谷与时间
    ("gen_alarm", "闹钟响了", "time", "app", "holding a ringing alarm clock with both hands, startled, a strand of hair sticking up"),
    ("gen_hourglass", "盯着沙漏", "time", "app", "resting her chin on her hands while watching a large hourglass intently"),
    ("gen_wristwatch", "看表", "time", "app", "raising her left arm to look down at a large, clearly visible wristwatch on her wrist, tapping one foot impatiently, small sigh puff"),
    ("gen_sunrise", "早起", "time", "app", "stretching with both arms up and a big yawn, a small cartoon sun rising behind her"),
    ("gen_night_owl", "夜猫子", "time", "app", "sitting on a crescent moon holding a glowing smartphone, sleepy half-closed eyes"),
    ("gen_red_paddle", "高峰别用", "time", "app", "holding up a round red sign paddle and making a stop gesture with her other hand, stern face"),
    ("gen_green_paddle", "空闲随便用", "time", "app", "holding up a round green sign paddle and giving an okay hand gesture, cheerful smile"),
    ("gen_calendar", "撕日历", "time", "app", "tearing a page off a large desk calendar with blank pages, surprised expression"),
    ("gen_countdown", "倒计时", "time", "app", "pointing at a big round stopwatch floating beside her, excited and leaning forward"),
    ("gen_weekend", "周末到了", "time", "app", "throwing both arms up in celebration with confetti falling around her, huge smile"),
    # 回应用户
    ("gen_hello", "你好呀", "reply", "sticker", "waving hello with a big friendly smile while leaning slightly forward"),
    ("gen_bow", "鞠躬", "reply", "sticker", "seen from the side, bowing deeply forward at the waist about 45 degrees with her upper body tilted down, both hands folded in front of her apron, eyes closed politely"),
    ("gen_salute", "收到", "reply", "sticker", "giving a crisp salute with a confident smile and a little sparkle near her eye"),
    ("gen_ok_sign", "好的", "reply", "sticker", "making an okay sign with her fingers held up near her face, cheerful wink"),
    ("gen_thanks", "谢谢", "reply", "sticker", "holding a small bouquet of flowers out to the viewer with both hands, grateful smile"),
    ("gen_sorry", "对不起", "reply", "sticker", "bowing deeply with her hands pressed together and sweat drops, apologetic expression"),
    ("gen_good_job", "做得好", "reply", "sticker", "clapping her hands enthusiastically with a bright smile, little sparkles around her hands"),
    ("gen_hug", "抱抱", "reply", "sticker", "stretching both arms forward toward the viewer asking for a hug, pleading eyes and a blush"),
    ("gen_peek_side", "偷看", "reply", "sticker", "only her head, shoulders and both hands visible as she leans in from the left side of the canvas, hands gripping the edge, curious wide eyes, the rest of her body hidden past the left edge", ["left"]),
    ("gen_bye", "拜拜", "reply", "sticker", "waving goodbye with one hand while walking away and looking back over her shoulder, gentle smile"),
    # 吃吃喝喝
    ("gen_dumplings", "吃饺子", "food", "sticker", "holding up a dumpling with chopsticks over a plate of dumplings, delighted face"),
    ("gen_noodles", "嗦面", "food", "sticker", "slurping a long noodle from a big bowl, cheeks round, steam rising"),
    ("gen_milktea", "奶茶", "food", "sticker", "sipping bubble milk tea through a thick straw, blissful closed eyes"),
    ("gen_icecream", "冰淇淋", "food", "sticker", "licking a tall ice cream cone, a small drip on her cheek, happy"),
    ("gen_dried_fish", "小鱼干", "food", "lore", "holding a small dried fish snack with sparkling eyes and a tiny drool drop"),
    ("gen_cake", "蛋糕", "food", "sticker", "holding a plate with a strawberry shortcake slice and a fork, excited"),
    ("gen_hotpot", "火锅", "food", "sticker", "sitting in front of a small steaming hotpot with chopsticks, flushed happy cheeks"),
    ("gen_watermelon", "啃西瓜", "food", "sticker", "biting into a big slice of watermelon, a few seeds stuck on her cheek"),
    ("gen_bento", "便当", "food", "sticker", "proudly presenting an open lunch box with neatly arranged rice and side dishes"),
    ("gen_coffee", "续命咖啡", "food", "office", "hugging a giant coffee mug with both hands, tired eyes slowly brightening, steam rising"),
    # 节日与季节
    ("gen_red_envelope", "红包", "season", "sticker", "holding up a plain red envelope with both hands and bowing slightly, festive smile"),
    ("gen_lantern", "提灯笼", "season", "sticker", "holding a glowing round red paper lantern on a short stick, warm smile"),
    ("gen_fireworks", "看烟花", "season", "sticker", "covering her ears with both hands and looking up with excited sparkling eyes while several small colorful fireworks burst in a circle around her head"),
    ("gen_zongzi", "粽子", "season", "sticker", "holding a zongzi rice dumpling wrapped in green leaves and tied with string, curious"),
    ("gen_mooncake", "月饼", "season", "sticker", "holding a big round mooncake with a plain flower pattern, content smile"),
    ("gen_snowman", "堆雪人", "season", "sticker", "building a small snowman with a scarf, wearing mittens, rosy cheeks"),
    ("gen_umbrella", "下雨天", "season", "sticker", "holding a blue umbrella with small raindrops falling around her, smiling"),
    ("gen_summer_fan", "好热", "season", "sticker", "fanning herself with a round paper fan, sweating with her tongue slightly out"),
    ("gen_birthday", "生日快乐", "season", "sticker", "holding a small birthday cake with lit candles, wearing a party hat on top of her headband"),
    ("gen_santa", "圣诞", "season", "sticker", "wearing a santa hat over her headband and carrying a small wrapped gift box, cheerful"),
    # 海洋与鲸鱼
    ("gen_spout", "喷水", "ocean", "lore", "laughing as a playful water spout fountain shoots up from the top of her head"),
    ("gen_swim", "游来游去", "ocean", "lore", "swimming through the air as if underwater, small bubbles around her, tail swishing"),
    ("gen_surf", "冲浪", "ocean", "sticker", "riding a small surfboard on a stylized curling wave, arms out for balance, thrilled"),
    ("gen_seashell", "听贝壳", "ocean", "sticker", "holding a seashell up to her ear and listening with curious eyes"),
    ("gen_fishing", "钓鱼", "ocean", "lore", "sitting with a fishing rod as a small fish bites the line, excited expression"),
    ("gen_baby_whale", "抱小鲸鱼", "ocean", "lore", "hugging a cute cartoon baby whale affectionately, both of them smiling"),
    ("gen_message_bottle", "漂流瓶", "ocean", "sticker", "holding a glass bottle with a rolled note inside, hopeful expression"),
    ("gen_anchor", "拖船锚", "ocean", "sticker", "dragging a heavy anchor with both hands, struggling comically, sweat drops"),
    ("gen_snorkel", "潜水", "ocean", "sticker", "wearing a small diving mask pushed up on her forehead and holding a snorkel, cheerful"),
    ("gen_starfish", "海星糊脸", "ocean", "sticker", "a starfish stuck on top of her head, startled and cross-eyed looking up at it"),
]

assert len(ideas) == 100, len(ideas)
ids = [i[0] for i in ideas]
assert len(set(ids)) == 100, "duplicate ids"

out = []
for row in ideas:
    i, name, cat, src, pose = row[:5]
    e = {"id": i, "name": "鲸鱼娘·" + name, "category": C[cat], "inspiration": S[src], "pose": pose}
    if len(row) > 5:
        e["allowEdges"] = row[5]
    out.append(e)
json.dump(out, open("ideas.json", "w"), ensure_ascii=False, indent=2)

md = ["# Art ideas", "", "100 candidate poses. Move the ones you want into `assets.json`, then run `./art.sh all`.", ""]
for key, title in C.items():
    md += [f"## {title}", "", "| ID | 名称 | 灵感来源 | Pose prompt |", "|---|---|---|---|"]
    for e in out:
        if e["category"] == title:
            md.append(f"| {e['id']} | {e['name']} | {e['inspiration']} | {e['pose']} |")
    md.append("")
open("ideas.md", "w").write("\n".join(md))
print("wrote ideas.json and ideas.md:", len(out), "ideas")
