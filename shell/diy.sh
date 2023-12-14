#!/usr/bin/bash
set -e
UNAME_M="$(uname -m)"
readonly UNAME_M

UNAME_U="$(uname -s)"
readonly UNAME_U

# COLORS
readonly COLOUR_RESET='\e[0m'
readonly aCOLOUR=(
    '\e[38;5;154m' # green  	| Lines, bullets and separators
    '\e[1m'        # Bold white	| Main descriptions
    '\e[90m'       # Grey		| Credits
    '\e[91m'       # Red		| Update notifications Alert
    '\e[33m'       # Yellow		| Emphasis
)

readonly GREEN_LINE=" ${aCOLOUR[0]}─────────────────────────────────────────────────────$COLOUR_RESET"
readonly GREEN_BULLET=" ${aCOLOUR[0]}-$COLOUR_RESET"
readonly GREEN_SEPARATOR="${aCOLOUR[0]}:$COLOUR_RESET"

Show() {
    # OK
    if (($1 == 0)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[0]}  OK  $COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2"
    # FAILED
    elif (($1 == 1)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[3]}FAILED$COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2"
        exit 1
    # INFO
    elif (($1 == 2)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[0]} INFO $COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2"
    # NOTICE
    elif (($1 == 3)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[4]}NOTICE$COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2"
    fi
}

Warn() {
    echo -e "${aCOLOUR[3]}$1$COLOUR_RESET"
}

GreyStart() {
    echo -e "${aCOLOUR[2]}\c"
}

ColorReset() {
    echo -e "$COLOUR_RESET\c"
}

InitBanner() {
    echo -e "${GREEN_LINE}"
    echo -e " https://github.com/wukongdaily/diy-nas-onescript"
    echo -e "${GREEN_LINE}"
    echo -e ""
}

# 函數：檢查並啟動 SSH
enable_ssh() {
    # 檢查 openssh-server 是否安裝
    if dpkg -l | grep -q openssh-server; then
        echo "openssh-server 已安裝。"
    else
        echo "openssh-server 未安裝，正在安裝..."
        sudo apt-get update
        sudo apt-get install openssh-server -y
    fi

    # 啟動 SSH 服務
    sudo systemctl start ssh
    echo "SSH 服務已啟動。"

    # 設置 SSH 服務開機自啟
    sudo systemctl enable ssh
    echo "SSH 服務已設置為開機自啟。"

    # 顯示 SSH 服務狀態
    sudo systemctl status ssh
}

#安裝常用辦公必備軟件(office、QQ、微信、遠程桌面等)
install_need_apps() {
    sudo apt-get upgrade -y
    sudo apt-get update
    sudo apt-get install cn.wps.wps-office com.qq.weixin.deepin com.gitee.rustdesk com.qq.im.deepin com.mozilla.firefox-zh -y
    sudo apt-get install neofetch -y
}

# 下載虛擬機安裝包run，並保存為virtualbox7.run
install_virtualbox() {
    echo "安裝虛擬機VirtualBox 7"
    wget -O virtualbox7.run https://download.virtualbox.org/virtualbox/7.0.12/VirtualBox-7.0.12-159484-Linux_amd64.run
    sudo sh virtualbox7.run
}

install_virtualbox_extpack() {
    wget https://download.virtualbox.org/virtualbox/7.0.12/Oracle_VM_VirtualBox_Extension_Pack-7.0.12.vbox-extpack
    sudo chmod 777 Oracle_VM_VirtualBox_Extension_Pack-7.0.12.vbox-extpack
    echo "y" | sudo VBoxManage extpack install --replace Oracle_VM_VirtualBox_Extension_Pack-7.0.12.vbox-extpack
    sudo VBoxManage list extpacks
    sudo groupadd usbfs
    sudo adduser $USER vboxusers
    sudo adduser $USER usbfs
    Show 0 "VM 擴展包安裝完成,重啟後才能生效。重啟後USB才可以被虛擬機識別"
}

