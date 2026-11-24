# DNS-fix YouTube

**Набор для восстановления DNS YouTube**

Скрипт для Windows, который автоматически находит самый быстрый и рабочий DNS-сервер для доступа к сайтам, применяет его в системе и настраивает шифрование (DoH).

## Что он делает?
- Тестирует **популярные DNS-провайдеры** (Yandex, AdGuard, Quad9, Cloudflare, Google и другие).
- Проверяет работу как в обычном режиме (**UDP**), так и с шифрованием (**DoH**).
- Отсеивает подмену IP-адресов и NXDOMAIN (когда провайдер блокирует сайт).
- Показывает **Топ-3 лучших DNS** и позволяет выбрать нужный.
- Применяет настройки к активному сетевому адаптеру и очищает DNS-кэш.

## Структура проекта
- **`DNS-fix.bat`** — единый интерфейс программы. Спрашивает вашу версию Windows (10 или 11), режим тестирования (Быстрый или Расширенный) и цель (YouTube или свой домен). 
- **`core/engine.ps1`** — ядро программы, которое выполняет тесты и применяет настройки.
- **`modules/`** — базы DNS-серверов, разделенные под разные ОС. Для Windows 11 включены шаблоны DoH (шифрование), для Windows 10 — только обычный DNS.

## Как запустить?
1. Скачайте **архив** из раздела **Releases** и распакуйте его в любую папку.
2. Запустите **`DNS-fix.bat`**.
3. Выберите свою версию Windows и режим тестирования.
4. Подождите пару минут, выберите лучший DNS из предложенных (или нажмите Enter для авто-выбора).

## Что ещё нужно знать?
- **DoH (DNS over HTTPS)**: для включения шифрования требуется **Windows 11**. На Windows 10 скрипт подберёт лучший обычный DNS, но без шифрования.
- **Антивирусы**: некоторые антивирусы могут ругаться на bat-файлы, которые меняют настройки сети. Это нормально, скрипт ничего не ломает.

---
---

## English Version

**YouTube DNS rescue kit**

A Windows script that automatically finds the fastest and most reliable DNS server for accessing websites, applies it to your system, and configures encryption (DoH).

### What it does?
- Tests **popular DNS providers** (Yandex, AdGuard, Quad9, Cloudflare, Google, and others).
- Checks both standard mode (**UDP**) and encrypted mode (**DoH**).
- Filters out IP spoofing and NXDOMAIN (when the provider blocks the website).
- Shows the **Top-3 best DNS** options and lets you choose.
- Applies the settings to the active network adapter and flushes the DNS cache.

### Project structure
- **`DNS-fix.bat`** — the main interface. Asks for your Windows version (10 or 11), testing mode (Fast or Full), and target (YouTube or custom domain).
- **`core/engine.ps1`** — the core engine that performs tests and applies settings.
- **`modules/`** — DNS server databases split by OS. For Windows 11, DoH (encryption) templates are included; for Windows 10, only standard DNS.

### How to run?
1. Download the **archive** from the **Releases** section and extract it to any folder.
2. Run **`DNS-fix.bat`**.
3. Choose your Windows version and testing mode.
4. Wait a couple of minutes, choose the best DNS from the list (or press Enter for auto-selection).

### What else you need to know
- **DoH (DNS over HTTPS)**: enabling encryption requires **Windows 11**. On Windows 10, the script will find the best standard DNS, but without encryption.
- **Antiviruses**: some antiviruses may complain about bat-files that change network settings. This is normal; the script doesn't break anything.

---
*Create by Lampa-Popera*
