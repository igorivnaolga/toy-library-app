# toy-library-app

## Тема дослідження (Project Theme)

Розробка мобільної інформаційної системи управління бібліотекою іграшок (Toy Library) з інтеграцією методів комп'ютерного зору для автоматизації інвентаризації


## Проблема (Problem Statement)
Економічний аспект: Висока вартість підписки на існуючі SaaS-рішення (SETLS), що є критичним тягарем для волонтерських та community-проєктів.

Операційний аспект: Фрагментованість процесів (ручне ведення каталогів, паперовий облік) призводить до помилок при поверненні іграшок (втрата деталей).

Технічний аспект: Відсутність спеціалізованих мобільних рішень з підтримкою AI для швидкої перевірки комплектації іграшок "на місці".

## Мета дослідження (Project Purpose)
Розробити та впровадити архітектуру безкоштовної мобільно-орієнтованої системи управління бібліотекою іграшок, яка дозволить автоматизувати життєвий цикл оренди та підвищити точність контролю інвентарю за допомогою алгоритмів комп'ютерного зору.

## Завдання дослідження (Objectives)

Аналіз предметної області та реінжиніринг процесів: Проведення порівняльного аналізу існуючих рішень (зокрема SETLS) та формалізація вимог до безкоштовної альтернативи з відкритим кодом для волонтерських організацій.

Проектування хмарної архітектури та бази даних: Розробка структури БД у Supabase та проектування рольової моделі доступу для забезпечення безпечної взаємодії гостей, членів бібліотеки та адміністраторів.

Формування та підготовка датасету: Збір, анотування та препроцесинг набору зображень іграшок (різних категорій та станів комплектації) для подальшого навчання нейронної мережі.

Розробка та навчання інтелектуального модуля: Вибір оптимальної архітектури нейромережі (YOLO) та проведення процесу fine-tuning для автоматизації детекції об'єктів та перевірки комплектації під час повернення іграшок.

Реалізація серверної логіки (Backend): Розробка високопродуктивного API на базі FastAPI для обробки запитів, інтеграції з AI-моделлю та управління сховищем зображень у Supabase Storage.

Розробка кросплатформенного мобільного клієнта: Реалізація користувацького інтерфейсу на Flutter з інтеграцією push-сповіщень через FCM та реалізацією логіки сканування в реальному часі.

Валідація та тестування: Оцінка точності навченої моделі (метрики mAP, Precision, Recall) та проведення функціонального тестування системи в умовах, максимально наближених до реальної діяльності бібліотеки іграшок.


## Project Theme
AI-assisted mobile Toy Library Management System for community toy libraries, designed to improve catalog access, booking and lending workflows, and inventory control through role-based user journeys and computer-vision-assisted check-in.

## Project Purpose
This diploma project aims to design and implement a mobile-first information system that replaces fragmented manual toy library operations with a centralized digital platform.
The system enables guests, members, and administrators to work with the toy catalog and lending workflows efficiently, while adding AI-assisted inventory verification to reduce check-in errors during toy returns.

## Completed Steps

- Step 1: Backend bootstrap added (`FastAPI` app entrypoint, API router, health endpoint, `requirements.txt`, `.env.example`).
- Step 2: Backend architecture scaffold added (`core`, `db`, `models`, `schemas`, `repositories`, `services`, `scripts`, `tests`).
- Step 3: API endpoint stubs added and wired for `GET /toys`, `GET /toys/{toy_id}`, and `GET /categories`.
- Step 4: Mobile Flutter scaffold added (`mobile/` structure with `core` and feature folders for `catalog`, `auth`, `bookings`, `admin`).
- Step 5: Project theme and purpose added to `README.md`.

## Next Steps

- Implement real database models and migrations for toys, categories, users, bookings, and loans.
- Implement CSV seed import from `export_imgs/toy_photo_map_by_description.csv`.
- Replace API stubs with real search, filter, and pagination logic.
- Connect Flutter catalog screens to backend API endpoints.