# 格式轉換
convert_vm_format() {
    echo "虛擬機一鍵格式轉換(img2vdi)"
    sudo apt-get update >/dev/null 2>&1
    if ! command -v pv &>/dev/null; then
        echo "pv is not installed. Installing pv..."
        sudo apt-get install pv -y || true
    else
        echo -e
    fi

    # 獲取用戶輸入的文件路徑
    read -p "請將待轉換的文件拖拽到此處(img|img.zip|img.gz): " file_path

    # 去除路徑兩端的單引號（如果存在）
    file_path=$(echo "$file_path" | sed "s/^'//; s/'$//")

    # 驗證文件是否存在
    if [ ! -f "$file_path" ]; then
        Show 1 "文件不存在，請檢查路徑是否正確。"
        exit 1
    fi

    # 定義目標文件路徑
    target_path="${file_path%.*}.vdi"

    # 檢查文件類型並進行相應的處理
    if [[ "$file_path" == *.zip ]]; then
        # 如果是 zip 文件，先解壓
        Show 0 "正在解壓 zip 文件..."
        unzip_dir=$(mktemp -d)
        unzip "$file_path" -d "$unzip_dir"
        img_file=$(find "$unzip_dir" -type f -name "*.img")

        if [ -z "$img_file" ]; then
            Show 1 "在 zip 文件中未找到 img 文件。"
            rm -rf "$unzip_dir"
            exit 1
        fi

        # 執行轉換命令
        Show 0 "正在轉換 請稍後..."
        VBoxManage convertfromraw "$img_file" "$target_path" --format VDI

        # 清理臨時目錄
        rm -rf "$unzip_dir"
    elif [[ "$file_path" == *.img.gz ]]; then
        # 如果是 img.gz 文件，先解壓
        Show 0 "正在解壓 img.gz 文件..."
        pv "$file_path" | gunzip -c >"${file_path%.*}" || true
        img_file="${file_path%.*}"

        # 執行轉換命令
        Show 0 "正在轉換 請稍後..."
        VBoxManage convertfromraw "$img_file" "$target_path" --format VDI

        # 刪除解壓後的 img 文件
        rm -f "$img_file"
    elif [[ "$file_path" == *.img ]]; then
        # 如果是 img 文件，直接執行轉換
        Show 0 "正在轉換 請稍後..."
        VBoxManage convertfromraw "$file_path" "$target_path" --format VDI
    else
        Show 1 "不支持的文件類型。"
        exit 1
    fi

    # 檢查命令是否成功執行
    if [ $? -eq 0 ]; then
        sudo chmod 777 $target_path
        Show 0 "轉換成功。轉換後的文件位於：$target_path"
    else
        Show 1 "轉換失敗，請檢查輸入的路徑和文件。"
    fi
}

# 卸載虛擬機
uninstall_vm() {
    echo "卸載虛擬機"
    sudo sh /opt/VirtualBox/uninstall.sh
}

#  為了深度系統順利安裝CasaOS 打補丁和臨時修改os-release
patch_os_release() {
    # 備份一下原始文件
    sudo cp /etc/os-release /etc/os-release.backup
    Show 0 "準備CasaOS的使用環境..."
    Show 0 "打補丁和臨時修改os-release"
    # 打補丁
    # 安裝深度deepin缺少的依賴包udevil
    wget -O /tmp/udevil.deb https://cdn.jsdelivr.net/gh/wukongdaily/diy-nas-onescript@master/res/udevil.deb
    sudo dpkg -i /tmp/udevil.deb
    # 安裝深度deepin缺少的依賴包mergerfs
    wget -O /tmp/mergerfs.deb https://cdn.jsdelivr.net/gh/wukongdaily/diy-nas-onescript@master/res/mergerfs.deb
    sudo dpkg -i /tmp/mergerfs.deb

    #偽裝debian 12 修改系統名稱和代號，待CasaOS安裝成功後，還原回來
    sudo sed -i -e 's/^ID=.*$/ID=debian/' -e 's/^VERSION_CODENAME=.*$/VERSION_CODENAME=bookworm/' /etc/os-release
    Show 0 "妥啦! 深度Deepin系統下安裝CasaOS的環境已經準備好 你可以安裝CasaOS了."
}

# 安裝CasaOS—Docker
install_casaos() {
    patch_os_release
    echo "安裝CasaOS"
    curl -fsSL https://get.casaos.io | sudo bash
    Show 0 "CasaOS 已安裝,正在還原配置文件"
    restore_os_release
}

# CasaOS安裝成功之後,要記得還原配置文件
restore_os_release() {
    sudo cp /etc/os-release.backup /etc/os-release
    Show 0 "配置文件已還原"
}

#卸載CasaOS
uninstall_casaos() {
    Show 2 "卸載 CasaOS"
    sudo casaos-uninstall
}

#配置docker為國內鏡像
configure_docker_mirror() {
    echo "配置docker為國內鏡像"
    sudo mkdir -p /etc/docker

    sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": [
    "https://0b27f0a81a00f3560fbdc00ddd2f99e0.mirror.swr.myhuaweicloud.com",
    "https://ypzju6vq.mirror.aliyuncs.com",
    "https://registry.docker-cn.com",
    "http://hub-mirror.c.163.com",
    "https://docker.mirrors.ustc.edu.cn"
  ]
}
EOF

    sudo systemctl daemon-reload
    sudo systemctl restart docker
    Show 0 "docker 國內鏡像地址配置完畢!"
}

