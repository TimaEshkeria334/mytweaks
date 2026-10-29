# timagray — my APT repo

Личный репозиторий для Cydia / Sileo / Zebra + страница приложений (.ipa). Хостится на GitHub Pages.

```
https://timaeshkeria334.github.io/mytweaks/
```

- индекс пакетов: <https://timaeshkeria334.github.io/mytweaks/>
- приложения .ipa: <https://timaeshkeria334.github.io/mytweaks/ipa/>

## Пакеты

| Пакет | Версия | Архитектуры | Описание |
|---|---|---|---|
| `ai.akemi.appsyncunified` | 116.0 | `iphoneos-arm`, `iphoneos-arm64` | AppSync Unified — установка неподписанных / fakesigned IPA |
| `ellekit` | 1.2 | `iphoneos-arm`, `iphoneos-arm64` | Tweak-инъектор, предоставляет `mobilesubstrate` |
| `com.githublegacy.app` | 1.1 | `iphoneos-arm` | GitHub Legacy — клиент GitHub для iOS 5+ |
| `com.ra1nndev.yamus1c` | 2.1.2 | `iphoneos-arm` | YaMus1c — клиент Яндекс.Музыки для iOS 6 |
| `ru.computershik.troubadour` | 1.6 | `iphoneos-arm` | Troubadour — клиент YouTube для iOS 5.1+ |

### Приложения (.ipa)

Лежат в `ipa/`, каталог с кнопками — `ipa/index.html`, ссылки есть и на главной.

| Файл | Приложение | Bundle ID | Версия | Min iOS |
|---|---|---|---|---|
| `ipa/legacyai_3.5.ipa` | LegacyAI | `com.sashok.legacyai` | 3.5 | 6.0 |
| `ipa/lovit_1.1.ipa` | Ловит | `ru.computershik.lovit` | 1.1 | 6.0 |
| `ipa/retroclash_1.70.ipa` | Clash of Clans | `com.supercell.magic` | 1.70 | 4.3 |
| `ipa/trubach_1.1.ipa` | Трубач | `ru.computershik.trubach` | 1.1 | 5.1 |

### Как ставить .ipa на iOS 10.3.3 / 12.5.8

1. Поставить `ai.akemi.appsyncunified` 116.0 из репозитория (он идёт с зависимостью
   `mobilesubstrate (>= 0.9.5100)`; на iOS 10/12 это Cydia Substrate, который уже стоит после джейлбрейка —
   ElleKit там не нужен и конфликтует с ним).
2. Скачать `.ipa` по ссылке с <https://timaeshkeria334.github.io/mytweaks/ipa/>
   (Safari сохранит в «Файлы», либо скачать через Filza).
3. Установить: открыть `.ipa` в Filza → «Install», либо `ipainstaller <файл>.ipa` по SSH,
   либо через AppSync в настройках. Перезагрузить springboard (`killall SpringBoard`).

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
├── debs/                  # все .deb
├── ipa/                   # все .ipa + index.html (генерируется)
├── Packages{,.gz,.bz2,.xz}
├── Release                # метаданные + хеши индексов
├── update-repo.sh         # пересборка индексов и ipa/index.html
├── depictions/            # HTML-страницы описаний (?p=<package>)
├── CydiaIcon.png          # иконка репозитория
└── index.html             # лендинг
```

## Добавить / обновить пакет

```sh
cp my.tweak_1.0_iphoneos-arm64.deb debs/
./update-repo.sh
git add -A && git commit -m "add my.tweak 1.0" && git push
```

`update-repo.sh` достаёт `control` прямо из `.deb`, добавляет `Filename`, `Size`,
`MD5sum`, `SHA1`, `SHA256`, `SHA512`, при наличии `depictions/<package>/info.xml`
подставляет `Depiction`, и перегенерирует `Packages*` + `Release`.

## Добавить приложение (.ipa)

```sh
cp MyApp.ipa ipa/
./update-repo.sh
git add -A && git commit -m "add MyApp.ipa" && git push
```

Скрипт читает `Payload/*.app/Info.plist` из каждого `.ipa` (bundle id, название, версию,
`MinimumOSVersion`), вытаскивает иконку в `ipa/icons/`, считает SHA256 и собирает
`ipa/index.html`. Файлы с пробелами лучше переименовать заранее (`MyApp_1.0.ipa`).

Зависимости скрипта: `ar`, `tar`, `gzip`, `bzip2`, `xz`, coreutils;
`python3` — опционально (без него `ipa/index.html` не обновляется).

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
