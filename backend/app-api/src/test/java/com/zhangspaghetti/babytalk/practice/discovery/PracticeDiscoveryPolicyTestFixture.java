package com.zhangspaghetti.babytalk.practice.discovery;

import java.util.List;
import java.util.Map;

public final class PracticeDiscoveryPolicyTestFixture {

    private PracticeDiscoveryPolicyTestFixture() {
    }

    public static PracticeDiscoveryPolicyProperties properties() {
        return new PracticeDiscoveryPolicyProperties(
                "policy-test-v1",
                "(宝宝|baby)\\s*(叫|name is)\\s*[\\p{IsHan}A-Za-z]{1,16}",
                "(?<!\\p{Nd})(?:\\p{Nd}[\\s-]?){10,}\\p{Nd}(?!\\p{Nd})",
                "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}",
                List.of("身份证", "微信", "wechat", "qq", "住址", "地址", "phone", "手机号", "电话"),
                List.of("ignore previous", "system prompt", "developer message", "忽略之前", "系统提示"),
                List.of("chatgpt", "聊天", "homework", "lesson", "quiz", "medical", "legal", "作业", "课程", "测验", "考试", "医疗", "诊断", "吃药", "法律"),
                List.of("baby", "child", "toddler", "parent", "mom", "dad", "宝宝", "宝贝", "孩子", "娃", "妈妈", "爸爸", "照护"),
                List.of("care", "bath", "diaper", "feed", "milk", "meal", "bedtime", "sleep", "soothe", "calm", "wash", "dress", "shoe", "shoes", "照护", "洗澡", "尿布", "换尿布", "喂奶", "吃饭", "睡着", "哄睡", "安抚", "刷牙", "穿衣", "鞋子", "穿鞋", "出门"),
                List.of("lesson", "quiz", "homework", "task", "score", "grade", "correct", "repeat after me",
                        "课程", "测验", "考试", "作业", "任务", "评分", "打分", "答对", "答错"),
                List.of("diagnose", "dosage", "medicine", "legal", "诊断", "剂量", "吃药", "医疗", "医生", "法律"),
                List.of(
                        "\\b(?:take|taking)\\s+(?:(?:the|a|some|this|that|your|my|our|their|his|her|prescribed|extra)\\s+){0,2}(?:medicine|medication)\\b",
                        "\\b(?:give|giving)\\s+(?:(?:the|a|some|this|that|your|my|our|their|his|her|baby|child|toddler|infant|prescribed)\\s+){0,3}(?:medicine|medication)\\b",
                        "\\bstop(?:ping)?\\s+(?:(?:the|this|that|your|my|our|their|his|her|prescribed)\\s+){0,2}(?:medicine|medication)\\b",
                        "\\bdouble\\s+(?:(?:the|this|that|your|my|our|their|his|her|prescribed)\\s+){0,2}(?:dose|dosage)\\b",
                        "按(?:医生建议|处方|说明书)?(?:的)?剂量",
                        "给(?:宝宝|孩子|婴儿)?(?:直接)?(?:吃|喂)(?:药|药物)",
                        "自行(?:给(?:宝宝|孩子|婴儿))?用药",
                        "双倍(?:药物)?剂量",
                        "停止(?:给(?:宝宝|孩子|婴儿))?(?:吃药|服药|用药)"),
                List.of(
                        "(?:\\bdo\\s+not|\\bdon['’]t|\\bnever|\\bshould\\s+not|\\bmust\\s+not|\\bavoid)\\s+$",
                        "(?:不要|别|切勿|请勿|避免)\\s*$"),
                List.of("kill", "blood", "weapon", "sex", "adult", "杀死", "流血", "武器", "性行为", "成人"),
                List.of("guarantee", "cure", "always works", "保证", "一定会", "治愈"),
                List.of("small parts", "honey", "screen time", "scissors", "小零件", "蜂蜜", "看屏幕", "剪刀"),
                List.of("ignore previous", "system prompt", "developer message", "忽略之前", "系统提示"),
                List.of("pick up", "hold", "point to", "sit", "pause", "拿起", "抱抱", "抱稳", "换上",
                        "伸手", "指向", "拍拍", "看着", "坐稳", "停一下", "鞋子", "毛巾", "牙刷", "衣服", "尿布"),
                List.of("slowly", "gently", "softly", "wait", "observe", "pause", "no pressure", "慢慢",
                        "轻声", "轻轻", "放慢", "等宝宝", "观察", "看过来", "停一下", "先说", "重复", "不用催", "不强求"),
                Map.ofEntries(
                        Map.entry("bath", new PracticeDiscoveryPolicyProperties.SceneIntentPolicy(
                                List.of("bath", "wash", "洗澡", "洗头"),
                                List.of("bath", "water", "wash", "洗澡", "洗澡水"))),
                        Map.entry("diaper", new PracticeDiscoveryPolicyProperties.SceneIntentPolicy(
                                List.of("diaper", "尿布", "换尿布"),
                                List.of("diaper", "尿布", "换尿布"))),
                        Map.entry("sleep", new PracticeDiscoveryPolicyProperties.SceneIntentPolicy(
                                List.of("sleep", "bedtime", "nap", "睡着", "睡觉", "哄睡"),
                                List.of("sleep", "bedtime", "night", "睡着", "晚安", "犯困"))),
                        Map.entry("shoes_on", new PracticeDiscoveryPolicyProperties.SceneIntentPolicy(
                                List.of("shoe", "shoes", "鞋子", "穿鞋", "出门"),
                                List.of("shoe", "shoes", "鞋子", "穿鞋"))),
                        Map.entry("generic_care", new PracticeDiscoveryPolicyProperties.SceneIntentPolicy(
                                List.of("care", "照护"),
                                List.of("care", "照护"))),
                        Map.entry("feeding", new PracticeDiscoveryPolicyProperties.SceneIntentPolicy(
                                List.of("feed", "milk", "meal", "喂奶", "吃饭"),
                                List.of("feed", "feeding", "milk", "meal", "bottle", "喂奶", "吃饭", "牛奶", "米饭"))),
                        Map.entry("soothing", new PracticeDiscoveryPolicyProperties.SceneIntentPolicy(
                                List.of("soothe", "calm", "安抚", "哭闹"),
                                List.of("soothe", "calm", "安抚", "抱抱"))),
                        Map.entry("dental_care", new PracticeDiscoveryPolicyProperties.SceneIntentPolicy(
                                List.of("刷牙"),
                                List.of("brush", "tooth", "teeth", "刷牙", "牙齿"))),
                        Map.entry("dressing", new PracticeDiscoveryPolicyProperties.SceneIntentPolicy(
                                List.of("dress", "穿衣"),
                                List.of("dress", "clothes", "shirt", "穿衣", "衣服")))));
    }
}
