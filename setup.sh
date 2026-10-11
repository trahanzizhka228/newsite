
#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# TG Shop Bridge — scaffolding Этапа 1
# Создаёт дерево проекта и все файлы.
# Запуск:  bash setup.sh
# ============================================================

ROOT="$(pwd)"
PLUGIN="$ROOT/wordpress-plugin/tg-shop-bridge"
MINI="$ROOT/miniapp"

echo "→ Создаю дерево каталогов…"
mkdir -p "$ROOT/docs"
mkdir -p "$PLUGIN/includes"
mkdir -p "$PLUGIN/assets/miniapp"
mkdir -p "$PLUGIN/tests"
mkdir -p "$MINI/src/api" "$MINI/src/config" "$MINI/src/telegram" "$MINI/src/types" "$MINI/src/components"
mkdir -p "$MINI/public"

# ---------- корневые файлы ----------

cat > "$ROOT/.gitignore" <<'EOF'
# Node / Vite
node_modules/
miniapp/dist/
*.log
npm-debug.log*
yarn-error.log*
pnpm-debug.log*

# Vite build → плагин
wordpress-plugin/tg-shop-bridge/assets/miniapp/*
!wordpress-plugin/tg-shop-bridge/assets/miniapp/.gitkeep

# Env
.env
.env.local
.env.*.local
!.env.example

# IDE / OS
.idea/
.vscode/
.DS_Store
Thumbs.db
*.swp

# WP
wp-content/uploads/
wp-config.php

# Composer (на будущее)
vendor/
composer.lock
EOF

cat > "$ROOT/.env.example" <<'EOF'
# ============================================================
# Этот файл относится ТОЛЬКО к Mini App (Vite, префикс VITE_).
# Секреты бота НЕ ХРАНЯТСЯ здесь и НЕ попадают в JS.
# Они задаются на сервере в wp-config.php (см. docs/SECURITY.md).
# ============================================================

# Публичный базовый URL REST API плагина.
# Пример: https://example.com/wp-json/tg-shop/v1
# Если пусто — Mini App использует тот же origin, что и страница WordPress.
VITE_API_BASE=

# Demo-режим для локальной разработки БЕЗ WordPress.
# Работает ТОЛЬКО при `npm run dev` (import.meta.env.DEV === true).
# В production build этот флаг игнорируется.
VITE_DEMO_MODE=false
EOF

cat > "$ROOT/README.md" <<'EOF'
# TG Shop Bridge

Интернет-магазин физических товаров:
WordPress + WooCommerce (каталог, цены, заказы) + Telegram-бот и Mini App.

Источник правды — **WooCommerce**. Mini App только читает каталог через REST API плагина.

## Что реализовано в Этапе 1

- WordPress-плагин `TG Shop Bridge` с read-only REST-каталогом и Telegram webhook.
- Shortcode `[tg_shop_mini_app]` — точка монтирования React-приложения.
- React + TypeScript + Vite Mini App: каталог, состояния загрузки/ошибки/пустого списка, тема Telegram.
- Проверка `X-Telegram-Bot-Api-Secret-Token` и дедупликация `update_id` на webhook.
- Команды `/start` и `/help`, инлайн-кнопка открытия Mini App (если задан URL).
- Документация: `docs/ARCHITECTURE.md`, `docs/SECURITY.md`, `docs/ROADMAP.md`.

Не реализовано намеренно: корзина, заказы, оплата, авторизация по Telegram `initData`, промокоды — см. ROADMAP.

---

## 1. Установка WordPress-плагина

1. Скопируйте каталог `wordpress-plugin/tg-shop-bridge/` в
   `wp-content/plugins/` вашего сайта.
2. Установите и активируйте **WooCommerce**.
3. Активируйте плагин **TG Shop Bridge** в админке WordPress.
4. Проверьте, что API отвечает:

   ```
   GET https://<ваш-домен>/wp-json/tg-shop/v1/health
   ```

   Ожидаемый JSON: `{"ok":true,"plugin":"tg-shop-bridge","version":"0.1.0","woo":true}`.

   Если `"woo": false` — WooCommerce не активирован, каталог работать не будет.

---

## 2. Настройка серверных констант (`wp-config.php`)

Секреты задаются **только** на сервере. Добавьте в `wp-config.php` **до** строки
`/* That's all, stop editing! */`:

```php
// Токен бота из @BotFather. НИКОГДА не коммитить.
define( 'TG_SHOP_BOT_TOKEN', 'сюда-вставьте-токен-локально' );

// Случайная строка 32+ символов, которую вы передаёте в setWebhook.
// Пример генерации: openssl rand -hex 32
define( 'TG_SHOP_WEBHOOK_SECRET', 'сюда-вставьте-случайный-секрет' );

// Публичный URL страницы с shortcode [tg_shop_mini_app].
// Именно этот URL открывается по кнопке web_app в боте.
define( 'TG_SHOP_MINIAPP_URL', 'https://example.com/shop/' );

// (опционально) Максимальный возраст auth_date initData, сек. По умолчанию 600.
// define( 'TG_SHOP_INITDATA_MAX_AGE', 600 );
```

---

## 3. Сборка Mini App

```bash
cd miniapp
cp ../.env.example .env.local      # отредактируйте VITE_API_BASE при необходимости
npm install
npm run typecheck
npm run lint
npm run build
```

`npm run build` складывает статику в
`wordpress-plugin/tg-shop-bridge/assets/miniapp/` вместе с `manifest.json`.
Плагин сам находит точные имена файлов и подключает их — **руками HTML править не нужно**.

---

## 4. Страница Mini App

1. В админке WordPress создайте страницу, например «Магазин».
2. Вставьте в неё shortcode:

   ```
   [tg_shop_mini_app]
   ```

3. Опубликуйте. Скопируйте URL этой страницы.
4. Пропишите этот URL в `wp-config.php` как `TG_SHOP_MINIAPP_URL` (см. шаг 2).
   URL должен быть **https** — Telegram не открывает http-адреса Mini App.

Откройте страницу в браузере. Если вне Telegram — увидите каталог и подсказку,
что полный функционал доступен из бота.

---

## 5. Регистрация webhook в Telegram

> `setWebhook` **не вызывается автоматически**. Выполните один раз вручную.

Подставьте ваш домен, токен и тот же секрет, что в `TG_SHOP_WEBHOOK_SECRET`:

```bash
BOT_TOKEN="вставьте-токен"
SECRET="вставьте-тот-же-секрет"
URL="https://example.com/wp-json/tg-shop/v1/telegram/webhook"

curl -sS "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook" \
  -H 'Content-Type: application/json' \
  -d "{
    \"url\": \"${URL}\",
    \"secret_token\": \"${SECRET}\",
    \"allowed_updates\": [\"message\"]
  }"
