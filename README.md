# DNS-fix YouTube

**Набор для восстановления DNS YouTube**

Скрипт для Windows, который автоматически находит самый быстрый и рабочий DNS-сервер для доступа к YouTube, применяет его в системе и настраивает шифрование (DoH).

## Что он делает?
- Тестирует **популярные DNS-провайдеры** (Yandex, AdGuard, Quad9, Cloudflare, Google и другие).
- Проверяет работу как в обычном режиме (**UDP**), так и с шифрованием (**DoH**). **Не у всех есть шифрование!**
- Отсеивает подмену IP-адресов и NXDOMAIN (когда провайдер блокирует сайт).
- Автоматически выбирает **самый быстрый рабочий вариант** (с приоритетом на зашифрованный DoH).
- Применяет настройки к активному сетевому адаптеру и очищает DNS-кэш.

## Как запустить?
1. Скачайте файл из этого репозитория.
2. Запустите его.
3. Подождите пару минут, пока идёт тестирование всех серверов.
4. Скрипт сам выберет лучший DNS, применит его и покажет результат проверки.

*Примечание: После теста рядом со скриптом создастся лог-файл с результатами!*

## Дополнительные команды
Если запускать скрипт через командную строку, можно использовать аргументы:
- `-OnlyTest` — только протестировать все DNS и показать таблицу (ничего не меняя в системе).
- `-Reset` — вернуть автоматическое получение DNS.
- `-Provider <имя>` — протестировать и применить конкретный DNS (например, `-Provider adguard` или `-Provider yandex`).

*Пример: `DNS-fix.bat -OnlyTest`*

##  Что ещё нужно знать?
- **DoH (DNS over HTTPS)**: для включения шифрования требуется **Windows 11**. На Windows 10 скрипт всё равно подберёт лучший обычный DNS, но без шифрования.
- **Антивирусы**: некоторые антивирусы могут ругаться на bat-файлы, которые меняют настройки сети. Это нормально, скрипт ничего не ломает.

---
---

##  English Version

**YouTube DNS rescue kit**

A Windows script that automatically finds the fastest and most reliable DNS server for accessing YouTube, applies it to your system, and configures encryption (DoH).

### What it does?
- Tests **popular DNS providers** (Yandex, AdGuard, Quad9, Cloudflare, Google, and others).
- Checks both standard mode (**UDP**) and encrypted mode (**DoH**). **Not all providers support encryption!**
- Filters out IP spoofing and NXDOMAIN (when the provider blocks the website).
- Automatically selects the **fastest working option** (prioritizing encrypted DoH).
- Applies the settings to the active network adapter and flushes the DNS cache.

### How to run?
1. Download the file from this repository.
2. Run it.
3. Wait a couple of minutes while all servers are being tested.
4. The script will automatically select the best DNS, apply it, and show the test results.

*Note: After the test, a log file with the results will be created next to the script!*

### Additional commands
If you run the script via the command line, you can use the following arguments:
- `-OnlyTest` — test all DNS servers and show the table only (without changing anything in the system).
- `-Reset` — revert to automatic DNS (DHCP).
- `-Provider <name>` — test and apply a specific DNS provider (e.g., `-Provider adguard` or `-Provider yandex`).

*Example: `DNS-fix.bat -OnlyTest`*

###  What else you need to know
- **DoH (DNS over HTTPS)**: enabling encryption requires **Windows 11**. On Windows 10, the script will still find the best standard DNS, but without encryption.
- **Antiviruses**: some antiviruses may complain about bat-files that change network settings. This is normal; the script doesn't break anything.

---
*Create by Lampa-Popera*
