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
}

/// Built-in translations: key -> (ru, he, en)
enum Strings {
    static let table: [String: (String, String, String)] = [
        "menu.new": ("Новое шоу", "מופע חדש", "New show"),
        "menu.open": ("Открыть шоу…", "פתיחת מופע…", "Open show…"),
        "menu.saveAs": ("Сохранить шоу как…", "שמירת מופע בשם…", "Save show as…"),

        "ui.screen2": ("Экран 2", "מסך 2", "Screen 2"),
        "ui.screen2help": ("Открыть окно для второго монитора", "פתיחת חלון למסך השני", "Open a window for the second monitor"),
        "s2.programmer": ("Группы и программер", "קבוצות ופרוגרמר", "Groups & programmer"),
        "s2.buttons": ("Кнопки", "כפתורים", "Buttons"),
        "side.colors": ("Цвета", "צבעים", "Colors"),
        "s2.clock": ("Часы", "שעון", "Clock"),
        "cm.noGroups": ("Сначала создайте группы", "קודם צרו קבוצות", "Create groups first"),
        "cm.off": ("Убрать цвет", "הסרת צבע", "Remove color"),
        "midi.help": ("MIDI Learn: привязать кнопки и фейдеры MIDI-пульта", "MIDI Learn: חיבור כפתורים ופיידרים של בקר MIDI", "MIDI Learn: map controller buttons and faders"),
        "midi.hint": ("MIDI Learn: нажмите кнопку или MIDI над фейдером, потом двиньте ручку на пульте", "MIDI Learn: לחצו על כפתור או MIDI מעל פיידר, ואז הזיזו בבקר", "MIDI Learn: click a button or MIDI above a fader, then move a control"),
        "midi.waiting": ("Двиньте ручку на пульте для", "הזיזו בבקר עבור", "Move a control for"),
        "midi.learnThis": ("Привязать MIDI…", "חיבור MIDI…", "Learn MIDI…"),
        "midi.noDevices": ("MIDI-устройств нет", "אין התקני MIDI", "No MIDI devices"),
        "midi.learnGM": ("MIDI → GM", "MIDI → GM", "MIDI → GM"),
        "midi.learnBO": ("MIDI → Blackout", "MIDI → Blackout", "MIDI → Blackout"),
        "midi.clear": ("Сбросить MIDI", "איפוס MIDI", "Clear MIDI"),
        "ui.page": ("Страница", "עמוד", "Page"),
        "ui.name": ("Название", "שם", "Name"),
        "ui.done": ("Готово", "סיום", "Done"),
        "ui.sec": ("сек", "שנ׳", "sec"),
        "ui.language": ("Язык", "שפה", "Language"),
        "ui.theme": ("Тема", "ערכת נושא", "Theme"),
        "theme.dark": ("Тёмная", "כהה", "Dark"),
        "theme.light": ("Светлая", "בהירה", "Light"),

        "rec.hint": ("Запись: нажмите кнопку или REC над фейдером", "הקלטה: לחצו על כפתור או REC מעל פיידר", "Record: press a button or REC above a fader"),
        "out.ok": ("DMX выход работает", "יציאת DMX פועלת", "DMX output is running"),
        "out.none": ("Нет DMX выхода — откройте настройки", "אין יציאת DMX — פתחו הגדרות", "No DMX output — open Settings"),

        "msg.selectFirst": ("Сначала выберите приборы", "קודם בחרו גופים", "Select fixtures first"),
        "msg.programmerEmpty": ("Программер пуст — нечего записывать", "הפרוגרמר ריק — אין מה להקליט", "Programmer is empty — nothing to record"),
        "msg.saved": ("Шоу сохранено", "המופע נשמר", "Show saved"),
        "msg.openFailed": ("Не удалось открыть", "הפתיחה נכשלה", "Could not open"),

        "side.groups": ("Группы", "קבוצות", "Groups"),
        "side.fixtures": ("Приборы", "גופים", "Fixtures"),
        "sel.none": ("Ничего не выбрано", "לא נבחר כלום", "Nothing selected"),
        "sel.count": ("Выбрано", "נבחרו", "Selected"),
        "sel.clear": ("Снять выбор", "ביטול בחירה", "Deselect"),

        "grp.new": ("Группа из выбранных", "קבוצה מהנבחרים", "Group from selection"),
        "grp.rename": ("Переименовать", "שינוי שם", "Rename"),
        "grp.update": ("Заменить на выбранные приборы", "החלפה בגופים הנבחרים", "Replace with selected fixtures"),
        "grp.master": ("Мастер на фейдер", "מאסטר לפיידר", "Master on fader"),
        "grp.delete": ("Удалить группу", "מחיקת קבוצה", "Delete group"),

        "fx.noFixtures": ("Приборов пока нет", "עדיין אין גופים", "No fixtures yet"),
        "fx.openPatch": ("Открыть Patch", "פתיחת Patch", "Open Patch"),
        "fx.size": ("Размер", "גודל", "Size"),
        "fx.spread": ("Разброс", "פיזור", "Spread"),
        "fx.steps": ("Шагов", "צעדים", "Steps"),
        "fx.add": ("Добавить эффект к выбранным", "הוספת אפקט לנבחרים", "Add effect to selection"),

        "prog.selectHint": ("Выберите группу или приборы сверху", "בחרו קבוצה או גופים למעלה", "Select a group or fixtures above"),
        "prog.noAttrs": ("У выбранных приборов нет таких каналов", "לגופים הנבחרים אין ערוצים כאלה", "Selected fixtures have no such channels"),
        "prog.clearFamily": ("Очистить", "ניקוי", "Clear"),
        "pos.center": ("В центр", "למרכז", "Center"),

        "cl.edit": ("Редактировать…", "עריכה…", "Edit…"),
        "cl.mode": ("Режим", "מצב", "Mode"),
        "mode.toggle": ("Вкл/Выкл", "הפעלה/כיבוי", "Toggle"),
        "mode.flash": ("Flash (пока держу)", "Flash (בלחיצה)", "Flash (hold)"),
        "mode.go": ("Go (следующая сцена)", "Go (הסצנה הבאה)", "Go (next cue)"),
        "cl.color": ("Цвет", "צבע", "Color"),
        "cl.toFader": ("На фейдер", "לפיידר", "To fader"),
        "cl.release": ("Выключить", "כיבוי", "Release"),
        "cl.removeButton": ("Убрать с кнопки", "הסרה מהכפתור", "Remove from button"),
        "cl.delete": ("Удалить кьюлист", "מחיקת רשימה", "Delete cuelist"),
        "cl.recordHere": ("Записать программер сюда", "הקלטת הפרוגרמר לכאן", "Record programmer here"),
        "cl.placeExisting": ("Поставить кьюлист", "הצבת רשימה קיימת", "Place cuelist"),
        "cl.fadeOut": ("Затухание при выключении", "דעיכה בכיבוי", "Fade out"),
        "cl.fadeIn": ("Fade", "Fade", "Fade"),
        "cl.chase": ("Чейз (сцены идут сами)", "צ׳ייס (סצנות רצות לבד)", "Chase (cues run by themselves)"),
        "cl.cues": ("Сцены", "סצנות", "Cues"),
        "cl.tip": ("▶ включить сцену · ⤓ загрузить в программер · ⤒ записать программер в сцену", "▶ הפעלה · ⤓ טעינה לפרוגרמר · ⤒ הקלטת הפרוגרמר לסצנה", "▶ play cue · ⤓ load to programmer · ⤒ store programmer into cue"),
        "cue.play": ("Включить эту сцену", "הפעלת הסצנה", "Play this cue"),
        "cue.load": ("Загрузить в программер", "טעינה לפרוגרמר", "Load into programmer"),
        "cue.replace": ("Записать программер в эту сцену", "הקלטת הפרוגרמר לסצנה זו", "Store programmer into this cue"),
        "cue.replaced": ("Сцена обновлена", "הסצנה עודכנה", "Cue updated"),

        "fd.none": ("Пусто", "ריק", "Empty"),
        "fd.cuelist": ("Кьюлист", "רשימת סצנות", "Cuelist"),
        "fd.groupMaster": ("Мастер группы", "מאסטר קבוצה", "Group master"),

        "set.title": ("Настройки", "הגדרות", "Settings"),
        "set.showName": ("Название шоу", "שם המופע", "Show name"),
        "set.outputs": ("Выходы DMX", "יציאות DMX", "DMX outputs"),
        "set.refreshPorts": ("Обновить порты", "רענון פורטים", "Refresh ports"),
        "set.addOutput": ("Добавить выход", "הוספת יציאה", "Add output"),
        "set.universe": ("Юниверс", "יוניברס", "Universe"),
        "set.choosePort": ("— выберите USB —", "— בחרו USB —", "— choose USB —"),
        "set.help1": ("Enttec DMX USB Pro и Open DMX появляются как usbserial-XXXX. Если порта нет — переподключите кабель и нажмите «Обновить порты».", "Enttec DMX USB Pro ו־Open DMX מופיעים כ־usbserial-XXXX. אם אין פורט — חברו מחדש ולחצו ״רענון פורטים״.", "Enttec DMX USB Pro and Open DMX show up as usbserial-XXXX. If missing, replug and press Refresh ports."),
        "set.help2": ("Дешёвые «Enttec-совместимые» шнурки без процессора — выбирайте Open DMX. С синей коробкой Pro — Enttec Pro.", "כבלים זולים ״תואמי Enttec״ בלי מעבד — בחרו Open DMX. קופסת Pro — Enttec Pro.", "Cheap “Enttec-compatible” cables without a processor: choose Open DMX. Pro box: Enttec Pro."),
        "set.help3": ("Art-Net — для сетевых узлов DMX (кабель LAN).", "Art-Net — לממירי רשת DMX (כבל רשת).", "Art-Net — for network DMX nodes (LAN cable)."),

        "patch.fixtures": ("Приборы", "גופים", "Fixtures"),
        "patch.profiles": ("Профили", "פרופילים", "Profiles"),
        "patch.profile": ("Профиль", "פרופיל", "Profile"),
        "patch.address": ("Адрес", "כתובת", "Address"),
        "patch.conflict": ("Красные — адреса пересекаются", "אדום — כתובות חופפות", "Red — overlapping addresses"),
        "patch.count": ("приборов", "גופים", "fixtures"),
        "patch.delete": ("Удалить", "מחיקה", "Delete"),
        "patch.edit": ("Выбранный прибор", "הגוף הנבחר", "Selected fixture"),
        "patch.add": ("Добавить приборы", "הוספת גופים", "Add fixtures"),
        "patch.howMany": ("Сколько", "כמה", "How many"),
        "patch.startNumber": ("Номер первого", "מספר ראשון", "First number"),
        "patch.nextFree": ("Следующий свободный", "הבא הפנוי", "Next free"),
        "patch.channels": ("каналов", "ערוצים", "channels"),
        "patch.makeGroup": ("Сразу сделать группу", "ליצור קבוצה מיד", "Create a group too"),
        "patch.addButton": ("Добавить", "הוספה", "Add"),

        "prof.new": ("Новый", "חדש", "New"),
        "prof.duplicate": ("Копия", "שכפול", "Duplicate"),
        "prof.inUse": ("Нельзя удалить профиль, который используется", "אי אפשר למחוק פרופיל בשימוש", "A profile in use can't be deleted"),
        "prof.hint": ("Каналы по порядку, как в инструкции прибора (DMX mode). Default — значение, когда канал не управляется.", "ערוצים לפי הסדר, כמו במדריך הגוף (DMX mode). Default — ערך כשהערוץ לא בשליטה.", "Channels in order, as in the fixture manual (DMX mode). Default is the value when not controlled."),
        "prof.default": ("Default", "Default", "Default"),
        "prof.addChannel": ("Добавить канал", "הוספת ערוץ", "Add channel"),
        "prof.select": ("Выберите профиль слева", "בחרו פרופיל משמאל", "Select a profile on the left"),
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
