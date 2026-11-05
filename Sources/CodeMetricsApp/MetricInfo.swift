import SwiftUI

/// Описания метрик для подсказок.
enum Metric: String {
    case coverage, crap, ca, ce, instability, abstractness, distance, wmc, cbo, files, loc, comments, functions, maintainability, complexFunctions
    case language, commentRatio, maxCC, maxCog, cc, cog, length, params, nesting
    case languagesChart, complexityChart

    var title: String {
        switch self {
        case .coverage: tr("Покрытие тестами (Cov)")
        case .crap: tr("Индекс CRAP")
        case .ca: tr("Ca — входящие зависимости")
        case .ce: tr("Ce — исходящие зависимости")
        case .instability: tr("I — нестабильность")
        case .abstractness: tr("A — абстрактность")
        case .distance: tr("D — расстояние до главной последовательности")
        case .wmc: tr("WMC — взвешенная сложность методов")
        case .cbo: tr("CBO — связанность класса")
        case .files: tr("Файлы")
        case .loc: tr("Строки кода (LOC)")
        case .comments: tr("Комментарии")
        case .functions: tr("Функции")
        case .maintainability: "Maintainability Index (MI)"
        case .complexFunctions: tr("Сложные функции")
        case .language: tr("Язык")
        case .commentRatio: tr("Доля комментариев")
        case .maxCC: "Max CC"
        case .maxCog: "Max Cog"
        case .cc: tr("Цикломатическая сложность (CC)")
        case .cog: tr("Когнитивная сложность (Cog)")
        case .length: tr("Длина функции")
        case .params: tr("Параметры")
        case .nesting: tr("Вложенность")
        case .languagesChart: tr("Языки")
        case .complexityChart: tr("Распределение сложности")
        }
    }

