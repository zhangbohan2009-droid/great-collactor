extends RefCounted
class_name LocationHistoryDB
## 地点史实资料库。
## current_map=true 的条目对应现有互动地点；candidate=true 的条目仅入库，暂不加入战国关卡路线。

static func raw_data() -> Array:
	return [
		{
			"id": "chengdu",
			"name": "成都",
			"country": "蜀 / 秦",
			"active_era": "战国至秦汉",
			"active_years": "约前4世纪起",
			"historical_note": "成都平原在开明蜀与秦并巴蜀后持续发展。秦置蜀郡后，成都逐渐成为西南重要郡治与贸易中心。",
			"current_map": true,
		},
		{
			"id": "emei_temple",
			"name": "峨眉山",
			"country": "蜀",
			"active_era": "先秦有山岳文化；佛寺兴盛在汉以后",
			"active_years": "山岳传说先秦可用，佛教寺院不早于汉晋",
			"historical_note": "峨眉山作为巴蜀名山可保留为山岳/修行地点；严格说佛教寺院形态晚于战国，数据库中以“山岳文化”说明其战国适配边界。",
			"current_map": true,
		},
		{
			"id": "zhongnan_mountain",
			"name": "终南山",
			"country": "秦",
			"active_era": "西周至战国、秦汉以后长期活跃",
			"active_years": "先秦以来",
			"historical_note": "终南山位于关中南缘，是秦地重要山岳屏障与隐逸想象来源，适合作为秦地山岳景观。",
			"current_map": true,
		},
		{
			"id": "changan",
			"name": "长安",
			"country": "秦 / 汉",
			"active_era": "战国秦邑，西汉以后极盛",
			"active_years": "战国至汉唐",
			"historical_note": "战国时期关中已有秦邑与宫室体系；“长安”作为帝都名声主要来自汉唐，游戏中可作为秦地过渡城邑。",
			"current_map": true,
		},
		{
			"id": "xianyang",
			"name": "咸阳",
			"country": "秦",
			"active_era": "战国秦至秦代",
			"active_years": "前350年左右至秦亡",
			"historical_note": "秦孝公时期商鞅变法后迁都咸阳，战国晚期至秦统一期间为秦国政治中心。",
			"current_map": true,
		},
		{
			"id": "tongguan",
			"name": "潼关",
			"country": "秦",
			"active_era": "关中通道先秦可用；关名成型较晚",
			"active_years": "先秦通道，关防名号以后世为主",
			"historical_note": "潼关所在黄河、渭水、洛水通道自先秦即有战略意义；严格的“潼关”关名和军事体系在后世更明确。",
			"current_map": true,
		},
		{
			"id": "luoyi",
			"name": "洛邑",
			"country": "周",
			"active_era": "西周至东周",
			"active_years": "前11世纪起，东周尤重要",
			"historical_note": "洛邑是周王室东都，东周时期王畿所在，战国时代仍具有礼制与政治象征意义。",
			"current_map": true,
		},
		{
			"id": "baima_temple",
			"name": "白马寺",
			"country": "东汉洛阳",
			"active_era": "东汉以后",
			"active_years": "传统始建于公元68年",
			"historical_note": "白马寺不属于战国地点。现阶段数据库标注其真实活跃期为东汉以后，后续若做严格战国关卡可替换为洛邑宗庙或王畿祭祀点。",
			"current_map": true,
		},
		{
			"id": "xinzheng",
			"name": "新郑",
			"country": "韩",
			"active_era": "春秋郑国至战国韩国",
			"active_years": "前375年韩灭郑后为韩都",
			"historical_note": "新郑原为郑都，韩国灭郑后迁都于此，直到韩国被秦所灭，是战国韩国最具代表性的都城。",
			"current_map": true,
		},
		{
			"id": "handan",
			"name": "邯郸",
			"country": "赵",
			"active_era": "战国赵都",
			"active_years": "前386年至前228年",
			"historical_note": "赵敬侯迁都邯郸后，邯郸成为赵国都城，战国后期是黄河以北人口与商业都很发达的大都会。",
			"current_map": true,
		},
		{
			"id": "linzi",
			"name": "临淄",
			"country": "齐",
			"active_era": "春秋战国齐都",
			"active_years": "西周至秦灭齐前长期为齐都",
			"historical_note": "临淄是齐国都城，战国时期商业繁荣，稷下学宫汇聚诸子，是齐地政治、经济与文化中心。",
			"current_map": true,
		},
		{
			"id": "linzi_market",
			"name": "临淄闹市",
			"country": "齐",
			"active_era": "战国",
			"active_years": "齐都临淄繁盛期",
			"historical_note": "《史记·苏秦列传》形容临淄民众吹竽、鼓瑟、击筑、斗鸡、走狗、六博、蹴鞠，适合表现商业街与娱乐街。",
			"current_map": true,
		},
		{
			"id": "taishan",
			"name": "泰山",
			"country": "",
			"active_era": "先秦至历代",
			"active_years": "先秦以来",
			"historical_note": "泰山位于齐鲁文化交界，山岳祭祀传统久远，不宜强行归属单一战国势力。",
			"current_map": true,
		},
		{
			"id": "qufu",
			"name": "曲阜",
			"country": "鲁",
			"active_era": "西周至战国鲁都",
			"active_years": "西周封鲁后至前249年鲁亡",
			"historical_note": "曲阜为鲁国都城，周礼传统深厚，也是孔子故里，适合作为礼乐与儒学相关地点。",
			"current_map": true,
		},
		{
			"id": "taoqiu_black_market",
			"name": "陶丘",
			"country": "魏",
			"active_era": "春秋战国商业城邑",
			"active_years": "先秦至秦汉",
			"historical_note": "陶丘大致在今山东定陶一带，位居交通与商业要冲，战国秦汉间常被视为富庶都会，可作为黑市贸易点。",
			"current_map": true,
		},
		{
			"id": "yunmeng_marsh",
			"name": "云梦泽",
			"country": "楚",
			"active_era": "春秋战国楚地",
			"active_years": "先秦楚文化区域",
			"historical_note": "云梦泽是古代江汉平原湖沼群的总称，与楚地山泽、田猎和神巫想象关系密切。",
			"current_map": true,
		},
		{
			"id": "yingdu",
			"name": "郢都",
			"country": "楚",
			"active_era": "春秋战国楚都",
			"active_years": "春秋中后期至前278年秦拔郢",
			"historical_note": "郢都是楚国长期都城与文化中心，直到秦将白起攻破郢都后楚迁都，适合作为楚文化核心城市。",
			"current_map": true,
		},
		{
			"id": "daliang",
			"name": "大梁",
			"country": "魏",
			"active_era": "战国魏都",
			"active_years": "魏惠王迁都后至魏亡",
			"historical_note": "大梁位于今开封一带，战国中后期为魏国都城，是魏国政治与水陆交通中心。",
			"candidate": true,
		},
		{
			"id": "jixia_academy",
			"name": "稷下学宫",
			"country": "齐",
			"active_era": "战国",
			"active_years": "齐威王、齐宣王时期尤盛",
			"historical_note": "稷下学宫设于齐都临淄，汇聚诸子百家，荀子、邹衍等学者与此相关，是战国思想史核心地点。",
			"candidate": true,
		},
		{
			"id": "yanxiadu",
			"name": "燕下都",
			"country": "燕",
			"active_era": "战国燕都遗址",
			"active_years": "战国中晚期",
			"historical_note": "燕下都位于今河北易县一带，是战国燕国重要都城遗址，适合后续补充燕地城市与墓葬线。",
			"candidate": true,
		},
		{
			"id": "zhongshan_lingshou",
			"name": "灵寿",
			"country": "中山",
			"active_era": "战国中山国都",
			"active_years": "战国中期至中山亡",
			"historical_note": "灵寿是战国中山国都城所在地，中山王墓出土大量青铜、玉器与铭文重器。",
			"candidate": true,
		},
		{
			"id": "jinyang",
			"name": "晋阳",
			"country": "赵",
			"active_era": "春秋末至战国早期",
			"active_years": "三家分晋前后",
			"historical_note": "晋阳是赵氏早期重要根据地，与三家分晋、赵国早期政治军事发展关系密切。",
			"candidate": true,
		},
		{
			"id": "anyi",
			"name": "安邑",
			"country": "魏",
			"active_era": "战国早期魏都",
			"active_years": "魏迁大梁前",
			"historical_note": "安邑位于今山西夏县一带，是魏国早期都城，适合作为后续魏国早期线索地点。",
			"candidate": true,
		},
		{
			"id": "yangdi",
			"name": "阳翟",
			"country": "韩",
			"active_era": "战国早期韩国都城",
			"active_years": "韩迁新郑前",
			"historical_note": "阳翟位于今河南禹州一带，是韩国早期都城之一，后韩灭郑迁都新郑。",
			"candidate": true,
		},
	]

static func current_map_locations() -> Array:
	return raw_data().filter(func(d: Dictionary) -> bool:
		return bool(d.get("current_map", false))
	)

static func candidate_locations() -> Array:
	return raw_data().filter(func(d: Dictionary) -> bool:
		return bool(d.get("candidate", false))
	)

static func by_id(id: String) -> Dictionary:
	for d in raw_data():
		if str(d.get("id", "")) == id:
			return d
	return {}
