import Foundation

enum Lang: String, CaseIterable, Identifiable {
    case ru, he, en
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ru: return "Русский"
        case .he: return "עברית"
        case .en: return "English"
        }
    }
    var localeID: String {
        switch self {
        case .ru: return "ru_RU"
        case .he: return "he_IL"
        case .en: return "en_US"
        }
    }
}

/// Simple built-in translations: key -> (ru, he, en)
enum Strings {
    static let table: [String: (String, String, String)] = [
        "app.tagline": ("Уход за Mac", "תחזוקה למק", "Mac care"),

        "nav.overview": ("Обзор", "סקירה", "Overview"),
        "nav.maintenance": ("Обслуживание", "תחזוקה", "Maintenance"),
        "nav.bigfiles": ("Большие файлы", "קבצים גדולים", "Large files"),
        "nav.tweaks": ("Настройки macOS", "הגדרות macOS", "macOS tweaks"),
        "nav.log": ("Журнал", "יומן", "Log"),

        "ui.language": ("Язык", "שפה", "Language"),
        "ui.theme": ("Тема", "ערכת נושא", "Theme"),
        "theme.light": ("Светлая", "בהירה", "Light"),
        "theme.dark": ("Тёмная", "כהה", "Dark"),
        "theme.system": ("Как в системе", "לפי המערכת", "System"),

        "ov.subtitle": ("Состояние вашего Mac одним взглядом", "מצב המק במבט אחד", "Your Mac at a glance"),
        "ov.macos": ("Версия macOS", "גרסת macOS", "macOS version"),
        "ov.model": ("Модель", "דגם", "Model"),
        "ov.cpu": ("Процессор", "מעבד", "Processor"),
        "ov.memory": ("Память", "זיכרון", "Memory"),
        "ov.uptime": ("Без перезагрузки", "ללא אתחול", "Uptime"),
        "ov.disk": ("Системный диск", "דיסק המערכת", "Startup disk"),
        "ov.free": ("свободно", "פנוי", "free"),
        "ov.of": ("из", "מתוך", "of"),
        "ov.smart": ("Здоровье диска (SMART)", "בריאות הדיסק (SMART)", "Disk health (SMART)"),
        "ov.smartOK": ("В порядке", "תקין", "Verified"),
        "ov.verify": ("Проверить диск", "בדיקת דיסק", "Verify disk"),
        "ov.verifying": ("Проверяю диск…", "בודק את הדיסק…", "Verifying disk…"),
        "ov.verifyOK": ("Диск в порядке", "הדיסק תקין", "The disk is OK"),
        "ov.verifyFail": ("Найдены проблемы — смотрите журнал", "נמצאו בעיות — ראו ביומן", "Problems found — see the log"),
        "ov.verifyHint": ("Проверка файловой системы, ничего не меняет. Занимает 1–5 минут.", "בדיקת מערכת הקבצים, לא משנה כלום. לוקחת 1–5 דקות.", "Checks the file system without changing anything. Takes 1–5 minutes."),
        "ov.refresh": ("Обновить", "רענון", "Refresh"),
        "ov.lowSpace": ("Мало места на диске — загляните в «Большие файлы»", "מעט מקום בדיסק — כדאי לבדוק ב״קבצים גדולים״", "Low disk space — check “Large files”"),

        "m.subtitle": ("Отметьте, что сделать, и нажмите «Запустить». Перед запуском лучше закрыть другие программы.", "סמנו מה לבצע ולחצו ״הפעלה״. מומלץ לסגור תוכנות אחרות לפני כן.", "Tick what to do and press Run. Closing other apps first is recommended."),
        "m.groupUser": ("Без пароля", "ללא סיסמה", "No password needed"),
        "m.groupAdmin": ("Нужен пароль администратора (спросит один раз)", "דרושה סיסמת מנהל (תתבקש פעם אחת)", "Administrator password (asked once)"),
        "m.run": ("Запустить выбранное", "הפעלת הנבחרים", "Run selected"),
        "m.running": ("Работаю…", "עובד…", "Working…"),
        "m.done": ("Готово", "הסתיים", "Done"),
        "m.freed": ("Освобождено", "התפנו", "Freed"),
        "m.all": ("Всё", "הכל", "All"),
        "m.none": ("Ничего", "כלום", "None"),
        "m.recommended": ("Рекомендуемое", "מומלץ", "Recommended"),
        "m.cancelled": ("Пароль не введён — задачи с паролем пропущены", "לא הוזנה סיסמה — משימות המנהל דולגו", "No password — admin tasks skipped"),

        "t.userCaches": ("Кэши программ", "מטמון תוכנות", "App caches"),
        "d.userCaches": ("Временные файлы программ в вашей папке. Программы создадут их заново.", "קבצים זמניים של תוכנות בתיקייה שלך. התוכנות ייצרו אותם מחדש.", "Temporary app files in your home folder. Apps recreate them."),
        "t.userLogs": ("Журналы программ", "קבצי לוג של תוכנות", "App logs"),
        "d.userLogs": ("Старые отчёты и логи программ.", "דוחות ולוגים ישנים של תוכנות.", "Old app reports and logs."),
        "t.trash": ("Очистить корзину", "ריקון סל האשפה", "Empty the Trash"),
        "d.trash": ("Удаляет файлы из корзины навсегда.", "מוחק לצמיתות את הקבצים מהסל.", "Permanently deletes files in the Trash."),
        "t.quicklook": ("Миниатюры Quick Look", "תמונות ממוזערות Quick Look", "Quick Look thumbnails"),
        "d.quicklook": ("Помогает, если превью файлов показываются неправильно.", "עוזר כשתצוגות מקדימות מוצגות לא נכון.", "Helps when file previews look wrong."),
        "t.fonts": ("Кэш шрифтов", "מטמון גופנים", "Font cache"),
        "d.fonts": ("Помогает при «кривых» или пропавших шрифтах. Потом лучше перезагрузить Mac.", "עוזר כשגופנים מוצגים לא נכון או נעלמים. מומלץ לאתחל אחרי.", "Helps with broken or missing fonts. Restart afterwards."),
        "t.launchServices": ("База «Открыть с помощью»", "מאגר ״פתח באמצעות״", "“Open With” database"),
        "d.launchServices": ("Убирает дубли в меню «Открыть с помощью» и чинит значки.", "מסיר כפילויות בתפריט ״פתח באמצעות״ ומתקן סמלים.", "Removes duplicates in the Open With menu and fixes icons."),
        "t.restartFinder": ("Перезапустить Finder и Dock", "הפעלה מחדש של Finder ו־Dock", "Restart Finder and Dock"),
        "d.restartFinder": ("Применяет изменения сразу.", "מחיל את השינויים מיד.", "Applies changes right away."),
        "t.dns": ("Сбросить кэш DNS", "איפוס מטמון DNS", "Flush DNS cache"),
        "d.dns": ("Помогает, если сайты не открываются или открываются старые.", "עוזר כשאתרים לא נפתחים או מציגים גרסה ישנה.", "Helps when websites don't load or show old versions."),
        "t.purge": ("Освободить память", "שחרור זיכרון", "Free up memory"),
        "d.purge": ("Очищает неактивную оперативную память.", "מנקה זיכרון RAM לא פעיל.", "Clears inactive RAM."),
        "t.spotlight": ("Перестроить поиск Spotlight", "בנייה מחדש של חיפוש Spotlight", "Rebuild Spotlight index"),
        "d.spotlight": ("Если поиск не находит файлы. Идёт в фоне до часа.", "כשהחיפוש לא מוצא קבצים. רץ ברקע עד שעה.", "When search can't find files. Runs in background up to an hour."),
        "t.systemCaches": ("Системные кэши", "מטמון מערכת", "System caches"),
        "d.systemCaches": ("Временные файлы для всех пользователей.", "קבצים זמניים של כל המשתמשים.", "Temporary files for all users."),
        "t.diagReports": ("Отчёты о сбоях", "דוחות קריסה", "Crash reports"),
        "d.diagReports": ("Старые системные отчёты о сбоях программ.", "דוחות קריסה ישנים של המערכת.", "Old system crash reports."),

        "b.subtitle": ("Найдите, что занимает место: видео, архивы, старые проекты.", "מצאו מה תופס מקום: סרטונים, ארכיונים, פרויקטים ישנים.", "Find what takes up space: videos, archives, old projects."),
        "b.folder": ("Папка", "תיקייה", "Folder"),
        "b.choose": ("Выбрать…", "בחירה…", "Choose…"),
        "b.minSize": ("Не меньше", "לפחות", "At least"),
        "b.scan": ("Искать", "חיפוש", "Scan"),
        "b.scanning": ("Ищу…", "מחפש…", "Scanning…"),
        "b.found": ("Найдено файлов", "נמצאו קבצים", "Files found"),
        "b.total": ("всего", "סה״כ", "total"),
        "b.reveal": ("Показать в Finder", "הצגה ב־Finder", "Show in Finder"),
        "b.trash": ("В корзину", "לסל האשפה", "Move to Trash"),
        "b.empty": ("Нажмите «Искать», чтобы найти большие файлы", "לחצו ״חיפוש״ כדי למצוא קבצים גדולים", "Press Scan to find large files"),
        "b.name": ("Имя", "שם", "Name"),
        "b.size": ("Размер", "גודל", "Size"),
        "b.date": ("Изменён", "שונה", "Modified"),
        "b.where": ("Где", "מיקום", "Location"),
        "b.confirm": ("Переместить выбранное в корзину?", "להעביר את הנבחרים לסל האשפה?", "Move the selected files to the Trash?"),
        "b.confirmHint": ("Файлы можно будет вернуть из корзины.", "אפשר יהיה לשחזר אותם מהסל.", "You can restore them from the Trash."),

        "w.subtitle": ("Полезные скрытые настройки. Всё можно вернуть обратно.", "הגדרות נסתרות שימושיות. אפשר להחזיר הכל.", "Handy hidden settings. Everything can be reverted."),
        "w.finder": ("Finder", "Finder", "Finder"),
        "w.hidden": ("Показывать скрытые файлы", "הצגת קבצים נסתרים", "Show hidden files"),
        "w.ext": ("Показывать расширения всех файлов", "הצגת סיומות של כל הקבצים", "Show all file extensions"),
        "w.pathbar": ("Строка пути внизу окна", "שורת נתיב בתחתית החלון", "Path bar at the bottom"),
        "w.statusbar": ("Строка состояния (свободное место)", "שורת מצב (מקום פנוי)", "Status bar (free space)"),
        "w.dsstore": ("Не оставлять .DS_Store на флешках и сетевых дисках", "לא ליצור ‎.DS_Store בדיסק און קי ובכונני רשת", "No .DS_Store on USB and network drives"),
        "w.dock": ("Dock", "Dock", "Dock"),
        "w.dockAutohide": ("Автоматически прятать Dock", "הסתרה אוטומטית של ה־Dock", "Automatically hide the Dock"),
        "w.dockFast": ("Dock появляется без задержки", "ה־Dock מופיע בלי השהיה", "Dock appears without delay"),
        "w.shots": ("Снимки экрана", "צילומי מסך", "Screenshots"),
        "w.shotShadow": ("Без тени на снимках окон", "בלי צל בצילומי חלונות", "No shadow on window screenshots"),
        "w.shotFormat": ("Формат", "פורמט", "Format"),
        "w.shotFolder": ("Папка для снимков", "תיקייה לצילומים", "Screenshot folder"),
        "w.applied": ("Применено", "הוחל", "Applied"),

        "l.subtitle": ("Что делала программа", "מה התוכנה ביצעה", "What the app did"),
        "l.clear": ("Очистить", "ניקוי", "Clear"),
        "l.copy": ("Копировать", "העתקה", "Copy"),
        "l.empty": ("Пока пусто", "עדיין ריק", "Nothing yet"),

        "c.cancel": ("Отмена", "ביטול", "Cancel"),
        "c.error": ("Ошибка", "שגיאה", "Error"),
    ]

    static func get(_ key: String, _ lang: Lang) -> String {
        guard let v = table[key] else { return key }
        switch lang {
        case .ru: return v.0
        case .he: return v.1
        case .en: return v.2
        }
    }
}
