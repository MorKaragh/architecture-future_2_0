# Build Your Own Radar (локально)

Интерактивный техрадар на базе open-source [**ThoughtWorks Build Your Own Radar**](https://github.com/thoughtworks/build-your-own-radar). Лицензия проекта и образа Docker — **AGPL-3.0**.

Данные задания закреплены в [files/future20-tech-radar.csv](files/future20-tech-radar.csv) (квадранты в нижнем регистре: `techniques`, `platforms`, `tools`, `languages & frameworks`). Не используйте имя `radar.csv`: точка входа контейнера **перезаписывает** `radar.csv` и `radar.json` демо-данными Thoughtworks при каждом запуске.

Первый `docker compose pull` может занять время из‑за размера слоёв образа.

## Запуск

Из корня репозитория:

```bash
cd Task5Advanced/byor-radar
docker compose up -d
```

Если вы уже находитесь в каталоге `Task5Advanced`, достаточно `cd byor-radar`.

После первого старта подождите ~20–30 с, пока в логах контейнера завершится сборка webpack.

## Основной вход в радар

Откройте в браузере:

**[http://localhost:8080/?documentId=http%3A%2F%2Flocalhost%3A8080%2Ffiles%2Ffuture20-tech-radar.csv](http://localhost:8080/?documentId=http%3A%2F%2Flocalhost%3A8080%2Ffiles%2Ffuture20-tech-radar.csv)**

Это основной рабочий адрес: BYOR сразу подгружает `future20-tech-radar.csv` без ручного ввода в форме.

![Целевой техрадар в BYOR после открытия основной ссылки](../img/radar.png)

## Альтернатива: форма «Build your own Radar»

Если открыли только корень **http://localhost:8080/** — на стартовой странице вставьте в поле URL файла и нажмите **Build my radar**:

`http://localhost:8080/files/future20-tech-radar.csv`

Текст на странице про **Hold** / **Caution** относится к официальному радару Thoughtworks; при self-hosted и переменной `RINGS` в compose допускается своё именование колец.

После правок `files/future20-tech-radar.csv` обновите вкладку с радаром.

Остановка:

```bash
docker compose down
```

Порт по умолчанию **8080**; при занятости измените проброс в `docker-compose.yml` (например `"9080:80"`) и подставьте порт в ссылках выше.

## Если контейнер сразу завершается

Точка входа образа после сборки копирует файлы в каталог `files` внутри контейнера. Если том смонтирован **только для чтения** (`:ro`), появятся сообщения `cp: ... Read-only file system` и процесс завершится с кодом 1. В `docker-compose.yml` том `./files` должен быть **доступен на запись** (флаг `:ro` не используется).
