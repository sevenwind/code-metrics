import Foundation
import Observation

enum AppLanguage: String, CaseIterable, Identifiable {
    case en, ru
    var id: String { rawValue }
    var name: String { self == .en ? "English" : "Русский" }
}

/// Текущий язык интерфейса. По умолчанию английский; меняется в настройках (⌘,) без перезапуска.
@Observable
final class Localizer {
    static let shared = Localizer()
    private static let key = "appLanguage"
    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.key) }
    }
    private init() {
        language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: Self.key) ?? "") ?? .en
    }
}

/// Локализация строки. Ключ — русский текст (исходный язык), для английского берётся перевод из `englishStrings`.
/// Аргументы подставляются через String(format:), как в ключе: %@ — строка, %ld — целое.
func tr(_ key: String, _ args: CVarArg...) -> String {
    let template = Localizer.shared.language == .ru ? key : (englishStrings[key] ?? key)
    return args.isEmpty ? template : String(format: template, arguments: args)
}

let englishStrings: [String: String] = [
    "%.1f%% от непустых": "%.1f%% of non-blank",
    "%@ · %ld ф.": "%@ · %ld files",
    "%@ · файлов: %ld": "%@ · files: %ld",
    "%@ из %@": "%@ of %@",
    "%@ ф.": "%@ files",
    "%ld файлов · %@ строк кода": "%ld files · %@ lines of code",
    "Анализ… %ld%%": "Analyzing… %ld%%",
    "Вернуть путь в анализ и пересканировать": "Put this path back into the analysis and rescan",
    "Вернуть": "Restore",
    "Включить": "Include",
    "Вложен.": "Nest.",
    "Вложенность": "Nesting",
    "Все языки": "All languages",
    "Выберите отчёт покрытия: lcov.info, coverage-final.json или coverage.out (Go)": "Choose a coverage report: lcov.info, coverage-final.json or coverage.out (Go)",
    "Выберите папку проекта": "Choose the project folder",
    "Выбрать папку проекта для анализа": "Choose a project folder to analyze",
    "Выбрать файл отчёта…": "Choose report file…",
    "Двойной клик — открыть файл": "Double-click to open the file",
    "Длина функции": "Function length",
    "Длина": "Length",
    "Доля комментариев": "Comment ratio",
    "Доля строк кода, выполненных при запуске тестов (line coverage). Берётся из готового отчёта (lcov.info, coverage-final.json, Go coverage.out) — приложение само тесты не запускает. Для функции считается по строкам внутри неё; «—» значит, что в отчёте нет данных. ≥ 80% — хорошо, 50–80% — внимание, < 50% — плохо.":
        "Share of code lines executed when running the tests (line coverage). Taken from an existing report (lcov.info, coverage-final.json, Go coverage.out). For a function it is computed over the lines inside it; “—” means the report has no data. ≥ 80% good, 50–80% warning, < 50% bad.",
    "Доля строк-комментариев среди непустых строк файла.": "Share of comment lines among the non-blank lines of the file.",
    "зависимости/артефакты, по умолчанию": "dependencies/build artifacts, skipped by default",
    "Загрузить отчёт покрытия тестами (lcov.info, coverage-final.json, coverage.out)": "Load a test coverage report (lcov.info, coverage-final.json, coverage.out)",
    "Запустить тесты и создать отчёт о покрытии": "Run tests and create a coverage report",
    "Идёт запуск тестов и сбор покрытия": "Running tests and collecting coverage",
    "из 100, средневзвешенно": "out of 100, weighted average",
    "Индекс поддерживаемости от 0 до 100 (формула Visual Studio, на основе объёма Холстеда, цикломатики и размера). Чем выше, тем легче поддерживать код. ≥ 40 — хорошо, 20–40 — внимание, < 20 — плохо. Для проекта берётся среднее, взвешенное по строкам кода.":
        "Maintainability index from 0 to 100 (Visual Studio formula based on size, cyclomatic complexity and volume). The higher, the easier the code is to maintain. ≥ 40 good, 20–40 warning, < 20 bad. For the project it is the average weighted by lines of code.",
    "Искать отчёт в стандартных местах проекта (coverage/lcov.info и т. п.)": "Look for the report in the usual places of the project (coverage/lcov.info etc.)",
    "исключено вами": "excluded by you",
    "Исключить из анализа": "Exclude from analysis",
    "Исключить папку из анализа": "Exclude folder from analysis",
    "Исключить файл из анализа": "Exclude file from analysis",
    "Когнитивная сложность (Cog)": "Cognitive complexity (Cog)",
    "Код / комм. / пустых": "Code / comments / blank",
    "Код": "Code",
    "Количество параметров функции. Много параметров (обычно > 4–5) усложняют вызов и часто говорят о слишком широкой ответственности.":
        "Number of function parameters. Many parameters (usually > 4–5) make calls harder and often mean the function does too much.",
    "Количество проанализированных файлов с исходным кодом. Исключённые папки и зависимости не учитываются.":
        "Number of analyzed source files. Excluded folders and dependencies are not counted.",
    "Количество строк в теле функции. ≤ 50 — норма, 51–100 — длинная, > 100 — слишком длинная.":
        "Number of lines in the function body. ≤ 50 normal, 51–100 long, > 100 too long.",
    "Количество строк-комментариев. Процент считается от непустых строк (код + комментарии).":
        "Number of comment lines. The percentage is computed from non-blank lines (code + comments).",
    "Комм.": "Cmt.",
    "Комментарии": "Comments",
    "Копировать путь": "Copy path",
    "Максимальная глубина вложенности управляющих конструкций (if, циклы, switch, try) внутри функции.":
        "Maximum nesting depth of control structures (if, loops, switch, try) inside the function.",
    "Метрики кода": "Code Metrics",
    "Наибольшая когнитивная сложность среди функций файла. ≤ 15 — норма, 16–25 — повышенная, > 25 — высокая.":
        "Highest cognitive complexity among the functions of the file. ≤ 15 normal, 16–25 elevated, > 25 high.",
    "Наибольшая цикломатическая сложность среди функций файла. ≤ 10 — норма, 11–20 — повышенная, > 20 — высокая.":
        "Highest cyclomatic complexity among the functions of the file. ≤ 10 normal, 11–20 elevated, > 20 high.",
    "Найти автоматически": "Find automatically",
    "Насколько трудно функцию понять человеку. Как и CC учитывает ветвления, но добавляет штраф за вложенность: if внутри цикла «стоит» дороже, чем два if подряд. ≤ 15 — норма, 16–25 — повышенная, > 25 — высокая.":
        "How hard the function is for a human to understand. Like CC it counts branches, but adds a penalty for nesting: an if inside a loop “costs” more than two ifs in a row. ≤ 15 normal, 16–25 elevated, > 25 high.",
    "Не анализируется": "Not analyzed",
    "Не найден go.mod или package.json": "No go.mod or package.json found",
    "Не удалось разобрать %@": "Could not parse %@",
    "Недавние": "Recent",
    "Ничего не исключено": "Nothing excluded",
    "Открыть недавний проект: %@": "Open recent project: %@",
    "Открыть папку проекта для анализа (⌘O)": "Open a project folder for analysis (⌘O)",
    "Открыть папку": "Open Folder",
    "Открыть папку…": "Open Folder…",
    "Открыть файл": "Open file",
    "Открыть": "Open",
    "Отмена": "Cancel",
    "отчёт не найден": "no report found",
    "Отчёт не найден": "Report not found",
    "Папка": "Folder",
    "Парам.": "Params",
    "Параметры": "Parameters",
    "Пересканировать проект заново (⌘R)": "Rescan the project (⌘R)",
    "Пересканировать": "Rescan",
    "Перетащите папку проекта в окно или выберите её вручную.\nTypeScript, JavaScript, Go.": "Drag a project folder into the window or choose it manually.\nTypeScript, JavaScript, Go.",
    "Поиск по файлам и функциям": "Search files and functions",
    "Показано файлов из общего числа": "Files shown out of the total",
    "Показано функций из общего числа": "Functions shown out of the total",
    "Показать в Finder": "Show in Finder",
    "Показывать только функции с цикломатической сложностью не ниже этого порога": "Show only functions with cyclomatic complexity at or above this threshold",
    "Показывать файлы только выбранного языка": "Show only files of the selected language",
    "Покрытие тестами (Cov)": "Test coverage (Cov)",
    "Покрытие тестами": "Test coverage",
    "Прервать анализ": "Stop the analysis",
    "Проанализировано — правый клик по папке, чтобы исключить": "Analyzed — right-click a folder to exclude it",
    "Прогресс анализа файлов": "File analysis progress",
    "Пропущено: %ld": "Skipped: %ld",
    "Просканировано за %.1f с": "Scanned in %.1f s",
    "Распределение сложности функций": "Function complexity distribution",
    "Распределение сложности": "Complexity distribution",
    "Распределение строк кода по языкам. Рядом с каждым — число файлов.": "Lines of code per language, with the number of files next to each.",
    "Самые сложные функции": "Most complex functions",
    "Сканировать": "Scan",
    "Сколько функций попадает в каждый диапазон цикломатической сложности: зелёный — норма, оранжевый — повышенная, красный — высокая.":
        "How many functions fall into each cyclomatic complexity range: green normal, orange elevated, red high.",
    "Сложные функции без покрытия": "Complex functions without coverage",
    "Сложные функции": "Complex functions",
    "Сложных функций": "Complex functions",
    "Средняя CC": "Average CC",
    "Строк всего": "Total lines",
    "Строк кода в папке (с вложенными)": "Lines of code in the folder (including subfolders)",
    "строка %ld · %ld стр. · %ld парам.": "line %ld · %ld lines · %ld params",
    "Строки кода (LOC)": "Lines of code (LOC)",
    "Строки кода": "Lines of code",
    "Строки, содержащие код. Пустые строки и строки только с комментариями не считаются.": "Lines that contain code. Blank lines and comment-only lines are not counted.",
    "Таких нет": "None",
    "Тесты выполняются…": "Running tests…",
    "Тесты завершились с ошибкой (%ld)": "Tests failed (exit code %ld)",
    "Тесты прошли, но отчёт не создан": "Tests passed, but no report was produced",
    "Тесты": "Tests",
    "Указать lcov.info, coverage-final.json или coverage.out вручную": "Pick lcov.info, coverage-final.json or coverage.out manually",
    "Учитывать тестовые файлы (*.test.*, *.spec.*, *_test.go) при следующем сканировании": "Include test files (*.test.*, *.spec.*, *_test.go) on the next scan",
    "Файл разобран с синтаксическими ошибками": "The file was parsed with syntax errors",
    "Файл": "File",
    "Файлов в папке (с вложенными)": "Files in the folder (including subfolders)",
    "Файлы с худшей поддерживаемостью": "Files with the worst maintainability",
    "Файлы с худшим покрытием": "Files with the worst coverage",
    "Файлы": "Files",
    "Функц.": "Func.",
    "Функции (%ld)": "Functions (%ld)",
    "Функции с цикломатической сложностью больше 10 — их сложно читать и тестировать, это кандидаты на рефакторинг.":
        "Functions with cyclomatic complexity above 10 — hard to read and test, candidates for refactoring.",
    "Функции": "Functions",
    "Функций": "Functions",
    "Функция": "Function",
    "Цикломатика ≥ %ld": "Cyclomatic ≥ %ld",
    "цикломатика > 10": "cyclomatic > 10",
    "Цикломатическая сложность (CC)": "Cyclomatic complexity (CC)",
    "Число найденных функций, методов и стрелочных функций во всех файлах.": "Number of functions, methods and arrow functions found across all files.",
    "Число независимых путей выполнения функции: 1 + количество ветвлений (if, for, while, case, catch, &&, || и т. п.). Показывает, сколько тестов нужно для покрытия. ≤ 10 — норма, 11–20 — повышенная, > 20 — высокая.":
        "Number of independent execution paths through a function: 1 + number of branches (if, for, while, case, catch, &&, || etc.). Shows how many tests are needed to cover it. ≤ 10 normal, 11–20 elevated, > 20 high.",
    "Экспорт в CSV…": "Export to CSV…",
    "Язык программирования файла.": "Programming language of the file.",
    "Язык": "Language",
    "Языки (строки кода)": "Languages (lines of code)",
    "Языки": "Languages",
    "Запустить тесты": "Run tests",
    "Обзор": "Overview",
    "Папки": "Folders",
    "Команда: %@": "Command: %@",
    "Код завершения: %ld": "Exit code: %ld",
    "Команда не найдена: node/npx или go недоступны в PATH приложения.": "Command not found: node/npx or go is not available in the app's PATH.",
    "Не установлен провайдер покрытия для vitest. Установите его: npm i -D @vitest/coverage-v8": "The vitest coverage provider is not installed. Install it: npm i -D @vitest/coverage-v8",
    "Тесты не найдены: проверьте, что в проекте есть тестовые файлы и настроен тест-раннер.": "No tests found: make sure the project has test files and a configured test runner.",
    "Не найден модуль или команда: выполните установку зависимостей (npm install).": "A module or command is missing: install the dependencies (npm install).",
    "Тесты упали или команда завершилась с ошибкой. Подробности — в выводе ниже.": "Tests failed or the command exited with an error. See the output below for details.",
    "Команда завершилась успешно, но ни одного файла отчёта не появилось. Искали: %@.": "The command finished successfully, but no report file appeared. Looked for: %@.",
    "Возможные причины: используется другой тест-раннер (мы запускаем jest/vitest/go test), в конфиге покрытия указан свой каталог или формат (нужен lcov, json или coverage.out), либо покрытие отключено. Укажите готовый отчёт вручную: меню «Покрытие тестами» → «Выбрать файл отчёта…».":
        "Possible reasons: the project uses another test runner (we run jest/vitest/go test), the coverage config uses a custom directory or format (lcov, json or coverage.out are needed), or coverage is disabled. Pick an existing report manually: “Test coverage” menu → “Choose report file…”.",
    "Отчёт найден, но не подошёл": "Report found but unusable",
    "Файл отчёта найден, но не удалось сопоставить его с файлами проекта или разобрать формат.": "A report file was found, but it could not be matched to project files or its format could not be parsed.",
    "Конец вывода:": "End of output:",
    "Тип проекта не определён: в корне нет ни go.mod, ни package.json. Укажите готовый отчёт вручную.": "Project type not detected: there is neither go.mod nor package.json in the root. Pick an existing report manually.",
    "Файл %@ найден, но его не удалось разобрать или ни одна запись не совпала с файлами проекта (поддерживаются lcov, Istanbul coverage-final.json и Go coverage.out).": "File %@ was found, but it could not be parsed or none of its entries matched project files (supported: lcov, Istanbul coverage-final.json and Go coverage.out).",
    "Индекс CRAP": "CRAP index",
    "CRAP = CC² × (1 − покрытие)³ + CC. Показывает, насколько функция одновременно сложна и плохо покрыта тестами: чем выше, тем рискованнее её менять. ≤ 5 — безопасно, до 30 — терпимо, > 30 — «crappy», нужен рефакторинг или тесты. Считается только для функций с данными о покрытии.":
        "CRAP = CC² × (1 − coverage)³ + CC. Shows how complex and poorly tested a function is at the same time: the higher, the riskier it is to change. ≤ 5 safe, up to 30 tolerable, > 30 “crappy” — needs refactoring or tests. Computed only for functions with coverage data.",
    "среднее · макс. %@ · функций > 30: %ld": "average · max %@ · functions > 30: %ld",
    "Неактивно": "Inactive",
    "Приложение по умолчанию": "Default application",
    "Открыть в редакторе": "Open in editor",
    "Открыть проект в %@": "Open the project in %@",
    "Редактор": "Editor",
    "(не установлен)": "(not installed)",
    "К выбору проекта": "Back to project selection",
    "Закрыть проект и вернуться к выбору папки": "Close the project and return to folder selection",
    "макс. %@ · функций > 30: %ld": "max %@ · functions > 30: %ld",
    "Неактивно: нужен отчёт покрытия": "Inactive: coverage report required",
    "≤ 1 — зелёный, ≥ 30 — красный": "≤ 1 green, ≥ 30 red",
    "нужен отчёт покрытия тестами": "a test coverage report is required",
    "Индекс CRAP считается по покрытию тестами: запустите тесты или выберите отчёт покрытия.": "The CRAP index is based on test coverage: run the tests or pick a coverage report.",
    // Настройки
    "Язык интерфейса": "Interface language",
]
