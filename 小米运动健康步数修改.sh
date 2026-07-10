#!/bin/sh
# 小米运动健康步数修改 (Root版)
# 用法:
#   adb root
#   adb shell sh /sdcard/stepmod.sh [add|sub|set|clear] <步数>
#   示例: adb shell sh /sdcard/stepmod.sh add 10000
#   示例: adb shell sh /sdcard/stepmod.sh clear

# ---------- Root 检查 ----------
id | grep -q "uid=0" || { echo "需要 root 权限"; exit 1; }

# ---------- 自动检测 ----------
PACKAGE=""; DB_DIR=""
for pkg in com.mi.health com.xiaomi.health com.xiaomi.hm.health; do
    [ -d "/data/data/$pkg" ] && PACKAGE=$pkg && break
done
[ -z "$PACKAGE" ] && { echo "未找到小米运动健康 App"; exit 1; }
echo "App: $PACKAGE"

for d in /data/data/$PACKAGE/databases/*/; do
    [ -f "${d}cn/fitness_data" ] && DB_DIR="${d}cn" && break
done
[ -z "$DB_DIR" ] && { echo "未找到用户数据库"; exit 1; }
echo "数据: $DB_DIR"

FDB="$DB_DIR/fitness_data"
SDB="$DB_DIR/fitness_summary"

# ---------- 获取配置 ----------
SID=$(sqlite3 "$FDB" "SELECT sid FROM step_record WHERE key='steps' LIMIT 1;" 2>/dev/null)
[ -z "$SID" ] && SID="hlth.gen_$(date +%s)"

TZOFF=$(sqlite3 "$FDB" "SELECT zoneOffsetInSec FROM step_record LIMIT 1;" 2>/dev/null)
[ -z "$TZOFF" ] && TZOFF=28800
TZNM=$(sqlite3 "$FDB" "SELECT zoneName FROM step_record LIMIT 1;" 2>/dev/null)
[ -z "$TZNM" ] && TZNM="Asia/Shanghai"

# 今天时间范围 (本地时间)
NOW=$(date +%s)
TODAY_S=$(( (NOW + TZOFF) / 86400 * 86400 - TZOFF ))
TODAY_E=$(( TODAY_S + 86400 ))

# ---------- 计算今日步数 ----------
# 将所有 value 的 JSON 写入临时文件，再用 sh 解析
sqlite3 "$FDB" "SELECT value FROM step_record WHERE key='steps' AND time>=$TODAY_S AND time<$TODAY_E AND isDeleted=0 ORDER BY time;" 2>/dev/null > /data/local/tmp/steps.json

TOTAL=0
while IFS= read -r line; do
    [ -z "$line" ] && continue
    # 从 {"time":...,"steps":N,...} 提取 steps 值
    s=${line#*\"steps\":}
    s=${s%%,*}
    s=${s%%\}*}
    s=${s%% *}
    case "$s" in ''|*[!0-9]*) ;; *) TOTAL=$((TOTAL + s)) ;; esac
done < /data/local/tmp/steps.json

echo "今日步数: $TOTAL"
echo ""

# ---------- 交互/命令行参数 ----------
CMD="$1"; VAL="$2"
if [ -z "$CMD" ]; then
    echo "操作: 1=增加 2=减少 3=清零 4=查看详情"
    printf "选择: "; read CMD
    case "$CMD" in
        1) CMD="add"; printf "步数: "; read VAL ;;
        2) CMD="sub"; printf "步数: "; read VAL ;;
        3) CMD="clear" ;;
        4) CMD="view" ;;
    esac
fi

case "$CMD" in
    add|+)
        echo "$VAL" | grep -qE '^[0-9]+$' || { echo "无效步数"; exit 1; }
        NEW_TOTAL=$((TOTAL + VAL)); ADD=$VAL ;;
    sub|-)
        echo "$VAL" | grep -qE '^[0-9]+$' || { echo "无效步数"; exit 1; }
        [ "$VAL" -gt "$TOTAL" ] && VAL=$TOTAL
        NEW_TOTAL=$((TOTAL - VAL)); ADD=$((0 - VAL)) ;;
    clear)
        NEW_TOTAL=0; ADD="clear" ;;
    set|=)
        echo "$VAL" | grep -qE '^[0-9]+$' || { echo "无效步数"; exit 1; }
        ADD="set"; NEW_TOTAL=$VAL ;;
    view)
        echo "今日步数详情:"
        sqlite3 -header -column "$FDB" "SELECT datetime(time, 'unixepoch', 'localtime') as t, value FROM step_record WHERE key='steps' AND time>=$TODAY_S AND time<$TODAY_E AND isDeleted=0 ORDER BY time;" 2>/dev/null
        [ -f "$SDB" ] && {
            echo ""
            echo "每日汇总:"
            sqlite3 -header -column "$SDB" "SELECT datetime(timeInZero, 'unixepoch', 'localtime') as day, dataType, value FROM daily_report WHERE dataType='STEP' AND timeInZero=$TODAY_S AND isDeleted=0;" 2>/dev/null
        }
        exit 0 ;;
    *)
        echo "用法: $0 [add|sub|set|clear|view] [步数]"; exit 1 ;;
esac

echo "步数: $TOTAL -> $NEW_TOTAL"

# ---------- 执行修改 ----------
am force-stop $PACKAGE 2>/dev/null; sleep 1

if [ "$ADD" = "clear" ]; then
sqlite3 "$FDB" "UPDATE step_record SET isDeleted=1 WHERE key='steps' AND time>=$TODAY_S AND time<$TODAY_E AND isDeleted=0;" 2>/dev/null
# 清理 daily_report 让 App 重启时重新生成
[ -f "$SDB" ] && sqlite3 "$SDB" "DELETE FROM daily_report WHERE dataType='STEP' AND timeInZero=$TODAY_S;" 2>/dev/null
echo "已清零"
elif [ "$ADD" = "set" ]; then
    # 先清零，再插入新记录
    sqlite3 "$FDB" "UPDATE step_record SET isDeleted=1 WHERE key='steps' AND time>=$TODAY_S AND time<$TODAY_E AND isDeleted=0;" 2>/dev/null
    [ -f "$SDB" ] && sqlite3 "$SDB" "DELETE FROM daily_report WHERE dataType='STEP' AND timeInZero=$TODAY_S;" 2>/dev/null
    SQL_JSON="{\"time\":$NOW,\"steps\":$NEW_TOTAL,\"distance\":0,\"calories\":0}"
    sqlite3 "$FDB" "INSERT INTO step_record (key,sid,time,value,zoneOffsetInSec,zoneName,timeIn0Tz,isUpload,isDeleted) VALUES('steps','$SID',$NOW,'$SQL_JSON',$TZOFF,'$TZNM',$TODAY_S,0,0);" 2>/dev/null
    echo "已设置为 $NEW_TOTAL"
else
    # add/sub: 插入增量记录
    SQL_JSON="{\"time\":$NOW,\"steps\":$ADD,\"distance\":0,\"calories\":0}"
    sqlite3 "$FDB" "INSERT INTO step_record (key,sid,time,value,zoneOffsetInSec,zoneName,timeIn0Tz,isUpload,isDeleted) VALUES('steps','$SID',$NOW,'$SQL_JSON',$TZOFF,'$TZNM',$TODAY_S,0,0);" 2>/dev/null
    # 清理 daily_report 让 App 重启时重新生成
    [ -f "$SDB" ] && sqlite3 "$SDB" "DELETE FROM daily_report WHERE dataType='STEP' AND timeInZero=$TODAY_S;" 2>/dev/null
    echo "已修改 (+$ADD)"
fi

# ---------- 验证 ----------
sqlite3 "$FDB" "SELECT value FROM step_record WHERE key='steps' AND time>=$TODAY_S AND time<$TODAY_E AND isDeleted=0 ORDER BY time;" 2>/dev/null > /data/local/tmp/steps_v.json
V=0
while IFS= read -r line; do
    [ -z "$line" ] && continue
    s=${line#*\"steps\":}; s=${s%%,*}; s=${s%%\}*}; s=${s%% *}
    case "$s" in ''|*[!0-9]*) ;; *) V=$((V + s)) ;; esac
done < /data/local/tmp/steps_v.json
echo "验证步数: $V"