install_fcitx5_chewing() {
    sudo apt-get install fcitx5-chewing -y
    if [ $? -eq 0 ]; then
        Show 0 "新酷音輸入法(注音輸入法) 安裝成功"
        Show 0 "請您在全部應用里找到Fxitx5配置,添加新酷音"
    else
        Show 1 "安裝失敗，請檢查錯誤信息"
    fi
}

# 設置開機自啟動虛擬機virtualbox
set_vm_autostart() {
    # 定義紅色文本
    RED='\033[0;31m'
    # 無顏色
    NC='\033[0m'
    GREEN='\033[0;32m'

    # 顯示帶有紅色文本的提示信息
    echo -e
    echo -e "設置虛擬機開機自啟動,需要${GREEN}設置系統自動登錄。${NC}\n${RED}這可能會帶來安全風險。當然如果你後悔了,也可以在系統設置里取消自動登錄。是否繼續？${NC} [Y/n] "

    # 讀取用戶的響應
    read -r -n 1 response
    echo # 新行

    case $response in
    [nN])
        echo "操作已取消。"
        exit 1
        ;;
    *)
        do_autostart_vm
        ;;
    esac

}

#設置自動登錄
setautologin() {
    # 使用whoami命令獲取當前有效的用戶名
    USERNAME=$(whoami)

    # 設置LightDM配置以啟用自動登錄
    sudo sed -i '/^#autologin-user=/s/^#//' /etc/lightdm/lightdm.conf
    sudo sed -i "s/^autologin-user=.*/autologin-user=$USERNAME/" /etc/lightdm/lightdm.conf
    sudo sed -i "s/^#autologin-user-timeout=.*/autologin-user-timeout=0/" /etc/lightdm/lightdm.conf
    # 去掉開機提示:解鎖您的開機密鑰環
    sudo rm -rf ~/.local/share/keyrings/*
}

# 設置開機5秒後
# 自動啟動所有虛擬機(無頭啟動)
do_autostart_vm() {
    # 檢查系統上是否安裝了VirtualBox
    if ! command -v VBoxManage >/dev/null; then
        Show 1 "未檢測到VirtualBox。請先安裝VirtualBox。"
        return
    fi

    # 確定/etc/rc.local文件是否存在，如果不存在，則創建它
    if [ ! -f /etc/rc.local ]; then
        echo "#!/bin/sh -e" | sudo tee /etc/rc.local >/dev/null
        sudo chmod +x /etc/rc.local
    fi

    # 獲取當前用戶名
    USERNAME=$(whoami)

    # 獲取當前所有虛擬機的名稱並轉換為數組
    VMS=$(VBoxManage list vms | cut -d ' ' -f 1 | sed 's/"//g')
    VM_ARRAY=($VMS)

    # 檢查虛擬機數量
    if [ ${#VM_ARRAY[@]} -eq 0 ]; then
        Show 1 "沒有檢測到任何虛擬機,您應該先創建虛擬機"
        return
    fi

    # 設置自動登錄 免GUI桌面登錄
    setautologin

    # 創建一個臨時文件用於存儲新的rc.local內容
    TMP_RC_LOCAL=$(mktemp)

    # 向臨時文件添加初始行
    echo "#!/bin/sh -e" >$TMP_RC_LOCAL
    echo "sleep 5" >>$TMP_RC_LOCAL

    # 為每個現存的虛擬機添加啟動命令
    for VMNAME in "${VM_ARRAY[@]}"; do
        echo "su - $USERNAME -c \"VBoxHeadless -s $VMNAME &\"" >>$TMP_RC_LOCAL
    done

    # 添加exit 0到臨時文件的末尾
    echo "exit 0" >>$TMP_RC_LOCAL

    # 用新的rc.local內容替換舊的rc.local文件
    cat $TMP_RC_LOCAL | sudo tee /etc/rc.local >/dev/null

    # 刪除臨時文件
    rm $TMP_RC_LOCAL

    # 創建一個臨時文件用於存儲虛擬機列表
    TMP_VM_LIST=$(mktemp)

    # 將虛擬機名稱寫入臨時文件
    for VMNAME in "${VM_ARRAY[@]}"; do
        echo "$VMNAME" >>"$TMP_VM_LIST"
    done

    # 使用 dialog 顯示虛擬機列表，並將按鈕標記為“確定”
    dialog --title "下列虛擬機均已設置為開機自啟動" --ok-label "確定" --textbox "$TMP_VM_LIST" 10 50

    # 清除對話框
    clear

    # 刪除臨時文件
    rm "$TMP_VM_LIST"

    # 顯示/etc/rc.local的內容
    Show 0 "已將所有虛擬機設置為開機無頭自啟動。查看配置 /etc/rc.local,如下"
    cat /etc/rc.local
}

# 安裝btop
enable_btop() {
    # 嘗試使用 apt 安裝 btop
    if sudo apt-get update >/dev/null 2>&1 && sudo apt-get install -y btop 2>/dev/null; then
        echo "btop successfully installed using apt."
        return 0
    else
        echo "Failed to install btop using apt, trying snap..."

        # 檢查 snap 是否已安裝
        if ! command -v snap >/dev/null; then
            echo "Snap is not installed. Installing snapd..."
            if ! sudo apt-get install -y snapd; then
                echo "Failed to install snapd."
                return 1
            fi
            echo "Snapd installed successfully."
        else
            echo "Snap is already installed."
        fi

        # 使用 snap 安裝 btop
        if sudo snap install btop; then
            echo "btop successfully installed using snap."
            # 定義要添加的路徑
            path_to_add="/snap/bin"
            # 檢查 ~/.bashrc 中是否已存在該路徑
            if ! grep -q "export PATH=\$PATH:$path_to_add" ~/.bashrc; then
                # 如果不存在，將其添加到 ~/.bashrc 文件的末尾
                echo "export PATH=\$PATH:$path_to_add" >>~/.bashrc
                echo "Path $path_to_add added to ~/.bashrc"
            else
                echo "Path $path_to_add already in ~/.bashrc"
            fi
            # 重新加載 ~/.bashrc
            source ~/.bashrc
            Show 0 "btop已經安裝,你可以使用btop命令了"
            return 0
        else
            echo "Failed to install btop using snap."
            return 1
        fi
    fi
}

declare -a menu_options
declare -A commands
menu_options=(
    "啟用SSH服務"
    "安裝注音輸入法(新酷音輸入法)"
    "安裝常用辦公必備軟件(office、QQ、微信、遠程桌面等)"
    "安裝虛擬機VirtualBox 7"
    "安裝虛擬機VirtualBox 7擴展包"
    "設置虛擬機開機無頭自啟動"
    "卸載虛擬機"
    "虛擬機一鍵格式轉換(img2vdi)"
    "準備CasaOS的使用環境"
    "安裝CasaOS(包含Docker)"
    "還原配置文件os-release"
    "卸載 CasaOS"
    "配置docker為國內鏡像"
    "安裝btop資源監控工具"
)

commands=(
    ["啟用SSH服務"]="enable_ssh"
    ["安裝虛擬機VirtualBox 7"]="install_virtualbox"
    ["安裝虛擬機VirtualBox 7擴展包"]="install_virtualbox_extpack"
    ["虛擬機一鍵格式轉換(img2vdi)"]="convert_vm_format"
    ["設置虛擬機開機無頭自啟動"]="set_vm_autostart"
    ["卸載虛擬機"]="uninstall_vm"
    ["準備CasaOS的使用環境"]="patch_os_release"
    ["安裝CasaOS(包含Docker)"]="install_casaos"
    ["還原配置文件os-release"]="restore_os_release"
    ["卸載 CasaOS"]="uninstall_casaos"
    ["配置docker為國內鏡像"]="configure_docker_mirror"
    ["安裝常用辦公必備軟件(office、QQ、微信、遠程桌面等)"]="install_need_apps"
    ["安裝注音輸入法(新酷音輸入法)"]="install_fcitx5_chewing"
    ["安裝btop資源監控工具"]="enable_btop"

)

show_menu() {
    YELLOW="\e[33m"
    NO_COLOR="\e[0m"

    echo -e "${GREEN_LINE}"
    echo '
    ***********  DIY NAS 工具箱v1.1  ***************
    適配系統:deepin 20.9/v23 beta2(基於debian)
    腳本作用:快速部署一個辦公場景下的Diy NAS
    
            --- Made by wukong with YOU ---
    '
    echo -e "${GREEN_LINE}"
    echo "請選擇操作："

    for i in "${!menu_options[@]}"; do
        if [[ "${menu_options[i]}" == "設置虛擬機開機無頭自啟動" ]]; then
            echo -e "$((i + 1)). ${YELLOW}${menu_options[i]}${NO_COLOR}"
        else
            echo "$((i + 1)). ${menu_options[i]}"
        fi
    done
}

handle_choice() {
    local choice=$1

    if [ -z "${menu_options[$choice - 1]}" ] || [ -z "${commands[${menu_options[$choice - 1]}]}" ]; then
        echo "無效選項，請重新選擇。"
        return
    fi

    "${commands[${menu_options[$choice - 1]}]}"
}

# 主邏輯
while true; do
    show_menu
    read -p "請輸入選項的序號(輸入q退出): " choice
    if [[ $choice == 'q' ]]; then
        break
    fi
    handle_choice $choice
done
