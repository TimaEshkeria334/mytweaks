# timagray — my APT repo

Личный репозиторий для Cydia / Sileo / Zebra. Хостится на GitHub Pages.

```
https://timaeshkeria334.github.io/mytweaks/
```

## Пакеты

| Пакет | Версия | Архитектуры | Описание |
|---|---|---|---|
| `ai.akemi.appsyncunified` | 116.0 | `iphoneos-arm`, `iphoneos-arm64` | AppSync Unified — установка неподписанных / fakesigned IPA |
| `ellekit` | 1.2 | `iphoneos-arm`, `iphoneos-arm64` | Tweak-инъектор, предоставляет `mobilesubstrate` |
| `com.supermamon.newpackage` | 2.0.0-1 | `iphoneos-arm` | пример из шаблона (можно удалить) |
| `com.supermamon.oldpackage` | 1.0.0-1 | `iphoneos-arm` | пример из шаблона (можно удалить) |

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
├── Packages{,.gz,.bz2,.xz}
├── Release                # метаданные + хеши индексов
├── update-repo.sh         # пересборка индексов
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

Зависимости скрипта: `ar`, `tar`, `gzip`, `bzip2`, `xz`, coreutils.

Проверка индекса:

```sh
apt-get -o Dir::Etc::SourceList=/dev/null update 2>/dev/null  # на устройстве — обновление в менеджере
```

## Удалить примеры из шаблона

```sh
git rm debs/com.supermamon.*.deb
git rm -r depictions/com.supermamon.*
./update-repo.sh && git add -A && git commit -m "drop template samples" && git push
```

## Источники и лицензии

- AppSync Unified — © Karen/あけみ, официальный репозиторий <https://cydia.akemi.ai/>.
  Пожалуйста, не используйте его для пиратства.
- ElleKit — © ElleKit Team, <https://ellekit.space/>.
- Структура репозитория и depiction-шаблон — [SuperMamon/Reposi3](https://github.com/supermamon/Reposi3) (см. `LICENSE`).
