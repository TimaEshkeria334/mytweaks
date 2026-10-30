# timagray — my APT repo

Личный репозиторий для Cydia / Sileo / Zebra + приложения (.deb). Хостится на GitHub Pages.

```
https://timaeshkeria334.github.io/mytweaks/
```

- индекс пакетов: <https://timaeshkeria334.github.io/mytweaks/>
- приложения (.deb): <https://timaeshkeria334.github.io/mytweaks/debs/>

## Пакеты

| Пакет | Версия | Архитектуры | Описание |
|---|---|---|---|
| `ai.akemi.appsyncunified` | 116.0 | `iphoneos-arm`, `iphoneos-arm64` | AppSync Unified — установка неподписанных / fakesigned IPA |
| `com.timagray.appsynclite` | 1.0.0 | `iphoneos-arm` (arm64) | AppSyncLite — свой твик для установки неподписанных IPA на iOS 10.x (конфликтует с AppSync Unified) |
| `ellekit` | 1.2 | `iphoneos-arm`, `iphoneos-arm64` | Tweak-инъектор, предоставляет `mobilesubstrate` |
| `com.githublegacy.app` | 1.1 | `iphoneos-arm` | GitHub Legacy — клиент GitHub для iOS 5+ |
| `com.ra1nndev.yamus1c` | 2.1.2 | `iphoneos-arm` | YaMus1c — клиент Яндекс.Музыки для iOS 6 |
| `com.sashok.legacyai` | 3.5 | `iphoneos-arm` | LegacyAI — клиент GitHub для iOS 5+ |
| `com.supercell.magic` | 1.70 | `iphoneos-arm` | Clash of Clans — игра для iOS 4.3+ |
| `ru.computershik.lovit` | 1.1 | `iphoneos-arm` | Lovit — музыка для iOS 6+ |
| `ru.computershik.troubadour` | 1.6 | `iphoneos-arm` | Troubadour — клиент YouTube для iOS 5.1+ |
| `ru.computershik.trubach` | 1.1 | `iphoneos-arm` | Trubach — клиент YouTube для iOS 5.1+ |

### Приложения

Все приложения — обычные `.deb` в `debs/`, внутри них лежит `Applications/<App>.app`
(с `Info.plist` и иконкой). Ставятся через Cydia / Sileo / Zebra как обычные пакеты.

| Файл | Приложение | Bundle ID | Версия | Min iOS |
|---|---|---|---|---|
| `debs/com.githublegacy.app_1.1_iphoneos-arm.deb` | GitHub Legacy | `com.githublegacy.app` | 1.1 | 5.0 |
| `debs/com.sashok.legacyai_3.5_iphoneos-arm.deb` | LegacyAI | `com.sashok.legacyai` | 3.5 | 6.0 |
| `debs/ru.computershik.lovit_1.1_iphoneos-arm.deb` | Lovit | `ru.computershik.lovit` | 1.1 | 6.0 |
| `debs/com.supercell.magic_1.70_iphoneos-arm.deb` | Clash of Clans | `com.supercell.magic` | 1.70 | 4.3 |
| `debs/ru.computershik.trubach_1.1_iphoneos-arm.deb` | Trubach | `ru.computershik.trubach` | 1.1 | 5.1 |

### Как ставить приложения (deb) на iOS 10.3.3 / 12.5.8

1. Поставить `ai.akemi.appsyncunified` 116.0 из репозитория (он идёт с зависимостью
   `mobilesubstrate (>= 0.9.5100)`; на iOS 10/12 это Cydia Substrate, который уже стоит после джейлбрейка —
   ElleKit там не нужен и конфликтует с ним).
2. Установить нужный пакет приложения из этого репозитория (он виден в Cydia/Sileo/Zebra как обычный пакет).
3. Перезагрузить springboard (`killall SpringBoard`).

Для сторонних приложений (не из App Store) AppSync Unified нужен обязательно — без него они
установятся как tweaks-пакеты с ошибкой, либо не установятся вовсе.

### Почему здесь лежит ElleKit

`ai.akemi.appsyncunified` объявляет:

```
Depends:   firmware (>= 5.0), mobilesubstrate (>= 0.9.5100), firmware (<= 18.2)
Conflicts: ... , ellekit (< 1.1)
```

