# Build Your Own Radar (локально)

Интерактивный техрадар на базе open-source [**ThoughtWorks Build Your Own Radar**](https://github.com/thoughtworks/build-your-own-radar). Лицензия проекта и образа Docker — **AGPL-3.0**.

Данные: [files/radar.csv](files/radar.csv) (квадранты в нижнем регистре: `techniques`, `platforms`, `tools`, `languages & frameworks`). Первый `docker compose pull` может занять время из‑за размера слоёв образа.

## Запуск

Из корня репозитория:

```bash
cd Task5Advanced/byor-radar
docker compose up -d
```

Если вы уже находитесь в каталоге `Task5Advanced`, достаточно `cd byor-radar`.

В браузере откройте `http://localhost:8080`, запустите построение радара и укажите URL данных:

`http://localhost:8080/files/radar.csv`

После правок CSV достаточно обновить страницу. Остановка:

```bash
docker compose down
```

Порт по умолчанию 8080; при занятости порта измените проброс в `docker-compose.yml` (например `"9080:80"`).
