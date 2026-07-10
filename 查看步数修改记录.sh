#!/bin/sh
# 查看步数修改记录 (Root版 - com.mi.health)

id | grep -q "uid=0" || { echo "需要 root 权限"; exit 1; }

PACKAGE=""; DB_DIR=""
for pkg in com.mi.health com.xiaomi.health com.xiaomi.hm.health; do
    [ -d "/data/data/$pkg" ] && PACKAGE=$pkg && break
done
[ -z "$PACKAGE" ] && { echo "未找到小米运动健康 App"; exit 1; }

if [ -n "$ACCOUNT" ]; then
    DB_DIR="/data/data/$PACKAGE/databases/$ACCOUNT/cn"
    [ -f "$DB_DIR/fitness_data" ] || { echo "账号 $ACCOUNT 不存在"; exit 1; }
else
    BEST_DIR=""; BEST_TIME=0
    for d in /data/data/$PACKAGE/databases/*/; do
        [ -f "${d}cn/fitness_data" ] || continue
        LATEST=$(sqlite3 "${d}cn/fitness_data" "SELECT MAX(time) FROM step_record WHERE key='steps' AND isDeleted=0;" 2>/dev/null)
        echo "$LATEST" | grep -qE '^[0-9]+$' && [ "$LATEST" -gt "$BEST_TIME" ] && { BEST_TIME=$LATEST; BEST_DIR="${d}cn"; }
    done
    [ -z "$BEST_DIR" ] && { echo "未找到用户数据库"; exit 1; }
    DB_DIR="$BEST_DIR"
fi

FDB="$DB_DIR/fitness_data"
SDB="$DB_DIR/fitness_summary"

echo "=== 步数数据库 ==="
echo "App: $PACKAGE"
echo "数据库: $FDB"

echo ""
echo "=== 最近 7 天步数汇总 ==="
sqlite3 -header -column "$FDB" "
SELECT datetime(time, 'unixepoch', 'localtime') as t, value
FROM step_record WHERE key='steps' AND isDeleted=0
  AND time > (strftime('%s','now','-7 days','localtime'))
ORDER BY time DESC LIMIT 30;" 2>/dev/null

[ -f "$SDB" ] && {
    echo ""
    echo "=== 每日汇总 ==="
    sqlite3 -header -column "$SDB" "SELECT datetime(timeInZero, 'unixepoch', 'localtime') as day, substr(value, 1, 100) as summary FROM daily_report WHERE dataType='STEP' AND isDeleted=0 ORDER BY timeInZero DESC LIMIT 7;" 2>/dev/null
}