То есть нужен tweak-инъектор, предоставляющий `mobilesubstrate`, версии не ниже 1.1
(на rootless-джейлбрейках это обязательно). ElleKit 1.2 даёт `Provides: mobilesubstrate (= 99)`,
поэтому обе зависимости закрываются одним пакетом.

- `iphoneos-arm` — rootful (iPhone 5s / iOS 12.5.8, checkra1n, unc0ver, palera1n rootful): файлы в `/Library`, `/usr/bin`
- `iphoneos-arm64` — rootless (palera1n rootless, Dopamine, XinaA15): файлы в `/var/jb`

> AppSync Unified 116.0 поддерживается до iOS 18.2 включительно.

## Структура

```
.
├── debs/                  # все .deb (твики + приложения с Applications/<App>.app)
├── Packages{,.gz,.bz2,.xz}
├── Release                # метаданные + хеши индексов
├── update-repo.sh         # пересборка индексов APT
├── publish.sh             # автосборка твиков + индексы + push + GitHub Releases
├── depictions/            # HTML-страницы описаний (?p=<package>)
├── CydiaIcon.png          # иконка репозитория
└── index.html             # лендинг
```

## publish.sh — автоопределение твиков и релизы

Скрипт сам находит все твики в `~/tweaks/*/` (по наличию `control`), собирает их
(`build.sh` или `make package`, если задан `THEOS`), раскладывает `.deb` в репозиторий,
перегенерирует индексы, синхронизирует LAN-зеркало, коммитит/пушит и создаёт
GitHub Release с прикреплённым `.deb`.

```sh
./publish.sh                  # всё сразу
BUILD=0 ./publish.sh          # без сборки, взять готовые .deb
PUSH=0 RELEASES=0 ./publish.sh
RELEASE_ALL=1 ./publish.sh    # релизить все секции, а не только Tweaks
```

Тег релиза: `<Package>-v<Version>`, например `com.timagray.appsynclite-v1.0.0`.
Если такой тег уже есть — ассет обновляется (`--clobber`), если `.deb` изменился.

Переменные: `TWEAKS`, `REPO`, `LAN`, `BUILD`, `PUSH`, `RELEASES`, `RELEASE_ALL`, `GH_REPO`.

## Добавить / обновить пакет

```sh
cp my.tweak_1.0_iphoneos-arm64.deb debs/
./update-repo.sh
git add -A && git commit -m "add my.tweak 1.0" && git push
```

`update-repo.sh` достаёт `control` прямо из `.deb`, добавляет `Filename`, `Size`,
`MD5sum`, `SHA1`, `SHA256`, `SHA512`, при наличии `depictions/<package>/info.xml`
подставляет `Depiction`, и перегенерирует `Packages*` + `Release`.

## Добавить приложение (deb)

```sh
cp MyApp_1.0_iphoneos-arm.deb debs/
./update-repo.sh
git add -A && git commit -m "add MyApp" && git push
```

Приложение упаковывается в deb вида `Applications/<App>.app` (с `Info.plist`, иконкой,
`Library/MobileSubstrate/DynamicLibraries` при необходимости) + `DEBIAN/control`.
Зависимости скрипта: `ar`, `tar`, `gzip`, `bzip2`, `xz`, coreutils.

Если у приложения есть своя страница описания — положите шаблон в `depictions/<package>/info.xml`.

## Если Cydia не видит изменения

Cydia на iOS 10 упорно кеширует индекс — сделайте Refresh, либо по SSH:

```sh
rm -rf /var/lib/apt/lists/*
apt-get update
killall Cydia
```

## Источники и лицензии

- AppSync Unified — © Karen/あけみ, официальный репозиторий <https://cydia.akemi.ai/>.
  Пожалуйста, не используйте его для пиратства.
- ElleKit — © ElleKit Team, <https://ellekit.space/>.
- GitHub Legacy — © автор пакета `com.githublegacy.app`.
- YaMus1c — © ra1nndev. Troubadour, Ловит, Трубач — © computershik.
- Структура репозитория и depiction-шаблон — [SuperMamon/Reposi3](https://github.com/supermamon/Reposi3) (см. `LICENSE`).
