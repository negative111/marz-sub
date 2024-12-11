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

# Загрузка файлов с проверкой на ошибки с помощью wget
wget -O "$base_dir/subscription/index.html" "https://github.com/cortez24rus/marz-sub/raw/main/index.html" || echo "Ошибка загрузки index.html"
wget -O "$base_dir/v2ray/default.json" "https://github.com/cortez24rus/marz-sub/raw/main/v2ray/default.json" || echo "Ошибка загрузки default.json"
wget -O "$base_dir/clash/default.yml" "https://github.com/cortez24rus/marz-sub/raw/main/clash/default.yml" || echo "Ошибка загрузки default.yml"
wget -O "$base_dir/clash/settings.yml" "https://github.com/cortez24rus/marz-sub/raw/main/clash/settings.yml" || echo "Ошибка загрузки settings.yml"
wget -O "$base_dir/singbox/default.json" "https://github.com/BLUEBL0B/Secret-Sing-Box/raw/main/Config-Examples-WS/Client-VLESS-WS.json" || echo "Ошибка загрузки Client-VLESS-WS.json"

# Получение переменных DOMAIN и SERVER-IP
DOMAIN=$(grep "XRAY_SUBSCRIPTION_URL_PREFIX" /opt/marzban/.env | cut -d '"' -f 2 | sed 's|https://||')
SERVER_IP=$(wget -qO- https://ipinfo.io/ip)


# Запрос пользовательской ссылки
read -p "Введите вашу Telegram ссылку, которая будет расположена на странице подписки (например, https://t.me/yourID): " tg_user_link

# Экранирование специальных символов для использования в sed
tg_escaped_link=$(echo "$tg_user_link" | sed 's/[&/\]/\\&/g')

# Замена ссылки в файле index.html
# Используем '#' в качестве разделителя для sed
sed -i "s#https://t.me/yourID#$tg_escaped_link#g" "$base_dir/subscription/index.html"

echo "Ссылка успешно обновлена в index.html"

env_file="/opt/marzban/.env"

# Обновление или добавление настроек в .env файл
update_or_add() {
    local key="$1"
    local value="$2"
    local file="$3"
    if grep -q "^#*$key=" "$file"; then
        # Строка существует, обновляем значение
        sed -i "s|^#*\($key=\).*|\1\"$value\"|" "$file"
    else
        # Строка не существует, добавляем ее
        echo "$key=\"$value\"" >> "$file"
    fi
}

# Обновление переменных конфигурации
update_or_add "CUSTOM_TEMPLATES_DIRECTORY" "/var/lib/marzban/templates/" "$env_file"
update_or_add "SUBSCRIPTION_PAGE_TEMPLATE" "subscription/index.html" "$env_file"
update_or_add "SINGBOX_SUBSCRIPTION_TEMPLATE" "singbox/default.json" "$env_file"
update_or_add "CLASH_SUBSCRIPTION_TEMPLATE" "clash/default.yml" "$env_file"
update_or_add "CLASH_SETTINGS_TEMPLATE" "clash/settings.yml" "$env_file"
update_or_add "V2RAY_SUBSCRIPTION_TEMPLATE" "v2ray/default.json" "$env_file"

echo "Обновление файла .env выполнено."

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

echo "Скрипт выполнен успешно."
echo "Не забудь перезапустить Marzban."