```

Проверка:

```bash
curl -sS "https://api.telegram.org/bot${BOT_TOKEN}/getWebhookInfo"
```

Удаление webhook (при отладке):

```bash
curl -sS "https://api.telegram.org/bot${BOT_TOKEN}/deleteWebhook"
```

---

## 6. Проверка бота

В Telegram найдите бота, отправьте:

- `/start` → приветствие и кнопка «Открыть каталог» (если `TG_SHOP_MINIAPP_URL` задан).
- `/help` → список команд.

Если URL Mini App не задан, бот вернёт сообщение без кнопки — это ожидаемое поведение.

---

## 7. Проверки

```bash
php -l wordpress-plugin/tg-shop-bridge/tg-shop-bridge.php
find wordpress-plugin/tg-shop-bridge/includes -name '*.php' -exec php -l {} \;
php wordpress-plugin/tg-shop-bridge/tests/run.php

cd miniapp
npm install
npm run typecheck
npm run lint
npm run build
```

## 8. Следующий этап

Этап 2 — безопасная проверка Telegram `initData` на сервере и связывание
WordPress-покупателя с Telegram ID через одноразовый код. См. `docs/ROADMAP.md`.
EOF

cat > "$ROOT/AGENTS.md" <<'EOF'
# AGENTS.md — инструкции для будущих агентов

## Роль проекта

Интернет-магазин физических товаров. Источник правды — **WooCommerce**.
Telegram Mini App и бот — только фасад над REST API WordPress-плагина.

## Жёсткие правила

1. **WooCommerce — единственный источник** товаров, цен, остатков, купонов, заказов.
2. **Никаких секретов** в JS, HTML, логах, Git, browser storage. Только wp-config.php.
3. **Не доверяй** `initDataUnsafe`. Проверять оригинальную `initData` на сервере.
4. **Никакой доставки** — только самовывоз/личная передача.
5. **Никаких платёжных данных** на своей стороне.
6. **Публичные REST** — только read-only, с пагинацией и лимитом полей.
7. **Изменения цен/заказов** — только серверные, через WooCommerce CRUD/API.
8. `hash_equals` для секретов, экранирование вывода, подготовленные запросы.

## Команды проверки

```bash
php -l wordpress-plugin/tg-shop-bridge/tg-shop-bridge.php
find wordpress-plugin/tg-shop-bridge/includes -name '*.php' -exec php -l {} \;
php wordpress-plugin/tg-shop-bridge/tests/run.php
cd miniapp && npm install && npm run typecheck && npm run lint && npm run build
```

## Стиль

- PHP: PSR-12-подобный, префиксы `TG_Shop_*`, файлы `class-*.php`.
- TS: strict, без `any`, тексты интерфейса — на русском.
EOF

# ---------- docs ----------

cat > "$ROOT/docs/ARCHITECTURE.md" <<'EOF'
# Архитектура

## Компоненты

```
Telegram  ──webhook──▶  WP REST /tg-shop/v1/telegram/webhook
   ▲                              │
   │                              ▼
Mini App  ──fetch──▶  WP REST /tg-shop/v1/products
                                   │
                                   ▼
                              WooCommerce CRUD