    var text: String {
        switch self {
        case .coverage: tr("Доля строк кода, выполненных при запуске тестов (line coverage). Берётся из готового отчёта (lcov.info, coverage-final.json, Go coverage.out) — приложение само тесты не запускает. Для функции считается по строкам внутри неё; «—» значит, что в отчёте нет данных. ≥ 80% — хорошо, 50–80% — внимание, < 50% — плохо.")
        case .crap: tr("CRAP = CC² × (1 − покрытие)³ + CC. Показывает, насколько функция одновременно сложна и плохо покрыта тестами: чем выше, тем рискованнее её менять. ≤ 5 — безопасно, до 30 — терпимо, > 30 — «crappy», нужен рефакторинг или тесты. Считается только для функций с данными о покрытии.")
        case .ca: tr("Афферентная связь: сколько других пакетов (папок) зависят от этого. Много — пакет ответственный, его изменения заденут многих.")
        case .ce: tr("Эфферентная связь: от скольких других пакетов зависит этот. Много — пакет сильно зависим и хрупок.")
        case .instability: tr("I = Ce / (Ca + Ce), от 0 до 1. 0 — максимально устойчивый пакет (зависят от него, а он почти ни от чего), 1 — нестабильный (зависит от других, от него не зависят). Прочерк — у пакета нет связей.")
        case .abstractness: tr("Доля абстрактных типов (interface, abstract class, Go interface) среди всех типов пакета, от 0 до 1. Прочерк — в пакете нет типов.")
        case .distance: tr("D = |A + I − 1| — расстояние до «главной последовательности», идеального баланса абстрактности и стабильности. 0 — идеально. Стабильный и конкретный пакет — «зона боли», нестабильный и абстрактный — «зона бесполезности». ≤ 0.2 — хорошо, ≤ 0.5 — внимание, выше — плохо.")
        case .wmc: tr("Сумма цикломатической сложности всех методов класса (для Go — методов структуры). ≤ 20 — норма, 21–50 — повышенная, > 50 — класс слишком тяжёлый.")
        case .cbo: tr("Приближённо: число разных импортированных модулей и типов, которые использует класс. Считается по импортам и их использованию внутри класса, без разрешения типов. ≤ 9 — норма, 10–14 — повышенная, > 14 — высокая связанность.")
        case .files: tr("Количество проанализированных файлов с исходным кодом. Исключённые папки и зависимости не учитываются.")
        case .loc: tr("Строки, содержащие код. Пустые строки и строки только с комментариями не считаются.")
        case .comments: tr("Количество строк-комментариев. Процент считается от непустых строк (код + комментарии).")
        case .functions: tr("Число найденных функций, методов и стрелочных функций во всех файлах.")
        case .maintainability: tr("Индекс поддерживаемости от 0 до 100 (формула Visual Studio, на основе объёма Холстеда, цикломатики и размера). Чем выше, тем легче поддерживать код. ≥ 40 — хорошо, 20–40 — внимание, < 20 — плохо. Для проекта берётся среднее, взвешенное по строкам кода.")
        case .complexFunctions: tr("Функции с цикломатической сложностью больше 10 — их сложно читать и тестировать, это кандидаты на рефакторинг.")
        case .language: tr("Язык программирования файла.")
        case .commentRatio: tr("Доля строк-комментариев среди непустых строк файла.")
        case .maxCC: tr("Наибольшая цикломатическая сложность среди функций файла. ≤ 10 — норма, 11–20 — повышенная, > 20 — высокая.")
        case .maxCog: tr("Наибольшая когнитивная сложность среди функций файла. ≤ 15 — норма, 16–25 — повышенная, > 25 — высокая.")
        case .cc: tr("Число независимых путей выполнения функции: 1 + количество ветвлений (if, for, while, case, catch, &&, || и т. п.). Показывает, сколько тестов нужно для покрытия. ≤ 10 — норма, 11–20 — повышенная, > 20 — высокая.")
        case .cog: tr("Насколько трудно функцию понять человеку. Как и CC учитывает ветвления, но добавляет штраф за вложенность: if внутри цикла «стоит» дороже, чем два if подряд. ≤ 15 — норма, 16–25 — повышенная, > 25 — высокая.")
        case .length: tr("Количество строк в теле функции. ≤ 50 — норма, 51–100 — длинная, > 100 — слишком длинная.")
        case .params: tr("Количество параметров функции. Много параметров (обычно > 4–5) усложняют вызов и часто говорят о слишком широкой ответственности.")
        case .nesting: tr("Максимальная глубина вложенности управляющих конструкций (if, циклы, switch, try) внутри функции.")
        case .languagesChart: tr("Распределение строк кода по языкам. Рядом с каждым — число файлов.")
        case .complexityChart: tr("Сколько функций попадает в каждый диапазон цикломатической сложности: зелёный — норма, оранжевый — повышенная, красный — высокая.")
        }
    }
}

/// Значок «?» в круге: при наведении — системный тултип, по клику — popover с описанием.
struct InfoButton: View {
    let metric: Metric
    @Environment(AppModel.self) private var model

    var body: some View {
        let shown = Binding<Bool>(
            get: { model.infoShown == metric },
            set: { model.infoShown = $0 ? metric : nil })
        Button { shown.wrappedValue.toggle() } label: {
            Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(metric.text)
        .popover(isPresented: shown, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text(metric.title).font(.headline)
                Text(metric.text).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            .padding(12).frame(width: 300, alignment: .leading)
        }
    }
}

/// Заголовок с кнопкой подсказки.
struct InfoLabel: View {
    let text: String
    let metric: Metric
    var body: some View {
        HStack(spacing: 4) { Text(text); InfoButton(metric: metric).font(.caption) }
    }
}

/// Строка «Что значат колонки»: подпись + «?» для каждой метрики таблицы.
struct MetricLegend: View {
    let items: [(String, Metric)]
    var body: some View {
        HStack(spacing: 12) {
            ForEach(items.indices, id: \.self) { i in
                InfoLabel(text: items[i].0, metric: items[i].1)
            }
        }
        .font(.caption).foregroundStyle(.secondary)
    }
}
