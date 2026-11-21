# DNS-fix YouTube

**Набор для восстановления DNS YouTube**

Скрипт для Windows, который автоматически находит самый быстрый и рабочий DNS-сервер для доступа к сайтам, применяет его в системе и настраивает шифрование (DoH).

## Что он делает?
- Тестирует **популярные DNS-провайдеры** (Yandex, AdGuard, Quad9, Cloudflare, Google и другие).
- Проверяет работу как в обычном режиме (**UDP**), так и с шифрованием (**DoH**). **Не у всех есть шифрование!**
- Отсеивает подмену IP-адресов и NXDOMAIN (когда провайдер блокирует сайт).
- Автоматически выбирает **самый быстрый рабочий вариант** (с приоритетом на зашифрованный DoH).
- **Позволяет выбрать один из Топ-3 лучших DNS** для применения.
- Применяет настройки к активному сетевому адаптеру и очищает DNS-кэш.

## Файлы в проекте
В релизе (вкладка Releases) доступны следующие файлы:
- **`DNS-fix (version).bat`** — основной скрипт. Тестирует DNS для YouTube, показывает Топ-3 лучших варианта и предлагает выбрать нужный.
- **`Custom DNS Tester.bat`** — скрипт для теста конкретного домена.
- **`Refund.bat`** — скрипт для отката. Возвращает автоматическое получение DNS (DHCP), если что-то пошло не так.

## Как запустить?
1. Скачайте нужный файл из раздела **Releases** (или прямо из репозитория).
2. Запустите его.
3. Подождите пару минут, пока идёт тестирование серверов.
4. Выберите лучший DNS из предложенных (или нажмите Enter для авто-выбора).

*Примечание: После теста рядом со скриптом создастся лог-файл с результатами!*

## Дополнительные команды
Если запускать основной скрипт через командную строку, можно использовать аргументы:
- `-OnlyTest` — только протестировать все DNS и показать таблицу (ничего не меняя в системе).
- `-Reset` — вернуть автоматическое получение DNS.
- `-Provider <имя>` — протестировать и применить конкретный DNS (например, `-Provider adguard`).
- `-Domain <сайт>` — проверить конкретный домен (например, `-Domain vk.com`).

*Пример: `DNS-fix 0.2.bat -OnlyTest`*

## Что ещё нужно знать?
- **DoH (DNS over HTTPS)**: для включения шифрования требуется **Windows 11**. На Windows 10 скрипт всё равно подберёт лучший обычный DNS, но без шифрования.
- **Антивирусы**: некоторые антивирусы могут ругаться на bat-файлы, которые меняют настройки сети. Это нормально, скрипт ничего не ломает.

---
---

##  English Version

**YouTube DNS rescue kit**

A Windows script that automatically finds the fastest and most reliable DNS server for accessing websites, applies it to your system, and configures encryption (DoH).

### What it does?
- Tests **popular DNS providers** (Yandex, AdGuard, Quad9, Cloudflare, Google, and others).
- Checks both standard mode (**UDP**) and encrypted mode (**DoH**). **Not all providers support encryption!**
- Filters out IP spoofing and NXDOMAIN (when the provider blocks the website).
- Automatically selects the **fastest working option** (prioritizing encrypted DoH).
- **Allows you to choose one of the Top-3 best DNS** options to apply.
- Applies the settings to the active network adapter and flushes the DNS cache.

### Files in the project
The release (Releases tab) includes the following files:
- **`DNS-fix 0.2.bat`** — the main script. Tests DNS for YouTube, shows the Top-3 best options, and lets you choose.
- **`Custom DNS Tester.bat`** — script for testing a specific domain.
- **`Refund.bat`** — rollback script. Reverts to automatic DNS (DHCP) if something goes wrong.

### How to run?
1. Download the required file from the **Releases** section (or directly from the repository).
2. Run it.
3. Wait a couple of minutes while the servers are being tested.
4. Choose the best DNS from the list (or press Enter for auto-selection).

*Note: After the test, a log file with the results will be created next to the script!*

### Additional commands
If you run the main script via the command line, you can use the following arguments:
- `-OnlyTest` — test all DNS servers and show the table only (without changing anything in the system).
- `-Reset` — revert to automatic DNS (DHCP).
- `-Provider <name>` — test and apply a specific DNS provider (e.g., `-Provider adguard`).
- `-Domain <site>` — test a specific domain (e.g., `-Domain vk.com`).

*Example: `DNS-fix 0.2.bat -OnlyTest`*

### What else you need to know
- **DoH (DNS over HTTPS)**: enabling encryption requires **Windows 11**. On Windows 10, the script will still find the best standard DNS, but without encryption.
- **Antiviruses**: some antiviruses may complain about bat-files that change network settings. This is normal; the script doesn't break anything.

---
*Create by Lampa-Popera*
