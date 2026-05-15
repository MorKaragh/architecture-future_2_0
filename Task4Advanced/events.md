# Каталог доменных событий

События именуются в прошедшем времени (факт произошёл). Все события проходят через **Event Backbone**; источник — bounded context, публикующий событие. Контракты версионируются (`schema_version`).

## Соглашения по минимальному контракту

Обязательные поля для каждого события:

| Поле | Тип | Смысл |
|------|-----|--------|
| `event_id` | UUID | Уникальный идентификатор факта |
| `occurred_at` | timestamp (UTC) | Время бизнес-факта |
| `schema_version` | string | Версия схемы полезной нагрузки |
| `aggregate_id` | string | Идентификатор корня агрегата-источника |
| `aggregate_version` | int | Версия агрегата (оптимистическая конкуренция) |
| `tenant_id` | string | Изоляция арендатора/региона |
| `correlation_id` | string | Сквозная корреляция процесса |

Дополнительные поля — в `payload` ниже.

## Каталог

| Название события | Контекст-источник | Семантика | Минимальный контракт (`payload`) |
|------------------|-------------------|-----------|----------------------------------|
| `PatientRegistered` | Clinical Care | В клиническом контуре создан пациент | `patient_id`, `registration_channel`, `primary_site_id` |
| `EncounterOpened` | Clinical Care | Начат эпизод обслуживания | `episode_id`, `patient_id`, `department_id`, `opened_at` |
| `EncounterClosed` | Clinical Care | Эпизод закрыт | `episode_id`, `patient_id`, `closure_reason`, `closed_at` |
| `StudyOrdered` | Diagnostics & Studies | Создан заказ исследования | `order_id`, `episode_id`, `modality`, `priority` |
| `StudyCompleted` | Diagnostics & Studies | Результат зафиксирован и подписан | `result_id`, `order_id`, `episode_id`, `result_descriptor_uri` (ссылка на хранилище контура) |
| `StudyCorrected` | Diagnostics & Studies | Выпущена коррекция результата | `correction_id`, `original_result_id`, `reason_code` |
| `AIMedicalRunCompleted` | AI Medical Run | Успешно завершён инференс | `run_id`, `model_version`, `order_id` или `result_id`, `interpretation_id`, `confidence_summary` |
| `AIMedicalRunFailed` | AI Medical Run | Ошибка пайплайна | `run_id`, `error_code`, `retryable` |
| `CreditAgreementCreated` | Lending | Создан кредитный договор (черновик/подписанный по правилам продукта) | `agreement_id`, `party_reference`, `product_code`, `principal_amount`, `currency` |
| `CreditAgreementActivated` | Lending | Договор вступил в силу | `agreement_id`, `activated_at`, `first_payment_date` |
| `PaymentPosted` | Accounts & Payments | Проведён платёж | `payment_id`, `account_id`, `amount`, `currency`, `payment_reference` |
| `AccountBalanceChanged` | Accounts & Payments | Изменился доступный остаток | `account_id`, `new_balance`, `reason` |
| `ShiftAssigned` | Clinical Operations | Назначена смена сотруднику | `shift_id`, `employee_id`, `site_id`, `interval` |
| `InventoryThresholdBreached` | Clinical Operations | Остаток ниже порога | `sku_id`, `location_id`, `quantity` |
| `PartnerCatalogUpdated` | External Integration | Обновлён справочник партнёра | `contract_id`, `catalog_version`, `effective_from` |
| `EquipmentShipmentStatusChanged` | External Integration | Изменился статус поставки оборудования | `shipment_id`, `status`, `eta` |
| `ConsentUpdated` | IAM & Consent | Изменилось согласие | `consent_id`, `user_id` или `patient_link_token`, `purpose`, `granted` |
| `AccessGranted` | IAM & Consent | Выдано право на действие/роль | `grant_id`, `principal_id`, `role`, `scope`, `expires_at` |

## Подписчики (целевое состояние)

| Событие | Подписчик | Реакция |
|---------|-----------|---------|
| `PatientRegistered` | IAM & Consent | Создание или связывание цифровой идентичности пациента, проверка согласий |
| `PatientRegistered` | Analytics & Data Products | Обновление витрины «клиенты/поток» без PHI |
| `PatientRegistered` | Lending | Инициация KYC/скоринга при связке продукта |
| `EncounterOpened` | Clinical Operations | Резервирование ресурсов (политика) |
| `StudyCompleted` | AI Medical Run | Автозапуск модели по политике модальности |
| `StudyCorrected` | Clinical Care | Обновление клинической записи ссылкой на корректирующий результат |
| `StudyCorrected` | AI Medical Run | Переоценка необходимости повторного инференса |
| `AIMedicalRunCompleted` | Clinical Care | Прикрепление заключения к эпизоду (черновик для врача) |
| `CreditAgreementCreated` | Accounts & Payments | Создание счетовых объектов и лимитов |
| `CreditAgreementActivated` | Accounts & Payments | Активация графика списаний |
| `PaymentPosted` | Analytics & Data Products | Финансовые потоки и касса |
| `ConsentUpdated` | Clinical Care, Diagnostics & Studies, AI Medical Run, Analytics & Data Products, Lending | Остановка обработки, маскирование или отзыв доступа по политике согласия |

## Совместимость и эволюция

- Добавление полей — backward compatible в пределах мажорной линии схемы.
- Изменение смысла — новое имя события или новая мажорная версия с двойной публикацией на период миграции.
- Потребители обязаны быть **идемпотентны** по `event_id`.