```

- Mini App — статика (`assets/miniapp/` внутри плагина).
- REST-эндпоинты — внутри WordPress, namespace `tg-shop/v1`.
- Webhook — там же.

## Данные

WooCommerce — единственный источник. Плагин не создаёт своих таблиц каталога/заказов.

## REST API (Этап 1)

| Метод | Путь                | Доступ     | Назначение                      |
|-------|---------------------|------------|---------------------------------|
| GET   | `/health`           | публично   | Диагностика                     |
| GET   | `/products`         | публично   | Список товаров, пагинация       |
| GET   | `/products/<id>`    | публично   | Карточка опубликованного товара |
| POST  | `/telegram/webhook` | секрет     | Приём обновлений Telegram       |

Пагинация: `page` ≥1, `per_page` 1..50 (по умолчанию 20).
Публикуются только товары со статусом `publish`.

## Shortcode

`[tg_shop_mini_app]` рендерит `<div id="tg-shop-miniapp-root">` и подключает
`assets/miniapp/manifest.json` (Vite) → точный JS-вход и CSS. Ручной правки
сгенерированного HTML не требуется.

## Безопасность (кратко)

См. `docs/SECURITY.md`.
EOF

cat > "$ROOT/docs/SECURITY.md" <<'EOF'
# Безопасность

## Обязательно перед публикацией

1. HTTPS на сайте и на URL Mini App.
2. В `wp-config.php` заданы `TG_SHOP_BOT_TOKEN`, `TG_SHOP_WEBHOOK_SECRET`,
   `TG_SHOP_MINIAPP_URL`.
3. `secret_token` при `setWebhook` **побайтово совпадает** с `TG_SHOP_WEBHOOK_SECRET`.
4. `WP_DEBUG_DISPLAY=false` на проде, `debug.log` не в web-root.
5. Плагин недоступен на запись веб-сервером.

## Что плагин НЕ делает

- Не хранит секреты в БД/JS/Git.
- Не отключает TLS-проверки.
- Не публикует черновики/приватные товары/метаданные заказов.
- Не принимает webhook без секрета (в production-режиме).
- Не делает `setWebhook` автоматически.
- Не использует `initDataUnsafe` как подтверждённую идентичность.

## Модель угроз Этапа 1

| Угроза                        | Мера                                                       |
|-------------------------------|------------------------------------------------------------|
| Подделка webhook              | secret header + `hash_equals`, отказ без секрета           |
| Replay webhook                | дедупликация `update_id` (transient, TTL 1 ч)              |
| Большой payload               | лимит тела 64 КБ                                           |
| Сканирование приватных товаров| фильтр `status = publish`                                  |
| Утечка секрета на фронтенд    | секреты только в wp-config.php                             |
| DoS на публичный каталог      | `per_page ≤ 50`, внешний кэш по усмотрению                 |
| Подмена `user.id` в Mini App  | на Этапе 1 идентичность не используется; Этап 2 — сервер   |

## Проверка initData (Этап 2) — план

1. `data_check_string` = сортировка `key=value` через `\n`, кроме `hash`.
2. `secret_key = HMAC_SHA256(bot_token, key="WebAppData")`.
3. `computed = HMAC_SHA256(data_check_string, key=secret_key)`.
4. Сравнение с `hash` через `hash_equals`.
5. `auth_date` не старше `TG_SHOP_INITDATA_MAX_AGE` секунд (по умолчанию 600).

## Логирование

Логируем только код ответа, тип события, `update_id`.
Никогда: `bot_token`, `webhook_secret`, полный `initData`, телефоны, email, ФИО.

## Ограничения MVP

- Публичный каталог доступен без авторизации (так задумано).
- Полная защита от мошенничества — Этапы 4–6.
EOF

cat > "$ROOT/docs/ROADMAP.md" <<'EOF'
# Дорожная карта

## Этап 1 (текущий) — каркас и каталог
- [x] Структура, документация, `.env.example`, `.gitignore`.
- [x] Плагин `TG Shop Bridge` с bootstrap и конфигом.
- [x] REST: `/health`, `/products`, `/products/<id>`.
- [x] Webhook с проверкой секрета и команд `/start`, `/help`.
- [x] Shortcode `[tg_shop_mini_app]`.
- [x] React + TS + Vite Mini App.
- [x] Простые PHP-тесты.

## Этап 2 — безопасная авторизация
- Проверка `initData` (HMAC, `auth_date`).
- Связывание Telegram ID ↔ WP customer одноразовым кодом.
- Серверная сессия для Mini App.

## Этап 3 — корзина и оформление
- Корзина на сервере, расчёт итогов только на сервере.
- Создание заказа через `wc_create_order`.
- Способ получения: самовывоз/личная передача.

## Этап 4 — купоны и антифрод
- Встроенные купоны WooCommerce, ограничения по сроку/лимитам/покупателю.
- Проверка и применение — только сервер.
- Идемпотентность при параллельных попытках.

## Этап 5 — история и уведомления
- Общая история заказов (источник — WooCommerce).
- Проверка принадлежности заказа пользователю.
- Уведомления в Telegram.

## Этап 6 — запуск
- Нагрузочные, безопасностные тесты, резервное копирование.
EOF

# ---------- wordpress-plugin ----------

cat > "$PLUGIN/tg-shop-bridge.php" <<'EOF'
<?php
/**
 * Plugin Name:       TG Shop Bridge
 * Plugin URI:        https://example.com/tg-shop-bridge
 * Description:       REST API каталога WooCommerce (read-only) и интеграция с Telegram (webhook, Mini App).
 * Version:           0.1.0
 * Requires at least: 6.0
 * Requires PHP:      7.4
 * Author:            TG Shop
 * License:           GPL-2.0-or-later
 * License URI:       https://www.gnu.org/licenses/gpl-2.0.html
 * Text Domain:       tg-shop-bridge
 *
 * @package TG_Shop_Bridge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

define( 'TG_SHOP_BRIDGE_VERSION', '0.1.0' );
define( 'TG_SHOP_BRIDGE_FILE', __FILE__ );
define( 'TG_SHOP_BRIDGE_DIR', plugin_dir_path( __FILE__ ) );
define( 'TG_SHOP_BRIDGE_URL', plugin_dir_url( __FILE__ ) );

require_once TG_SHOP_BRIDGE_DIR . 'includes/class-tg-shop-bridge.php';

register_activation_hook( __FILE__, array( 'TG_Shop_Bridge', 'activate' ) );
register_deactivation_hook( __FILE__, array( 'TG_Shop_Bridge', 'deactivate' ) );

add_action( 'plugins_loaded', array( 'TG_Shop_Bridge', 'init' ) );
EOF

cat > "$PLUGIN/readme.txt" <<'EOF'
=== TG Shop Bridge ===
Contributors: tgshop
Tags: woocommerce, telegram, mini app, rest api, webhook
Requires at least: 6.0
Tested up to: 6.6
Requires PHP: 7.4
Stable tag: 0.1.0
License: GPLv2 or later
License URI: https://www.gnu.org/licenses/gpl-2.0.html

REST API каталога WooCommerce (read-only) и Telegram webhook + Mini App.

== Description ==

Плагин предоставляет:
* Публичный read-only REST API опубликованных товаров WooCommerce.
* Webhook Telegram с проверкой секрета и командами /start и /help.
* Shortcode [tg_shop_mini_app] для монтирования React Mini App.

Секреты задаются в wp-config.php:
TG_SHOP_BOT_TOKEN, TG_SHOP_WEBHOOK_SECRET, TG_SHOP_MINIAPP_URL.

== Installation ==

1. Установите и активируйте WooCommerce.
2. Скопируйте плагин в wp-content/plugins/tg-shop-bridge/ и активируйте.
3. Соберите Mini App: cd miniapp && npm install && npm run build.
4. Создайте страницу со shortcode [tg_shop_mini_app].
5. Зарегистрируйте webhook через Telegram Bot API.

== Changelog ==

= 0.1.0 =
* Первый выпуск.
EOF

cat > "$PLUGIN/assets/miniapp/.gitkeep" <<'EOF'
# Здесь будет сборка Vite (manifest.json, assets/*.js, assets/*.css).
EOF

cat > "$PLUGIN/includes/index.php" <<'EOF'
<?php
// Silence is golden.
EOF

cat > "$PLUGIN/includes/class-tg-shop-bridge.php" <<'EOF'
<?php
/**
 * Основной класс плагина.
 *
 * @package TG_Shop_Bridge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

final class TG_Shop_Bridge {

	const REST_NAMESPACE = 'tg-shop/v1';

	public static function init() {
		load_plugin_textdomain(
			'tg-shop-bridge',
			false,
			dirname( plugin_basename( TG_SHOP_BRIDGE_FILE ) ) . '/languages'
		);

		require_once TG_SHOP_BRIDGE_DIR . 'includes/class-config.php';
		require_once TG_SHOP_BRIDGE_DIR . 'includes/class-telegram-api.php';
		require_once TG_SHOP_BRIDGE_DIR . 'includes/class-update-dedupe.php';
		require_once TG_SHOP_BRIDGE_DIR . 'includes/class-rest-catalog.php';
		require_once TG_SHOP_BRIDGE_DIR . 'includes/class-rest-telegram.php';
		require_once TG_SHOP_BRIDGE_DIR . 'includes/class-shortcode.php';

		add_action( 'rest_api_init', array( 'TG_Shop_REST_Catalog', 'register_routes' ) );
		add_action( 'rest_api_init', array( 'TG_Shop_REST_Telegram', 'register_routes' ) );
		add_action( 'init', array( 'TG_Shop_Shortcode', 'register' ) );
		add_action( 'admin_notices', array( __CLASS__, 'maybe_show_woocommerce_notice' ) );
	}

	public static function activate() {}

	public static function deactivate() {}

	public static function woo_active() {
		return class_exists( 'WooCommerce' );
	}

	public static function maybe_show_woocommerce_notice() {
		if ( self::woo_active() ) {
			return;
		}
		if ( ! current_user_can( 'activate_plugins' ) ) {
			return;
		}
		echo '<div class="notice notice-warning"><p>';
		echo esc_html__(
			'TG Shop Bridge: WooCommerce не активен. Каталог и REST API товаров будут недоступны, пока WooCommerce не установлен и не активирован.',
			'tg-shop-bridge'
		);
		echo '</p></div>';
	}
}
EOF

cat > "$PLUGIN/includes/class-config.php" <<'EOF'
<?php
/**
 * Чтение серверных констант из wp-config.php.
 *
 * @package TG_Shop_Bridge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

final class TG_Shop_Config {

	public static function bot_token() {
		return defined( 'TG_SHOP_BOT_TOKEN' ) ? (string) TG_SHOP_BOT_TOKEN : '';
	}

	public static function webhook_secret() {
		return defined( 'TG_SHOP_WEBHOOK_SECRET' ) ? (string) TG_SHOP_WEBHOOK_SECRET : '';
	}

	public static function miniapp_url() {
		return defined( 'TG_SHOP_MINIAPP_URL' ) ? (string) TG_SHOP_MINIAPP_URL : '';
	}

	public static function init_data_max_age() {
		if ( defined( 'TG_SHOP_INITDATA_MAX_AGE' ) ) {
			return max( 30, (int) TG_SHOP_INITDATA_MAX_AGE );
		}
		return 600;
	}
}
EOF

cat > "$PLUGIN/includes/class-telegram-api.php" <<'EOF'
<?php
/**
 * Обёртка над Telegram Bot API.
 *
 * @package TG_Shop_Bridge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

final class TG_Shop_Telegram_API {

	const API_BASE = 'https://api.telegram.org';

	public static function send_message( $chat_id, $text, $reply_markup = null ) {
		$token = TG_Shop_Config::bot_token();
		if ( $token === '' ) {
			return false;
		}

		$payload = array(
			'chat_id' => (int) $chat_id,
			'text'    => (string) $text,
		);
		if ( is_array( $reply_markup ) ) {
			$payload['reply_markup'] = wp_json_encode( $reply_markup );
		}

		$url = self::API_BASE . '/bot' . rawurlencode( $token ) . '/sendMessage';

		$response = wp_remote_post(
			$url,
			array(
				'timeout' => 10,
				'headers' => array( 'Content-Type' => 'application/json' ),
				'body'    => wp_json_encode( $payload ),
			)
		);

		if ( is_wp_error( $response ) ) {
			error_log( '[tg-shop-bridge] sendMessage WP_Error: ' . $response->get_error_code() );
			return false;
		}

		$code = (int) wp_remote_retrieve_response_code( $response );
		if ( $code < 200 || $code >= 300 ) {
			error_log( '[tg-shop-bridge] sendMessage HTTP ' . $code );
			return false;
		}

		return true;
	}
}
EOF

cat > "$PLUGIN/includes/class-update-dedupe.php" <<'EOF'
<?php
/**
 * Дедупликация Telegram update_id через транзиенты.
 *
 * @package TG_Shop_Bridge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

final class TG_Shop_Update_Dedupe {

	const TTL = 3600;

	public static function seen( $update_id ) {
		$update_id = (int) $update_id;
		if ( $update_id <= 0 ) {
			return false;
		}
		$key = 'tg_shop_upd_' . $update_id;
		if ( get_transient( $key ) ) {
			return true;
		}
		set_transient( $key, 1, self::TTL );
		return false;
	}
}
EOF

cat > "$PLUGIN/includes/class-rest-catalog.php" <<'EOF'
<?php
/**
 * Публичный read-only REST для каталога.
 *
 * @package TG_Shop_Bridge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

final class TG_Shop_REST_Catalog {

	const MAX_PER_PAGE     = 50;
	const DEFAULT_PER_PAGE = 20;

	public static function register_routes() {
		register_rest_route(
			TG_Shop_Bridge::REST_NAMESPACE,
			'/health',
			array(
				'methods'             => WP_REST_Server::READABLE,
				'callback'            => array( __CLASS__, 'health' ),
				'permission_callback' => '__return_true',
			)
		);

		register_rest_route(
			TG_Shop_Bridge::REST_NAMESPACE,
			'/products',
			array(
				'methods'             => WP_REST_Server::READABLE,
				'callback'            => array( __CLASS__, 'list_products' ),
				'permission_callback' => '__return_true',
				'args'                => array(
					'page'     => array( 'type' => 'integer', 'default' => 1, 'minimum' => 1 ),
					'per_page' => array( 'type' => 'integer', 'default' => self::DEFAULT_PER_PAGE, 'minimum' => 1, 'maximum' => self::MAX_PER_PAGE ),
					'search'   => array( 'type' => 'string', 'default' => '' ),
				),
			)
		);

		register_rest_route(
			TG_Shop_Bridge::REST_NAMESPACE,
			'/products/(?P<id>\d+)',
			array(
				'methods'             => WP_REST_Server::READABLE,
				'callback'            => array( __CLASS__, 'get_product' ),
				'permission_callback' => '__return_true',
				'args'                => array(
					'id' => array( 'type' => 'integer', 'required' => true, 'minimum' => 1 ),
				),
			)
		);
	}

	public static function health() {
		return new WP_REST_Response(
			array(
				'ok'      => true,
				'plugin'  => 'tg-shop-bridge',
				'version' => TG_SHOP_BRIDGE_VERSION,
				'woo'     => TG_Shop_Bridge::woo_active(),
			),
			200
		);
	}

	public static function list_products( WP_REST_Request $request ) {
		if ( ! TG_Shop_Bridge::woo_active() ) {
			return new WP_Error( 'tg_shop_no_woo', 'WooCommerce не активен.', array( 'status' => 503 ) );
		}

		$page     = (int) $request->get_param( 'page' );
		$per_page = (int) $request->get_param( 'per_page' );
		$search   = (string) $request->get_param( 'search' );

		$args = array(
			'status'   => 'publish',
			'limit'    => $per_page,
			'page'     => $page,
			'paginate' => true,
			'orderby'  => 'date',
			'order'    => 'DESC',
			'return'   => 'objects',
		);
		if ( $search !== '' ) {
			$args['s'] = $search;
		}

		$query = wc_get_products( $args );

		$items = array();
		if ( is_object( $query ) && isset( $query->products ) && is_array( $query->products ) ) {
			foreach ( $query->products as $product ) {
				$items[] = self::format_product( $product );
			}
		}

		return new WP_REST_Response(
			array(
				'page'        => $page,
				'per_page'    => $per_page,
				'total'       => isset( $query->total ) ? (int) $query->total : count( $items ),
				'total_pages' => isset( $query->max_num_pages ) ? (int) $query->max_num_pages : 1,
				'items'       => $items,
			),
			200
		);
	}

	public static function get_product( WP_REST_Request $request ) {
		if ( ! TG_Shop_Bridge::woo_active() ) {
			return new WP_Error( 'tg_shop_no_woo', 'WooCommerce не активен.', array( 'status' => 503 ) );
		}

		$id      = (int) $request->get_param( 'id' );
		$product = wc_get_product( $id );

		if ( ! $product || $product->get_status() !== 'publish' ) {
			return new WP_Error( 'tg_shop_not_found', 'Товар не найден.', array( 'status' => 404 ) );
		}

		return new WP_REST_Response( self::format_product( $product ), 200 );
	}

	private static function format_product( $product ) {
		$image_id  = (int) $product->get_image_id();
		$image_url = $image_id ? (string) wp_get_attachment_image_url( $image_id, 'medium' ) : '';

		if ( $image_url === '' && function_exists( 'wc_placeholder_img_src' ) ) {
			$image_url = (string) wc_placeholder_img_src( 'medium' );
		}

		return array(
			'id'                => (int) $product->get_id(),
			'name'              => (string) $product->get_name(),
			'short_description' => wp_strip_all_tags( (string) $product->get_short_description() ),
			'price'             => (string) $product->get_price(),
			'currency'          => function_exists( 'get_woocommerce_currency' ) ? (string) get_woocommerce_currency() : '',
			'image'             => $image_url !== '' ? esc_url_raw( $image_url ) : '',
			'in_stock'          => (bool) $product->is_in_stock(),
			'purchasable'       => (bool) $product->is_purchasable(),
			'permalink'         => (string) get_permalink( $product->get_id() ),
		);
	}
}
EOF

cat > "$PLUGIN/includes/class-rest-telegram.php" <<'EOF'
<?php
/**
 * Webhook Telegram Bot API.
 *
 * @package TG_Shop_Bridge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

final class TG_Shop_REST_Telegram {

	const MAX_BODY_BYTES = 65536;

	public static function register_routes() {
		register_rest_route(
			TG_Shop_Bridge::REST_NAMESPACE,
			'/telegram/webhook',
			array(
				'methods'             => WP_REST_Server::CREATABLE,
				'callback'            => array( __CLASS__, 'handle' ),
				'permission_callback' => array( __CLASS__, 'check_secret' ),
			)
		);
	}

	public static function check_secret( WP_REST_Request $request ) {
		$expected = TG_Shop_Config::webhook_secret();

		if ( $expected === '' ) {
			return new WP_Error( 'tg_shop_no_secret', 'Webhook secret не настроен на сервере.', array( 'status' => 503 ) );
		}

		$got = (string) $request->get_header( 'x-telegram-bot-api-secret-token' );
		if ( $got === '' || ! hash_equals( $expected, $got ) ) {
			return new WP_Error( 'tg_shop_forbidden', 'Forbidden', array( 'status' => 403 ) );
		}

		if ( strlen( (string) $request->get_body() ) > self::MAX_BODY_BYTES ) {
			return new WP_Error( 'tg_shop_too_large', 'Payload too large', array( 'status' => 413 ) );
		}

		return true;
	}

	public static function handle( WP_REST_Request $request ) {
		$body = $request->get_json_params();
		if ( ! is_array( $body ) ) {
			return new WP_REST_Response( array( 'ok' => true ), 200 );
		}

		$update_id = isset( $body['update_id'] ) ? (int) $body['update_id'] : 0;
		if ( $update_id > 0 && TG_Shop_Update_Dedupe::seen( $update_id ) ) {
			return new WP_REST_Response( array( 'ok' => true, 'dedupe' => true ), 200 );
		}

		try {
			self::dispatch( $body );
		} catch ( Throwable $e ) {
			error_log( '[tg-shop-bridge] webhook error: ' . $e->getMessage() );
		}

		return new WP_REST_Response( array( 'ok' => true ), 200 );
	}

	private static function dispatch( array $update ) {
		if ( isset( $update['message']['text'] ) ) {
			$chat_id = isset( $update['message']['chat']['id'] ) ? (int) $update['message']['chat']['id'] : 0;
			$text    = (string) $update['message']['text'];
			self::handle_message( $chat_id, $text );
		}
	}

	private static function handle_message( $chat_id, $text ) {
		if ( $chat_id <= 0 ) {
			return;
		}

		$first   = explode( ' ', trim( $text ), 2 );
		$command = strtolower( (string) $first[0] );
		$command = (string) preg_replace( '/@.*$/', '', $command );

		switch ( $command ) {
			case '/start':
				self::send_welcome( $chat_id );
				break;
			case '/help':
				self::send_help( $chat_id );
				break;
			default:
				break;
		}
	}

	private static function send_welcome( $chat_id ) {
		$text = "Добро пожаловать в магазин!\nНажмите кнопку ниже, чтобы открыть каталог.";
		TG_Shop_Telegram_API::send_message( $chat_id, $text, self::miniapp_keyboard() );
	}

	private static function send_help( $chat_id ) {
		$text = "Доступные команды:\n/start — открыть магазин\n/help — эта справка";
		TG_Shop_Telegram_API::send_message( $chat_id, $text, self::miniapp_keyboard() );
	}

	private static function miniapp_keyboard() {
		$url = TG_Shop_Config::miniapp_url();
		if ( $url === '' ) {
			return null;
		}

		return array(
			'inline_keyboard' => array(
				array(
					array(
						'text'    => 'Открыть каталог',
						'web_app' => array( 'url' => $url ),
					),
				),
			),
		);
	}
}
EOF

cat > "$PLUGIN/includes/class-shortcode.php" <<'EOF'
<?php
/**
 * Shortcode [tg_shop_mini_app].
 *
 * @package TG_Shop_Bridge
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

final class TG_Shop_Shortcode {

	const HANDLE = 'tg-shop-miniapp';

	public static function register() {
		add_shortcode( 'tg_shop_mini_app', array( __CLASS__, 'render' ) );
		add_filter( 'script_loader_tag', array( __CLASS__, 'module_script_tag' ), 10, 3 );
	}

	public static function render() {
		$base_url = TG_SHOP_BRIDGE_URL . 'assets/miniapp/';
		$manifest = TG_SHOP_BRIDGE_DIR . 'assets/miniapp/manifest.json';

		$js_url  = '';
		$css_url = '';

		if ( file_exists( $manifest ) ) {
			$raw = file_get_contents( $manifest );
			if ( is_string( $raw ) ) {
				$json = json_decode( $raw, true );
				if ( is_array( $json ) ) {
					foreach ( $json as $entry ) {
						if ( ! is_array( $entry ) || empty( $entry['isEntry'] ) ) {
							continue;
						}
						if ( ! empty( $entry['file'] ) ) {
							$js_url = $base_url . ltrim( (string) $entry['file'], '/' );
						}
						if ( ! empty( $entry['css'] ) && is_array( $entry['css'] ) ) {
							$css_file = (string) $entry['css'][0];
							$css_url  = $base_url . ltrim( $css_file, '/' );
						}
						break;
					}
				}
			}
		}

		if ( $js_url === '' ) {
			if ( current_user_can( 'manage_options' ) ) {
				return '<div class="tg-shop-miniapp-error">' .
					esc_html__( 'Mini App не собран. Запустите `npm run build` в каталоге miniapp.', 'tg-shop-bridge' ) .
					'</div>';
			}
			return '';
		}

		if ( $css_url !== '' ) {
			wp_enqueue_style( self::HANDLE, $css_url, array(), TG_SHOP_BRIDGE_VERSION );
		}

		wp_enqueue_script( self::HANDLE, $js_url, array(), TG_SHOP_BRIDGE_VERSION, true );

		wp_localize_script(
			self::HANDLE,
			'TG_SHOP_BRIDGE',
			array(
				'apiBase' => esc_url_raw( rest_url( TG_Shop_Bridge::REST_NAMESPACE ) ),
			)
		);

		return '<div id="tg-shop-miniapp-root" class="tg-shop-miniapp-root"></div>';
	}

	public static function module_script_tag( $tag, $handle, $src ) {
		if ( $handle !== self::HANDLE ) {
			return $tag;
		}
		return sprintf(
			'<script type="module" src="%s" id="%s-js"></script>' . "\n",
			esc_url( $src ),
			esc_attr( $handle )
		);
	}
}
EOF

cat > "$PLUGIN/tests/run.php" <<'EOF'
<?php
/**
 * Простой тестовый раннер без внешних зависимостей.
 * Запуск: php wordpress-plugin/tg-shop-bridge/tests/run.php
 *
 * @package TG_Shop_Bridge
 */

if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', __DIR__ );
}

$GLOBALS['__transients'] = array();

if ( ! function_exists( 'get_transient' ) ) {
	function get_transient( $key ) {
		return $GLOBALS['__transients'][ $key ] ?? false;
	}
}
if ( ! function_exists( 'set_transient' ) ) {
	function set_transient( $key, $value, $ttl = 0 ) {
		$GLOBALS['__transients'][ $key ] = $value;
		return true;
	}
}

if ( ! defined( 'TG_SHOP_BRIDGE_VERSION' ) ) {
	define( 'TG_SHOP_BRIDGE_VERSION', '0.1.0-test' );
}
if ( ! defined( 'TG_SHOP_BRIDGE_FILE' ) ) {
	define( 'TG_SHOP_BRIDGE_FILE', __DIR__ . '/../tg-shop-bridge.php' );
}
if ( ! defined( 'TG_SHOP_BRIDGE_DIR' ) ) {
	define( 'TG_SHOP_BRIDGE_DIR', __DIR__ . '/../' );
}
if ( ! defined( 'TG_SHOP_BRIDGE_URL' ) ) {
	define( 'TG_SHOP_BRIDGE_URL', 'http://example.test/' );
}

require_once __DIR__ . '/../includes/class-config.php';
require_once __DIR__ . '/../includes/class-update-dedupe.php';

$GLOBALS['__tests']    = 0;
$GLOBALS['__failures'] = 0;

function tgs_check( $name, $condition ) {
	$GLOBALS['__tests']++;
	if ( $condition ) {
		echo "PASS: {$name}\n";
	} else {
		$GLOBALS['__failures']++;
		echo "FAIL: {$name}\n";
	}
}

tgs_check( 'Config::bot_token пусто', '' === TG_Shop_Config::bot_token() );
tgs_check( 'Config::webhook_secret пусто', '' === TG_Shop_Config::webhook_secret() );
tgs_check( 'Config::miniapp_url пусто', '' === TG_Shop_Config::miniapp_url() );
tgs_check( 'Config::init_data_max_age 600', 600 === TG_Shop_Config::init_data_max_age() );

$GLOBALS['__transients'] = array();
tgs_check( 'Dedupe первый раз not seen', false === TG_Shop_Update_Dedupe::seen( 1001 ) );
tgs_check( 'Dedupe повторно seen', true === TG_Shop_Update_Dedupe::seen( 1001 ) );
tgs_check( 'Dedupe другой id not seen', false === TG_Shop_Update_Dedupe::seen( 1002 ) );
tgs_check( 'Dedupe id<=0', false === TG_Shop_Update_Dedupe::seen( 0 ) );

$expected = 'super-secret-value';
tgs_check( 'hash_equals совпадение', true === hash_equals( $expected, 'super-secret-value' ) );
tgs_check( 'hash_equals несовпадение', false === hash_equals( $expected, 'other' ) );

echo "\n" . $GLOBALS['__tests'] . " тестов, " . $GLOBALS['__failures'] . " ошибок\n";
exit( $GLOBALS['__failures'] === 0 ? 0 : 1 );
EOF

# ---------- miniapp ----------

cat > "$MINI/package.json" <<'EOF'
{
  "name": "tg-shop-miniapp",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc --noEmit && vite build",
    "preview": "vite preview",
    "lint": "eslint \"src/**/*.{ts,tsx}\"",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {
    "@types/node": "^20.14.10",
    "@types/react": "^18.3.12",
    "@types/react-dom": "^18.3.1",
    "@typescript-eslint/eslint-plugin": "^8.13.0",
    "@typescript-eslint/parser": "^8.13.0",
    "@vitejs/plugin-react": "^4.3.3",
    "eslint": "^8.57.1",
    "eslint-plugin-react-hooks": "^4.6.2",
    "eslint-plugin-react-refresh": "^0.4.14",
    "typescript": "^5.6.3",
    "vite": "^5.4.10"
  }
}
EOF

cat > "$MINI/index.html" <<'EOF'
<!doctype html>
<html lang="ru">
  <head>
    <meta charset="UTF-8" />
    <meta
      name="viewport"
      content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no"
    />
    <title>Магазин</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

cat > "$MINI/tsconfig.json" <<'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "moduleDetection": "force",
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "types": ["vite/client", "node"]
  },
  "include": ["src", "vite.config.ts"]
}
EOF

cat > "$MINI/vite.config.ts" <<'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { fileURLToPath, URL } from 'node:url';
import { resolve } from 'node:path';

const here = fileURLToPath(new URL('.', import.meta.url));
const pluginAssetsDir = resolve(here, '../wordpress-plugin/tg-shop-bridge/assets/miniapp');

export default defineConfig({
  plugins: [react()],
  base: './',
  build: {
    outDir: pluginAssetsDir,
    emptyOutDir: true,
    manifest: 'manifest.json',
    sourcemap: false,
    rollupOptions: {
      input: resolve(here, 'index.html'),
    },
  },
  server: {
    port: 5173,
    strictPort: false,
  },
});
EOF

cat > "$MINI/.eslintrc.cjs" <<'EOF'
module.exports = {
  root: true,
  env: { browser: true, es2020: true },
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:react-hooks/recommended',
  ],
  ignorePatterns: ['dist', 'node_modules', '.eslintrc.cjs', 'vite.config.ts'],
  parser: '@typescript-eslint/parser',
  parserOptions: { ecmaVersion: 'latest', sourceType: 'module' },
  plugins: ['react-refresh'],
  rules: {
    'react-refresh/only-export-components': ['warn', { allowConstantExport: true }],
    '@typescript-eslint/no-unused-vars': ['warn', { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }],
  },
};
EOF

cat > "$MINI/.gitignore" <<'EOF'
node_modules
dist
.env
.env.local
EOF

: > "$MINI/public/.gitkeep"

cat > "$MINI/src/main.tsx" <<'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './styles.css';

const root = document.getElementById('root');
if (!root) {
  throw new Error('Не найден контейнер #root');
}

ReactDOM.createRoot(root).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
EOF

cat > "$MINI/src/config/env.ts" <<'EOF'
/**
 * Публичная конфигурация Mini App.
 * СЕКРЕТЫ ЗДЕСЬ НЕ ХРАНЯТСЯ. Только базовый URL REST.
 */

type GlobalWithConfig = typeof globalThis & {
  TG_SHOP_BRIDGE?: { apiBase?: string };
};

function readApiBase(): string {
  const injected = (globalThis as GlobalWithConfig).TG_SHOP_BRIDGE?.apiBase;
  if (injected && injected.trim() !== '') {
    return injected.replace(/\/+$/, '');
  }

  const fromVite = import.meta.env.VITE_API_BASE;
  if (typeof fromVite === 'string' && fromVite.trim() !== '') {
    return fromVite.replace(/\/+$/, '');
  }

  return '/wp-json/tg-shop/v1';
}

export const API_BASE = readApiBase();

export const DEMO_MODE: boolean =
  import.meta.env.DEV === true && import.meta.env.VITE_DEMO_MODE === 'true';
EOF

cat > "$MINI/src/types/product.ts" <<'EOF'
export interface Product {
  id: number;
  name: string;
  short_description: string;
  price: string;
  currency: string;
  image: string;
  in_stock: boolean;
  purchasable: boolean;
  permalink: string;
}

export interface ProductListResponse {
  page: number;
  per_page: number;
  total: number;
  total_pages: number;
  items: Product[];
}
EOF

cat > "$MINI/src/api/demo.ts" <<'EOF'
/**
 * Демо-данные для локальной разработки без WordPress.
 * Включаются ТОЛЬКО при DEMO_MODE (см. config/env.ts).
 */

import type { Product, ProductListResponse } from '../types/product';

const DEMO_PRODUCTS: Product[] = [
  {
    id: 1,
    name: 'Демо-товар 1',
    short_description: 'Пример карточки. Реальные данные берутся из WooCommerce.',
    price: '1000',
    currency: 'RUB',
    image: '',
    in_stock: true,
    purchasable: true,
    permalink: '#',
  },
  {
    id: 2,
    name: 'Демо-товар 2',
    short_description: 'Пример карточки без наличия.',
    price: '2500',
    currency: 'RUB',
    image: '',
    in_stock: false,
    purchasable: false,
    permalink: '#',
  },
];

export async function demoList(params: {
  page: number;
  perPage: number;
  search: string;
}): Promise<ProductListResponse> {
  const filtered = params.search
    ? DEMO_PRODUCTS.filter((p) =>
        p.name.toLowerCase().includes(params.search.toLowerCase()),
      )
    : DEMO_PRODUCTS;

  return {
    page: params.page,
    per_page: params.perPage,
    total: filtered.length,
    total_pages: 1,
    items: filtered,
  };
}

export async function demoGet(id: number): Promise<Product> {
  const found = DEMO_PRODUCTS.find((p) => p.id === id);
  if (!found) {
    throw new Error('Товар не найден');
  }
  return found;
}
EOF

cat > "$MINI/src/api/catalog.ts" <<'EOF'
import { API_BASE, DEMO_MODE } from '../config/env';
import type { Product, ProductListResponse } from '../types/product';
import { demoList, demoGet } from './demo';

export class ApiError extends Error {
  status?: number;
  constructor(message: string, status?: number) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
  }
}

async function fetchJson<T>(url: string, signal?: AbortSignal): Promise<T> {
  let response: Response;
  try {
    response = await fetch(url, {
      signal,
      credentials: 'omit',
      headers: { Accept: 'application/json' },
    });
  } catch (e) {
    if ((e as Error).name === 'AbortError') throw e;
    throw new ApiError('Нет соединения с сервером. Проверьте интернет.');
  }

  if (!response.ok) {
    throw new ApiError(`Сервер вернул ошибку (${response.status}).`, response.status);
  }

  try {
    return (await response.json()) as T;
  } catch {
    throw new ApiError('Некорректный ответ сервера.');
  }
}

export interface ListProductsParams {
  page?: number;
  perPage?: number;
  search?: string;
}

export async function listProducts(
  params: ListProductsParams = {},
  signal?: AbortSignal,
): Promise<ProductListResponse> {
  const page = params.page ?? 1;
  const perPage = params.perPage ?? 20;
  const search = params.search ?? '';

  if (DEMO_MODE) {
    return demoList({ page, perPage, search });
  }

  const url = new URL(
    `${API_BASE}/products`,
    typeof window !== 'undefined' ? window.location.origin : 'http://localhost',
  );
  url.searchParams.set('page', String(page));
  url.searchParams.set('per_page', String(perPage));
  if (search) url.searchParams.set('search', search);

  return fetchJson<ProductListResponse>(url.toString(), signal);
}

export async function getProduct(
  id: number,
  signal?: AbortSignal,
): Promise<Product> {
  if (DEMO_MODE) {
    return demoGet(id);
  }
  return fetchJson<Product>(`${API_BASE}/products/${id}`, signal);
}
EOF

cat > "$MINI/src/telegram/webapp.ts" <<'EOF'
/**
 * Безопасная обёртка над Telegram WebApp SDK.
 *
 * На Этапе 1 мы НЕ доверяем initDataUnsafe и НЕ используем initData
 * для авторизации. Только ready()/expand() и проверка «внутри ли Telegram».
 */

export interface TelegramWebApp {
  initData: string;
  initDataUnsafe: unknown;
  ready: () => void;
  expand: () => void;
  themeParams?: Record<string, string>;
  colorScheme?: 'light' | 'dark';
  openLink?: (url: string) => void;
}

interface WindowWithTelegram {
  Telegram?: { WebApp?: TelegramWebApp };
}

export function getWebApp(): TelegramWebApp | null {
  if (typeof window === 'undefined') return null;
  const w = window as WindowWithTelegram;
  return w.Telegram?.WebApp ?? null;
}

export function isInsideTelegram(): boolean {
  return getWebApp() !== null;
}

export function initTelegram(): void {
  const app = getWebApp();
  if (!app) return;
  try {
    app.ready();
    app.expand();
  } catch {
    // SDK может быть частично инициализирован.
  }
}
EOF

cat > "$MINI/src/components/LoadingState.tsx" <<'EOF'
export function LoadingState() {
  return (
    <div className="state state--loading" role="status" aria-live="polite">
      <div className="spinner" aria-hidden="true" />
      <p>Загружаем каталог…</p>
    </div>
  );
}
EOF

cat > "$MINI/src/components/EmptyState.tsx" <<'EOF'
export function EmptyState() {
  return (
    <div className="state state--empty">
      <p>В каталоге пока нет товаров.</p>
    </div>
  );
}
EOF

cat > "$MINI/src/components/ErrorState.tsx" <<'EOF'
export function ErrorState({
  message,
  onRetry,
}: {
  message: string;
  onRetry: () => void;
}) {
  return (
    <div className="state state--error" role="alert">
      <p>{message}</p>
      <button type="button" className="btn" onClick={onRetry}>
        Повторить
      </button>
    </div>
  );
}
EOF

cat > "$MINI/src/components/ProductCard.tsx" <<'EOF'
import type { CSSProperties } from 'react';
import type { Product } from '../types/product';

const imageStyle: CSSProperties = {
  aspectRatio: '1 / 1',
  objectFit: 'cover',
  width: '100%',
  borderRadius: 12,
  display: 'block',
  backgroundColor: 'rgba(127, 127, 127, 0.12)',
};

export function ProductCard({ product }: { product: Product }) {
  return (
    <article className="product-card">
      {product.image ? (
        <img src={product.image} alt={product.name} style={imageStyle} loading="lazy" />
      ) : (
        <div
          style={{
            ...imageStyle,
            display: 'grid',
            placeItems: 'center',
            color: 'var(--tg-hint)',
            fontSize: 12,
          }}
        >
          Нет фото
        </div>
      )}

      <h3 className="product-card__title">{product.name}</h3>

      {product.short_description && (
        <p className="product-card__desc">{product.short_description}</p>
      )}

      <div className="product-card__row">
        <span className="product-card__price">
          {product.price} {product.currency}
        </span>
        <span className={product.in_stock ? 'badge badge--ok' : 'badge badge--off'}>
          {product.in_stock ? 'В наличии' : 'Нет в наличии'}
        </span>
      </div>
    </article>
  );
}
EOF

cat > "$MINI/src/components/ProductList.tsx" <<'EOF'
import type { Product } from '../types/product';
import { ProductCard } from './ProductCard';

export function ProductList({ products }: { products: Product[] }) {
  return (
    <div className="product-grid">
      {products.map((p) => (
        <ProductCard key={p.id} product={p} />
      ))}
    </div>
  );
}
EOF

cat > "$MINI/src/App.tsx" <<'EOF'
import { useCallback, useEffect, useState } from 'react';
import { ApiError, listProducts } from './api/catalog';
import type { Product } from './types/product';
import { ProductList } from './components/ProductList';
import { LoadingState } from './components/LoadingState';
import { EmptyState } from './components/EmptyState';
import { ErrorState } from './components/ErrorState';
import { getWebApp, initTelegram, isInsideTelegram } from './telegram/webapp';

type Status = 'loading' | 'ready' | 'error';

export default function App() {
  const [status, setStatus] = useState<Status>('loading');
  const [products, setProducts] = useState<Product[]>([]);
  const [error, setError] = useState<string>('');
  const [reloadKey, setReloadKey] = useState(0);

  useEffect(() => {
    initTelegram();
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    setStatus('loading');
    setError('');

    listProducts({ page: 1, perPage: 20 }, controller.signal)
      .then((res) => {
        setProducts(res.items);
        setStatus('ready');
      })
      .catch((e: unknown) => {
        if ((e as Error).name === 'AbortError') return;
        const msg =
          e instanceof ApiError
            ? e.message
            : 'Не удалось загрузить каталог. Попробуйте позже.';
        setError(msg);
        setStatus('error');
      });

    return () => controller.abort();
  }, [reloadKey]);

  const retry = useCallback(() => setReloadKey((k) => k + 1), []);

  const inTelegram = isInsideTelegram();
  const webApp = getWebApp();

  return (
    <div className="app">
      <header className="app__header">
        <h1>Каталог</h1>
        {!inTelegram && (
          <p className="app__hint">
            Откройте магазин через Telegram-бота, чтобы получить полный функционал.
          </p>
        )}
      </header>

      <main className="app__main">
        {status === 'loading' && <LoadingState />}
        {status === 'error' && <ErrorState message={error} onRetry={retry} />}
        {status === 'ready' &&
          (products.length === 0 ? (
            <EmptyState />
          ) : (
            <ProductList products={products} />
          ))}
      </main>

      {webApp && (
        <footer className="app__footer">
          <small>Открыто в Telegram</small>
        </footer>
      )}
    </div>
  );
}
EOF

cat > "$MINI/src/styles.css" <<'EOF'
:root {
  --tg-bg: var(--tg-theme-bg-color, #ffffff);
  --tg-text: var(--tg-theme-text-color, #111111);
  --tg-hint: var(--tg-theme-hint-color, #707579);
  --tg-button: var(--tg-theme-button-color, #2ea6ff);
  --tg-button-text: var(--tg-theme-button-text-color, #ffffff);
  color-scheme: light dark;
}

* { box-sizing: border-box; }

html, body, #root {
  margin: 0;
  padding: 0;
  min-height: 100%;
  background: var(--tg-bg);
  color: var(--tg-text);
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  -webkit-font-smoothing: antialiased;
}

.app { max-width: 640px; margin: 0 auto; padding: 12px 12px 32px; }
.app__header h1 { font-size: 20px; margin: 4px 0 8px; }
.app__hint { color: var(--tg-hint); font-size: 13px; margin: 0 0 12px; }

.product-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.product-card {
  background: rgba(127, 127, 127, 0.06);
  border-radius: 14px;
  padding: 10px;
  display: flex;
  flex-direction: column;
  gap: 6px;
  min-width: 0;
}

.product-card__title { font-size: 15px; margin: 4px 0 0; line-height: 1.3; word-break: break-word; }
.product-card__desc {
  font-size: 12px;
  color: var(--tg-hint);
  margin: 0;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.product-card__row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 6px;
  margin-top: auto;
}
.product-card__price { font-weight: 600; font-size: 14px; }

.badge { font-size: 11px; padding: 3px 6px; border-radius: 8px; white-space: nowrap; }
.badge--ok { background: rgba(0, 180, 100, 0.15); color: #0a8a4c; }
.badge--off { background: rgba(220, 50, 50, 0.15); color: #b32626; }

.state { padding: 32px 12px; text-align: center; color: var(--tg-hint); }

.spinner {
  width: 28px;
  height: 28px;
  border: 3px solid rgba(127, 127, 127, 0.3);
  border-top-color: var(--tg-button);
  border-radius: 50%;
  margin: 0 auto 8px;
  animation: tg-shop-spin 0.9s linear infinite;
}
@keyframes tg-shop-spin { to { transform: rotate(360deg); } }

.btn {
  background: var(--tg-button);
  color: var(--tg-button-text);
  border: none;
  padding: 10px 16px;
  border-radius: 10px;
  font-size: 14px;
  cursor: pointer;
}

.app__footer { margin-top: 24px; text-align: center; color: var(--tg-hint); }
EOF

chmod +x "$ROOT/setup.sh" 2>/dev/null || true

echo ""
echo "✓ Готово. Создано:"
echo "   $ROOT"
find "$ROOT" -type f -not -path '*/.git/*' | sed "s|$ROOT|  .|" | sort
echo ""
echo "Дальше:"
echo "  git init && git add . && git commit -m 'chore: initial scaffolding (stage 1)'"
echo "  git branch -M main && git remote add origin <URL> && git push -u origin main"
