#!/bin/bash

# Цветовая схема
GREEN='\033[0;32m'    # Нормальный отклик
YELLOW='\033[0;33m'   # Медленный отклик
RED='\033[0;31m'      # Нет ответа
CYAN='\033[0;36m'     # Имена хостов
BLUE='\033[0;34m'     # Заголовки
NC='\033[0m'          # Сброс цвета

# Порог медленного соединения (мс)
SLOW_THRESHOLD=200

# Быстрая проверка (1 пакет, timeout=5s)
fast_check() {
    local client=$1
    echo -n -e "${CYAN}${client}${NC}... "
    local ping_result=$(ping -c 1 -W 5 "$client" 2>&1)
    if echo "$ping_result" | grep -q "time="; then
        local ping_time=$(echo "$ping_result" | grep -oP 'time=\K\d+\.?\d*')
        if (( $(echo "$ping_time > $SLOW_THRESHOLD" | bc -l) )); then
            echo -e "${YELLOW}${ping_time} ms (медленно)${NC}"
        else
            echo -e "${GREEN}${ping_time} ms${NC}"
        fi
    else
        echo -e "${RED}НЕТ ОТВЕТА${NC}"
    fi
}

# Детальная проверка (3 пакета, timeout=10s)
detailed_check() {
    local client=$1
    echo -n -e "${CYAN}${client}${NC}... "
    local ping_result=$(ping -c 3 -W 10 "$client" 2>&1)
    if echo "$ping_result" | grep -q "time="; then
        local avg_time=$(echo "$ping_result" | grep -oP 'time=\K\d+\.?\d*' | \
              awk '{sum+=$1; count++} END {printf "%.1f", sum/count}')
        if (( $(echo "$avg_time > $SLOW_THRESHOLD" | bc -l) )); then
            echo -e "${YELLOW}${avg_time} ms (медленно)${NC}"
        else
            echo -e "${GREEN}${avg_time} ms${NC}"
        fi
    elif echo "$ping_result" | grep -q "100% packet loss"; then
        echo -e "${RED}НЕТ ОТВЕТА${NC}"
    else
        echo -e "${YELLOW}ОШИБКА СВЯЗИ${NC}"
    fi
}

# --- Интерфейс ---
echo -e "${BLUE}"
echo "Мониторинг клиентов OpenVPN"
echo "---------------------------"
echo -e "${NC}"

echo -e "1. ${CYAN}Быстрая проверка${NC} (1 пакет, timeout=5s)"
echo -e "2. ${CYAN}Детальная проверка${NC} (3 пакета, анализ задержек)"
echo -e "3. ${CYAN}Выход${NC}"
echo -e "${BLUE}---------------------------${NC}"

# Выбор режима
while true; do
    read -p "Выберите режим [1-3]: " mode
    case $mode in
        1|2) break;;
        3) exit 0;;
        *) echo -e "${RED}Неверный выбор${NC}";;
    esac
done

# Получение списка клиентов
clients=$(grep -i client_list /etc/openvpn/server/openvpn-status.log \
         | tr ',' ' ' \
         | awk '$4 != "Name" {print $4}' \
         | sort -nk1)

# Проверка
start_time=$(date +%s)
echo -e "${BLUE}\nНачало проверки...${NC}"

for client in $clients; do
    if [ "$mode" == "1" ]; then
        fast_check "$client"
    else
        detailed_check "$client"
    fi
done

# Итоги
end_time=$(date +%s)
echo -e "${BLUE}---------------------------${NC}"
echo -e "Проверено: ${CYAN}$(echo "$clients" | wc -l)${NC} хостов"
echo -e "Время выполнения: ${CYAN}$((end_time - start_time))${NC} секунд"
