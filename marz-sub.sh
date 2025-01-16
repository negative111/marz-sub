#!/bin/bash

# Определение путей к директориям
base_dir="/var/lib/marzban/templates"
declare -a dirs=("singbox" "v2ray" "clash" "subscription")

# Создание директорий, если они не существуют
for dir in "${dirs[@]}"; do
  if [ ! -d "$base_dir/$dir" ]; then
    mkdir -p "$base_dir/$dir"
    echo "Создана директория: $base_dir/$dir"
  fi
done

# Загрузка шаблона подписки
while true; do
    echo "Выберите шаблон для скачивания:"
    echo "1) marz-sub fork by legiz (https://github.com/cortez24rus/marz-sub)"
    echo "2) marzbanify-template fork by legiz (https://github.com/legiz-ru/marzbanify-template)"
    read -p "Введите номер шаблона (1 или 2): " choice

    if [ "$choice" -eq 1 ]; then
        shablonurl="https://github.com/cortez24rus/marz-sub/raw/main/index.html"
        break
    elif [ "$choice" -eq 2 ]; then
        shablonurl="https://github.com/legiz-ru/marzbanify-template/raw/main/index.html"
        break
    else
        echo "Неверный выбор. Попробуйте снова."
    fi
done
wget -O "$base_dir/subscription/index.html" "$shablonurl" || echo "Ошибка загрузки index.html"

# Загрузка шаблона подписки для клиентов xray
wget -O "$base_dir/v2ray/default.json" "https://github.com/cortez24rus/marz-sub/raw/main/v2ray/default.json" || echo "Ошибка загрузки default.json"

# Загрузка шаблона подписки для клиентов mihomo (clash meta)
while true; do
    echo "Выберите шаблон clash meta для скачивания:"
    echo "1) ru-bundle by legiz (https://github.com/legiz-ru/marz-sub)"
    echo "2) template by Skrepysh (https://github.com/Skrepysh/tools/)"
    read -p "Введите номер шаблона (1 или 2): " choice

    if [ "$choice" -eq 1 ]; then
        mihomourl="https://github.com/cortez24rus/marz-sub/raw/main/clash/default.yml"
        break
    elif [ "$choice" -eq 2 ]; then
        mihomourl="https://github.com/Skrepysh/tools/raw/main/marzban-subscription-templates/clash-sub.yml"
        break
    else
        echo "Неверный выбор. Попробуйте снова."
    fi
done
wget -O "$base_dir/clash/default.yml" "$mihomourl" || echo "Ошибка загрузки default.yml"
wget -O "$base_dir/clash/settings.yml" "https://github.com/cortez24rus/marz-sub/raw/main/clash/settings.yml" || echo "Ошибка загрузки settings.yml"

# Загрузка шаблона подписки для клиентов sing-box
while true; do
    echo "Выберите шаблон sing-box для скачивания:"
    echo "1) Secret-Sing-Box template by BLUEBL0B"
    echo "2) template by Skrepysh (https://github.com/Skrepysh/tools/)"
    read -p "Введите номер шаблона (1 или 2): " choice

    if [ "$choice" -eq 1 ]; then
        wget -O "$base_dir/singbox/default.json" "https://github.com/BLUEBL0B/Secret-Sing-Box/raw/main/Config-Examples-WS/Client-VLESS-WS.json" || echo "Ошибка загрузки Client-VLESS-WS.json"
        # Получение переменных DOMAIN и SERVER-IP
        sleep 1
        DOMAIN=$(grep "XRAY_SUBSCRIPTION_URL_PREFIX" /opt/marzban/.env | cut -d '"' -f 2 | sed 's|https://||')
        sleep 1
        SERVER_IP=$(wget -qO- https://ipinfo.io/ip)
        sleep 1
        # Обновление файла default.json (на основе клиентского шаблона secret-sing-box) в директории singbox
jq --arg domain "$DOMAIN" --arg server_ip "$SERVER_IP" '
  .dns.servers[0].client_subnet = $server_ip |
  (.dns.rules[] | select(.domain_suffix? and (.domain_suffix | length > 0)) | .domain_suffix[4]) = $domain |
  (.route.rules[] | select(.domain_suffix? and (.domain_suffix | length > 0)) | .domain_suffix[4]) = $domain |
  (.route.rules[] | select(.ip_cidr? and (.ip_cidr | length > 0)) | .ip_cidr[0]) = $server_ip |
  .outbounds = [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    },
    {
      "type": "selector",
      "tag": "proxy",
      "outbounds": null
    },
    {
      "type": "urltest",
      "tag": "Fastest",
      "outbounds": null,
      "url": "https://www.gstatic.com/generate_204",
      "interval": "15m0s"
    },
    {
      "type": "dns",
      "tag": "dns-out"
    }
  ]
' "$base_dir/singbox/default.json" > "$base_dir/singbox/temp.json" && mv "$base_dir/singbox/temp.json" "$base_dir/singbox/default.json"
        break
    elif [ "$choice" -eq 2 ]; then
        wget -O "$base_dir/singbox/default.json" "https://github.com/Skrepysh/tools/raw/main/marzban-subscription-templates/sing-sub.json" || echo "Ошибка загрузки Client-VLESS-WS.json"
        break
    else
        echo "Неверный выбор. Попробуйте снова."
    fi
done


# Запрос пользовательской ссылки
read -p "Введите вашу Telegram ссылку, которая будет расположена на странице подписки (например, https://t.me/yourID): " tg_user_link

# Экранирование специальных символов для использования в sed
tg_escaped_link=$(echo "$tg_user_link" | sed 's/[&/\]/\\&/g')

# Замена ссылки в файле index.html
# Используем '#' в качестве разделителя для sed
sed -i "s#https://t.me/yourID#$tg_escaped_link#g" "$base_dir/subscription/index.html"

echo "Ссылка успешно обновлена в index.html"

# Обновление или добавление настроек в .env файл
env_file="/opt/marzban/.env"

# Обновление или добавление настроек в .env файл
update_or_add() {
local key="$1"
local value="$2"
local file="$3"

# Удаляем все возможные варианты строк с ключом (активные, закомментированные, с пробелами)
sed -i "/^\s#\s$key\s=\s.$/d" "$file"

# Добавляем новую строку в конец файла
echo "$key = \"$value\"" >> "$file"
}


# Обновление переменных конфигурации
update_or_add "CUSTOM_TEMPLATES_DIRECTORY" "/var/lib/marzban/templates/" "$env_file"
update_or_add "SUBSCRIPTION_PAGE_TEMPLATE" "subscription/index.html" "$env_file"
update_or_add "SINGBOX_SUBSCRIPTION_TEMPLATE" "singbox/default.json" "$env_file"
update_or_add "CLASH_SUBSCRIPTION_TEMPLATE" "clash/default.yml" "$env_file"
update_or_add "CLASH_SETTINGS_TEMPLATE" "clash/settings.yml" "$env_file"
update_or_add "V2RAY_SUBSCRIPTION_TEMPLATE" "v2ray/default.json" "$env_file"
update_or_add "SUB_SUPPORT_URL" "$tg_escaped_link" "$env_file"

echo "Обновление файла .env выполнено."



echo "Скрипт выполнен успешно."
echo "Не забудь перезапустить Marzban."
