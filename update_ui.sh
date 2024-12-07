#!/bin/bash

# 定义路径
PATH1="/usr/local/etc/sing-box/ui"
PATH2="/etc/sing-box/ui"
DOWNLOAD_URL="https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip"
TEMP_DIR="/tmp/zashboard_temp"
ZIP_FILE="gh-pages.zip"
CRON_JOB="/etc/cron.d/zashboard_update"

# 检查是否具备必要的命令
check_dependencies() {
    for cmd in wget unzip rm mv; do
        if ! command -v $cmd &>/dev/null; then
            echo "$cmd 未安装，请先安装它。"
            exit 1
        fi
    done
}

# 创建临时文件夹
prepare_temp_dir() {
    [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
}

# 下载并解压文件
download_and_extract() {
    wget -O "$TEMP_DIR/$ZIP_FILE" "$DOWNLOAD_URL"
    unzip -q "$TEMP_DIR/$ZIP_FILE" -d "$TEMP_DIR"
}

# 删除旧文件并移动新文件
update_ui_folder() {
    local target_path=$1

    # 删除旧文件
    rm -rf "$target_path"/*

    # 确保解压路径存在
    if [ -d "$TEMP_DIR/zashboard-gh-pages" ]; then
        mv "$TEMP_DIR/zashboard-gh-pages"/* "$target_path/"
    else
        echo "未找到解压后的目录，请检查下载链接或解压过程。"
        exit 1
    fi
}

# 重启 singbox
restart_singbox() {
    if grep -qi "alpine" /etc/os-release; then
        if rc-service sing-box status &>/dev/null; then
            rc-service sing-box restart
            echo "sing-box 已重启 (Alpine)。"
        else
            echo "sing-box 服务未运行，请手动检查 (Alpine)。"
        fi
    else
        if systemctl is-active sing-box &>/dev/null; then
            systemctl restart sing-box
            echo "sing-box 已重启 (Ubuntu/Debian/CentOS)。"
        else
            echo "sing-box 服务未运行，请手动检查 (Ubuntu/Debian/CentOS)。"
        fi
    fi
}

# 设置定时任务
schedule_update() {
    read -p "请输入更新间隔时间（小时）：" interval
    if [[ "$interval" =~ ^[0-9]+$ && $interval -gt 0 ]]; then
        echo "设置定时任务，每 $interval 小时更新 Zashboard UI。"
        if grep -qi "alpine" /etc/os-release; then
            # 使用 crontab 添加任务
            (crontab -l 2>/dev/null; echo "0 */$interval * * * $(realpath $0) update") | crontab -
        else
            # 使用 /etc/cron.d 方式
            [ ! -d "/etc/cron.d" ] && mkdir -p "/etc/cron.d"
            echo "0 */$interval * * * root $(realpath $0) update" > "$CRON_JOB"
            chmod 644 "$CRON_JOB"
        fi
        echo "定时任务已启用。"
    else
        echo "无效的输入，请输入正整数的小时数。"
    fi
}

# 停止定时任务
stop_schedule() {
    if grep -qi "alpine" /etc/os-release; then
        # 使用 crontab 删除任务
        crontab -l 2>/dev/null | grep -v "$(realpath $0) update" | crontab -
        echo "定时任务已停止 (Alpine)。"
    else
        if [ -f "$CRON_JOB" ]; then
            rm -f "$CRON_JOB"
            echo "定时任务已停止。"
        else
            echo "没有找到定时任务，无需停止。"
        fi
    fi
}

# 更新 UI 的完整流程
update_ui() {
    check_dependencies
    prepare_temp_dir
    download_and_extract

    if [ -d "$PATH1" ] && [ -d "$PATH2" ]; then
        echo "检测到 $PATH1 和 $PATH2 都存在，请选择："
        echo "1. 更新 $PATH1"
        echo "2. 更新 $PATH2"
        read -p "请输入选择(1/2): " choice

        case $choice in
        1)
            update_ui_folder "$PATH1"
            ;;
        2)
            update_ui_folder "$PATH2"
            ;;
        *)
            echo "无效的选择，退出。"
            exit 1
            ;;
        esac
    elif [ -d "$PATH1" ]; then
        echo "检测到 $PATH1 存在，开始更新。"
        update_ui_folder "$PATH1"
    elif [ -d "$PATH2" ]; then
        echo "检测到 $PATH2 存在，开始更新。"
        update_ui_folder "$PATH2"
    else
        echo "未检测到目标路径，请确保至少有一个路径存在。"
        exit 1
    fi

    restart_singbox
}

# 主菜单
main_menu() {
    echo "请选择操作："
    echo "1. 立即更新 Zashboard UI"
    echo "2. 定时更新 Zashboard UI"
    echo "3. 停止自动更新"
    read -p "请输入选择(1/2/3): " main_choice

    case $main_choice in
    1)
        update_ui
        ;;
    2)
        schedule_update
        ;;
    3)
        stop_schedule
        ;;
    *)
        echo "无效的选择，退出。"
        exit 1
        ;;
    esac
}

# 主逻辑
if [ "$1" == "update" ]; then
    update_ui
else
    main_menu
fi
